#!/bin/bash
# packages/node.sh — Node.js and npm global installation
# Uses nvm for managed Node.js installation

set -euo pipefail

# ── Node.js installation via nvm ──────────────────────────────────────────────
node::install() {
    log_info "Installing Node.js ${NODE_VERSION} via nvm..."

    # Source nvm if already installed
    export NVM_DIR="${INSTALL_PREFIX:-$HOME}/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install nvm if not present
    if ! command -v nvm >/dev/null 2>&1 && [ ! -s "$NVM_DIR/nvm.sh" ]; then
        log_info "Installing nvm ${NVM_VERSION}..."
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi

    # Install node if not already present (nvm installer may pre-install it via NODE_VERSION env)
    if ! nvm ls "${NODE_VERSION}" 2>/dev/null | grep -q "v${NODE_VERSION}"; then
        log_info "Installing Node.js ${NODE_VERSION}..."
        nvm install "${NODE_VERSION}"
        nvm alias default "${NODE_VERSION}"
        log_success "Node.js ${NODE_VERSION} installed"
    else
        log_info "Node.js ${NODE_VERSION} already installed"
    fi

    # Always ensure node/npm symlinks exist in .local/bin (idempotent, needed for
    # static ENV PATH in docker exec sessions where nvm is not sourced).
    # Use filesystem lookup instead of `nvm which` to avoid subshell function scope issues.
    local nvm_node_dir
    nvm_node_dir=$(ls -d "${INSTALL_PREFIX:-$HOME}/.nvm/versions/node"/v* 2>/dev/null | head -1)
    if [ -n "$nvm_node_dir" ] && [ -f "$nvm_node_dir/bin/node" ]; then
        ln -sf "$nvm_node_dir/bin/node" "${INSTALL_PREFIX:-$HOME}/.local/bin/node" || true
        ln -sf "$nvm_node_dir/bin/npm"  "${INSTALL_PREFIX:-$HOME}/.local/bin/npm"  || true
    fi
}

# ── npm globals configuration ─────────────────────────────────────────────────
node::install_npm_globals() {
    log_info "Installing npm global packages..."

    # Use --prefix flag directly — avoids writing to ~/.npmrc (nvm rejects prefix
    # there) and avoids exporting NPM_CONFIG_PREFIX (nvm returns exit 11 on that).
    local npm_prefix="${INSTALL_PREFIX:-$HOME}/.npm-global"

    local packages=(
        "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION:-latest}"
        "@mermaid-js/mermaid-cli@${MMDC_VERSION:-latest}"
        "@openai/codex@${CODEX_VERSION:-latest}"
        "@google/gemini-cli@${GEMINI_CLI_VERSION:-latest}"
    )

    for pkg in "${packages[@]}"; do
        log_info "Installing npm package: $pkg"
        npm install -g --prefix "$npm_prefix" "$pkg" 2>/dev/null || log_warn "Failed to install $pkg; continuing"
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
