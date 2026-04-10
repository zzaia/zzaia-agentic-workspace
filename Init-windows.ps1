# Init-windows.ps1 - ZZAIA Workspace Launcher (Windows PowerShell)
# Installs Bitwarden CLI if missing, loads secrets, and launches Claude Code.
#
# Usage: .\Init-windows.ps1

Write-Host ""
Write-Host "  ZZAIA Agentic Workspace"
Write-Host ""

# ── Bitwarden CLI ─────────────────────────────────────────────────────────────
if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Host "[1/3] Installing Bitwarden CLI..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Bitwarden.BitwardenCLI --accept-source-agreements --accept-package-agreements
    } else {
        $bwVersion = (Invoke-RestMethod "https://api.github.com/repos/bitwarden/clients/releases/latest").tag_name -replace "cli-v", ""
        $bwUrl = "https://github.com/bitwarden/clients/releases/download/cli-v$bwVersion/bw-windows-$bwVersion.zip"
        Invoke-WebRequest -Uri $bwUrl -OutFile "$env:TEMP\bw.zip"
        Expand-Archive -Path "$env:TEMP\bw.zip" -DestinationPath "$env:TEMP\bw-cli" -Force
        Move-Item "$env:TEMP\bw-cli\bw.exe" "$env:LOCALAPPDATA\Microsoft\WindowsApps\bw.exe" -Force
        Remove-Item "$env:TEMP\bw.zip", "$env:TEMP\bw-cli" -Recurse -Force
    }
    Write-Host "[1/3] Bitwarden CLI installed"
} else {
    Write-Host "[1/3] Bitwarden CLI already installed"
}

# ── Bitwarden login ───────────────────────────────────────────────────────────
Write-Host "[2/3] Unlocking Bitwarden vault..."

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
Write-Host "[3/3] Launching Claude Code..."
Write-Host ""

claude --enable-auto-mode
