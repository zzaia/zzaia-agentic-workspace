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

log_info()    { echo -e "${_B}[mcp-github]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-github] WARN:${_N} $*" >&2; }
log_error()   { echo -e "${_R}[mcp-github] ERROR:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-github] ✓${_N} $*"; }

# ── Validate secrets ──────────────────────────────────────────────────────────
# Secrets are projected into the pod environment by External Secrets Operator
# (Azure Key Vault → Kubernetes Secret → envFrom), so they are already present.
validate_secrets() {
    if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
        log_error "GITHUB_PERSONAL_ACCESS_TOKEN not set — cannot start mcp-github. Check the workspace credentials secret projection."
        exit 1
    fi
    log_success "Secrets present"
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    # Wrapper passes auth header to mcp-remote without exposing token in supergateway logs
    cat > /tmp/mcp-runner.sh << 'EOF'
#!/bin/sh
exec mcp-remote https://api.githubcopilot.com/mcp/ \
    --header "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"
EOF
    chmod +x /tmp/mcp-runner.sh
    log_info "Starting GitHub MCP server..."
    exec supergateway --port 3005 --outputTransport streamableHttp --stateful \
        --stdio "/tmp/mcp-runner.sh"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    validate_secrets
    start_server
}

main "$@"
