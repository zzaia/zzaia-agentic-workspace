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
log_success() { echo -e "${_G}[mcp-github] ✓${_N} $*"; }

# ── AppRole login ─────────────────────────────────────────────────────────────
vault_approle_login() {
    local cred_file="/secrets/vault-approle-mcp.env"
    [ -f "$cred_file" ] || return 1
    local role_id secret_id
    role_id=$(grep '^VAULT_ROLE_ID=' "$cred_file" | cut -d= -f2-)
    secret_id=$(grep '^VAULT_SECRET_ID=' "$cred_file" | cut -d= -f2-)
    [ -n "$role_id" ] && [ -n "$secret_id" ] || return 1
    local resp
    resp=$(wget -q -O - \
        --post-data="{\"role_id\":\"${role_id}\",\"secret_id\":\"${secret_id}\"}" \
        --header="Content-Type: application/json" \
        "${VAULT_ADDR}/v1/auth/approle/login" 2>/dev/null || echo '{}')
    VAULT_TOKEN=$(printf '%s' "$resp" | jq -r '.auth.client_token // empty' 2>/dev/null || echo "")
    [ -n "$VAULT_TOKEN" ] && export VAULT_TOKEN && return 0 || return 1
}

# ── Fetch secrets ─────────────────────────────────────────────────────────────
fetch_secrets() {
    log_info "Fetching secrets from Vault..."

    local github_pat=""

    if [ -n "${VAULT_ADDR:-}" ]; then
        vault_approle_login || log_warn "AppRole login failed — secret will be empty"
    fi

    if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
        local vault_data
        vault_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/github" 2>/dev/null || echo '{}')
        github_pat=$(printf '%s' "$vault_data" | jq -r '.data.data.GITHUB_PERSONAL_ACCESS_TOKEN // empty' 2>/dev/null || echo "")
    fi

    unset VAULT_TOKEN
    export GITHUB_PERSONAL_ACCESS_TOKEN="$github_pat"

    log_success "Secrets loaded"
}

# ── Validate secrets ──────────────────────────────────────────────────────────
validate_secrets() {
    if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN}" ]; then
        log_warn "GITHUB_PERSONAL_ACCESS_TOKEN not set - mcp-github idle."
        trap 'exit 0' TERM INT
        while :; do sleep 3600 & wait $!; done
    fi
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    log_info "Starting GitHub MCP server..."
    exec supergateway --port 3005 --outputTransport streamableHttp --stdio "npx -y mcp-remote@latest https://api.githubcopilot.com/mcp/ --header \"Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}\""
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    fetch_secrets
    validate_secrets
    start_server
}

main "$@"
