#!/bin/bash
# Install.sh - ZZAIA Agentic Workspace Prerequisites Installer
# Ubuntu/Debian - installs all required tools if not already present

set -e

echo "🚀 ZZAIA Workspace Installer"
echo "=============================="

is_installed() { command -v "$1" &>/dev/null; }

# ── 1. Git ──────────────────────────────────────────────────────────────────
if ! is_installed git; then
    echo "[1/12] Installing Git..."
    sudo apt-get update -qq
    sudo apt-get install -y git
else
    echo "[1/12] Git already installed"
fi

# ── 2. Node.js + npm ────────────────────────────────────────────────────────
if ! is_installed node; then
    echo "[2/12] Installing Node.js LTS + npm..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "[2/12] Node.js already installed"
fi

# ── 3. VS Code ──────────────────────────────────────────────────────────────
if ! is_installed code; then
    echo "[3/12] Installing VS Code..."
    sudo snap install code --classic
else
    echo "[3/12] VS Code already installed"
fi

# ── 4. Claude Code Terminal ─────────────────────────────────────────────────
if ! is_installed claude; then
    echo "[4/12] Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
else
    echo "[4/12] Claude Code already installed"
fi

# ── 5. 1Password (Desktop + CLI) ────────────────────────────────────────────
if ! is_installed op; then
    echo "[5/12] Installing 1Password Desktop + CLI..."
    curl -sS https://downloads.1password.com/linux/keys/1password.asc \
        | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] \
https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
        | sudo tee /etc/apt/sources.list.d/1password.list
    sudo apt-get update -qq
    sudo apt-get install -y 1password 1password-cli
else
    echo "[5/12] 1Password already installed"
fi

# ── 6. Docker Desktop ───────────────────────────────────────────────────────
if ! is_installed docker; then
    echo "[6/12] Installing Docker Desktop..."
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
    echo "[6/12] Docker already installed"
fi

# ── 7. .NET (latest LTS SDK) ────────────────────────────────────────────────
if ! is_installed dotnet; then
    echo "[7/12] Installing .NET SDK (latest LTS)..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --channel LTS
    echo 'export DOTNET_ROOT="$HOME/.dotnet"' >> "$HOME/.bashrc"
    echo 'export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"' >> "$HOME/.bashrc"
    export DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"
else
    echo "[7/12] .NET already installed"
fi

# ── 8. .NET Aspire Workload + CLI ───────────────────────────────────────────
if ! dotnet workload list 2>/dev/null | grep -q aspire; then
    echo "[8/12] Installing Aspire workload + CLI..."
    dotnet workload install aspire
    dotnet tool install -g aspire
else
    echo "[8/12] Aspire already installed"
fi

# ── 9. Dapr CLI ─────────────────────────────────────────────────────────────
if ! is_installed dapr; then
    echo "[9/12] Installing Dapr CLI..."
    wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
else
    echo "[9/12] Dapr already installed"
fi

# ── 10. Aspirate (Aspire → Kubernetes) ──────────────────────────────────────
if ! is_installed aspirate; then
    echo "[10/12] Installing Aspirate..."
    dotnet tool install -g aspirate
else
    echo "[10/12] Aspirate already installed"
fi

# ── 11. Anaconda + environments ─────────────────────────────────────────────
CONDA_DIR="$HOME/anaconda3"
if ! is_installed conda; then
    echo "[11/12] Installing Anaconda..."
    wget -q https://repo.anaconda.com/archive/Anaconda3-latest-Linux-x86_64.sh -O /tmp/anaconda.sh
    bash /tmp/anaconda.sh -b -p "$CONDA_DIR"
    "$CONDA_DIR/bin/conda" init bash
    export PATH="$CONDA_DIR/bin:$PATH"
else
    echo "[11/12] Anaconda already installed"
fi

CONDA_BIN="${CONDA_DIR}/bin/conda"
if ! "$CONDA_BIN" env list | grep -q "venv-analytics"; then
    echo "       Creating conda env: venv-analytics (analytics workflows)..."
    "$CONDA_BIN" create -n venv-analytics python=3 -y
fi
if ! "$CONDA_BIN" env list | grep -q "venv-development"; then
    echo "       Creating conda env: venv-development (application development workflows)..."
    "$CONDA_BIN" create -n venv-development python=3 -y
fi

# ── 12. k6 Load Testing + Web Dashboard ─────────────────────────────────────
if ! is_installed k6; then
    echo "[12/12] Installing k6..."
    sudo gpg --no-default-keyring \
        --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
        --keyserver hkp://keyserver.ubuntu.com:80 \
        --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
    echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
        | sudo tee /etc/apt/sources.list.d/k6.list
    sudo apt-get update -qq
    sudo apt-get install -y k6
else
    echo "[12/12] k6 already installed"
fi

echo ""
echo "✅ Installation complete."
echo "⚠️  Restart your terminal or run: source ~/.bashrc"
echo "   Then run: .claude/Init.sh to launch the workspace."
