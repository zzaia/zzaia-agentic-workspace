#!/bin/bash
# ml-server/entrypoint.sh — Runtime bootstrap for ml-server with miniforge + venv-system
# Installs: miniforge3, venv-system conda env with headroom-ai, fastapi, uvicorn
# Supports GPU_ENABLED=true for torch variant

set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/ml-tools}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_MARKER="$INSTALL_PREFIX/.bootstrap/venv-system.ready"
VERSIONS_FILE="${VERSIONS_FILE:-/opt/scripts/versions.env}"

# Source versions
if [ -f "$VERSIONS_FILE" ]; then
    source "$VERSIONS_FILE"
fi

log_info()    { echo "[ml-server] $*"; }
log_success() { echo "[ml-server] ✓ $*"; }
log_warn()    { echo "[ml-server] ⚠ $*" >&2; }
log_error()   { echo "[ml-server] ✗ $*" >&2; }

# ── Download and install miniforge3 ────────────────────────────────────────────
install_miniforge() {
    if [ -x "$INSTALL_PREFIX/miniforge3/bin/conda" ]; then
        log_info "Miniforge already installed"
        return 0
    fi

    log_info "Downloading miniforge3..."
    mkdir -p "$INSTALL_PREFIX/.local/share"

    curl -fsSL "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" \
        -o /tmp/miniforge.sh

    log_info "Installing miniforge3 to $INSTALL_PREFIX/miniforge3..."
    bash /tmp/miniforge.sh -b -p "$INSTALL_PREFIX/miniforge3"
    rm /tmp/miniforge.sh

    # Initialize conda for bash
    "$INSTALL_PREFIX/miniforge3/bin/conda" init bash

    log_success "Miniforge installed"
}

# ── Create venv-system conda environment ───────────────────────────────────────
install_venv_system() {
    local conda="$INSTALL_PREFIX/miniforge3/bin/conda"
    local pip="$INSTALL_PREFIX/miniforge3/envs/venv-system/bin/pip"
    local py_ver="${PYTHON_VERSION:-3.12}"

    if [ ! -x "$conda" ]; then
        log_warn "conda not found; skipping venv-system setup"
        return 1
    fi

    log_info "Creating venv-system conda environment with python=${py_ver}..."
    "$conda" create -n venv-system "python=${py_ver}" -y 2>/dev/null || true

    if [ ! -x "$pip" ]; then
        log_warn "pip not found in venv-system"
        return 1
    fi

    log_info "Installing base packages (fastapi, uvicorn, httpx)..."
    "$pip" install --upgrade pip --quiet
    "$pip" install \
        "fastapi${FASTAPI_VERSION:+==${FASTAPI_VERSION}}" \
        "uvicorn${UVICORN_VERSION:+==${UVICORN_VERSION}}" \
        "httpx[http2]" \
        --quiet || log_warn "Some packages failed to install; continuing"

    # Install headroom-ai variant based on GPU_ENABLED
    if [ "${GPU_ENABLED:-false}" = "true" ]; then
        log_info "Installing headroom-ai[ml] with torch (GPU mode)..."
        local torch_spec="torch${TORCH_VERSION:+==${TORCH_VERSION}}"
        local headroom_spec="headroom-ai[ml]${HEADROOM_AI_VERSION:+==${HEADROOM_AI_VERSION}}"

        "$pip" install \
            "$torch_spec" torchvision torchaudio \
            "$headroom_spec" \
            --quiet || log_warn "GPU packages failed to install; continuing"

        log_success "GPU packages installed (torch, headroom-ai[ml])"
    else
        log_info "Installing headroom-ai[code] (CPU mode)..."
        local headroom_spec="headroom-ai[code]${HEADROOM_AI_VERSION:+==${HEADROOM_AI_VERSION}}"

        "$pip" install "$headroom_spec" --quiet || log_warn "headroom-ai[code] failed to install; continuing"

        log_success "CPU packages installed (headroom-ai[code])"
    fi

    log_success "venv-system conda environment ready"
}

# ── Bootstrap venv-system with hash-based marker ───────────────────────────────
bootstrap_venv_system() {
    local script_hash
    script_hash=$(sha256sum "$0" | awk '{print $1}')

    mkdir -p "$INSTALL_PREFIX/.bootstrap"

    if [ -f "$BOOTSTRAP_MARKER" ]; then
        local stored_hash
        stored_hash=$(cat "$BOOTSTRAP_MARKER" 2>/dev/null || echo "")
        if [ "$stored_hash" = "$script_hash" ]; then
            log_info "venv-system already bootstrapped (hash match)"
            return 0
        fi
        log_warn "Script changed — reinstalling venv-system"
    fi

    install_miniforge
    install_venv_system

    echo "$script_hash" > "$BOOTSTRAP_MARKER"
    log_success "venv-system bootstrap complete"
}

# ── Activate venv-system and run headroom proxy ────────────────────────────────
main() {
    log_info "Starting ml-server (GPU_ENABLED=${GPU_ENABLED:-false})..."

    bootstrap_venv_system

    local venv="$INSTALL_PREFIX/miniforge3/envs/venv-system"
    if [ ! -x "$venv/bin/headroom" ]; then
        log_warn "headroom not found in venv-system; attempting pip install..."
        "$INSTALL_PREFIX/miniforge3/bin/pip" install "headroom-ai" --quiet || true
    fi

    if [ ! -x "$venv/bin/headroom" ]; then
        log_error "headroom proxy not available in venv-system"
        exit 1
    fi

    export PATH="$venv/bin:$PATH"
    log_info "Activating venv-system and starting headroom proxy..."
    exec "$venv/bin/headroom" proxy "$@"
}

main "$@"
