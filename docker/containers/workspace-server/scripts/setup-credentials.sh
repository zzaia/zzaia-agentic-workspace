#!/bin/bash
# setup-credentials.sh — Workspace templating and Claude plugin setup
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

trap cleanup_secrets EXIT

# ── Template WORKSPACE_NAME in config files ──────────────────────────────────
apply_workspace_templating() {
    log_info "Applying WORKSPACE_NAME templating..."

    WORKSPACE_NAME="$WORKSPACE_NAME" \
    su -s /bin/bash user -c '
        find /home/user /home/user/.vscode-server /home/user/workspace \
            \( -name "*.json" -o -name "*.code-workspace" \) -maxdepth 4 2>/dev/null \
            | xargs sed -i "s/{{WORKSPACE_NAME}}/${WORKSPACE_NAME}/g" 2>/dev/null || true

        # Rename any *.code-workspace that is not already named for this workspace
        for ws in /home/user/*.code-workspace; do
            [ -f "$ws" ] || continue
            target="/home/user/${WORKSPACE_NAME}.code-workspace"
            [ "$ws" = "$target" ] || mv "$ws" "$target" 2>/dev/null || true
        done
    '

    log_success "WORKSPACE_NAME templating complete"
}

# ── Claude Code plugin installation ──────────────────────────────────────────
setup_claude_plugins() {
    log_info "Installing Claude Code plugins..."

    su -s /bin/bash user -c "
        export HOME=/home/user
        export NVM_DIR=/opt/tools/.nvm
        [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
        export PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:\$PATH
        claude plugin marketplace add https://github.com/zzaia/zzaia-agentic-workspace.git#feature/improve-agentic-system || true
        claude plugin install agentic-workspace@zzaia || true
    " && log_success "Claude Code plugins installed" \
      || log_warn "Claude Code plugin install failed; MCP config and settings are pre-seeded"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    apply_workspace_templating
    setup_claude_plugins

    log_success "Workspace setup complete"
}

main "$@"
