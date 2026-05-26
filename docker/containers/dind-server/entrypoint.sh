#!/bin/bash
# DinD entrypoint with conditional NVIDIA Container Toolkit configuration

if [ "${GPU_ENABLED:-false}" = "true" ]; then
    echo "[DinD] GPU_ENABLED=true — configuring nvidia runtime..."

    if command -v nvidia-ctk > /dev/null 2>&1; then
        nvidia-ctk runtime configure --runtime=docker 2>&1 | sed 's/^/[DinD] /'
        echo "[DinD] nvidia runtime configured"
    else
        echo "[DinD] WARNING: nvidia-ctk not available — Docker daemon will start without nvidia runtime"
    fi
fi

exec "$@"
