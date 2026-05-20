#!/bin/bash
# entrypoint.sh — Unified headroom proxy entrypoint supporting GPU and CPU modes
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/tools}"
GPU_VENV="$INSTALL_PREFIX/miniforge3/envs/venv-analytics"
LOCAL_VENV="/opt/headroom/venv"
BOOTSTRAP_MARKER="/opt/headroom/.bootstrap/packages.ready"
HEADROOM_PACKAGES="headroom-ai fastapi uvicorn httpx[http2]"

log_info()    { echo "[headroom-proxy] $*"; }
log_success() { echo "[headroom-proxy] ✓ $*"; }
log_warn()    { echo "[headroom-proxy] ⚠ $*" >&2; }

activate_gpu_venv() {
    if [ ! -x "$GPU_VENV/bin/python" ]; then
        log_warn "GPU venv not found at $GPU_VENV — workspace-server may still be bootstrapping"
        return 1
    fi
    log_info "Using GPU venv with Kompress (headroom-ai[ml])"
    export PATH="$GPU_VENV/bin:$PATH"
    return 0
}

bootstrap_cpu_venv() {
    local script_hash
    script_hash=$(sha256sum "$0" | awk '{print $1}')
    mkdir -p /opt/headroom/.bootstrap

    if [ -f "$BOOTSTRAP_MARKER" ]; then
        local stored_hash
        stored_hash=$(cat "$BOOTSTRAP_MARKER" 2>/dev/null || echo "")
        if [ "$stored_hash" = "$script_hash" ]; then
            log_info "CPU packages already installed (hash match) — skipping"
            export PATH="$LOCAL_VENV/bin:$PATH"
            return 0
        fi
        log_warn "Script changed — reinstalling CPU packages"
    fi

    log_info "Installing CPU headroom packages..."
    python3 -m venv "$LOCAL_VENV"
    "$LOCAL_VENV/bin/pip" install --upgrade pip --quiet
    "$LOCAL_VENV/bin/pip" install $HEADROOM_PACKAGES
    log_success "CPU packages installed"

    echo "$script_hash" > "$BOOTSTRAP_MARKER"
    export PATH="$LOCAL_VENV/bin:$PATH"
}

main() {
    log_info "Starting headroom proxy (GPU_ENABLED=${GPU_ENABLED:-false})..."

    if [ "${GPU_ENABLED:-false}" = "true" ]; then
        activate_gpu_venv || bootstrap_cpu_venv
    else
        bootstrap_cpu_venv
    fi

    log_info "Starting headroom proxy server..."
    exec headroom proxy "$@"
}

main "$@"
