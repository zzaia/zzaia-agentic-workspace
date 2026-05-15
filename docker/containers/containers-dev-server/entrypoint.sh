#!/bin/bash
# entrypoint.sh — Dev-server container bootstrap (setup phases, no SSH daemon)
set -euo pipefail

SCRIPT_DIR="/usr/local/lib/zzaia/scripts"
export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

source "$SCRIPT_DIR/common.sh"

log_info "Starting zzaia dev-server container..."
log_info "Workspace: $WORKSPACE_NAME"

log_info "Phase 1: User and system setup"
bash "$SCRIPT_DIR/setup-user.sh"

log_info "Phase 2: Runtime tools bootstrap"
bash "$SCRIPT_DIR/setup-tools.sh"

log_info "Phase 3: Credentials and authentication"
bash "$SCRIPT_DIR/setup-credentials.sh"

log_success "Dev-server bootstrap complete — container ready for devcontainer connection"
exec sleep infinity
