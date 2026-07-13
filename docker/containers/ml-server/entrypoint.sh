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
    exec "${venv}/bin/opentelemetry-instrument" "${venv}/bin/headroom" proxy "$@" \
        --log-messages \
        --log-file /home/headroom/.headroom/logs/proxy_messages.jsonl
}

# ── Main entry point ──────────────────────────────────────────────────────────
# ── Start embeddings server (GPU mode only) ────────────────────────────────
start_embeddings_server() {
    if [ "${GPU_ENABLED:-false}" != "true" ]; then
        return 0
    fi

    log_info "Starting embeddings server on port 8788 (GPU mode)..."

    local venv="${INSTALL_PREFIX}/miniforge3/envs/venv-system"
    "${venv}/bin/python" /opt/ml-tools/embeddings_server.py &
    local server_pid=$!
    sleep 2

    if kill -0 $server_pid 2>/dev/null; then
        log_success "Embeddings server started (PID: $server_pid)"
        return 0
    else
        log_error "Embeddings server failed to start"
        return 1
    fi
}

main() {
    bootstrap
    verify_headroom
    start_embeddings_server || log_warn "Embeddings server failed to start — GPU-mode local embedder unavailable, continuing with Headroom only"
    start_headroom "$@"
}

main "$@"
