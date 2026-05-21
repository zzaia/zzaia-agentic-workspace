#!/bin/bash
set -e

# NVIDIA Container Toolkit installation for Alpine DinD (conditional, at runtime)
# This script runs before Docker daemon starts, allowing GPU support when GPU_ENABLED=true

if [ "${GPU_ENABLED:-false}" = "true" ]; then
    echo "[DinD] GPU_ENABLED=true — installing NVIDIA Container Toolkit..."

    # Add NVIDIA repository and install toolkit
    # For Alpine, we download the pre-built binaries directly since Alpine edge repos aren't guaranteed stable
    if ! command -v nvidia-ctk &> /dev/null; then
        echo "[DinD] Downloading NVIDIA Container Toolkit..."

        # Detect architecture
        ARCH=$(uname -m)
        case "${ARCH}" in
            x86_64) ARCH="x86_64" ;;
            aarch64) ARCH="arm64" ;;
            *) echo "[DinD] Unsupported architecture: ${ARCH}"; exit 1 ;;
        esac

        # Download latest nvidia-container-toolkit release
        NVIDIA_TOOLKIT_VERSION=$(curl -s https://api.github.com/repos/NVIDIA/nvidia-container-toolkit/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)
        NVIDIA_TOOLKIT_VERSION=${NVIDIA_TOOLKIT_VERSION#v}

        DOWNLOAD_URL="https://github.com/NVIDIA/nvidia-container-toolkit/releases/download/v${NVIDIA_TOOLKIT_VERSION}/nvidia-container-toolkit-${NVIDIA_TOOLKIT_VERSION}-${ARCH}.tar.gz"

        echo "[DinD] Installing NVIDIA Container Toolkit v${NVIDIA_TOOLKIT_VERSION}..."
        curl -fsSL "${DOWNLOAD_URL}" | tar -xz -C /usr/local/bin nvidia-container-toolkit nvidia-container-runtime nvidia-ctk

        # Verify installation
        if ! nvidia-ctk --version &> /dev/null; then
            echo "[DinD] ERROR: nvidia-ctk installation failed"
            exit 1
        fi

        echo "[DinD] NVIDIA Container Toolkit installed successfully"
    fi

    # Configure Docker daemon to use nvidia runtime — must run BEFORE dockerd starts
    nvidia-ctk runtime configure --runtime=docker 2>&1 | sed 's/^/[DinD] /'
    echo "[DinD] nvidia runtime configured"
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
