#!/bin/bash
# entrypoint.sh — Workspace server bootstrap: tools, home, credentials, SSH
set -euo pipefail

SCRIPT_DIR="/usr/local/lib/zzaia/scripts"
export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"
export INSTALL_PREFIX="/opt/tools"

source "$SCRIPT_DIR/common.sh"

# ── GPU setup (DinD support when GPU_ENABLED=true) ────────────────────────────
setup_gpu() {
    if [ "${GPU_ENABLED:-false}" != "true" ]; then
        return 0
    fi

    log_info "Setting up GPU support (DinD)..."

    # Install NVIDIA Container Toolkit inside workspace-server
    if ! command -v nvidia-ctk &>/dev/null; then
        log_info "Installing NVIDIA Container Toolkit..."

        # Add nvidia-container-toolkit repo
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
            | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
            | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
            | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

        apt-get update && apt-get install -y --no-install-recommends nvidia-container-toolkit \
            || log_warn "NVIDIA Container Toolkit install had issues; continuing"
    fi

    # Generate CDI spec for GPU device injection
    if ! [ -f /etc/cdi/nvidia.yaml ]; then
        log_info "Generating CDI spec for GPU devices..."
        mkdir -p /etc/cdi
        nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml \
            || log_warn "CDI spec generation had issues; continuing"
    fi

    # Configure inner Docker daemon with nvidia runtime
    log_info "Configuring Docker daemon with nvidia runtime..."
    nvidia-ctk runtime configure --runtime=docker \
        || log_warn "Docker daemon nvidia runtime config had issues; continuing"

    log_success "GPU support configured (DinD ready)"
}

log_info "Starting zzaia workspace-server..."
log_info "Workspace: $WORKSPACE_NAME"

log_info "Phase 1: User and system setup"
bash "$SCRIPT_DIR/setup-user.sh"

log_info "Phase 2: Runtime tool installation"
mkdir -p "$INSTALL_PREFIX"
chown user:user "$INSTALL_PREFIX"
su -s /bin/bash user -c "INSTALL_PREFIX=$INSTALL_PREFIX HOME=/home/user bash $SCRIPT_DIR/runtime-install.sh"

log_info "Phase 3: Credentials and authentication"
bash "$SCRIPT_DIR/setup-credentials.sh"

log_info "Phase 4: GPU setup (if enabled)"
setup_gpu

log_success "Workspace bootstrap complete"
log_info "Starting SSH daemon..."
exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
