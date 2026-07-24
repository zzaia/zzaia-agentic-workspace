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

log_info()    { echo -e "${_B}[mcp-tavily]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-tavily] WARN:${_N} $*" >&2; }
log_error()   { echo -e "${_R}[mcp-tavily] ERROR:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-tavily] ✓${_N} $*"; }

# ── Validate secrets ──────────────────────────────────────────────────────────
# Secrets are projected into the pod environment by External Secrets Operator
# (Azure Key Vault → Kubernetes Secret → envFrom), so they are already present.
validate_secrets() {
    if [ -z "${TAVILY_API_KEY:-}" ]; then
        log_error "TAVILY_API_KEY not set — cannot start mcp-tavily. Check the workspace credentials secret projection."
        exit 1
    fi
    log_success "Secrets present"
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    log_info "Starting Tavily MCP server..."
    exec supergateway --port 3001 --outputTransport streamableHttp --stateful --stdio "tavily-mcp"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    validate_secrets
    start_server
}

main "$@"
