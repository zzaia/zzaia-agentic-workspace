#!/bin/bash
set -euo pipefail

# ── Logging ───────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    _G='\033[0;32m'
    _Y='\033[1;33m'
    _B='\033[0;34m'
    _R='\033[0;31m'
    _N='\033[0m'
else
    _G=''
    _Y=''
    _B=''
    _R=''
    _N=''
fi

log_info()    { echo -e "${_B}[mcp-azure-portal]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-azure-portal] WARN:${_N} $*" >&2; }
log_error()   { echo -e "${_R}[mcp-azure-portal] ERROR:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-azure-portal] ✓${_N} $*"; }

# ── Validate secrets ──────────────────────────────────────────────────────────
# Secrets are projected into the pod environment by External Secrets Operator
# (Bitwarden Secrets Manager → ESO → Kubernetes Secret → envFrom), so they are already present.
validate_secrets() {
    if [ -z "${AZURE_CLIENT_ID:-}" ] || [ -z "${AZURE_CLIENT_SECRET:-}" ] || [ -z "${AZURE_TENANT_ID:-}" ]; then
        log_error "Azure credentials (AZURE_CLIENT_ID/AZURE_CLIENT_SECRET/AZURE_TENANT_ID) not set — cannot start mcp-azure-portal. Check the workspace credentials secret projection."
        exit 1
    fi
    log_success "Secrets present"
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    log_info "Starting Azure Portal MCP server..."
    exec supergateway --port 3015 --outputTransport streamableHttp --stateful --stdio "npx -y @azure/mcp@latest server start"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    validate_secrets
    start_server
}

main "$@"
