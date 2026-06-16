#!/bin/bash
set -euo pipefail

if [ -t 1 ]; then
    _G='\033[0;32m'
    _Y='\033[1;33m'
    _B='\033[0;34m'
    _N='\033[0m'
else
    _G=''; _Y=''; _B=''; _N=''
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

    local anthropic_api_key="" claude_oauth_token="" openai_api_key="" gemini_api_key="" new_relic_api_key="" aws_key_id=""
    local -a pool_keys=()

    if [ -n "${VAULT_ADDR:-}" ]; then
        vault_approle_login || log_warn "AppRole login failed — no AI keys available"
    fi

    if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
        local vault_data
        vault_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/ai" 2>/dev/null || echo '{}')
        anthropic_api_key=$(printf '%s' "$vault_data" | jq -r '.data.data.ANTHROPIC_API_KEY // empty' 2>/dev/null || echo "")
        claude_oauth_token=$(printf '%s' "$vault_data" | jq -r '.data.data.CLAUDE_CODE_OAUTH_TOKEN // empty' 2>/dev/null || echo "")
        openai_api_key=$(printf '%s' "$vault_data" | jq -r '.data.data.OPENAI_API_KEY // empty' 2>/dev/null || echo "")
        gemini_api_key=$(printf '%s' "$vault_data" | jq -r '.data.data.GEMINI_API_KEY // empty' 2>/dev/null || echo "")

        local idx=1
        while true; do
            local oauth_val api_val
            oauth_val=$(printf '%s' "$vault_data" | jq -r ".data.data.CLAUDE_OAUTH_TOKEN_${idx} // empty" 2>/dev/null || echo "")
            api_val=$(printf '%s' "$vault_data" | jq -r ".data.data.ANTHROPIC_API_KEY_${idx} // empty" 2>/dev/null || echo "")
            [ -z "$oauth_val" ] && [ -z "$api_val" ] && break
            if [ -n "$oauth_val" ]; then
                pool_keys+=("$oauth_val")
                export ANTHROPIC_POOL_KEY_${idx}="$oauth_val"
            elif [ -n "$api_val" ]; then
                pool_keys+=("$api_val")
                export ANTHROPIC_POOL_KEY_${idx}="$api_val"
            fi
            idx=$((idx + 1))
        done

        local integrations_data
        integrations_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/integrations" 2>/dev/null || echo '{}')
        new_relic_api_key=$(printf '%s' "$integrations_data" | jq -r '.data.data.NEW_RELIC_API_KEY // empty' 2>/dev/null || echo "")

        local aws_data
        aws_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/aws" 2>/dev/null || echo '{}')
        aws_key_id=$(printf '%s' "$aws_data" | jq -r '.data.data.AWS_ACCESS_KEY_ID // empty' 2>/dev/null || echo "")
    fi

    unset VAULT_TOKEN
    export NEW_RELIC_API_KEY_AVAILABLE=""
    [ -n "$new_relic_api_key" ] && export NEW_RELIC_API_KEY_AVAILABLE="true" && log_info "New Relic: API key available" || log_warn "New Relic: no API key — skipping newrelic MCP"

    export AWS_MCP_AVAILABLE=""
    [ -n "$aws_key_id" ] && export AWS_MCP_AVAILABLE="true" && log_info "AWS: credentials available" || log_warn "AWS: no credentials — skipping AWS MCP tools"

    if [ ${#pool_keys[@]} -gt 0 ]; then
        export ANTHROPIC_POOL_ENABLED="true"
        log_info "Anthropic: pool mode enabled with ${#pool_keys[@]} credential(s)"
    elif [ -n "$claude_oauth_token" ]; then
        export ANTHROPIC_EFFECTIVE_KEY="$claude_oauth_token"
        log_info "Anthropic: using CLAUDE_CODE_OAUTH_TOKEN (Pro/Max)"
    elif [ -n "$anthropic_api_key" ]; then
        export ANTHROPIC_EFFECTIVE_KEY="$anthropic_api_key"
        log_info "Anthropic: using ANTHROPIC_API_KEY"
    else
        export ANTHROPIC_EFFECTIVE_KEY=""
        log_warn "Anthropic: no key available"
    fi
    export OPENAI_API_KEY="$openai_api_key"
    export GEMINI_API_KEY="$gemini_api_key"

    log_success "Secrets loaded"
}

start_auth_proxy() {
    if [ -n "${ANTHROPIC_EFFECTIVE_KEY:-}" ] || [ "${ANTHROPIC_POOL_ENABLED:-}" = "true" ]; then
        log_info "Starting Bearer auth proxy on 127.0.0.1:8099..."
        python3 /auth_proxy.py &
        sleep 1
        log_success "Bearer auth proxy started"
    fi
}

generate_config() {
    local providers=""
    local sep=""
    local workspace_key="${BIFROST_WORKSPACE_KEY:-sk-bf-workspace-agent-001}"
    local newrelic_entry=""
    [ -n "${NEW_RELIC_API_KEY_AVAILABLE:-}" ] && \
        newrelic_entry='      { "name": "newrelic", "connection_type": "http", "connection_string": "http://mcp-newrelic:3004/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },'

    local aws_entries=""
    [ -n "${AWS_MCP_AVAILABLE:-}" ] && aws_entries='
      { "name": "aws_sns_sqs", "connection_type": "http", "connection_string": "http://mcp-aws-sns-sqs:3010/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },
      { "name": "aws_cloudwatch", "connection_type": "http", "connection_string": "http://mcp-aws-cloudwatch:3011/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },
      { "name": "aws_cloudwatch_xray", "connection_type": "http", "connection_string": "http://mcp-aws-cloudwatch-xray:3012/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },
      { "name": "aws_ecs", "connection_type": "http", "connection_string": "http://mcp-aws-ecs:3013/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },
      { "name": "aws_postgres", "connection_type": "http", "connection_string": "http://mcp-aws-postgres:3014/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },'

    local anthropic_keys=""
    if [ "${ANTHROPIC_POOL_ENABLED:-}" = "true" ]; then
        local idx=1
        while [ -n "$(eval echo \${ANTHROPIC_POOL_KEY_${idx}:-})" ]; do
            if [ -n "$anthropic_keys" ]; then
                anthropic_keys="${anthropic_keys},"
            fi
            anthropic_keys="${anthropic_keys}
      { \"name\": \"pool-${idx}\", \"value\": \"env.ANTHROPIC_POOL_KEY_${idx}\", \"weight\": 1, \"models\": [\"*\"] }"
            idx=$((idx + 1))
        done
    elif [ -n "${ANTHROPIC_EFFECTIVE_KEY:-}" ]; then
        anthropic_keys="{ \"name\": \"primary\", \"value\": \"env.ANTHROPIC_EFFECTIVE_KEY\", \"weight\": 1, \"models\": [\"*\"] }"
    fi

    if [ -n "$anthropic_keys" ]; then
        providers="${providers}${sep}
    \"anthropic\": {
      \"keys\": [${anthropic_keys}
      ],
      \"network_config\": { \"base_url\": \"http://127.0.0.1:8099\" }
    }"
        sep=","
    fi
    if [ -n "${OPENAI_API_KEY:-}" ]; then
        providers="${providers}${sep}
    \"openai\": { \"keys\": [{ \"name\": \"primary\", \"value\": \"env.OPENAI_API_KEY\", \"weight\": 1, \"models\": [\"*\"] }] }"
        sep=","
    fi
    if [ -n "${GEMINI_API_KEY:-}" ]; then
        providers="${providers}${sep}
    \"gemini\": { \"keys\": [{ \"name\": \"primary\", \"value\": \"env.GEMINI_API_KEY\", \"weight\": 1, \"models\": [\"*\"] }] }"
    fi

    cat > /app/data/config.json << EOF
{
  "\$schema": "https://www.getbifrost.ai/schema",
  "providers": {${providers}
  },
  "governance": {
    "virtual_keys": [
      {
        "id": "workspace-agent",
        "name": "Workspace Agent",
        "value": "${workspace_key}",
        "provider_configs": [
          { "provider": "anthropic", "allowed_models": ["*"], "key_ids": ["*"] }
        ]
      }
    ]
  },
  "mcp": {
    "client_configs": [
      { "name": "tavily", "connection_type": "http", "connection_string": "http://mcp-tavily:3001/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },
      { "name": "azure_devops", "connection_type": "http", "connection_string": "http://mcp-azure-devops:3002/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },
      { "name": "postman", "connection_type": "http", "connection_string": "http://mcp-postman:3003/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },
      ${newrelic_entry}
      { "name": "github", "connection_type": "http", "connection_string": "http://mcp-github:3005/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },
      { "name": "playwright", "connection_type": "http", "connection_string": "http://mcp-playwright:3006/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true }${aws_entries}
    ]
  }
}
EOF

    if [ -z "$providers" ]; then
        log_warn "No API keys configured — bifrost starts without providers (add keys via Vault UI)"
    else
        log_success "Config generated with available providers"
    fi
}

start_server() {
    log_info "Starting Bifrost gateway..."
    exec /app/main -app-dir /app/data -host 0.0.0.0
}

main() {
    fetch_secrets
    start_auth_proxy
    generate_config
    start_server
}

main "$@"
