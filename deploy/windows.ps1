#Requires -Version 7

param(
    [Parameter(Mandatory = $false)]
    [string] $WorkspaceName,

    [Parameter(Mandatory = $false)]
    [string] $SshPublicKey,

    [Parameter(Mandatory = $false)]
    [switch] $Gpu = $false,

    [Parameter(Mandatory = $false)]
    [int] $VaultPort = 8200,

    [Parameter(Mandatory = $false)]
    [int] $SshPort = 2222,

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
  -VaultPort PORT                  Vault server port (default: 8200)
  -SshPort PORT                    SSH server port (default: 2222)
  -VscodePort PORT                 VS Code server port (default: 8080)
  -AspireDashboardPort PORT        Aspire Dashboard port (default: 18890)
  -JupyterPort PORT                Jupyter port (default: 8888)
  -Profiles PROFILES               Comma-separated server profiles: vscode,jupyter,devcontainer,tunnel

Examples:
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..."
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..." -Gpu -Profiles vscode
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

if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
    $BWS_ACCESS_TOKEN = Read-Host "Bitwarden Secrets Manager Access Token" -AsSecureString
    if ($null -eq $BWS_ACCESS_TOKEN -or $BWS_ACCESS_TOKEN.Length -eq 0) {
        Write-Error "Error: BWS_ACCESS_TOKEN is required"
        exit 1
    }
    $env:BWS_ACCESS_TOKEN = [System.Net.NetworkCredential]::new('', $BWS_ACCESS_TOKEN).Password
} else {
    Write-Host "Using BWS_ACCESS_TOKEN from environment"
}

$GPU_ENABLED = if ($Gpu) { "true" } else { "false" }

$ScriptDir = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $ScriptDir "docker\.env"

@"
WORKSPACE_NAME=$WorkspaceName
SSH_PUBLIC_KEY=$SshPublicKey
GPU_ENABLED=$GPU_ENABLED
VAULT_PORT=$VaultPort
SSH_PORT=$SshPort
VSCODE_PORT=$VscodePort
ASPIRE_DASHBOARD_PORT=$AspireDashboardPort
JUPYTER_PORT=$JupyterPort
DEPLOY_PROFILES=$Profiles
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

Write-Host ""
Write-Host "Starting workspace..."
$env:BWS_ACCESS_TOKEN = if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
    $BWS_ACCESS_TOKEN = Read-Host "Bitwarden Secrets Manager Access Token" -AsSecureString
    [System.Net.NetworkCredential]::new('', $BWS_ACCESS_TOKEN).Password
} else {
    $env:BWS_ACCESS_TOKEN
}

docker compose `
    -f (Join-Path $ScriptDir "docker\docker-compose.yml") `
    @gpuComposeArgs `
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
Write-Host ""
Write-Host "Configure secrets in Vault UI after login with the root token stored in vault-data volume."
