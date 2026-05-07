#!/bin/bash
# setup-tools.sh — Runtime tools installation via mise
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ── Bootstrap directory validation ────────────────────────────────────────────
ensure_bootstrap_dir() {
    ensure_dir "$BOOTSTRAP_DIR" "user:user" "755"
}

# ── Miniforge (conda) installation ────────────────────────────────────────────
install_miniforge() {
    log_info "Installing Miniforge if needed..."
    su -s /bin/bash user -c "
        if [ ! -x /home/user/miniforge3/bin/conda ]; then
            log_info 'Downloading Miniforge...'
            curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
                -o /tmp/miniforge.sh
            bash /tmp/miniforge.sh -b -p /home/user/miniforge3
            rm /tmp/miniforge.sh
            /home/user/miniforge3/bin/conda init bash
            log_success 'Miniforge installed'
        fi
    "
}

# ── Git and essential toolchain ───────────────────────────────────────────────
install_git_and_essentials() {
    log_info "Installing git and essential tools via mise..."
    su -s /bin/bash user -c "
        export PATH=/home/user/miniforge3/bin:/home/user/.local/share/mise/shims:/home/user/.local/bin:/home/user/.dotnet/tools:\$PATH
        [ -n \"${GITHUB_PERSONAL_ACCESS_TOKEN:-}\" ] && export GITHUB_TOKEN=\"${GITHUB_PERSONAL_ACCESS_TOKEN}\" || true
        [ -n \"${GITHUB_PERSONAL_ACCESS_TOKEN:-}\" ] && export AQUA_GITHUB_TOKEN=\"${GITHUB_PERSONAL_ACCESS_TOKEN}\" || true
        
        mise trust /home/user/mise.toml
        mise run install-git
        mise run install-azure-cli
        mise run install-tectonic
    "
}

# ── Verify required runtime binaries ─────────────────────────────────────────
verify_required_tools() {
    log_info "Verifying required tools are available..."

    su -s /bin/bash user -c "
        export PATH=/home/user/miniforge3/bin:/home/user/.local/share/mise/shims:/home/user/.local/bin:/home/user/.dotnet/tools:\$PATH
        command -v git >/dev/null
        command -v unzip >/dev/null
        command -v node >/dev/null
        command -v gh >/dev/null
        command -v claude >/dev/null
        command -v codex >/dev/null
        command -v gemini >/dev/null
    "

    log_success "Required tools verification passed"
}

# ── Install individual tool with retries ─────────────────────────────────────
install_tool_with_retry() {
    local tool="$1"
    local max_attempts=5
    local delay=15
    
    su -s /bin/bash user -c "
        export PATH=/home/user/miniforge3/bin:/home/user/.local/share/mise/shims:/home/user/.local/bin:/home/user/.dotnet/tools:\$PATH
        retry_with_backoff $max_attempts $delay mise install '$tool'
    "
}

# ── NPM and other tools ───────────────────────────────────────────────────────
install_npm_tools() {
    log_info "Installing NPM-based tools..."
    
    local npm_tools=(
        "gh"
        "tmux"
        "node"
        "dotnet"
        "k6"
        "d2"
        "dapr"
        "npm:@anthropic-ai/claude-code"
        "npm:@mermaid-js/mermaid-cli"
        "npm:@openai/codex"
        "npm:supergateway"
        "npm:@google/gemini-cli"
    )
    
    for tool in "${npm_tools[@]}"; do
        log_info "Installing $tool..."
        install_tool_with_retry "$tool"
    done
    
    log_success "NPM tools installed"
}

# ── Python, Conda, Dotnet environments ────────────────────────────────────────
install_environments() {
    log_info "Configuring Python, Conda, and Dotnet environments..."
    
    su -s /bin/bash user -c "
        export PATH=/home/user/miniforge3/bin:/home/user/.local/share/mise/shims:/home/user/.local/bin:/home/user/.dotnet/tools:\$PATH
        mise run python-packages || true
        mise run conda-envs || true
        mise run dotnet-tools || true
    "
    
    log_success "Environments configured"
}

# ── Optional tools (can fail gracefully) ──────────────────────────────────────
install_optional_tools() {
    log_info "Installing optional tools..."
    
    su -s /bin/bash user -c "
        export PATH=/home/user/miniforge3/bin:/home/user/.local/share/mise/shims:/home/user/.local/bin:/home/user/.dotnet/tools:\$PATH
        mise run rtk || log_warn 'RTK installation skipped'
        mise run claude-plugins || log_warn 'Claude plugins installation skipped'
        mise run gh-extensions || log_warn 'GitHub extensions installation skipped'
        mise run vscode-extensions || log_warn 'VSCode extensions installation skipped'
    "
}

# ── Main runtime bootstrap ────────────────────────────────────────────────────
bootstrap_runtime() {
    if [ -f "$BOOTSTRAP_MARKER" ]; then
        log_info "Runtime already bootstrapped ($(cat "$BOOTSTRAP_MARKER"))"
        return 0
    fi
    
    log_info "Bootstrapping runtime tools and extensions via mise..."
    
    ensure_bootstrap_dir
    install_miniforge
    install_git_and_essentials
    install_npm_tools
    install_environments
    install_optional_tools
    verify_required_tools
    
    su -s /bin/bash user -c "date -u +\"%Y-%m-%dT%H:%M:%SZ\" > $BOOTSTRAP_MARKER"
    log_success "Runtime bootstrap complete"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    bootstrap_runtime
}

main "$@"
