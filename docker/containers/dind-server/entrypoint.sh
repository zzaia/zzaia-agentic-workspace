#!/bin/bash
# entrypoint.sh — DinD entrypoint with conditional NVIDIA Container Toolkit configuration
set -euo pipefail

# ── Configure GPU ─────────────────────────────────────────────────────────────
configure_gpu() {
    if [ "${GPU_ENABLED:-false}" = "true" ]; then
        echo "[DinD] GPU_ENABLED=true — configuring nvidia runtime..."

        if command -v nvidia-ctk > /dev/null 2>&1; then
            nvidia-ctk runtime configure --runtime=docker 2>&1 | sed 's/^/[DinD] /'
            echo "[DinD] nvidia runtime configured"
        else
            echo "[DinD] WARNING: nvidia-ctk not available — Docker daemon will start without nvidia runtime"
        fi
    fi
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    configure_gpu
    # When TLS is disabled, add TCP listener so Portainer and other clients can connect
    if [ "${DOCKER_TLS_CERTDIR:-}" = "" ]; then
        exec "$@" --host tcp://0.0.0.0:2375 --host unix:///var/run/docker.sock
    else
        exec "$@"
    fi
}

main "$@"
