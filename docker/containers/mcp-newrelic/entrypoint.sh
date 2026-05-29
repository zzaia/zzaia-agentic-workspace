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
log_success() { echo -e "${_G}[mcp-newrelic] ✓${_N} $*"; }

# ── Fetch secrets ─────────────────────────────────────────────────────────────
fetch_secrets() {
    log_info "Fetching secrets from Vault..."

    local new_relic_api_key=""

    if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
        local vault_data
        vault_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/newrelic" 2>/dev/null || echo '{}')
        new_relic_api_key=$(printf '%s' "$vault_data" | jq -r '.data.data.NEW_RELIC_API_KEY // empty' 2>/dev/null || echo "")
    fi

    export NEW_RELIC_API_KEY="$new_relic_api_key"

    log_success "Secrets loaded"
}

# ── Validate secrets ──────────────────────────────────────────────────────────
validate_secrets() {
    if [ -z "${NEW_RELIC_API_KEY}" ]; then
        log_warn "NEW_RELIC_API_KEY not set - mcp-newrelic idle."
        trap 'exit 0' TERM INT
        while :; do sleep 3600 & wait $!; done
    fi
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    log_info "Starting New Relic MCP server..."
    exec supergateway --port 3004 --outputTransport streamableHttp --stateful --stdio "npx -y mcp-remote@latest https://mcp.newrelic.com/mcp/ --header \"Api-Key: ${NEW_RELIC_API_KEY}\""
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    fetch_secrets
    validate_secrets
    start_server
}

main "$@"
