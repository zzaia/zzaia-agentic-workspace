# Init-windows.ps1 - ZZAIA Workspace Launcher (Windows PowerShell)
# Installs Bitwarden CLI if missing, loads secrets, and launches Claude Code.
#
# Usage: .\Init-windows.ps1

Write-Host ""
Write-Host "  ZZAIA Agentic Workspace"
Write-Host ""

# ── Bitwarden login ───────────────────────────────────────────────────────────
if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Bitwarden CLI not found. Run Install-windows.ps1 first."
    exit 1
}

Write-Host "[1/2] Unlocking Bitwarden vault..."

$bwStatus = ""
try {
    $bwStatus = (bw status | ConvertFrom-Json).status
} catch {
    $bwStatus = "unauthenticated"
}

if ($bwStatus -eq "unauthenticated") {
    bw login
}

$env:BW_SESSION = (bw unlock --raw)

function Load-Secret {
    param (
        [string]$VarName,
        [string]$ItemName
    )
    try {
        $value = (bw get password $ItemName --session $env:BW_SESSION 2>$null)
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

bw lock --session $env:BW_SESSION 2>$null | Out-Null

# ── Launch Claude Code ────────────────────────────────────────────────────────
Write-Host "[2/2] Launching Claude Code..."
Write-Host ""

claude --enable-auto-mode
