#!/bin/bash
# packages/cli.sh — Command-line tool installation (gh, k6, d2, dapr, rtk)

set -euo pipefail

# ── GitHub CLI installation ───────────────────────────────────────────────────
cli::install_gh() {
    if command -v gh >/dev/null 2>&1; then
        log_info "GitHub CLI already installed"
        return 0
    fi

    log_info "Installing GitHub CLI..."

    mkdir -p "$HOME/.local/bin"

    # Get latest release from GitHub API
    local gh_version
    gh_version=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name"' | sed 's/.*"v//;s/".*//') || true

    if [ -n "$gh_version" ]; then
        local gh_url="https://github.com/cli/cli/releases/download/v${gh_version}/gh_${gh_version}_linux_amd64.tar.gz"
        curl -fsSL "$gh_url" | tar xz -C "$HOME/.local/bin" "gh_${gh_version}_linux_amd64/bin/gh" --strip-components 2
        chmod +x "$HOME/.local/bin/gh"
        log_success "GitHub CLI installed"
    else
        log_warn "Could not determine gh version; skipping installation"
        return 0
    fi
}

# ── k6 load testing tool ──────────────────────────────────────────────────────
cli::install_k6() {
    if command -v k6 >/dev/null 2>&1; then
        log_info "k6 already installed"
        return 0
    fi

    log_info "Installing k6..."

    mkdir -p "$HOME/.local/bin"

    local k6_version
    k6_version=$(curl -fsSL https://api.github.com/repos/grafana/k6/releases/latest | grep '"tag_name"' | sed 's/.*v//;s/".*//') || true

    if [ -n "$k6_version" ]; then
        local k6_url="https://github.com/grafana/k6/releases/download/v${k6_version}/k6-v${k6_version}-linux-amd64.tar.gz"
        curl -fsSL "$k6_url" | tar xz -C "$HOME/.local/bin" --strip-components 1 || log_warn "k6 download failed; continuing"
        [ -f "$HOME/.local/bin/k6" ] && chmod +x "$HOME/.local/bin/k6"
        log_success "k6 installed"
    else
        log_warn "Could not determine k6 version; skipping installation"
        return 0
    fi
}

# ── D2 diagram tool ──────────────────────────────────────────────────────────
cli::install_d2() {
    if command -v d2 >/dev/null 2>&1; then
        log_info "D2 already installed"
        return 0
    fi

    log_info "Installing D2..."

    curl -fsSL https://d2lang.com/install.sh | sh -s -- --prefix "$HOME/.local" || log_warn "D2 install failed; continuing"

    if [ -f "$HOME/.local/bin/d2" ]; then
        chmod +x "$HOME/.local/bin/d2"
        log_success "D2 installed"
    else
        log_warn "D2 binary not found after installation"
        return 0
    fi
}

# ── Dapr CLI ──────────────────────────────────────────────────────────────────
cli::install_dapr() {
    if command -v dapr >/dev/null 2>&1; then
        log_info "Dapr already installed"
        return 0
    fi

    log_info "Installing Dapr..."

    curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | bash || log_warn "Dapr install failed; continuing"

    log_success "Dapr installation attempted"
}

# ── RTK (Rust Token Killer) ───────────────────────────────────────────────────
cli::install_rtk() {
    if command -v rtk >/dev/null 2>&1; then
        log_info "RTK already installed"
        return 0
    fi

    log_info "Installing RTK..."

    mkdir -p "$HOME/.local/bin"

    local rtk_version
    rtk_version=$(curl -fsSL https://api.github.com/repos/rtk-ai/rtk/releases/latest | grep '"tag_name"' | sed 's/.*"v//;s/".*//') || true

    if [ -n "$rtk_version" ]; then
        local rtk_url="https://github.com/rtk-ai/rtk/releases/download/v${rtk_version}/rtk-x86_64-unknown-linux-musl.tar.gz"
        curl -fsSL "$rtk_url" | tar xz -C "$HOME/.local/bin" rtk || log_warn "RTK download failed; continuing"
        [ -f "$HOME/.local/bin/rtk" ] && chmod +x "$HOME/.local/bin/rtk"
        log_success "RTK installed"
    else
        log_warn "Could not determine RTK version; skipping installation"
        return 0
    fi
}

# ── Verify CLI tools ──────────────────────────────────────────────────────────
cli::verify() {
    log_info "Verifying CLI tools..."

    local required_tools=("gh" "k6" "d2" "dapr" "rtk")
    local failed=0

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_warn "Tool not found: $tool"
            failed=$((failed + 1))
        fi
    done

    if [ $failed -eq 0 ]; then
        log_success "CLI tools verification passed"
    else
        log_warn "CLI tools verification: $failed tools not available"
    fi
}
