#Requires -Version 7

param(
    [Parameter(Mandatory = $false)]
    [string] $WorkspaceName,

    [Parameter(Mandatory = $false)]
    [string] $SshPublicKey,

    [Parameter(Mandatory = $false)]
    [switch] $Gpu = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Observability = $false,

    [Parameter(Mandatory = $false)]
    [switch] $NoBws = $false,

    [Parameter(Mandatory = $false)]
    [int] $VaultPort = 8200,

    [Parameter(Mandatory = $false)]
    [int] $SshPort = 2222,

    [Parameter(Mandatory = $false)]
    [int] $SignozPort = 3301,

    [Parameter(Mandatory = $false)]
    [int] $VscodePort = 8080,

    [Parameter(Mandatory = $false)]
    [int] $AspireDashboardPort = 18890,

    [Parameter(Mandatory = $false)]
    [int] $JupyterPort = 8888,

    [Parameter(Mandatory = $false)]
    [string] $Profiles = ""
)

function Show-Usage {
    Write-Host @'
Usage: .\deploy\windows.ps1 [OPTIONS]

Options:
  -WorkspaceName NAME              Workspace name (required)
  -SshPublicKey KEY                SSH public key (required)
  -Gpu                             Enable GPU support (default: $false)
  -Observability                   Enable observability stack: SigNoz, Fluent Bit, OTel Collector, cAdvisor (default: $false)
  -NoBws                           Skip Bitwarden token prompt, use Vault UI only (default: $false)
  -VaultPort PORT                  Vault server port (default: 8200)
  -SshPort PORT                    SSH server port (default: 2222)
  -SignozPort PORT                 SigNoz UI port (default: 3301)
  -VscodePort PORT                 VS Code server port (default: 8080)
  -AspireDashboardPort PORT        Aspire Dashboard port (default: 18890)
  -JupyterPort PORT                Jupyter port (default: 8888)
  -Profiles PROFILES               Comma-separated server profiles: vscode,jupyter,devcontainer,tunnel

Examples:
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..."
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..." -Gpu -Profiles vscode
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..." -Observability -SignozPort 3301
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..." -NoBws
'@
}

if ([string]::IsNullOrWhiteSpace($WorkspaceName) -or [string]::IsNullOrWhiteSpace($SshPublicKey)) {
    Write-Error "Error: -WorkspaceName and -SshPublicKey are required"
    Show-Usage
    exit 1
}

Write-Host ''
Write-Host '  ███████╗███████╗ █████╗ ██╗ █████╗ '
Write-Host '     ███╔╝   ███╔╝██╔══██╗██║██╔══██╗'
Write-Host '    ███╔╝   ███╔╝ ███████║██║███████║ '
Write-Host '   ███╔╝   ███╔╝  ██╔══██║██║██╔══██║ '
Write-Host '  ███████╗███████╗██║  ██║██║██║  ██║ '
Write-Host '  ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝'
Write-Host ''
Write-Host '         ⚡  Agentic Workspace  ⚡'
Write-Host ''

$BwsMode = "bitwarden"
if ($NoBws) {
    $env:BWS_ACCESS_TOKEN = ""
    $BwsMode = "manual"
} elseif ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
    $BWS_ACCESS_TOKEN = Read-Host "Bitwarden Secrets Manager Access Token (press Enter to skip — use Vault UI)" -AsSecureString
    $BwsPlain = [System.Net.NetworkCredential]::new('', $BWS_ACCESS_TOKEN).Password
    if ([string]::IsNullOrWhiteSpace($BwsPlain)) {
        $BwsMode = "manual"
        $env:BWS_ACCESS_TOKEN = ""
    } else {
        $env:BWS_ACCESS_TOKEN = $BwsPlain
    }
} else {
    Write-Host "Using BWS_ACCESS_TOKEN from environment"
}

$GPU_ENABLED = if ($Gpu) { "true" } else { "false" }
$OBSERVABILITY_ENABLED = if ($Observability) { "true" } else { "false" }

$ScriptDir = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $ScriptDir "docker\.env"

# Preserve SIGNOZ_JWT_SECRET and SIGNOZ_ADMIN_PASSWORD across re-deployments
$SIGNOZ_JWT_SECRET = ""
$SIGNOZ_ADMIN_PASSWORD = ""
if (Test-Path $EnvFile) {
    $envContent = Get-Content $EnvFile -Raw
    if ($envContent -match "SIGNOZ_JWT_SECRET=(.+)") {
        $SIGNOZ_JWT_SECRET = $matches[1].Trim()
    }
    if ($envContent -match "SIGNOZ_ADMIN_PASSWORD=(.+)") {
        $SIGNOZ_ADMIN_PASSWORD = $matches[1].Trim()
    }
}
if ([string]::IsNullOrWhiteSpace($SIGNOZ_JWT_SECRET)) {
    $SIGNOZ_JWT_SECRET = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | % {[char]$_})
}
if ([string]::IsNullOrWhiteSpace($SIGNOZ_ADMIN_PASSWORD)) {
    $randomPart = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | % {[char]$_})
    $SIGNOZ_ADMIN_PASSWORD = "Admin@$randomPart!"
}

@"
WORKSPACE_NAME=$WorkspaceName
SSH_PUBLIC_KEY=$SshPublicKey
GPU_ENABLED=$GPU_ENABLED
OBSERVABILITY_ENABLED=$OBSERVABILITY_ENABLED
VAULT_PORT=$VaultPort
SSH_PORT=$SshPort
SIGNOZ_PORT=$SignozPort
VSCODE_PORT=$VscodePort
ASPIRE_DASHBOARD_PORT=$AspireDashboardPort
JUPYTER_PORT=$JupyterPort
DEPLOY_PROFILES=$Profiles
SIGNOZ_JWT_SECRET=$SIGNOZ_JWT_SECRET
SIGNOZ_ADMIN_PASSWORD=$SIGNOZ_ADMIN_PASSWORD
"@ | Out-File -FilePath $EnvFile -Encoding UTF8

$profileArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Profiles)) {
    foreach ($p in ($Profiles -split ',')) {
        $p = $p.Trim()
        if ($p -match '^(vscode|devcontainer|jupyter|tunnel)$') {
            $profileArgs += '--profile'
            $profileArgs += $p
        } else {
            Write-Warning "Unknown server profile '$p' — valid: vscode, devcontainer, jupyter, tunnel"
        }
    }
}

$gpuComposeArgs = @()
if ($GPU_ENABLED -eq "true") {
    $gpuComposeArgs = @('-f', (Join-Path $ScriptDir "docker\docker-compose.gpu.yml"))
}

$observabilityComposeArgs = @()
if ($OBSERVABILITY_ENABLED -eq "true") {
    $observabilityComposeArgs = @('-f', (Join-Path $ScriptDir "docker\docker-compose.observability.yml"))
}

Write-Host ""
Write-Host "Starting workspace..."

docker compose `
    -f (Join-Path $ScriptDir "docker\docker-compose.yml") `
    @gpuComposeArgs `
    @observabilityComposeArgs `
    -p $WorkspaceName `
    @profileArgs `
    up -d

Remove-Item "Env:BWS_ACCESS_TOKEN" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "✓ Workspace started. Access:"
Write-Host "  SSH: ssh -p $SshPort user@localhost"
if ($Profiles -match 'vscode') { Write-Host "  VS Code: http://localhost:$VscodePort" }
if ($Profiles -match 'devcontainer') { Write-Host "  Dev Container: attach via VS Code Dev Containers extension" }
if ($Profiles -match 'tunnel') { Write-Host "  VS Code Tunnel: Remote Tunnels extension → '$WorkspaceName'" }
Write-Host "  Vault UI: http://localhost:$VaultPort/ui"
Write-Host "  AppHost Dashboard (when AppHost is running): http://localhost:$AspireDashboardPort"
if ($OBSERVABILITY_ENABLED -eq "true") { Write-Host "  SigNoz UI: http://localhost:$SignozPort" }
Write-Host ""
if ($BwsMode -eq "manual") {
    Write-Host "Vault started empty (no Bitwarden token). Enter secrets via Vault UI:"
    Write-Host "  1. Wait ~30s for vault-server to initialize, then open http://localhost:$VaultPort/ui"
    Write-Host "  2. Get root token: docker exec ${WorkspaceName}-vault-server-1 cat /vault/data/.init | jq -r .root_token"
    Write-Host "  3. Log in and add secrets under: secret/ai, secret/mcp/github, secret/mcp/azure-devops, secret/cloud, secret/integrations"
} else {
    Write-Host "Secrets bootstrapped from Bitwarden. Manage via Vault UI with root token:"
    Write-Host "  docker exec ${WorkspaceName}-vault-server-1 cat /vault/data/.init | jq -r .root_token"
}
