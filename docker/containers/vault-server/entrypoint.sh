#!/bin/sh
set -eu

VAULT_DATA_DIR="/vault/data"
VAULT_CONFIG_DIR="/vault/config"
VAULT_INIT_FILE="${VAULT_DATA_DIR}/init.json"
VAULT_POLICY_DIR="/vault/policies"

# Always connect CLI to localhost regardless of compose VAULT_ADDR
export VAULT_ADDR="http://127.0.0.1:8200"

mkdir -p "${VAULT_DATA_DIR}" "${VAULT_CONFIG_DIR}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

log "Starting Vault server..."
vault server -config="${VAULT_CONFIG_DIR}/vault.hcl" &
VAULT_PID=$!

log "Waiting for Vault API to be ready..."
RETRY_COUNT=0
MAX_RETRIES=30
until nc -z 127.0.0.1 8200 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        log "ERROR: Vault did not start within ${MAX_RETRIES} retries"
        kill "$VAULT_PID" 2>/dev/null || true
        exit 1
    fi
    log "Waiting... (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

log "Vault API is ready"

# Use grep -q (no count) to avoid double-zero issue with grep -c || echo
if vault status 2>/dev/null | grep -q "Initialized.*true"; then
    log "Vault already initialized. Checking seal status..."

    if vault status 2>/dev/null | grep -q "Sealed.*false"; then
        log "Vault is unsealed"
    else
        log "Vault is sealed. Unsealing..."
        UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' "${VAULT_INIT_FILE}" 2>/dev/null || echo "")
        if [ -n "$UNSEAL_KEY" ]; then
            vault operator unseal "$UNSEAL_KEY" >/dev/null 2>&1 || true
        else
            log "ERROR: Cannot unseal — init.json not found at ${VAULT_INIT_FILE}"
            kill "$VAULT_PID" 2>/dev/null || true
            exit 1
        fi
    fi

    ROOT_TOKEN=$(jq -r '.root_token' "${VAULT_INIT_FILE}" 2>/dev/null || echo "")
    if [ -z "$ROOT_TOKEN" ]; then
        log "ERROR: Could not read root token from ${VAULT_INIT_FILE}"
        kill "$VAULT_PID" 2>/dev/null || true
        exit 1
    fi
else
    log "Vault not initialized. Running init..."
    INIT_OUTPUT=$(vault operator init -key-shares=1 -key-threshold=1 -format=json 2>/dev/null)
    echo "$INIT_OUTPUT" > "${VAULT_INIT_FILE}"
    chmod 600 "${VAULT_INIT_FILE}"
    log "Vault initialized. Keys saved to ${VAULT_INIT_FILE}"

    ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
    UNSEAL_KEY=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')

    log "Unsealing Vault..."
    vault operator unseal "$UNSEAL_KEY" >/dev/null 2>&1 && log "Vault unsealed" || log "WARN: Unseal may have failed"
fi

log "Logging in with root token..."
export VAULT_TOKEN="$ROOT_TOKEN"

# Enable KV v2
if ! vault secrets enable -version=2 -path=secret kv 2>/dev/null; then
    if vault secrets list 2>/dev/null | grep -q "^secret/"; then
        log "KV v2 already enabled at secret/"
    else
        log "WARN: Could not enable KV v2"
    fi
else
    log "KV v2 secrets engine enabled at secret/"
fi

# Helper: build JSON from env vars using jq, write via temp file (vault kv put @file)
write_kv() {
    path="$1"; shift
    json="{}"
    for var in "$@"; do
        eval "val=\${${var}:-}"
        if [ -n "$val" ]; then
            json=$(printf '%s' "$json" | jq --arg k "$var" --arg v "$val" '. + {($k): $v}')
        fi
    done
    if [ "$json" != "{}" ]; then
        tmpfile=$(mktemp /tmp/vault_kv.XXXXXX)
        printf '%s' "$json" > "$tmpfile"
        vault kv put "secret/${path}" "@${tmpfile}" >/dev/null 2>&1 && \
            log "Written: secret/${path}" || log "WARN: Failed to write secret/${path}"
        rm -f "$tmpfile"
    fi
}

log "Syncing secrets from environment to Vault KV..."

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
log "Secrets unset from process environment"

# Create a token with the user-provided VAULT_ROOT_TOKEN value
# so all other containers can authenticate using VAULT_TOKEN=${VAULT_ROOT_TOKEN}
if [ -n "${VAULT_ROOT_TOKEN:-}" ]; then
    if vault token lookup "${VAULT_ROOT_TOKEN}" >/dev/null 2>&1; then
        log "Workspace deploy token already exists"
    else
        vault token create \
            -id="${VAULT_ROOT_TOKEN}" \
            -policy=root \
            -no-default-policy \
            -orphan \
            -display-name="workspace-deploy-token" \
            >/dev/null 2>&1 && log "Created workspace deploy token" || \
            log "WARN: Could not create workspace deploy token"
    fi
fi
unset VAULT_ROOT_TOKEN

# AppRole auth
log "Setting up AppRole authentication..."
vault auth enable approle 2>/dev/null && log "AppRole enabled" || log "AppRole already enabled"

log "Writing policies..."
vault policy write workspace-policy "${VAULT_POLICY_DIR}/workspace-policy.hcl" >/dev/null 2>&1 && \
    log "workspace-policy written" || log "workspace-policy write skipped"
vault policy write mcp-policy "${VAULT_POLICY_DIR}/mcp-policy.hcl" >/dev/null 2>&1 && \
    log "mcp-policy written" || log "mcp-policy write skipped"

log "Creating AppRole roles..."
vault write auth/approle/role/workspace-role \
    token_policies="workspace-policy" \
    token_ttl=24h token_max_ttl=24h \
    >/dev/null 2>&1 && log "workspace-role created/updated" || log "workspace-role skipped"

vault write auth/approle/role/mcp-role \
    token_policies="mcp-policy" \
    token_ttl=24h token_max_ttl=24h \
    >/dev/null 2>&1 && log "mcp-role created/updated" || log "mcp-role skipped"

mkdir -p "${VAULT_DATA_DIR}/approle"
WORKSPACE_ROLE_ID=$(vault read -field=role_id auth/approle/role/workspace-role/role-id 2>/dev/null || echo "")
WORKSPACE_SECRET=$(vault write -field=secret_id -f auth/approle/role/workspace-role/secret-id 2>/dev/null || echo "")
if [ -n "$WORKSPACE_ROLE_ID" ] && [ -n "$WORKSPACE_SECRET" ]; then
    printf '%s' "$WORKSPACE_ROLE_ID" > "${VAULT_DATA_DIR}/approle/workspace-role-id"
    printf '%s' "$WORKSPACE_SECRET" > "${VAULT_DATA_DIR}/approle/workspace-secret-id"
    chmod 600 "${VAULT_DATA_DIR}/approle/workspace-role-id" "${VAULT_DATA_DIR}/approle/workspace-secret-id"
fi

MCP_ROLE_ID=$(vault read -field=role_id auth/approle/role/mcp-role/role-id 2>/dev/null || echo "")
MCP_SECRET=$(vault write -field=secret_id -f auth/approle/role/mcp-role/secret-id 2>/dev/null || echo "")
if [ -n "$MCP_ROLE_ID" ] && [ -n "$MCP_SECRET" ]; then
    printf '%s' "$MCP_ROLE_ID" > "${VAULT_DATA_DIR}/approle/mcp-role-id"
    printf '%s' "$MCP_SECRET" > "${VAULT_DATA_DIR}/approle/mcp-secret-id"
    chmod 600 "${VAULT_DATA_DIR}/approle/mcp-role-id" "${VAULT_DATA_DIR}/approle/mcp-secret-id"
fi

log "Vault setup complete."
log "Bringing Vault to foreground..."
wait "$VAULT_PID"
