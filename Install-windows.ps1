# Install-windows.ps1 - ZZAIA Workspace Prerequisites Installer (Windows PowerShell)
# Installs all required tools including Claude Code CLI and Bitwarden CLI.
#
# Usage: .\Install-windows.ps1

Write-Host ""
Write-Host "  ZZAIA Workspace Installer — Windows PowerShell"
Write-Host ""

# ── winget check ──────────────────────────────────────────────────────────────
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: winget is required. Install App Installer from the Microsoft Store."
    exit 1
}

# ── 1. Git ────────────────────────────────────────────────────────────────────
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[1/13] Installing Git..."
    winget install --id Git.Git --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[1/13] Git already installed"
}

# ── 2. Node.js LTS ───────────────────────────────────────────────────────────
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[2/13] Installing Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[2/13] Node.js already installed"
}

# ── 3. VS Code ────────────────────────────────────────────────────────────────
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "[3/13] Installing VS Code..."
    winget install --id Microsoft.VisualStudioCode --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[3/13] VS Code already installed"
}

# ── 4. Claude Code CLI ───────────────────────────────────────────────────────
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "[4/13] Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
} else {
    Write-Host "[4/13] Claude Code already installed"
}

# ── 5. Bitwarden CLI ─────────────────────────────────────────────────────────
if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Host "[5/13] Installing Bitwarden CLI..."
    winget install --id Bitwarden.BitwardenCLI --accept-source-agreements --accept-package-agreements
    Write-Host "[5/13] Bitwarden CLI installed"
} else {
    Write-Host "[5/13] Bitwarden CLI already installed"
}

# ── 6. Docker Desktop ────────────────────────────────────────────────────────
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[6/13] Installing Docker Desktop..."
    winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[6/13] Docker Desktop already installed"
}

# ── 7. .NET SDK (LTS) ────────────────────────────────────────────────────────
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "[7/13] Installing .NET SDK (LTS)..."
    winget install --id Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[7/13] .NET SDK already installed"
}

# ── 8. .NET Aspire Workload + CLI ────────────────────────────────────────────
$aspireListed = (dotnet workload list 2>$null) -match "aspire"
if (-not $aspireListed) {
    Write-Host "[8/13] Installing Aspire workload + CLI..."
    dotnet workload install aspire
    dotnet tool install -g aspire
} else {
    Write-Host "[8/13] Aspire already installed"
}

# ── 9. Dapr CLI ──────────────────────────────────────────────────────────────
if (-not (Get-Command dapr -ErrorAction SilentlyContinue)) {
    Write-Host "[9/13] Installing Dapr CLI..."
    winget install --id Dapr.CLI --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[9/13] Dapr already installed"
}

# ── 10. Aspirate ─────────────────────────────────────────────────────────────
if (-not (Get-Command aspirate -ErrorAction SilentlyContinue)) {
    Write-Host "[10/13] Installing Aspirate..."
    dotnet tool install -g aspirate
} else {
    Write-Host "[10/13] Aspirate already installed"
}

# ── 11. Anaconda ─────────────────────────────────────────────────────────────
if (-not (Get-Command conda -ErrorAction SilentlyContinue)) {
    Write-Host "[11/13] Installing Anaconda..."
    winget install --id Anaconda.Anaconda3 --accept-source-agreements --accept-package-agreements
    Write-Host "[11/13] Anaconda installed — restart terminal to use conda"
} else {
    Write-Host "[11/13] Anaconda already installed"
    conda create -n venv-analytics python=3 -y 2>$null | Out-Null
    conda create -n venv-development python=3 -y 2>$null | Out-Null
}

# ── 12. k6 Load Testing ──────────────────────────────────────────────────────
if (-not (Get-Command k6 -ErrorAction SilentlyContinue)) {
    Write-Host "[12/13] Installing k6..."
    winget install --id k6.k6 --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[12/13] k6 already installed"
}

# ── 13. D2 (diagram language) ────────────────────────────────────────────────
if (-not (Get-Command d2 -ErrorAction SilentlyContinue)) {
    Write-Host "[13/13] Installing D2..."
    winget install --id terrastruct.d2 --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "[13/13] D2 already installed"
}

# ── Python packages ──────────────────────────────────────────────────────────
Write-Host "Installing Python packages..."
pip install pypdf python-docx textual jinja2 mmdc graphviz diagrams

Write-Host ""
Write-Host "Installation complete."
Write-Host "Restart your terminal, then run: .\Init-windows.ps1"
