#!/bin/bash
# packages/dotnet.sh — .NET SDK and tools installation

set -euo pipefail

# ── .NET SDK installation ─────────────────────────────────────────────────────
dotnet::install() {
    local dotnet_version="${DOTNET_VERSION:-10}"

    if [ -x "${INSTALL_PREFIX:-$HOME}/.dotnet/dotnet" ]; then
        log_info ".NET SDK already installed"
        return 0
    fi

    log_info "Installing .NET $dotnet_version SDK..."

    mkdir -p "${INSTALL_PREFIX:-$HOME}/.dotnet"
    curl -fsSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin \
        --channel "${dotnet_version}.0" \
        --install-dir "${INSTALL_PREFIX:-$HOME}/.dotnet"

    log_success ".NET $dotnet_version SDK installed"
}

# ── .NET global tools ─────────────────────────────────────────────────────────
dotnet::install_tools() {
    log_info "Installing .NET tools..."

    # Aspire CLI
    if ! command -v aspire >/dev/null 2>&1; then
        log_info "Installing Aspire CLI..."
        curl -sSL https://aspire.dev/install.sh | bash || log_warn "Aspire install script failed; continuing"
        [ -d "${INSTALL_PREFIX:-$HOME}/.aspire/bin" ] && ln -sf "${INSTALL_PREFIX:-$HOME}/.aspire/bin/aspire" "${INSTALL_PREFIX:-$HOME}/.local/bin/aspire" 2>/dev/null || true
    fi

    # Aspirate tool
    if [ -x "${INSTALL_PREFIX:-$HOME}/.dotnet/dotnet" ]; then
        log_info "Installing aspirate tool..."
        "${INSTALL_PREFIX:-$HOME}/.dotnet/dotnet" tool install -g aspirate 2>/dev/null \
            || "${INSTALL_PREFIX:-$HOME}/.dotnet/dotnet" tool update -g aspirate 2>/dev/null \
            || log_warn "aspirate tool installation failed; continuing"
    fi

    log_success ".NET tools installed"
}

# ── Verify .NET installation ──────────────────────────────────────────────────
dotnet::verify() {
    log_info "Verifying .NET installation..."

    if [ -x "${INSTALL_PREFIX:-$HOME}/.dotnet/dotnet" ] && "${INSTALL_PREFIX:-$HOME}/.dotnet/dotnet" --version >/dev/null 2>&1; then
        log_success ".NET verification passed"
    else
        log_warn ".NET verification: dotnet command not available"
    fi
}
