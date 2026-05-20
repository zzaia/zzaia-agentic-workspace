#!/bin/bash
# entrypoint.nvidia.sh — Bootstrap headroom-ai[ml] packages to a persistent volume
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/headroom}"
VENV_DIR="$INSTALL_PREFIX/venv"
BOOTSTRAP_MARKER="$INSTALL_PREFIX/.bootstrap/packages.ready"
HEADROOM_PACKAGES="headroom-ai[ml] fastapi uvicorn httpx[http2]"

log_info()    { echo "[headroom-nvidia] $*"; }
log_success() { echo "[headroom-nvidia] ✓ $*"; }
log_warn()    { echo "[headroom-nvidia] ⚠ $*" >&2; }

bootstrap_packages() {
    local script_hash
    script_hash=$(sha256sum "$0" | awk '{print $1}')

    mkdir -p "$INSTALL_PREFIX/.bootstrap"

    if [ -f "$BOOTSTRAP_MARKER" ]; then
        local stored_hash
        stored_hash=$(cat "$BOOTSTRAP_MARKER" 2>/dev/null || echo "")
        if [ "$stored_hash" = "$script_hash" ]; then
            log_info "Packages already installed (hash match) — skipping"
            return 0
        fi
        log_warn "Script hash changed — reinstalling packages"
    fi

    log_info "Creating Python venv at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"

    log_info "Installing packages: $HEADROOM_PACKAGES"
    "$VENV_DIR/bin/pip" install --upgrade pip --quiet
    "$VENV_DIR/bin/pip" install $HEADROOM_PACKAGES
    log_success "Packages installed"

    echo "$script_hash" > "$BOOTSTRAP_MARKER"
    log_success "Bootstrap complete"
}

main() {
    log_info "Starting bootstrap..."
    bootstrap_packages

    log_info "Activating venv..."
    export PATH="$VENV_DIR/bin:$PATH"

    log_info "Starting headroom proxy..."
    exec headroom proxy "$@"
}

main "$@"
