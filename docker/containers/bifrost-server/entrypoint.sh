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
    local tavily_api_key="" github_pat="" postman_api_key="" ado_auth_token=""
    local bifrost_vkey_claude_pro="" bifrost_vkey_agents_generic=""
    local -a oauth_keys=() apikey_keys=()

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
        bifrost_vkey_claude_pro=$(printf '%s' "$vault_data" | jq -r '.data.data.BIFROST_VIRTUAL_KEY_CLAUDE_PRO // empty' 2>/dev/null || echo "")
        bifrost_vkey_agents_generic=$(printf '%s' "$vault_data" | jq -r '.data.data.BIFROST_VIRTUAL_KEY_AGENTS_GENERIC // empty' 2>/dev/null || echo "")

        local idx=1
        while true; do
            local oauth_val api_val
            oauth_val=$(printf '%s' "$vault_data" | jq -r ".data.data.CLAUDE_OAUTH_TOKEN_${idx} // empty" 2>/dev/null || echo "")
            api_val=$(printf '%s' "$vault_data" | jq -r ".data.data.ANTHROPIC_API_KEY_${idx} // empty" 2>/dev/null || echo "")
            [ -z "$oauth_val" ] && [ -z "$api_val" ] && break
            [ -n "$oauth_val" ] && oauth_keys+=("$oauth_val") && export ANTHROPIC_OAUTH_${idx}="$oauth_val"
            [ -n "$api_val" ] && apikey_keys+=("$api_val") && export ANTHROPIC_APIKEY_${idx}="$api_val"
            idx=$((idx + 1))
        done

        local integrations_data
        integrations_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/integrations" 2>/dev/null || echo '{}')
        new_relic_api_key=$(printf '%s' "$integrations_data" | jq -r '.data.data.NEW_RELIC_API_KEY // empty' 2>/dev/null || echo "")
        tavily_api_key=$(printf '%s' "$vault_data" | jq -r '.data.data.TAVILY_API_KEY // empty' 2>/dev/null || echo "")

        local aws_data
        aws_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/aws" 2>/dev/null || echo '{}')
        aws_key_id=$(printf '%s' "$aws_data" | jq -r '.data.data.AWS_ACCESS_KEY_ID // empty' 2>/dev/null || echo "")

        local github_data
        github_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/github" 2>/dev/null || echo '{}')
        github_pat=$(printf '%s' "$github_data" | jq -r '.data.data.GITHUB_PERSONAL_ACCESS_TOKEN // empty' 2>/dev/null || echo "")

        local postman_data
        postman_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/postman" 2>/dev/null || echo '{}')
        postman_api_key=$(printf '%s' "$postman_data" | jq -r '.data.data.POSTMAN_API_KEY // empty' 2>/dev/null || echo "")

        local ado_data
        ado_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/azure-devops" 2>/dev/null || echo '{}')
        ado_auth_token=$(printf '%s' "$ado_data" | jq -r '.data.data.ADO_MCP_AUTH_TOKEN // empty' 2>/dev/null || echo "")

        local azure_portal_data azure_portal_client_id=""
        azure_portal_data=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/secret/data/mcp/azure-portal" 2>/dev/null || echo '{}')
        azure_portal_client_id=$(printf '%s' "$azure_portal_data" | jq -r '.data.data.AZURE_CLIENT_ID // empty' 2>/dev/null || echo "")
    fi

    export TAVILY_AVAILABLE=""; [ -n "$tavily_api_key" ] && export TAVILY_AVAILABLE="true"
    export GITHUB_AVAILABLE=""; [ -n "$github_pat" ] && export GITHUB_AVAILABLE="true"
    export POSTMAN_AVAILABLE=""; [ -n "$postman_api_key" ] && export POSTMAN_AVAILABLE="true"
    export ADO_AVAILABLE=""; [ -n "$ado_auth_token" ] && export ADO_AVAILABLE="true"
    export AZURE_PORTAL_AVAILABLE=""; [ -n "$azure_portal_client_id" ] && export AZURE_PORTAL_AVAILABLE="true"

    unset VAULT_TOKEN
    export NEW_RELIC_API_KEY_AVAILABLE=""
    [ -n "$new_relic_api_key" ] && export NEW_RELIC_API_KEY_AVAILABLE="true" && log_info "New Relic: API key available" || log_warn "New Relic: no API key — skipping newrelic MCP"

    export AWS_MCP_AVAILABLE=""
    [ -n "$aws_key_id" ] && export AWS_MCP_AVAILABLE="true" && log_info "AWS: credentials available" || log_warn "AWS: no credentials — skipping AWS MCP tools"

    [ -z "${TAVILY_AVAILABLE:-}" ] && log_warn "Tavily: no API key — skipping mcp-tavily"
    [ -z "${GITHUB_AVAILABLE:-}" ] && log_warn "GitHub: no PAT — skipping mcp-github"
    [ -z "${POSTMAN_AVAILABLE:-}" ] && log_warn "Postman: no API key — skipping mcp-postman"
    [ -z "${ADO_AVAILABLE:-}" ] && log_warn "Azure DevOps: no token — skipping mcp-azure-devops"
    [ -z "${AZURE_PORTAL_AVAILABLE:-}" ] && log_warn "Azure Portal: no credentials — skipping mcp-azure-portal"

    export ANTHROPIC_OAUTH_VALUES=$(IFS=$'\n'; echo "${oauth_keys[*]}")
    export ANTHROPIC_APIKEY_POOL_VALUES=$(IFS=$'\n'; echo "${apikey_keys[*]}")

    if [ -z "$bifrost_vkey_claude_pro" ]; then
        bifrost_vkey_claude_pro="${BIFROST_VIRTUAL_KEY_CLAUDE_PRO:-sk-bf-claude-pro-001}"
        log_info "Anthropic: using default claude-pro virtual key"
    fi
    if [ -z "$bifrost_vkey_agents_generic" ]; then
        bifrost_vkey_agents_generic="${BIFROST_VIRTUAL_KEY_AGENTS_GENERIC:-sk-bf-agents-generic-001}"
        log_info "Anthropic: using default agents-generic virtual key"
    fi
    export BIFROST_VIRTUAL_KEY_CLAUDE_PRO="$bifrost_vkey_claude_pro"
    export BIFROST_VIRTUAL_KEY_AGENTS_GENERIC="$bifrost_vkey_agents_generic"

    if [ ${#oauth_keys[@]} -gt 0 ] || [ ${#apikey_keys[@]} -gt 0 ]; then
        export ANTHROPIC_TIER_MODE="two-tier"
        log_info "Anthropic: two-tier pool mode (Tier-1: ${#oauth_keys[@]} OAuth [fallback: shared Tier-2 pool], Tier-2: ${#apikey_keys[@]} API-keys)"
    elif [ -n "$claude_oauth_token" ]; then
        export ANTHROPIC_TIER_MODE="single"
        export ANTHROPIC_EFFECTIVE_KEY="$claude_oauth_token"
        export ANTHROPIC_EFFECTIVE_KEY_TYPE="oauth"
        log_info "Anthropic: single key mode (Pro/Max OAuth)"
    elif [ -n "$anthropic_api_key" ]; then
        export ANTHROPIC_TIER_MODE="single"
        export ANTHROPIC_EFFECTIVE_KEY="$anthropic_api_key"
        export ANTHROPIC_EFFECTIVE_KEY_TYPE="apikey"
        log_info "Anthropic: single key mode (API key)"
    else
        export ANTHROPIC_TIER_MODE="single"
        export ANTHROPIC_EFFECTIVE_KEY=""
        export ANTHROPIC_EFFECTIVE_KEY_TYPE=""
        log_warn "Anthropic: no key available"
    fi
    export OPENAI_API_KEY="$openai_api_key"
    export GEMINI_API_KEY="$gemini_api_key"

    log_success "Secrets loaded"
}

start_auth_proxy() {
    if [ -n "${ANTHROPIC_EFFECTIVE_KEY:-}" ] || [ "${ANTHROPIC_TIER_MODE:-}" = "two-tier" ]; then
        log_info "Starting credential tier proxy on 127.0.0.1:8099..."
        python3 /auth_proxy.py &
        sleep 1
        log_success "Credential tier proxy started"
    fi
}

generate_config() {
    local providers=""
    local sep=""
    local workspace_key="${BIFROST_WORKSPACE_KEY:-sk-bf-workspace-agent-001}"
    local newrelic_entry=""
    [ -n "${NEW_RELIC_API_KEY_AVAILABLE:-}" ] && \
        newrelic_entry='      { "name": "newrelic", "connection_type": "http", "connection_string": "http://mcp-newrelic:3004/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },'

    local tavily_entry=""
    [ -n "${TAVILY_AVAILABLE:-}" ] && \
        tavily_entry='{ "name": "tavily", "connection_type": "http", "connection_string": "http://mcp-tavily:3001/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },'

    local github_entry=""
    [ -n "${GITHUB_AVAILABLE:-}" ] && \
        github_entry='{ "name": "github", "connection_type": "http", "connection_string": "http://mcp-github:3005/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },'

    local postman_entry=""
    [ -n "${POSTMAN_AVAILABLE:-}" ] && \
        postman_entry='{ "name": "postman", "connection_type": "http", "connection_string": "http://mcp-postman:3003/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },'

    local ado_entry=""
    [ -n "${ADO_AVAILABLE:-}" ] && \
        ado_entry='{ "name": "azure_devops", "connection_type": "http", "connection_string": "http://mcp-azure-devops:3002/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },'

    local azure_portal_entry=""
    [ -n "${AZURE_PORTAL_AVAILABLE:-}" ] && \
        azure_portal_entry='{ "name": "azure_portal", "connection_type": "http", "connection_string": "http://mcp-azure-portal:3015/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true },'

    local aws_entries=""
    [ -n "${AWS_MCP_AVAILABLE:-}" ] && aws_entries=',
      { "name": "aws_api", "connection_type": "http", "connection_string": "http://mcp-aws-api:3010/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true }'

    # Build provider keys — For two-tier mode, use wildcard ("*") to allow auth-proxy to handle routing
    # The auth_proxy (running on 127.0.0.1:8099) has the actual credentials and handles Tier-1/Tier-2 selection
    local anthropic_keys="" claude_pro_key_ids="\"*\"" agents_generic_key_ids="\"*\""
    if [ "${ANTHROPIC_TIER_MODE:-}" = "two-tier" ]; then
        # In two-tier mode, use wildcard for all key_ids since auth-proxy handles the actual routing
        claude_pro_key_ids="\"*\""
        agents_generic_key_ids="\"*\""
        # Single sentinel key definition for provider (value doesn't matter; auth-proxy will intercept)
        anthropic_keys="{ \"name\": \"_bifrost_gateway\", \"value\": \"dummy\", \"weight\": 1, \"models\": [\"*\"] }"
    elif [ -n "${ANTHROPIC_EFFECTIVE_KEY:-}" ]; then
        # Single-key mode: embed actual key value directly in JSON
        local eff_key
        eff_key=$(printf '%s' "${ANTHROPIC_EFFECTIVE_KEY}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        anthropic_keys="{ \"name\": \"primary\", \"value\": \"${eff_key}\", \"weight\": 1, \"models\": [\"*\"] }"
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
      },
      {
        "id": "claude-pro",
        "name": "Claude Pro (Tier 1)",
        "value": "${BIFROST_VIRTUAL_KEY_CLAUDE_PRO}",
        "provider_configs": [
          { "provider": "anthropic", "allowed_models": ["*"], "key_ids": [${claude_pro_key_ids}] }
        ]
      },
      {
        "id": "agents-generic",
        "name": "Agents Generic (Tier 2)",
        "value": "${BIFROST_VIRTUAL_KEY_AGENTS_GENERIC}",
        "provider_configs": [
          { "provider": "anthropic", "allowed_models": ["*"], "key_ids": [${agents_generic_key_ids}] }
        ]
      }
    ]
  },
  "mcp": {
    "client_configs": [
      ${tavily_entry}
      ${ado_entry}
      ${azure_portal_entry}
      ${postman_entry}
      ${newrelic_entry}
      ${github_entry}
      { "name": "playwright", "connection_type": "http", "connection_string": "http://mcp-playwright:3006/mcp", "allow_on_all_virtual_keys": true, "is_code_mode_client": true }${aws_entries}
    ]
  }
}
EOF

    # Restrict config.json permissions — contains raw secret values
    chmod 600 /app/data/config.json

    # Debug: validate JSON structure and log key counts
    if command -v jq &>/dev/null; then
        local key_count
        key_count=$(jq '.providers.anthropic.keys | length' /app/data/config.json 2>/dev/null || echo "0")
        log_info "Config validation: Anthropic provider has ${key_count} keys configured"

        if [ "$key_count" -gt 0 ]; then
            jq -r '.providers.anthropic.keys[] | .name' /app/data/config.json | while read -r keyname; do
                log_info "  - Key: ${keyname}"
            done
        fi
    fi

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
