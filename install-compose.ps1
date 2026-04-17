#Requires -Version 7
# install-compose.ps1 — ZZAIA Docker Compose installer (Windows PowerShell)
# Run once per environment. Fetches secrets from Bitwarden and passes them
# via process environment — nothing written to disk.

Write-Host ''
Write-Host '  ███████╗███████╗ █████╗ ██╗ █████╗ '
Write-Host '     ███╔╝   ███╔╝██╔══██╗██║██╔══██╗'
Write-Host '    ███╔╝   ███╔╝ ███████║██║███████║ '
Write-Host '   ███╔╝   ███╔╝  ██╔══██║██║██╔══██║ '
Write-Host '  ███████╗███████╗██║  ██║██║██║  ██║ '
Write-Host '  ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝'
Write-Host ''
Write-Host '         ⚡  Docker Compose Installer  ⚡'
Write-Host ''

foreach ($cmd in @('bw', 'docker')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        $hints = @{
            'bw'     = "winget install --id Bitwarden.BitwardenCLI"
            'docker' = "Install Docker Desktop from https://www.docker.com/products/docker-desktop"
        }
        Write-Error "ERROR: '$cmd' not found. $($hints[$cmd])"
        exit 1
    }
}

$ScriptDir = $PSScriptRoot

# ── Bitwarden — unlock if already logged in, login otherwise ──────────────────
Write-Host "→ Unlocking Bitwarden vault..."
$s = & bw unlock --raw 2>&1
if ($LASTEXITCODE -ne 0) {
    $s = & bw login --raw
    if ($LASTEXITCODE -ne 0 -or -not $s) { Write-Error "Bitwarden login failed."; exit 1 }
}
if (-not $s) { Write-Error "Failed to obtain a Bitwarden session."; exit 1 }

$items = & bw list items --session $s | ConvertFrom-Json
if (-not $items) { Write-Error "Failed to list vault items — check your session."; exit 1 }

function Get-VaultSecret {
    param($items, [string]$name)
    $val = ($items | Where-Object { $_.name -eq $name }).login.password
    if (-not $val) { Write-Warning "  Bitwarden item '$name' not found — left empty." }
    if ($val -match "`n") { Write-Error "Bitwarden item '$name' contains a newline."; exit 1 }
    return $val
}

Write-Host "→ Fetching secrets from vault..."
$sshPublicKey         = Get-VaultSecret $items "ssh-public-key"
$tavilyApiKey         = Get-VaultSecret $items "tavily"
$adoMcpAuthToken      = Get-VaultSecret $items "azure-devops-pat"
$azureDevOpsOrg       = Get-VaultSecret $items "azure-devops-org"
$postmanApiKey        = Get-VaultSecret $items "postman"
$newRelicApiKey       = Get-VaultSecret $items "new-relic"

& bw logout 2>&1 | Out-Null
$s = $null; $items = $null

if (-not $azureDevOpsOrg) { Write-Error "ERROR: 'azure-devops-org' is required."; exit 1 }

try {
    $env:SSH_PUBLIC_KEY            = $sshPublicKey
    $env:TAVILY_API_KEY            = $tavilyApiKey
    $env:ADO_MCP_AUTH_TOKEN        = $adoMcpAuthToken
    $env:AZURE_DEVOPS_ORGANIZATION = $azureDevOpsOrg
    $env:POSTMAN_API_KEY           = $postmanApiKey
    $env:NEW_RELIC_API_KEY         = $newRelicApiKey

    Write-Host "→ Starting ZZAIA stack..."
    & docker compose `
        -f "$ScriptDir\docker\docker-compose.yml" `
        -p $azureDevOpsOrg `
        up -d

    if ($LASTEXITCODE -ne 0) { Write-Error "docker compose failed."; exit 1 }

    Write-Host ''
    Write-Host "✓ ZZAIA workspace running"
    Write-Host "  VS Code : http://localhost:8080"
    Write-Host "  SSH     : ssh -p 2222 zzaia@localhost"
    Write-Host ''
    Write-Host "  Subsequent starts: use Docker Desktop or"
    Write-Host "  docker compose -f docker\docker-compose.yml start"
    Write-Host "  To recreate containers: re-run this script."
}
finally {
    # jq not needed on Windows — ConvertFrom-Json is built-in (intentional)
    'SSH_PUBLIC_KEY','TAVILY_API_KEY','ADO_MCP_AUTH_TOKEN','AZURE_DEVOPS_ORGANIZATION',
    'POSTMAN_API_KEY','NEW_RELIC_API_KEY' | ForEach-Object {
        Remove-Item "Env:$_" -ErrorAction SilentlyContinue
    }
    $sshPublicKey = $tavilyApiKey = $adoMcpAuthToken = $azureDevOpsOrg = $postmanApiKey = $newRelicApiKey = $null
}
