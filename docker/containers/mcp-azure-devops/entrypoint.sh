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

log_info()    { echo -e "${_B}[mcp-azure-devops]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-azure-devops] WARN:${_N} $*" >&2; }
log_error()   { echo -e "${_R}[mcp-azure-devops] ERROR:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-azure-devops] ✓${_N} $*"; }

# ── Validate secrets ──────────────────────────────────────────────────────────
# Secrets are projected into the pod environment by External Secrets Operator
# (Bitwarden Secrets Manager → ESO → Kubernetes Secret → envFrom), so they are already present.
validate_secrets() {
    if [ -z "${ADO_MCP_AUTH_TOKEN:-}" ] || [ -z "${AZURE_DEVOPS_ORGANIZATION:-}" ]; then
        log_error "ADO_MCP_AUTH_TOKEN or AZURE_DEVOPS_ORGANIZATION not set — cannot start mcp-azure-devops. Check the workspace credentials secret projection."
        exit 1
    fi
    log_success "Secrets present"
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    log_info "Starting Azure DevOps MCP server..."
    exec supergateway --port 3002 --outputTransport streamableHttp --stateful --stdio "mcp-server-azuredevops ${AZURE_DEVOPS_ORGANIZATION} -a envvar"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    validate_secrets
    start_server
}

main "$@"
