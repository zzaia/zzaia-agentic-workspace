#!/bin/bash
# entrypoint.sh — Workspace server bootstrap: tools, home, credentials, SSH
set -euo pipefail

SCRIPT_DIR="/usr/local/lib/zzaia/scripts"
export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"
export INSTALL_PREFIX="/opt/tools"

source "$SCRIPT_DIR/common.sh"

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

log_success "Workspace bootstrap complete"
log_info "Starting SSH daemon..."
exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
