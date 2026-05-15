#!/bin/bash
# packages/node.sh — Node.js and npm global installation
# Uses nvm for managed Node.js installation

set -euo pipefail

# ── Node.js installation via nvm ──────────────────────────────────────────────
node::install() {
    local node_version="${NODE_VERSION:-22}"

    if [ -x "$HOME/.nvm/versions/node/v${node_version}."*/bin/node ] 2>/dev/null; then
        log_info "Node.js v$node_version already installed"
        return 0
    fi

    log_info "Installing Node.js v$node_version via nvm..."

    # Install nvm if not present
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    fi

    # Activate nvm and install Node.js
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install "${node_version}" --lts
    nvm use "${node_version}"

    log_success "Node.js v$node_version installed"
}

# ── npm globals configuration ─────────────────────────────────────────────────
node::install_npm_globals() {
    log_info "Installing npm global packages..."

    npm config set prefix "$HOME/.npm-global" 2>/dev/null || true

    local packages=(
        "@anthropic-ai/claude-code"
        "@mermaid-js/mermaid-cli"
        "@openai/codex"
        "@google/gemini-cli"
    )

    for pkg in "${packages[@]}"; do
        log_info "Installing npm package: $pkg"
        npm install -g "$pkg" 2>/dev/null || log_warn "Failed to install $pkg; continuing"
    done

    log_success "npm global packages installed"
}

# ── Verify Node.js and npm tools ──────────────────────────────────────────────
node::verify() {
    log_info "Verifying Node.js and npm tools..."

    local required_tools=("node" "npm" "claude" "mmdc" "codex" "gemini")
    local failed=0

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_warn "Tool not found: $tool"
            failed=$((failed + 1))
        fi
    done

    if [ $failed -eq 0 ]; then
        log_success "Node.js verification passed"
    else
        log_warn "Node.js verification: $failed tools not available"
    fi
}
