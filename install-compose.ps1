#Requires -Version 7
# install-compose.ps1 — ZZAIA Docker Compose installer (Windows PowerShell)
# Run once per company environment. Fetches secrets from Bitwarden, starts the stack,
# then discards all secret material — no .env file left on disk.

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

# ── Prerequisites ─────────────────────────────────────────────────────────────
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

# ── Bitwarden ─────────────────────────────────────────────────────────────────
Write-Host "→ Logging into Bitwarden..."
$s = bw login --raw
if ($LASTEXITCODE -ne 0 -or -not $s) { Write-Error "Bitwarden login failed."; exit 1 }

$items = bw list items --session $s | ConvertFrom-Json

function Get-VaultSecret {
    param($items, [string]$name)
    $val = ($items | Where-Object { $_.name -eq $name }).login.password
    if (-not $val) { Write-Warning "  Bitwarden item '$name' not found — left empty." }
    return $val
}

Write-Host "→ Fetching secrets from vault..."
$sshPublicKey          = Get-VaultSecret $items "ssh-public-key"
$tavilyApiKey          = Get-VaultSecret $items "tavily"
$adoMcpAuthToken       = Get-VaultSecret $items "azure-devops-pat"
$azureDevOpsOrg        = Get-VaultSecret $items "azure-devops-org"
$postmanApiKey         = Get-VaultSecret $items "postman"
$newRelicApiKey        = Get-VaultSecret $items "new-relic"

& bw logout 2>&1 | Out-Null
Remove-Variable s, items

if (-not $azureDevOpsOrg) {
    Write-Error "ERROR: 'azure-devops-org' is required — it becomes the compose project name."
    exit 1
}

# ── Temp env file — deleted in finally block ──────────────────────────────────
$tmpEnv = [System.IO.Path]::GetTempFileName()

try {
    $envContent = @"
SSH_PUBLIC_KEY=$sshPublicKey
TAVILY_API_KEY=$tavilyApiKey
ADO_MCP_AUTH_TOKEN=$adoMcpAuthToken
AZURE_DEVOPS_ORGANIZATION=$azureDevOpsOrg
POSTMAN_API_KEY=$postmanApiKey
NEW_RELIC_API_KEY=$newRelicApiKey
"@
    Set-Content -Path $tmpEnv -Value $envContent -Encoding UTF8

    # ── Start compose stack ───────────────────────────────────────────────────
    Write-Host "→ Starting ZZAIA stack for '$azureDevOpsOrg'..."
    & docker compose `
        -f "$ScriptDir\docker\docker-compose.yml" `
        -p $azureDevOpsOrg `
        --env-file $tmpEnv `
        up -d

    if ($LASTEXITCODE -ne 0) { Write-Error "docker compose failed."; exit 1 }

    Write-Host ''
    Write-Host "✓ ZZAIA workspace running  (project: $azureDevOpsOrg)"
    Write-Host "  VS Code : http://localhost:8080"
    Write-Host "  SSH     : ssh -p 2222 zzaia@localhost"
    Write-Host ''
    Write-Host "  Subsequent starts: use Docker Desktop or"
    Write-Host "  docker compose -f docker\docker-compose.yml -p $azureDevOpsOrg start"
    Write-Host "  To recreate containers: re-run this script."
}
finally {
    Remove-Item $tmpEnv -Force -ErrorAction SilentlyContinue
    Remove-Variable sshPublicKey, tavilyApiKey, adoMcpAuthToken, azureDevOpsOrg, postmanApiKey, newRelicApiKey -ErrorAction SilentlyContinue
}
