#!/bin/bash
# runtime-install.sh — Tool installation targeting INSTALL_PREFIX (default: $HOME)
# Installs: Node.js, npm globals, .NET, Python/Miniforge, CLI tools
# Usage: runtime-install.sh [--upgrade]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=versions.env
source "$SCRIPT_DIR/versions.env"
# shellcheck source=packages/node.sh
source "$SCRIPT_DIR/packages/node.sh"
# shellcheck source=packages/dotnet.sh
source "$SCRIPT_DIR/packages/dotnet.sh"
# shellcheck source=packages/python.sh
source "$SCRIPT_DIR/packages/python.sh"
# shellcheck source=packages/cli.sh
source "$SCRIPT_DIR/packages/cli.sh"

INSTALL_PREFIX="${INSTALL_PREFIX:-$HOME}"
BOOTSTRAP_MARKER="$INSTALL_PREFIX/.bootstrap/tools.ready"

# ── Configure PATH for all shells ─────────────────────────────────────────────
configure_path() {
    log_info "Configuring PATH environment..."

    local path_block='# zzaia-path-begin
export NVM_DIR="${INSTALL_PREFIX}/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
export PATH="/opt/ml-tools/envs/venv-development/bin:${INSTALL_PREFIX}/.local/bin:${INSTALL_PREFIX}/.npm-global/bin:${INSTALL_PREFIX}/.dotnet:${INSTALL_PREFIX}/.dotnet/tools:${INSTALL_PREFIX}/miniforge3/bin:$PATH"
# zzaia-path-end'

    for f in "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$f" ] || touch "$f"
        if grep -qF '# zzaia-path-begin' "$f" 2>/dev/null; then
            sed -i '/# zzaia-path-begin/,/# zzaia-path-end/d' "$f"
        fi
        printf '\n%s\n' "$path_block" >> "$f"
    done

    export NVM_DIR="${INSTALL_PREFIX}/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    export PATH="/opt/ml-tools/envs/venv-development/bin:${INSTALL_PREFIX}/.local/bin:${INSTALL_PREFIX}/.npm-global/bin:${INSTALL_PREFIX}/.dotnet:${INSTALL_PREFIX}/.dotnet/tools:${INSTALL_PREFIX}/miniforge3/bin:$PATH"

    log_success "PATH configured"
}

# ── Configure agent CLI aliases via rtk ──────────────────────────────────────
configure_aliases() {
    log_info "Configuring agent CLI aliases..."

    local alias_block='# zzaia-aliases-begin
alias claude="claude --dangerously-skip-permissions"
alias codex="codex --dangerously-bypass-approvals-and-sandbox"
alias gemini="gemini --yolo"
alias copilot="copilot --yolo"
alias opencode="opencode"
# zzaia-aliases-end'

    for f in "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$f" ] || touch "$f"
        if grep -qF '# zzaia-aliases-begin' "$f" 2>/dev/null; then
            sed -i '/# zzaia-aliases-begin/,/# zzaia-aliases-end/d' "$f"
        fi
        printf '\n%s\n' "$alias_block" >> "$f"
    done

    log_success "Agent CLI aliases configured"
}

# ── Initialize RTK hook for token optimization ───────────────────────────────
configure_rtk() {
    log_info "Initializing RTK hooks..."

    if ! command -v rtk &>/dev/null; then
        log_warn "rtk not found; skipping RTK hook initialization"
        return 0
    fi

    rtk init -g --agent claude --auto-patch 2>&1 | sed 's/^/  /'
    rtk init -g --gemini --auto-patch 2>&1 | sed 's/^/  /'
    rtk init -g --codex 2>&1 | sed 's/^/  /'
    rtk init -g --copilot --auto-patch 2>&1 | sed 's/^/  /'
    rtk init -g --opencode 2>&1 | sed 's/^/  /'

    log_success "RTK hooks initialized for claude, gemini, codex, copilot, opencode"
}

# ── Verify all required tools ─────────────────────────────────────────────────
verify_tools() {
    log_info "Verifying installed tools..."

    node::verify
    dotnet::verify
    python::verify
    cli::verify

    log_success "All tool verification checks passed"
}

# ── Main installation routine ─────────────────────────────────────────────────
main() {
    local upgrade=false
    [ "${1:-}" = "--upgrade" ] && upgrade=true

    mkdir -p "${INSTALL_PREFIX}/.bootstrap"

    # Bootstrap marker includes hash of this script — invalidate on changes
    local script_hash
    script_hash=$(sha256sum "$0" | awk '{print $1}')

    if [ "$upgrade" = false ] && [ -f "$BOOTSTRAP_MARKER" ]; then
        local stored_hash
        stored_hash=$(cat "$BOOTSTRAP_MARKER" 2>/dev/null || echo "")
        if [ "$stored_hash" = "$script_hash" ]; then
            log_info "Runtime already bootstrapped (hash match)"
            return 0
        fi
    fi

    log_info "Starting runtime tool installation..."

    # Create required directories
    mkdir -p "${INSTALL_PREFIX}/.bootstrap" "${INSTALL_PREFIX}/.local/bin" "${INSTALL_PREFIX}/.npm-global"

    # Install all tools in order
    python::install_miniforge
    python::install_cuda
    node::install
    node::install_npm_globals
    dotnet::install
    dotnet::install_tools
    python::install_packages
    python::install_venv_development
    cli::install_gh
    cli::install_k6
    cli::install_d2
    cli::install_dapr
    cli::install_rtk
    cli::install_docker
    cli::install_azure_cli
    cli::install_tectonic

    # Configure environment and verify
    configure_path
    configure_rtk
    configure_aliases
    verify_tools

    # ── Development environment marker ──────────────────────────────────────────
    DEV_MARKER="$INSTALL_PREFIX/.bootstrap/venv-development.ready"
    local dev_hash
    dev_hash=$(sha256sum "$SCRIPT_DIR/packages/python.sh" | awk '{print $1}')
    local stored_dev_hash
    stored_dev_hash=$(cat "$DEV_MARKER" 2>/dev/null || echo "")
    if [ "$stored_dev_hash" != "$dev_hash" ]; then
        log_info "venv-development marker updated"
        echo "$dev_hash" > "$DEV_MARKER"
    fi

    # Mark bootstrap as complete
    echo "$script_hash" > "$BOOTSTRAP_MARKER"
    log_success "Runtime bootstrap complete"
}

main "$@"
