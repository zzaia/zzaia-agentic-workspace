#!/bin/bash
# packages/system.sh — System-level package installation (run as root at build time)
# Provides functions for apt packages, Docker CLI, Azure CLI, Tectonic, VS Code CLI

set -euo pipefail

# ── APT packages ──────────────────────────────────────────────────────────────
system::install_apt_packages() {
    local label="APT packages"
    if dpkg -l | grep -q '^ii  curl'; then
        log_info "$label already installed"
        return 0
    fi

    log_info "Installing $label..."
    apt-get update
    apt-get install -y --no-install-recommends \
        curl git openssh-server sudo unzip \
        ca-certificates locales gpg gpg-agent \
        libicu74 plantuml tmux wget
    rm -rf /var/lib/apt/lists/*
    log_success "$label installed"
}

# ── Docker CE CLI ─────────────────────────────────────────────────────────────
system::install_docker_cli() {
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker CLI already installed"
        return 0
    fi

    log_info "Installing Docker CE CLI..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu noble stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y --no-install-recommends docker-ce-cli
    rm -rf /var/lib/apt/lists/*
    log_success "Docker CLI installed"
}

# ── Azure CLI ─────────────────────────────────────────────────────────────────
system::install_azure_cli() {
    if command -v az >/dev/null 2>&1; then
        log_info "Azure CLI already installed"
        return 0
    fi

    log_info "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    log_success "Azure CLI installed"
}

# ── Tectonic LaTeX engine ─────────────────────────────────────────────────────
system::install_tectonic() {
    if [ -f /usr/local/bin/tectonic ]; then
        log_info "Tectonic already installed"
        return 0
    fi

    log_info "Installing Tectonic..."
    curl --proto '=https' --tlsv1.2 -fsSL https://drop.tectonic-typesetting.org/install.sh | sh
    [ -f "$HOME/.local/bin/tectonic" ] && mv "$HOME/.local/bin/tectonic" /usr/local/bin/tectonic || true
    log_success "Tectonic installed"
}

# ── VS Code CLI ───────────────────────────────────────────────────────────────
system::install_vscode_cli() {
    if [ -f /usr/local/bin/code ]; then
        log_info "VS Code CLI already installed"
        return 0
    fi

    log_info "Installing VS Code CLI..."
    curl -fsSL "https://update.code.visualstudio.com/latest/cli-linux-x64/stable" | tar xz -C /usr/local/bin
    log_success "VS Code CLI installed"
}
