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
log_success() { echo -e "${_G}[mcp-azure-devops] ✓${_N} $*"; }

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

    local ado_mcp_auth_token=""
    local azure_devops_organization=""

    if [ -n "${VAULT_ADDR:-}" ]; then
        vault_approle_login || log_warn "AppRole login failed — secrets will be empty"
    fi

    if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
        local vault_data
        vault_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/azure-devops" 2>/dev/null || echo '{}')

        ado_mcp_auth_token=$(printf '%s' "$vault_data" | jq -r '.data.data.ADO_MCP_AUTH_TOKEN // empty' 2>/dev/null || echo "")
        azure_devops_organization=$(printf '%s' "$vault_data" | jq -r '.data.data.AZURE_DEVOPS_ORGANIZATION // empty' 2>/dev/null || echo "")
    fi

    unset VAULT_TOKEN
    export ADO_MCP_AUTH_TOKEN="$ado_mcp_auth_token"
    export AZURE_DEVOPS_ORGANIZATION="$azure_devops_organization"

    log_success "Secrets loaded"
}

# ── Validate secrets ──────────────────────────────────────────────────────────
validate_secrets() {
    if [ -z "${ADO_MCP_AUTH_TOKEN}" ] || [ -z "${AZURE_DEVOPS_ORGANIZATION}" ]; then
        log_warn "ADO_MCP_AUTH_TOKEN or AZURE_DEVOPS_ORGANIZATION not set - mcp-azure-devops idle."
        trap 'exit 0' TERM INT
        while :; do sleep 3600 & wait $!; done
    fi
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    log_info "Starting Azure DevOps MCP server..."
    exec supergateway --port 3002 --outputTransport streamableHttp --stateful --stdio "mcp-server-azuredevops ${AZURE_DEVOPS_ORGANIZATION} -a envvar"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    fetch_secrets
    validate_secrets
    start_server
}

main "$@"
