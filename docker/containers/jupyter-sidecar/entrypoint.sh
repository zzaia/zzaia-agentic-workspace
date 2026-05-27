#!/bin/bash
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/tools}"

log_info()    { echo "[jupyter-sidecar] $*"; }
log_success() { echo "[jupyter-sidecar] ✓ $*"; }
log_error()   { echo "[jupyter-sidecar] ✗ $*" >&2; }

log_info "Starting jupyter-sidecar (GPU_ENABLED=${GPU_ENABLED:-false})..."
log_info "Starting bootstrap via Ansible..."

ANSIBLE_CONFIG="/usr/local/lib/zzaia/ansible/ansible.cfg" \
    ansible-playbook /usr/local/lib/zzaia/ansible/site.yml \
    -e "install_prefix=${INSTALL_PREFIX}" \
    -e "gpu_enabled=${GPU_ENABLED:-false}" \
    -e "workspace_name=${WORKSPACE_NAME:-zzaia}" \
    2>&1

log_success "Bootstrap complete"

jupyter_bin="${INSTALL_PREFIX}/miniforge3/envs/venv-analytics/bin/jupyter"
if [ ! -x "${jupyter_bin}" ]; then
    log_error "jupyter binary not found in venv-analytics"
    exit 1
fi

notebook_dir="/home/user/${WORKSPACE_NAME:-zzaia}"
mkdir -p "${notebook_dir}"

log_info "Starting Jupyter Lab on port ${JUPYTER_PORT:-8888}..."
exec "${jupyter_bin}" lab \
    --ip=0.0.0.0 \
    --port="${JUPYTER_PORT:-8888}" \
    --no-browser \
    --NotebookApp.token='' \
    --NotebookApp.password='' \
    --notebook-dir="${notebook_dir}"
