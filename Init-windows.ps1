# Init-windows.ps1 - ZZAIA Workspace Launcher (Windows PowerShell)
# Unlocks Bitwarden vault, loads secrets, and launches Claude Code.
#
# Usage: .\Init-windows.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  ZZAIA Agentic Workspace"
Write-Host ""

# ── Bitwarden check ───────────────────────────────────────────────────────────
if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Bitwarden CLI not found. Run Install-windows.ps1 first." -ForegroundColor Red
    exit 1
}

# ── Bitwarden login ───────────────────────────────────────────────────────────
Write-Host "[1/2] Unlocking Bitwarden vault..."

$bwStatus = ""
try {
    $bwStatus = (bw status | ConvertFrom-Json).status
} catch {
    $bwStatus = "unauthenticated"
}

if ($bwStatus -eq "unauthenticated") {
    $loginJob = Start-Job { bw login }
    if (-not (Wait-Job $loginJob -Timeout 300)) {
        Stop-Job $loginJob
        Write-Host "ERROR: Bitwarden login timed out." -ForegroundColor Red
        exit 1
    }
    Receive-Job $loginJob
}

$unlockJob = Start-Job { bw unlock --raw }
if (-not (Wait-Job $unlockJob -Timeout 120)) {
    Stop-Job $unlockJob
    Write-Host "ERROR: Bitwarden unlock timed out." -ForegroundColor Red
    exit 1
}
$bwSession = (Receive-Job $unlockJob).Trim()

function Load-Secret {
    param (
        [string]$VarName,
        [string]$ItemName
    )
    try {
        $value = (bw get password $ItemName --session $bwSession 2>$null)
        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host "WARN missing_secret item=$ItemName var=$VarName"
            return
        }
        [System.Environment]::SetEnvironmentVariable($VarName, $value, "Process")
    } catch {
        Write-Host "WARN missing_secret item=$ItemName var=$VarName"
    }
}

Load-Secret "TAVILY_API_KEY"             "tavily"
Load-Secret "ADO_MCP_AUTH_TOKEN"         "azure-devops-pat"
Load-Secret "AZURE_DEVOPS_ORGANIZATION"  "azure-devops-org"
Load-Secret "POSTMAN_API_KEY"            "postman"
Load-Secret "NEW_RELIC_API_KEY"          "new-relic"

bw lock --session $bwSession 2>$null | Out-Null
Remove-Variable -Name bwSession -ErrorAction SilentlyContinue

# ── Launch Claude Code ────────────────────────────────────────────────────────
Write-Host "[2/2] Launching Claude Code..."
Write-Host ""

claude --enable-auto-mode
