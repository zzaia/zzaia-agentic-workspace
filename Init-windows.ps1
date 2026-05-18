#Requires -Version 7
# Init-windows.ps1 - ZZAIA Workspace Launcher (Windows PowerShell)
param(
    [Parameter(Mandatory)][string]$SessionName,
    [switch]$FullAutomatic
)

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

if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Error "Bitwarden CLI 'bw' not found. Install it before running this script."
    exit 1
}

$s = bw login --raw
if ($LASTEXITCODE -ne 0 -or -not $s) {
    Write-Error "Bitwarden login failed."
    exit 1
}

$items = bw list items --session $s | ConvertFrom-Json

function Get-VaultSecret {
    param($items, [string]$name)
    $val = ($items | Where-Object { $_.name -eq $name }).login.password
    if (-not $val) { Write-Warning "Vault item '$name' not found or has no password." }
    return $val
}

$env:TAVILY_API_KEY             = Get-VaultSecret $items "tavily"
$env:ADO_MCP_AUTH_TOKEN         = Get-VaultSecret $items "azure-devops-pat"
$env:AZURE_DEVOPS_ORGANIZATION  = Get-VaultSecret $items "azure-devops-org"
$env:POSTMAN_API_KEY            = Get-VaultSecret $items "postman"
$env:NEW_RELIC_API_KEY          = Get-VaultSecret $items "new-relic"
$env:GITHUB_PERSONAL_ACCESS_TOKEN = Get-VaultSecret $items "github-personal-access-token"
$env:AWS_ACCESS_KEY_ID          = Get-VaultSecret $items "aws-access-key-id"
$env:AWS_SECRET_ACCESS_KEY      = Get-VaultSecret $items "aws-secret-access-key"
$env:AWS_REGION                 = Get-VaultSecret $items "aws-region"

& bw logout 2>&1 | Out-Null
Remove-Variable s, items

$env:CLAUDE_CONFIG_DIR = "$PSScriptRoot\.claude"

$claudeFlags = if ($FullAutomatic) { "--dangerously-skip-permissions" } else { $null }

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    Write-Error "Python launcher 'py' not found. Install Python from python.org."
    exit 1
}

$sessionUuid = & py -c 'import uuid, sys; print(uuid.uuid5(uuid.NAMESPACE_DNS, sys.argv[1] + sys.argv[2]))' $SessionName $env:AZURE_DEVOPS_ORGANIZATION
if (-not $sessionUuid) {
    Write-Error "Failed to generate session UUID."
    exit 1
}

if ($claudeFlags) {
    & claude $claudeFlags --resume $sessionUuid
    if ($LASTEXITCODE -ne 0) {
        & claude $claudeFlags --session-id $sessionUuid
    }
} else {
    & claude --resume $sessionUuid
    if ($LASTEXITCODE -ne 0) {
        & claude --session-id $sessionUuid
    }
}
