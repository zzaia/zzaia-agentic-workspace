#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

VAULT_DATA_DIR="/vault/data"
VAULT_CONFIG_DIR="/vault/config"
VAULT_INIT_FILE="${VAULT_DATA_DIR}/.init"
VAULT_ADDR="http://127.0.0.1:8200"
VAULT_BG_PID=""

export VAULT_ADDR

mkdir -p "${VAULT_DATA_DIR}" "${VAULT_CONFIG_DIR}"

health_check() {
    local max_attempts=60
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if vault status -address="${VAULT_ADDR}" >/dev/null 2>&1; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    log_error "Vault health check failed after $max_attempts attempts"
    return 1
}

start_vault_background() {
    log_info "Starting Vault server in background..."
    vault server -config="${VAULT_CONFIG_DIR}/vault.hcl" >/dev/null 2>&1 &
    VAULT_BG_PID=$!
    if ! health_check; then
        log_error "Failed to start Vault"
        kill "$VAULT_BG_PID" 2>/dev/null || true
        return 1
    fi
    log_success "Vault server ready"
}

init_vault_if_needed() {
    log_info "Checking Vault initialization status..."

    if vault status -address="${VAULT_ADDR}" 2>&1 | grep -q "Initialized.*true"; then
        log_info "Vault already initialized"
        return 0
    fi

    log_info "Initializing Vault..."
    local init_output
    init_output=$(vault operator init -key-shares=1 -key-threshold=1 -format=json -address="${VAULT_ADDR}")

    echo "$init_output" > "${VAULT_INIT_FILE}"
    chmod 600 "${VAULT_INIT_FILE}"
    log_success "Vault initialized. Init file stored."
}

unseal_vault() {
    log_info "Checking Vault seal status..."

    if vault status -address="${VAULT_ADDR}" 2>&1 | grep -q "Sealed.*false"; then
        log_info "Vault already unsealed"
        return 0
    fi

    if [ ! -f "${VAULT_INIT_FILE}" ]; then
        log_error "Init file not found: ${VAULT_INIT_FILE}"
        return 1
    fi

    log_info "Unsealing Vault..."
    local unseal_key
    unseal_key=$(jq -r '.unseal_keys_b64[0]' "${VAULT_INIT_FILE}")

    vault operator unseal -address="${VAULT_ADDR}" "$unseal_key" >/dev/null
    log_success "Vault unsealed"
}

setup_vault_kv_if_needed() {
    log_info "Checking KV v2 secret engine..."

    local root_token
    root_token=$(jq -r '.root_token' "${VAULT_INIT_FILE}")
    export VAULT_TOKEN="$root_token"

    if vault secrets list -address="${VAULT_ADDR}" 2>&1 | grep -q '^secret/'; then
        log_info "KV v2 secret engine already enabled"
        return 0
    fi

    log_info "Enabling KV v2 secret engine at secret/..."
    vault secrets enable -version=2 -address="${VAULT_ADDR}" -path=secret kv >/dev/null
    log_success "KV v2 secret engine enabled"
}

generate_git_sidecar_keys() {
    log_info "Checking git-sidecar SSH keypair..."

    if vault kv list -address="${VAULT_ADDR}" secret/ 2>&1 | grep -q workspace; then
        if vault kv get -address="${VAULT_ADDR}" -field=GIT_SIDECAR_AGENT_KEY secret/workspace >/dev/null 2>&1; then
            log_info "git-sidecar keypair already exists in Vault"
            return 0
        fi
    fi

    log_info "Generating git-sidecar SSH keypair..."
    local tmpdir
    tmpdir=$(mktemp -d)

    ssh-keygen -t ed25519 -f "${tmpdir}/id_ed25519" -N "" -C "git-sidecar@zzaia" >/dev/null 2>&1

    local private_key public_key
    private_key=$(cat "${tmpdir}/id_ed25519")
    public_key=$(cat "${tmpdir}/id_ed25519.pub")

    vault kv put -address="${VAULT_ADDR}" secret/workspace \
        GIT_SIDECAR_AGENT_KEY="$private_key" \
        GIT_SIDECAR_AGENT_PUBKEY="$public_key" >/dev/null

    rm -rf "${tmpdir}"
    log_success "git-sidecar keypair generated and stored"
}

get_bws_value() {
    local bws_output="$1"
    local key="$2"
    echo "$bws_output" | jq -r ".[] | select(.key == \"$key\") | .value" 2>/dev/null || echo ""
}

write_vault_kv_path() {
    local path="$1"
    shift
    if [ $# -gt 0 ]; then
        vault kv put -address="${VAULT_ADDR}" "secret/${path}" "$@" >/dev/null 2>&1 \
            && log_info "Synced secret/${path}" \
            || log_warn "Failed to write secret/${path}"
    fi
}

bootstrap_secrets_from_bws() {
    if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
        log_warn "BWS_ACCESS_TOKEN not set — Vault started empty. Add secrets via Vault UI: http://localhost:${VAULT_PORT:-8200}/ui"
        return 0
    fi

    log_info "Bootstrapping secrets from Bitwarden Secrets Manager..."

    local root_token bws_output
    root_token=$(jq -r '.root_token' "${VAULT_INIT_FILE}")
    export VAULT_TOKEN="$root_token"

    bws_output=$(bws secret list --output json)

    local ai_args=()
    for key in ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY GEMINI_API_KEY TAVILY_API_KEY; do
        local val
        val=$(get_bws_value "$bws_output" "$key")
        [ -n "$val" ] && ai_args+=("${key}=${val}")
    done
    write_vault_kv_path "ai" "${ai_args[@]+"${ai_args[@]}"}"

    local gh_val
    gh_val=$(get_bws_value "$bws_output" "GITHUB_PERSONAL_ACCESS_TOKEN")
    [ -n "$gh_val" ] && write_vault_kv_path "mcp/github" "GITHUB_PERSONAL_ACCESS_TOKEN=${gh_val}"

    local ado_args=()
    for key in ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION; do
        local val
        val=$(get_bws_value "$bws_output" "$key")
        [ -n "$val" ] && ado_args+=("${key}=${val}")
    done
    write_vault_kv_path "mcp/azure-devops" "${ado_args[@]+"${ado_args[@]}"}"

    local cloud_args=()
    for key in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION ANTHROPIC_BEDROCK_BASE_URL \
               CLAUDE_CODE_USE_VERTEX ANTHROPIC_VERTEX_PROJECT_ID CLOUD_ML_REGION \
               CLAUDE_CODE_USE_FOUNDRY AZURE_FOUNDRY_BASE_URL; do
        local val
        val=$(get_bws_value "$bws_output" "$key")
        [ -n "$val" ] && cloud_args+=("${key}=${val}")
    done
    write_vault_kv_path "cloud" "${cloud_args[@]+"${cloud_args[@]}"}"

    local int_args=()
    for key in POSTMAN_API_KEY NEW_RELIC_API_KEY; do
        local val
        val=$(get_bws_value "$bws_output" "$key")
        [ -n "$val" ] && int_args+=("${key}=${val}")
    done
    write_vault_kv_path "integrations" "${int_args[@]+"${int_args[@]}"}"

    unset BWS_ACCESS_TOKEN
    log_success "Secrets bootstrapped from Bitwarden"
}

setup_approle_if_needed() {
    log_info "Checking AppRole auth method..."

    local root_token
    root_token=$(jq -r '.root_token' "${VAULT_INIT_FILE}")
    export VAULT_TOKEN="$root_token"

    if vault auth list -address="${VAULT_ADDR}" 2>&1 | grep -q '^approle/'; then
        log_info "AppRole auth method already enabled"
        return 0
    fi

    log_info "Enabling AppRole auth method..."
    vault auth enable -address="${VAULT_ADDR}" approle >/dev/null

    log_info "Creating git-sidecar-policy..."
    cat > /tmp/git-sidecar-policy.hcl << 'EOF'
path "secret/data/workspace/*" {
  capabilities = ["read", "list"]
}

path "secret/data/mcp/github/*" {
  capabilities = ["read", "list"]
}

path "secret/data/mcp/azure-devops/*" {
  capabilities = ["read", "list"]
}
EOF

    vault policy write -address="${VAULT_ADDR}" git-sidecar-policy /tmp/git-sidecar-policy.hcl >/dev/null
    rm -f /tmp/git-sidecar-policy.hcl

    log_success "AppRole auth method configured"
}

start_vault_foreground() {
    log_info "Starting Vault server in foreground (PID 1)..."
    exec vault server -config="${VAULT_CONFIG_DIR}/vault.hcl"
}

main() {
    log_info "Initializing Vault production setup..."

    start_vault_background
    init_vault_if_needed
    unseal_vault
    setup_vault_kv_if_needed
    generate_git_sidecar_keys
    bootstrap_secrets_from_bws
    setup_approle_if_needed

    kill "$VAULT_BG_PID" 2>/dev/null || true
    sleep 2

    start_vault_foreground
}

main "$@"
