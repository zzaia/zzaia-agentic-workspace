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
    echo "[1/16] Installing Git..."
    sudo apt-get update -qq
    sudo apt-get install -y git
else
    echo "[1/16] Git already installed"
fi

# ── 2. Node.js + npm ─────────────────────────────────────────────────────────
if ! is_installed node; then
    echo "[2/16] Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "[2/16] Node.js already installed"
fi

# ── 3. VS Code ───────────────────────────────────────────────────────────────
if ! is_installed code; then
    echo "[3/16] Installing VS Code..."
    sudo snap install code --classic
else
    echo "[3/16] VS Code already installed"
fi

# ── 4. Claude Code CLI ───────────────────────────────────────────────────────
if ! is_installed claude; then
    echo "[4/16] Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
else
    echo "[4/16] Claude Code already installed"
fi

# ── 5. Bitwarden CLI ─────────────────────────────────────────────────────────
if ! is_installed bw; then
    echo "[5/16] Installing Bitwarden CLI..."
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
    echo "[5/16] Bitwarden CLI installed"
else
    echo "[5/16] Bitwarden CLI already installed"
fi

# ── 6. Docker ────────────────────────────────────────────────────────────────
if ! is_installed docker; then
    echo "[6/16] Installing Docker..."
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list
    sudo apt-get update -qq
    sudo apt-get install -y docker-desktop
    systemctl --user enable docker-desktop
else
    echo "[6/16] Docker already installed"
fi

# ── 7. .NET SDK (LTS) ────────────────────────────────────────────────────────
if ! is_installed dotnet; then
    echo "[7/16] Installing .NET SDK (LTS)..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --channel LTS
    echo 'export DOTNET_ROOT="$HOME/.dotnet"' >> "$HOME/.bashrc"
    echo 'export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"' >> "$HOME/.bashrc"
    export DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"
else
    echo "[7/16] .NET SDK already installed"
fi

# ── 8. .NET Aspire Workload + CLI ────────────────────────────────────────────
if ! dotnet workload list 2>/dev/null | grep -q aspire; then
    echo "[8/16] Installing Aspire workload + CLI..."
    dotnet workload install aspire
    dotnet tool install -g aspire
else
    echo "[8/16] Aspire already installed"
fi

# ── 9. Dapr CLI ──────────────────────────────────────────────────────────────
if ! is_installed dapr; then
    echo "[9/16] Installing Dapr CLI..."
    wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
else
    echo "[9/16] Dapr already installed"
fi

# ── 10. Aspirate (Aspire → Kubernetes) ──────────────────────────────────────
if ! is_installed aspirate; then
    echo "[10/16] Installing Aspirate..."
    dotnet tool install -g aspirate
else
    echo "[10/16] Aspirate already installed"
fi

# ── 11. Anaconda + conda environments ───────────────────────────────────────
CONDA_DIR="$HOME/anaconda3"
if ! is_installed conda; then
    echo "[11/16] Installing Anaconda..."
    wget -q https://repo.anaconda.com/archive/Anaconda3-latest-Linux-x86_64.sh -O /tmp/anaconda.sh
    bash /tmp/anaconda.sh -b -p "$CONDA_DIR"
    "$CONDA_DIR/bin/conda" init bash
    export PATH="$CONDA_DIR/bin:$PATH"
else
    echo "[11/16] Anaconda already installed"
fi

CONDA_BIN="${CONDA_DIR}/bin/conda"
if ! "$CONDA_BIN" env list | grep -q "venv-analytics"; then
    echo "       Creating conda env: venv-analytics..."
    "$CONDA_BIN" create -n venv-analytics python=3 -y
fi
if ! "$CONDA_BIN" env list | grep -q "venv-development"; then
    echo "       Creating conda env: venv-development..."
    "$CONDA_BIN" create -n venv-development python=3 -y
fi

# ── 12. tmux ─────────────────────────────────────────────────────────────────
if ! is_installed tmux; then
    echo "[12/16] Installing tmux..."
    sudo apt-get install -y tmux
else
    echo "[12/16] tmux already installed"
fi

# ── 13. k6 Load Testing ──────────────────────────────────────────────────────
if ! is_installed k6; then
    echo "[13/16] Installing k6..."
    sudo gpg --no-default-keyring \
        --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
        --keyserver hkp://keyserver.ubuntu.com:80 \
        --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
    echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
        | sudo tee /etc/apt/sources.list.d/k6.list
    sudo apt-get update -qq
    sudo apt-get install -y k6
else
    echo "[13/16] k6 already installed"
fi

# ── 14. Tectonic (LaTeX engine) ──────────────────────────────────────────────
if ! is_installed tectonic; then
    echo "[14/16] Installing Tectonic..."
    sudo snap install tectonic
else
    echo "[14/16] Tectonic already installed"
fi

# ── 15. D2 (diagram language) ────────────────────────────────────────────────
if ! is_installed d2; then
    echo "[15/16] Installing D2..."
    curl -fsSL https://d2lang.com/install.sh | sh -s --
else
    echo "[15/16] D2 already installed"
fi

# ── 16. PlantUML ─────────────────────────────────────────────────────────────
if ! is_installed plantuml; then
    echo "[16/16] Installing PlantUML..."
    sudo apt-get install -y plantuml
else
    echo "[16/16] PlantUML already installed"
fi

# ── Python packages ──────────────────────────────────────────────────────────
echo "Installing Python packages..."
pip install pypdf python-docx textual jinja2 mmdc graphviz diagrams

echo ""
echo "Installation complete."
echo "Restart your terminal or run: source ~/.bashrc"
echo "Then run: bash Init-ubuntu.sh"
