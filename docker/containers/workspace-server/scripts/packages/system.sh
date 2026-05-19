#!/bin/bash
# packages/system.sh — System-level package installation (run as root at build time)
# Provides functions for apt packages, VS Code CLI

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
        curl git sudo unzip \
        ca-certificates locales gpg gpg-agent \
        libicu74 plantuml tmux wget
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8
    rm -rf /var/lib/apt/lists/*
    log_success "$label installed"
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
