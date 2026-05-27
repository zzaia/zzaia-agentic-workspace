#!/bin/bash
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/ml-tools}"

log_info()    { echo "[ml-server] $*"; }
log_success() { echo "[ml-server] ✓ $*"; }
log_error()   { echo "[ml-server] ✗ $*" >&2; }

log_info "Starting ml-server (GPU_ENABLED=${GPU_ENABLED:-false})..."
log_info "Starting bootstrap via Ansible..."

ANSIBLE_CONFIG="/usr/local/lib/zzaia/ansible/ansible.cfg" \
    ansible-playbook /usr/local/lib/zzaia/ansible/site.yml \
    -e "install_prefix=${INSTALL_PREFIX}" \
    -e "gpu_enabled=${GPU_ENABLED:-false}" \
    2>&1

log_success "Bootstrap complete"

venv="${INSTALL_PREFIX}/miniforge3/envs/venv-system"
if [ ! -x "${venv}/bin/headroom" ]; then
    log_error "headroom proxy not available in venv-system"
    exit 1
fi

log_info "Starting headroom proxy..."
exec "${venv}/bin/headroom" proxy "$@"
