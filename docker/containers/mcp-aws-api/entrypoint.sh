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

log_info()    { echo -e "${_B}[mcp-aws-api]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-aws-api] WARN:${_N} $*" >&2; }
log_error()   { echo -e "${_R}[mcp-aws-api] ERROR:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-aws-api] ✓${_N} $*"; }

# ── Validate secrets ──────────────────────────────────────────────────────────
# Secrets are projected into the pod environment by External Secrets Operator
# (Azure Key Vault → Kubernetes Secret → envFrom), so they are already present.
validate_secrets() {
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ] || [ -z "${AWS_REGION:-}" ]; then
        log_error "AWS credentials (AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY/AWS_REGION) not set — cannot start mcp-aws-api. Check the workspace credentials secret projection."
        exit 1
    fi
    log_success "Secrets present"
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    log_info "Starting AWS API MCP server..."
    log_info "Credentials: requires ReadOnlyAccess or narrower IAM scope"
    exec uvx awslabs.aws-api-mcp-server@latest
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    validate_secrets
    start_server
}

main "$@"
