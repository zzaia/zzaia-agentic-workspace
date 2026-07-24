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

log_info()    { echo -e "${_B}[mcp-newrelic]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-newrelic] WARN:${_N} $*" >&2; }
log_error()   { echo -e "${_R}[mcp-newrelic] ERROR:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-newrelic] ✓${_N} $*"; }

# ── Validate secrets ──────────────────────────────────────────────────────────
# Secrets are projected into the pod environment by External Secrets Operator
# (Azure Key Vault → Kubernetes Secret → envFrom), so they are already present.
validate_secrets() {
    if [ -z "${NEW_RELIC_API_KEY:-}" ]; then
        log_error "NEW_RELIC_API_KEY not set — cannot start mcp-newrelic. Check the workspace credentials secret projection."
        exit 1
    fi
    log_success "Secrets present"
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    # Wrapper passes auth header to mcp-remote without exposing token in supergateway logs
    cat > /tmp/mcp-runner.sh << 'EOF'
#!/bin/sh
exec npx -y mcp-remote@latest https://mcp.newrelic.com/mcp/ \
    --header "Api-Key: ${NEW_RELIC_API_KEY}"
EOF
    chmod +x /tmp/mcp-runner.sh
    log_info "Starting New Relic MCP server..."
    exec supergateway --port 3004 --outputTransport streamableHttp --stateful \
        --stdio "/tmp/mcp-runner.sh"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    validate_secrets
    start_server
}

main "$@"
