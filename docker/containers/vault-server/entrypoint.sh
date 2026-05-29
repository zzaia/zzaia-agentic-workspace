#!/bin/bash
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

VAULT_DATA_DIR="/vault/data"
VAULT_CONFIG_DIR="/vault/config"
VAULT_INIT_FILE="${VAULT_DATA_DIR}/init.json"
VAULT_ADDR="http://127.0.0.1:8200"

export VAULT_ADDR

mkdir -p "${VAULT_DATA_DIR}" "${VAULT_CONFIG_DIR}"

# ── Write KV secrets helper ────────────────────────────────────────────────────
write_kv() {
    local path="$1"; shift
    local tmpfile
    tmpfile=$(mktemp /tmp/vault_kv.XXXXXX)

    printf '{\n' > "$tmpfile"

    local first=true
    for var in "$@"; do
        eval "val=\${${var}:-}"
        if [ -n "$val" ]; then
            [ "$first" = false ] && printf ',\n' >> "$tmpfile"
            first=false
            printf '  "%s": %s' "$var" "$(printf '%s' "$val" | jq -Rs .)" >> "$tmpfile"
        fi
    done

    printf '\n}\n' >> "$tmpfile"

    if [ "$first" = false ]; then
        vault kv put "secret/${path}" "@${tmpfile}" >/dev/null 2>&1 && \
            log_info "Written: secret/${path}" || log_warn "Failed to write secret/${path}"
    fi
    rm -f "$tmpfile"
}

# ── Sync secrets to vault ──────────────────────────────────────────────────────
sync_secrets_to_vault() {
    log_info "Syncing secrets from environment to Vault KV..."

    write_kv workspace \
        WORKSPACE_NAME ADMIN_PASSWORD SSH_PUBLIC_KEY \
        ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN \
        OPENAI_API_KEY GEMINI_API_KEY \
        GITHUB_PERSONAL_ACCESS_TOKEN \
        AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION \
        ANTHROPIC_BEDROCK_BASE_URL CLAUDE_CODE_USE_VERTEX \
        ANTHROPIC_VERTEX_PROJECT_ID CLOUD_ML_REGION \
        CLAUDE_CODE_USE_FOUNDRY AZURE_FOUNDRY_BASE_URL

    write_kv mcp/tavily TAVILY_API_KEY
    write_kv mcp/azure-devops ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION
    write_kv mcp/postman POSTMAN_API_KEY
    write_kv mcp/newrelic NEW_RELIC_API_KEY
    write_kv mcp/github GITHUB_PERSONAL_ACCESS_TOKEN

    unset WORKSPACE_NAME ADMIN_PASSWORD SSH_PUBLIC_KEY \
          ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN \
          OPENAI_API_KEY GEMINI_API_KEY GITHUB_PERSONAL_ACCESS_TOKEN \
          AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION \
          ANTHROPIC_BEDROCK_BASE_URL CLAUDE_CODE_USE_VERTEX \
          ANTHROPIC_VERTEX_PROJECT_ID CLOUD_ML_REGION \
          CLAUDE_CODE_USE_FOUNDRY AZURE_FOUNDRY_BASE_URL \
          TAVILY_API_KEY ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION \
          POSTMAN_API_KEY NEW_RELIC_API_KEY
    log_info "Secrets unset from process environment"
}

# ── Main entry point (use dev mode for simplicity) ───────────────────────────
log_info "Starting Vault server in dev mode..."
export VAULT_TOKEN=vault-init-token

# Sync secrets immediately in dev mode
sync_secrets_to_vault

# Unset all secret environment variables to prevent exposure
unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN \
      OPENAI_API_KEY GEMINI_API_KEY GITHUB_PERSONAL_ACCESS_TOKEN \
      AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION \
      ANTHROPIC_BEDROCK_BASE_URL CLAUDE_CODE_USE_VERTEX \
      ANTHROPIC_VERTEX_PROJECT_ID CLOUD_ML_REGION \
      CLAUDE_CODE_USE_FOUNDRY AZURE_FOUNDRY_BASE_URL \
      TAVILY_API_KEY ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION \
      POSTMAN_API_KEY NEW_RELIC_API_KEY \
      VAULT_ROOT_TOKEN ADMIN_PASSWORD SSH_PUBLIC_KEY 2>/dev/null || true

# Start Vault in dev mode in the foreground
# Dev mode: auto-unsealed, auto-initialized, known token
exec vault server -dev \
    -dev-root-token-id=vault-init-token \
    -dev-listen-address=0.0.0.0:8200
