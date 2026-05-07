#!/bin/bash
# entrypoint.sh — Main orchestrator for workspace bootstrap
# Sources modular setup scripts in /usr/local/lib/zzaia/scripts/ for clarity and maintainability
set -euo pipefail

SCRIPT_DIR="/usr/local/lib/zzaia/scripts"
export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

# Source common utilities
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

# ── Log startup ───────────────────────────────────────────────────────────────
log_info "Starting zzaia workspace container..."
log_info "Workspace: $WORKSPACE_NAME"

# ── Phase 1: User setup (home, SSH, permissions) ─────────────────────────────
log_info "Phase 1: User and system setup"
bash "$SCRIPT_DIR/setup-user.sh"

# ── Phase 2: Runtime tools (mise, node, python, etc.) ────────────────────────
log_info "Phase 2: Runtime tools bootstrap"
bash "$SCRIPT_DIR/setup-tools.sh"

# ── Phase 3: Credentials (Claude, GitHub, Azure) ─────────────────────────────
log_info "Phase 3: Credentials and authentication"
bash "$SCRIPT_DIR/setup-credentials.sh"

# ── Phase 4: Aspire MCP service ───────────────────────────────────────────────
log_info "Phase 4: Starting Aspire MCP"
bash "$SCRIPT_DIR/setup-aspire.sh"

# ── All done, start SSH daemon ────────────────────────────────────────────────
log_success "All bootstrap phases complete"
log_info "Starting SSH daemon..."

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
