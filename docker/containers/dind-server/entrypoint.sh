#!/bin/bash
# NVIDIA Container Toolkit installation for Alpine DinD (conditional, at runtime)
# This script runs before Docker daemon starts, allowing GPU support when GPU_ENABLED=true

if [ "${GPU_ENABLED:-false}" = "true" ]; then
    echo "[DinD] GPU_ENABLED=true — installing NVIDIA Container Toolkit..."

    if ! command -v nvidia-ctk > /dev/null 2>&1; then
        echo "[DinD] Downloading NVIDIA Container Toolkit..."

        # Detect architecture (release assets use amd64/arm64)
        ARCH=$(uname -m)
        case "${ARCH}" in
            x86_64)  ARCH="amd64" ;;
            aarch64) ARCH="arm64" ;;
            *) echo "[DinD] Unsupported architecture: ${ARCH}"; ARCH="" ;;
        esac

        if [ -n "${ARCH}" ]; then
            # Use sed for BusyBox compatibility (no grep -P on Alpine)
            NVIDIA_TOOLKIT_VERSION=$(curl -s https://api.github.com/repos/NVIDIA/nvidia-container-toolkit/releases/latest \
                | grep '"tag_name"' | head -1 \
                | sed 's/.*"tag_name": "v\([^"]*\)".*/\1/')

            if [ -n "${NVIDIA_TOOLKIT_VERSION}" ]; then
                DOWNLOAD_URL="https://github.com/NVIDIA/nvidia-container-toolkit/releases/download/v${NVIDIA_TOOLKIT_VERSION}/nvidia-container-toolkit_${NVIDIA_TOOLKIT_VERSION}_linux_${ARCH}.tar.gz"
                echo "[DinD] Installing NVIDIA Container Toolkit v${NVIDIA_TOOLKIT_VERSION}..."

                mkdir -p /tmp/nvidia-toolkit
                if curl -fsSL "${DOWNLOAD_URL}" | tar -xz -C /tmp/nvidia-toolkit 2>/dev/null; then
                    cp /tmp/nvidia-toolkit/usr/bin/nvidia-container-runtime \
                       /tmp/nvidia-toolkit/usr/bin/nvidia-ctk \
                       /usr/local/bin/ 2>/dev/null || true
                    rm -rf /tmp/nvidia-toolkit
                    echo "[DinD] NVIDIA Container Toolkit installed successfully"
                else
                    echo "[DinD] WARNING: nvidia-ctk download/extract failed — GPU passthrough inside DinD unavailable"
                    rm -rf /tmp/nvidia-toolkit
                fi
            else
                echo "[DinD] WARNING: Could not resolve nvidia-ctk version — skipping install"
            fi
        fi
    fi

    if command -v nvidia-ctk > /dev/null 2>&1; then
        nvidia-ctk runtime configure --runtime=docker 2>&1 | sed 's/^/[DinD] /'
        echo "[DinD] nvidia runtime configured"
    else
        echo "[DinD] WARNING: nvidia-ctk not available — Docker daemon will start without nvidia runtime"
    fi
fi

# Preserve original Docker entrypoint behavior
# Source the original docker-entrypoint script or run dockerd directly
if [ -f /usr/local/bin/docker-entrypoint ]; then
    # If the original entrypoint exists, use it
    exec /usr/local/bin/docker-entrypoint "$@"
else
    # Otherwise, exec the command directly (usually dockerd)
    exec "$@"
fi
