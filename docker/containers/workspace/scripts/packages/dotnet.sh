#!/bin/bash
# packages/dotnet.sh — .NET SDK and tools installation

set -euo pipefail

# ── .NET SDK installation ─────────────────────────────────────────────────────
dotnet::install() {
    local dotnet_version="${DOTNET_VERSION:-10}"

    if [ -x "$HOME/.dotnet/dotnet" ]; then
        log_info ".NET SDK already installed"
        return 0
    fi

    log_info "Installing .NET $dotnet_version SDK..."

    mkdir -p "$HOME/.dotnet"
    curl -fsSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin \
        --channel "${dotnet_version}.0" \
        --install-dir "$HOME/.dotnet"

    log_success ".NET $dotnet_version SDK installed"
}

# ── .NET global tools ─────────────────────────────────────────────────────────
dotnet::install_tools() {
    log_info "Installing .NET tools..."

    # Aspire CLI
    if ! command -v aspire >/dev/null 2>&1; then
        log_info "Installing Aspire CLI..."
        curl -sSL https://aspire.dev/install.sh | bash || log_warn "Aspire install script failed; continuing"
        [ -d "$HOME/.aspire/bin" ] && ln -sf "$HOME/.aspire/bin/aspire" "$HOME/.local/bin/aspire" 2>/dev/null || true
    fi

    # Aspirate tool
    if [ -x "$HOME/.dotnet/dotnet" ]; then
        log_info "Installing aspirate tool..."
        "$HOME/.dotnet/dotnet" tool install -g aspirate 2>/dev/null \
            || "$HOME/.dotnet/dotnet" tool update -g aspirate 2>/dev/null \
            || log_warn "aspirate tool installation failed; continuing"
    fi

    log_success ".NET tools installed"
}

# ── Verify .NET installation ──────────────────────────────────────────────────
dotnet::verify() {
    log_info "Verifying .NET installation..."

    if [ -x "$HOME/.dotnet/dotnet" ] && "$HOME/.dotnet/dotnet" --version >/dev/null 2>&1; then
        log_success ".NET verification passed"
    else
        log_warn ".NET verification: dotnet command not available"
    fi
}
