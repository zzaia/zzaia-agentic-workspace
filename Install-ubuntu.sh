#!/bin/bash
# Install-ubuntu.sh - ZZAIA Workspace Prerequisites Installer (Ubuntu / WSL)
# Installs all required tools including Claude Code CLI and Bitwarden CLI.
#
# Usage: bash Install-ubuntu.sh

set -e

is_installed() { command -v "$1" &>/dev/null; }

echo ""
echo "  ZZAIA Workspace Installer — Ubuntu / WSL"
echo ""

# ── 1. Git ───────────────────────────────────────────────────────────────────
if ! is_installed git; then
    echo "[1/7] Installing Git..."
    sudo apt-get update -qq
    sudo apt-get install -y git
else
    echo "[1/7] Git already installed"
fi

# ── 2. Node.js + npm ─────────────────────────────────────────────────────────
if ! is_installed node; then
    echo "[2/7] Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "[2/7] Node.js already installed"
fi

# ── 3. Claude Code CLI ───────────────────────────────────────────────────────
if ! is_installed claude; then
    echo "[3/7] Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
else
    echo "[3/7] Claude Code already installed"
fi

# ── 4. Bitwarden CLI ─────────────────────────────────────────────────────────
if ! is_installed bw; then
    echo "[4/7] Installing Bitwarden CLI..."
    if is_installed snap; then
        sudo snap install bw
    else
        BW_VERSION=$(curl -s https://api.github.com/repos/bitwarden/clients/releases/latest \
            | grep '"tag_name"' | grep -o 'cli-v[0-9.]*' | head -1 | sed 's/cli-v//')
        curl -fsSL "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip" \
            -o /tmp/bw.zip
        unzip -o /tmp/bw.zip -d /tmp/bw-cli
        sudo mv /tmp/bw-cli/bw /usr/local/bin/bw
        sudo chmod +x /usr/local/bin/bw
        rm -rf /tmp/bw.zip /tmp/bw-cli
    fi
    echo "[4/7] Bitwarden CLI installed"
else
    echo "[4/7] Bitwarden CLI already installed"
fi

# ── 5. VS Code ───────────────────────────────────────────────────────────────
if ! is_installed code; then
    echo "[5/7] Installing VS Code..."
    sudo snap install code --classic
else
    echo "[5/7] VS Code already installed"
fi

# ── 6. Docker ────────────────────────────────────────────────────────────────
if ! is_installed docker; then
    echo "[6/7] Installing Docker..."
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker "$USER"
else
    echo "[6/7] Docker already installed"
fi

# ── 7. .NET SDK (LTS) ────────────────────────────────────────────────────────
if ! is_installed dotnet; then
    echo "[7/7] Installing .NET SDK..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --channel LTS
    echo 'export DOTNET_ROOT="$HOME/.dotnet"' >> "$HOME/.bashrc"
    echo 'export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"' >> "$HOME/.bashrc"
    export DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"
else
    echo "[7/7] .NET SDK already installed"
fi

echo ""
echo "Installation complete."
echo "Restart your terminal or run: source ~/.bashrc"
echo "Then run: bash Init-ubuntu.sh"
