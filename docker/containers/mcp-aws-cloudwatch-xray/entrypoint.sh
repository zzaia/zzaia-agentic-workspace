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

log_info()    { echo -e "${_B}[mcp-aws-cloudwatch-xray]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-aws-cloudwatch-xray] WARN:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-aws-cloudwatch-xray] ✓${_N} $*"; }

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

    local aws_access_key_id="" aws_secret_access_key="" aws_region=""

    if [ -n "${VAULT_ADDR:-}" ]; then
        vault_approle_login || log_warn "AppRole login failed — secrets will be empty"
    fi

    if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
        local vault_data
        vault_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/aws" 2>/dev/null || echo '{}')
        aws_access_key_id=$(printf '%s' "$vault_data" | jq -r '.data.data.AWS_ACCESS_KEY_ID // empty' 2>/dev/null || echo "")
        aws_secret_access_key=$(printf '%s' "$vault_data" | jq -r '.data.data.AWS_SECRET_ACCESS_KEY // empty' 2>/dev/null || echo "")
        aws_region=$(printf '%s' "$vault_data" | jq -r '.data.data.AWS_REGION // empty' 2>/dev/null || echo "")
    fi

    unset VAULT_TOKEN
    export AWS_ACCESS_KEY_ID="$aws_access_key_id"
    export AWS_SECRET_ACCESS_KEY="$aws_secret_access_key"
    export AWS_REGION="$aws_region"

    log_success "Secrets loaded"
}

# ── Validate secrets ──────────────────────────────────────────────────────────
validate_secrets() {
    if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ] || [ -z "${AWS_REGION}" ]; then
        log_warn "AWS credentials not set - mcp-aws-cloudwatch-xray idle."
        trap 'exit 0' TERM INT
        while :; do sleep 3600 & wait $!; done
    fi
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    cat > /tmp/mcp-runner.sh << 'EOF'
#!/bin/sh
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export AWS_REGION="${AWS_REGION}"
export FASTMCP_LOG_LEVEL="ERROR"
exec uvx awslabs.cloudwatch-applicationsignals-mcp-server@latest
EOF
    chmod +x /tmp/mcp-runner.sh
    log_info "Starting AWS CloudWatch/X-Ray MCP server..."
    exec supergateway --port 3012 --outputTransport streamableHttp --stateful \
        --stdio "/tmp/mcp-runner.sh"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    fetch_secrets
    validate_secrets
    start_server
}

main "$@"
