#!/bin/bash
# runtime-install.sh — User-space tool installation (entrypoint, shared volume)
# Installs: Node.js, npm globals, .NET, Python/Miniforge, CLI tools, VS Code extensions
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

BOOTSTRAP_MARKER="$HOME/.bootstrap/tools.ready"

# ── Configure PATH for all shells ─────────────────────────────────────────────
configure_path() {
    log_info "Configuring PATH environment..."

    local path_block='# zzaia-path-begin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.dotnet:$HOME/.dotnet/tools:$HOME/miniforge3/bin:$PATH"
# zzaia-path-end'

    for f in "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$f" ] || touch "$f"
        if grep -qF '# zzaia-path-begin' "$f" 2>/dev/null; then
            sed -i '/# zzaia-path-begin/,/# zzaia-path-end/d' "$f"
        fi
        printf '\n%s\n' "$path_block" >> "$f"
    done

    # Also update the current shell so verify_tools() can find installed binaries
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.dotnet:$HOME/.dotnet/tools:$HOME/miniforge3/bin:$PATH"

    log_success "PATH configured"
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
    mkdir -p "$HOME/.bootstrap" "$HOME/.local/bin" "$HOME/.npm-global"

    # Install all tools in order
    python::install_miniforge
    node::install
    node::install_npm_globals
    dotnet::install
    dotnet::install_tools
    python::install_packages
    python::install_conda_envs
    cli::install_gh
    cli::install_k6
    cli::install_d2
    cli::install_dapr
    cli::install_rtk
    cli::install_azure_cli
    cli::install_tectonic

    # Configure environment and verify
    configure_path
    verify_tools

    # Mark bootstrap as complete
    echo "$script_hash" > "$BOOTSTRAP_MARKER"
    log_success "Runtime bootstrap complete"
}

main "$@"
