# Install-windows.ps1 - ZZAIA Workspace Prerequisites Installer (Windows PowerShell)
# Installs all required tools including Claude Code CLI and Bitwarden CLI.
#
# Usage: .\Install-windows.ps1

Write-Host ""
Write-Host "  ZZAIA Workspace Installer — Windows PowerShell"
Write-Host ""

# ── 1. winget check ───────────────────────────────────────────────────────────
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: winget is required. Install App Installer from the Microsoft Store."
    exit 1
}

# ── 2. Git ────────────────────────────────────────────────────────────────────
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[1/6] Installing Git..."
    winget install --id Git.Git --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[1/6] Git already installed"
}

# ── 3. Node.js LTS ───────────────────────────────────────────────────────────
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[2/6] Installing Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[2/6] Node.js already installed"
}

# ── 4. Claude Code CLI ───────────────────────────────────────────────────────
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "[3/6] Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
} else {
    Write-Host "[3/6] Claude Code already installed"
}

# ── 5. Bitwarden CLI ─────────────────────────────────────────────────────────
if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Host "[4/6] Installing Bitwarden CLI..."
    winget install --id Bitwarden.BitwardenCLI --accept-source-agreements --accept-package-agreements
    Write-Host "[4/6] Bitwarden CLI installed"
} else {
    Write-Host "[4/6] Bitwarden CLI already installed"
}

# ── 6. VS Code ────────────────────────────────────────────────────────────────
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "[5/6] Installing VS Code..."
    winget install --id Microsoft.VisualStudioCode --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[5/6] VS Code already installed"
}

# ── 7. Docker Desktop ────────────────────────────────────────────────────────
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[6/6] Installing Docker Desktop..."
    winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[6/6] Docker Desktop already installed"
}

Write-Host ""
Write-Host "Installation complete."
Write-Host "Restart your terminal, then run: .\Init-windows.ps1"
