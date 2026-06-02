#!/bin/bash
set -euo pipefail

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

log_info()    { echo -e "${_B}[bifrost-server]${_N} $*"; }
log_warn()    { echo -e "${_Y}[bifrost-server] WARN:${_N} $*" >&2; }
log_success() { echo -e "${_G}[bifrost-server] ✓${_N} $*"; }

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

fetch_secrets() {
    log_info "Fetching secrets from Vault..."

    local anthropic_api_key=""
    local openai_api_key=""
    local gemini_api_key=""

    if [ -n "${VAULT_ADDR:-}" ]; then
        vault_approle_login || log_warn "AppRole login failed — secrets will be empty"
    fi

    if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
        local vault_data
        vault_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/workspace" 2>/dev/null || echo '{}')
        anthropic_api_key=$(printf '%s' "$vault_data" | jq -r '.data.data.ANTHROPIC_API_KEY // empty' 2>/dev/null || echo "")
        claude_oauth_token=$(printf '%s' "$vault_data" | jq -r '.data.data.CLAUDE_CODE_OAUTH_TOKEN // empty' 2>/dev/null || echo "")
        openai_api_key=$(printf '%s' "$vault_data" | jq -r '.data.data.OPENAI_API_KEY // empty' 2>/dev/null || echo "")
        gemini_api_key=$(printf '%s' "$vault_data" | jq -r '.data.data.GEMINI_API_KEY // empty' 2>/dev/null || echo "")
    fi

    unset VAULT_TOKEN
    if [ -n "$claude_oauth_token" ]; then
        export ANTHROPIC_EFFECTIVE_KEY="$claude_oauth_token"
        log_info "Anthropic: using CLAUDE_CODE_OAUTH_TOKEN (Pro/Max)"
    else
        export ANTHROPIC_EFFECTIVE_KEY="$anthropic_api_key"
        log_info "Anthropic: using ANTHROPIC_API_KEY"
    fi
    export OPENAI_API_KEY="$openai_api_key"
    export GEMINI_API_KEY="$gemini_api_key"

    log_success "Secrets loaded"
}

validate_secrets() {
    if [ -z "${ANTHROPIC_EFFECTIVE_KEY}" ] && [ -z "${OPENAI_API_KEY}" ] && [ -z "${GEMINI_API_KEY}" ]; then
        log_warn "No API keys available - bifrost-server idle."
        trap 'exit 0' TERM INT
        while :; do sleep 3600 & wait $!; done
    fi
}

start_server() {
    log_info "Starting Bifrost gateway..."
    exec bifrost
}

main() {
    fetch_secrets
    validate_secrets
    start_server
}

main "$@"
