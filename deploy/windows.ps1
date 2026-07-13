#Requires -Version 7

param(
    [Parameter(Mandatory = $false)]
    [string] $WorkspaceName,

    [Parameter(Mandatory = $false)]
    [string] $SshPublicKey,

    [Parameter(Mandatory = $true)]
    [string] $AdminEmail,

    [Parameter(Mandatory = $true)]
    [string] $AdminPassword,

    [Parameter(Mandatory = $false)]
    [switch] $Gpu = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Observability = $false,

    [Parameter(Mandatory = $false)]
    [switch] $NoBws = $false,

    [Parameter(Mandatory = $false)]
    [switch] $SkipHosts = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Node = $false,

    [Parameter(Mandatory = $false)]
    [switch] $NodeFrontend = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Java = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Rust = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Lua = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Cpp = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Clojure = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Go = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Kotlin = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Ruby = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Php = $false,

    [Parameter(Mandatory = $false)]
    [switch] $Swift = $false,

    [Parameter(Mandatory = $false)]
    [int] $NginxProxyPort = 80,

    [Parameter(Mandatory = $false)]
    [int] $SshPort = 2222,

    [Parameter(Mandatory = $false)]
    [int] $OtelGrpcPort = 4317,

    [Parameter(Mandatory = $false)]
    [int] $OtelHttpPort = 4318,

    [Parameter(Mandatory = $false)]
    [string] $Profiles = ""
)

function Show-Usage {
    Write-Host @'
Usage: .\deploy\windows.ps1 [OPTIONS]

Options:
  -WorkspaceName NAME              Workspace name (required)
  -SshPublicKey KEY                SSH public key (required)
  -AdminEmail EMAIL                Admin email for SigNoz and Vault (required)
  -AdminPassword PASSWORD          Admin password for SigNoz and Vault (required)
  -Gpu                             Enable GPU support (default: $false)
  -Observability                   Enable observability stack: SigNoz, Fluent Bit, OTel Collector, cAdvisor (default: $false)
  -NoBws                           Skip Bitwarden token prompt, use Vault UI only (default: $false)
  -SkipHosts                       Skip hosts-file auto-provisioning prompt, print manual instructions only (default: $false)
  -Node                            Install Node.js SDK (default: $false)
  -NodeFrontend                    Install Node.js + front-end tools: Angular CLI, Vite, TypeScript (default: $false; auto-enables -Node)
  -Java                            Install Java JDK 21 via Temurin (default: $false)
  -Rust                            Install Rust via rustup (default: $false)
  -Lua                             Install Lua 5.4 + luarocks (default: $false)
  -Cpp                             Install C++ build tools: clang, cmake, build-essential (default: $false)
  -Clojure                         Install Clojure CLI (default: $false; auto-enables -Java)
  -Go                              Install Go SDK (default: $false)
  -Kotlin                          Install Kotlin via SDKMAN (default: $false; auto-enables -Java)
  -Ruby                            Install Ruby via rbenv (default: $false)
  -Php                             Install PHP 8.2 + Composer (default: $false)
  -Swift                           Install Swift SDK (default: $false)
  -NginxProxyPort PORT             Nginx reverse-proxy port (default: 80)
  -SshPort PORT                    SSH server port (default: 2222)
  -OtelGrpcPort PORT               OTel Collector gRPC (OTLP) port — observability only (default: 4317)
  -OtelHttpPort PORT               OTel Collector HTTP (OTLP) port — observability only (default: 4318)
  -Profiles PROFILES               Comma-separated server profiles: vscode,jupyter,devcontainer,tunnel,portainer

Examples:
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..." -AdminEmail admin@example.com -AdminPassword MyPass1!
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..." -AdminEmail admin@example.com -AdminPassword MyPass1! -Gpu -Profiles vscode
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..." -AdminEmail admin@example.com -AdminPassword MyPass1! -Observability
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..." -AdminEmail admin@example.com -AdminPassword MyPass1! -NoBws
  .\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..." -AdminEmail admin@example.com -AdminPassword MyPass1! -Java -Rust -NodeFrontend -Go
'@
}

if ([string]::IsNullOrWhiteSpace($WorkspaceName) -or [string]::IsNullOrWhiteSpace($SshPublicKey) -or
    [string]::IsNullOrWhiteSpace($AdminEmail) -or [string]::IsNullOrWhiteSpace($AdminPassword)) {
    Write-Error "Error: -WorkspaceName, -SshPublicKey, -AdminEmail and -AdminPassword are required"
    Show-Usage
    exit 1
}

# Validate admin password meets SigNoz requirements (12+ chars, upper, lower, digit, symbol)
if ($AdminPassword.Length -lt 12 -or
    -not ($AdminPassword -cmatch '[A-Z]') -or
    -not ($AdminPassword -cmatch '[a-z]') -or
    -not ($AdminPassword -cmatch '[0-9]') -or
    -not ($AdminPassword -match '[~!@#$%^&*()\-_+=\[\]{}|;:,.<>?/]')) {
    Write-Error "Error: -AdminPassword must be at least 12 characters and contain uppercase, lowercase, number, and symbol. Required for SigNoz admin provisioning."
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

# SDK flags — auto-resolve dependencies
$NODE_FRONTEND_ENABLED = if ($NodeFrontend) { "true" } else { "false" }
$NODE_ENABLED = if ($Node -or $NodeFrontend) { "true" } else { "false" }
$JAVA_ENABLED = if ($Java -or $Clojure -or $Kotlin) { "true" } else { "false" }
$RUST_ENABLED = if ($Rust) { "true" } else { "false" }
$LUA_ENABLED = if ($Lua) { "true" } else { "false" }
$CPP_ENABLED = if ($Cpp) { "true" } else { "false" }
$CLOJURE_ENABLED = if ($Clojure) { "true" } else { "false" }
$GO_ENABLED = if ($Go) { "true" } else { "false" }
$KOTLIN_ENABLED = if ($Kotlin) { "true" } else { "false" }
$RUBY_ENABLED = if ($Ruby) { "true" } else { "false" }
$PHP_ENABLED = if ($Php) { "true" } else { "false" }
$SWIFT_ENABLED = if ($Swift) { "true" } else { "false" }

$ScriptDir = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $ScriptDir "docker\.env"

# Preserve SIGNOZ_JWT_SECRET across re-deployments
$SIGNOZ_JWT_SECRET = ""
if (Test-Path $EnvFile) {
    $envContent = Get-Content $EnvFile -Raw
    if ($envContent -match "SIGNOZ_JWT_SECRET=(.+)") {
        $SIGNOZ_JWT_SECRET = $matches[1].Trim()
    }
}
if ([string]::IsNullOrWhiteSpace($SIGNOZ_JWT_SECRET)) {
    $SIGNOZ_JWT_SECRET = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | % {[char]$_})
}
$SIGNOZ_ADMIN_EMAIL = $AdminEmail

@"
WORKSPACE_NAME=$WorkspaceName
SSH_PUBLIC_KEY=$SshPublicKey
GPU_ENABLED=$GPU_ENABLED
OBSERVABILITY_ENABLED=$OBSERVABILITY_ENABLED
NODE_ENABLED=$NODE_ENABLED
NODE_FRONTEND_ENABLED=$NODE_FRONTEND_ENABLED
JAVA_ENABLED=$JAVA_ENABLED
RUST_ENABLED=$RUST_ENABLED
LUA_ENABLED=$LUA_ENABLED
CPP_ENABLED=$CPP_ENABLED
CLOJURE_ENABLED=$CLOJURE_ENABLED
GO_ENABLED=$GO_ENABLED
KOTLIN_ENABLED=$KOTLIN_ENABLED
RUBY_ENABLED=$RUBY_ENABLED
PHP_ENABLED=$PHP_ENABLED
SWIFT_ENABLED=$SWIFT_ENABLED
NGINX_PROXY_PORT=$NginxProxyPort
SSH_PORT=$SshPort
OTEL_GRPC_PORT=$OtelGrpcPort
OTEL_HTTP_PORT=$OtelHttpPort
DEPLOY_PROFILES=$Profiles
SIGNOZ_JWT_SECRET=$SIGNOZ_JWT_SECRET
SIGNOZ_ADMIN_EMAIL=$SIGNOZ_ADMIN_EMAIL
SIGNOZ_ADMIN_PASSWORD=$AdminPassword
ADMIN_EMAIL=$AdminEmail
ADMIN_PASSWORD=$AdminPassword
"@ | Out-File -FilePath $EnvFile -Encoding UTF8

$nginxUrlSuffix = if ($NginxProxyPort -ne 80) { ":$NginxProxyPort" } else { "" }

$profileArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Profiles)) {
    foreach ($p in ($Profiles -split ',')) {
        $p = $p.Trim()
        if ($p -match '^(vscode|devcontainer|jupyter|tunnel|portainer)$') {
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

# Auto-provision hosts-file entries for the *.local URLs (Administrator-gated, idempotent)
$hostsNeeded = @("vault.$WorkspaceName.local", "aspire.$WorkspaceName.local", "bifrost.$WorkspaceName.local", "ssh.$WorkspaceName.local", "headroom.$WorkspaceName.local")
if ($Profiles -match 'vscode') { $hostsNeeded += "vscode.$WorkspaceName.local" }
if ($Profiles -match 'jupyter') { $hostsNeeded += "jupyter.$WorkspaceName.local" }
if ($Profiles -match 'portainer') { $hostsNeeded += "portainer.$WorkspaceName.local" }
if ($OBSERVABILITY_ENABLED -eq "true") { $hostsNeeded += "signoz.$WorkspaceName.local"; $hostsNeeded += "signoz-mcp.$WorkspaceName.local" }

$hostsFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsContent = if (Test-Path $hostsFilePath) { Get-Content $hostsFilePath -Raw } else { "" }
$missingHosts = @($hostsNeeded | Where-Object { $hostsContent -notmatch "(?m)(^|\s)$([regex]::Escape($_))(\s|$)" })

if ($missingHosts.Count -gt 0) {
    Write-Host ""
    Write-Host "Missing hosts file entries: $($missingHosts -join ', ')"
    $isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    if ((-not $SkipHosts) -and [Environment]::UserInteractive -and $isElevated) {
        $hostsAnswer = Read-Host "Add $($missingHosts.Count) missing entries to hosts file? Requires Administrator. [Y/n]"
        if ([string]::IsNullOrWhiteSpace($hostsAnswer) -or $hostsAnswer -match '^[Yy]$') {
            try {
                foreach ($missingHost in $missingHosts) {
                    Add-Content -Path $hostsFilePath -Value "127.0.0.1 $missingHost" -ErrorAction Stop
                }
                Write-Host "✓ Added missing entries to hosts file"
            } catch {
                Write-Warning "Could not update hosts file: $_"
            }
        }
    }
}

Write-Host ""
Write-Host "✓ Workspace started. Access:"
Write-Host "  SSH: ssh -p $SshPort user@ssh.$WorkspaceName.local"
if ($Profiles -match 'vscode') { Write-Host "  VS Code: http://vscode.$WorkspaceName.local$nginxUrlSuffix" }
if ($Profiles -match 'devcontainer') { Write-Host "  Dev Container: attach via VS Code Dev Containers extension" }
if ($Profiles -match 'tunnel') { Write-Host "  VS Code Tunnel: Remote Tunnels extension → '$WorkspaceName'" }
if ($Profiles -match 'jupyter') { Write-Host "  Jupyter: http://jupyter.$WorkspaceName.local$nginxUrlSuffix" }
Write-Host "  Vault UI: http://vault.$WorkspaceName.local$nginxUrlSuffix/ui"
if ($Profiles -match 'portainer') { Write-Host "  Portainer: http://portainer.$WorkspaceName.local$nginxUrlSuffix" }
Write-Host "  AppHost Dashboard (when AppHost is running): http://aspire.$WorkspaceName.local$nginxUrlSuffix"
Write-Host "  Bifrost UI: http://bifrost.$WorkspaceName.local$nginxUrlSuffix"
Write-Host "  Headroom Dashboard: http://headroom.$WorkspaceName.local$nginxUrlSuffix/dashboard"
if ($OBSERVABILITY_ENABLED -eq "true") { Write-Host "  SigNoz UI: http://signoz.$WorkspaceName.local$nginxUrlSuffix" }
if ($OBSERVABILITY_ENABLED -eq "true") { Write-Host "  SigNoz MCP: http://signoz-mcp.$WorkspaceName.local$nginxUrlSuffix/mcp" }
Write-Host ""
Write-Host "Note: the *.local URLs above require /etc/hosts entries — see QUICKSTART.md for the line to add."
if ($NginxProxyPort -ne 80) { Write-Host "Note: nginx-proxy is on non-default port $NginxProxyPort — the ':$NginxProxyPort' suffix above is required in the browser URL too." }
Write-Host ""
if ($BwsMode -eq "manual") {
    Write-Host "Vault started empty (no Bitwarden token). Enter secrets via Vault UI:"
    Write-Host "  1. Wait ~30s for vault-server to initialize, then open http://vault.$WorkspaceName.local$nginxUrlSuffix/ui"
    Write-Host "  2. Get root token: docker exec ${WorkspaceName}-vault-server-1 cat /vault/data/.init | jq -r .root_token"
    Write-Host "  3. Log in and add secrets under: secret/ai, secret/mcp/github, secret/mcp/azure-devops, secret/cloud, secret/integrations"
} else {
    Write-Host "Secrets bootstrapped from Bitwarden. Manage via Vault UI with root token:"
    Write-Host "  docker exec ${WorkspaceName}-vault-server-1 cat /vault/data/.init | jq -r .root_token"
}
