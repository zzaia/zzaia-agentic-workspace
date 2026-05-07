#!/bin/bash
# setup-aspire.sh — Start Aspire MCP as shared service
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ── Aspire MCP initialization ─────────────────────────────────────────────────
start_aspire_mcp() {
    log_info "Starting Aspire MCP service..."
    
    ensure_dir "/home/user/.local/share/vscode-server"
    
    su -s /bin/bash user -c "
        export PATH=/home/user/.local/share/mise/shims:/home/user/.local/bin:\$PATH
        npx -y supergateway@latest --port 3007 --stdio 'aspire mcp start --dashboard-endpoint http://vscode-server:17001' \
            >> /home/user/.local/share/vscode-server/aspire-mcp.log 2>&1 &
    "
    
    log_success "Aspire MCP started in background"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    start_aspire_mcp
}

main "$@"
