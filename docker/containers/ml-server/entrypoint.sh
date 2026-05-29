#!/bin/bash
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/ml-tools}"

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()    { echo "[ml-server] $*"; }
log_success() { echo "[ml-server] ✓ $*"; }
log_error()   { echo "[ml-server] ✗ $*" >&2; }

# ── Bootstrap ─────────────────────────────────────────────────────────────────
bootstrap() {
    log_info "Starting ml-server (GPU_ENABLED=${GPU_ENABLED:-false})..."
    log_info "Starting bootstrap via Ansible..."

    ANSIBLE_CONFIG="/usr/local/lib/zzaia/ansible/ansible.cfg" \
        ansible-playbook /usr/local/lib/zzaia/ansible/site.yml \
        -e "install_prefix=${INSTALL_PREFIX}" \
        -e "gpu_enabled=${GPU_ENABLED:-false}" \
        2>&1

    log_success "Bootstrap complete"
}

# ── Verify headroom ───────────────────────────────────────────────────────────
verify_headroom() {
    local venv="${INSTALL_PREFIX}/miniforge3/envs/venv-system"
    if [ ! -x "${venv}/bin/headroom" ]; then
        log_error "headroom proxy not available in venv-system"
        exit 1
    fi
}

# ── Start headroom proxy ──────────────────────────────────────────────────────
start_headroom() {
    log_info "Starting headroom proxy..."

    local venv="${INSTALL_PREFIX}/miniforge3/envs/venv-system"
    exec "${venv}/bin/headroom" proxy "$@"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    bootstrap
    verify_headroom
    start_headroom "$@"
}

main "$@"
