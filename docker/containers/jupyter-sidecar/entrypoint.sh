#!/bin/bash
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/tools}"

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()    { echo "[jupyter-sidecar] $*"; }
log_success() { echo "[jupyter-sidecar] ✓ $*"; }
log_error()   { echo "[jupyter-sidecar] ✗ $*" >&2; }

# ── Setup sudo password ───────────────────────────────────────────────────────
setup_sudo_password() {
    local pw
    pw=$(runuser -u user -- cat /run/secrets/admin_password 2>/dev/null || echo "")
    if [ -n "$pw" ]; then
        echo "user:$pw" | chpasswd
    else
        echo "ERROR: admin_password secret not found — sudo is mandatory, refusing to start" >&2
        exit 1
    fi
}

# ── Bootstrap ─────────────────────────────────────────────────────────────────
bootstrap() {
    log_info "Starting jupyter-sidecar (GPU_ENABLED=${GPU_ENABLED:-false})..."
    log_info "Starting bootstrap via Ansible..."

    ANSIBLE_CONFIG="/usr/local/lib/zzaia/ansible/ansible.cfg" \
        runuser -u user -- ansible-playbook /usr/local/lib/zzaia/ansible/site.yml \
        -e "install_prefix=${INSTALL_PREFIX}" \
        -e "gpu_enabled=${GPU_ENABLED:-false}" \
        -e "workspace_name=${WORKSPACE_NAME:-zzaia}" \
        2>&1

    log_success "Bootstrap complete"
}

# ── Verify jupyter ────────────────────────────────────────────────────────────
verify_jupyter() {
    local jupyter_bin="${INSTALL_PREFIX}/miniforge3/envs/venv-analytics/bin/jupyter"
    if [ ! -x "${jupyter_bin}" ]; then
        log_error "jupyter binary not found in venv-analytics"
        exit 1
    fi
}

# ── Start jupyter lab ─────────────────────────────────────────────────────────
start_jupyter() {
    log_info "Starting Jupyter Lab on port ${JUPYTER_PORT:-8888}..."

    local jupyter_bin="${INSTALL_PREFIX}/miniforge3/envs/venv-analytics/bin/jupyter"
    local notebook_dir="/home/user/${WORKSPACE_NAME:-zzaia}"
    mkdir -p "${notebook_dir}"

    exec runuser -u user -- "${jupyter_bin}" lab \
        --ip=0.0.0.0 \
        --port="${JUPYTER_PORT:-8888}" \
        --no-browser \
        --NotebookApp.token='' \
        --NotebookApp.password='' \
        --notebook-dir="${notebook_dir}"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    setup_sudo_password
    bootstrap
    verify_jupyter
    start_jupyter
}

main "$@"
