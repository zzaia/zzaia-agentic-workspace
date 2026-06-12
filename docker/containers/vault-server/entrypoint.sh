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
        # vault status: 0=init+unsealed, 1=error, 2=init or sealed
        # Use || to prevent set -e from triggering on non-zero exit
        local status_code=0
        vault status -address="${VAULT_ADDR}" >/dev/null 2>&1 || status_code=$?
        if [ "$status_code" -eq 0 ] || [ "$status_code" -eq 2 ]; then
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
    vault server -config="${VAULT_CONFIG_DIR}/vault.hcl" >> /tmp/vault.log 2>&1 &
    VAULT_BG_PID=$!
    if ! health_check; then
        log_error "Failed to start Vault"
        log_error "Vault server log:"
        cat /tmp/vault.log >&2
        kill "$VAULT_BG_PID" 2>/dev/null || true
        return 1
    fi
    log_success "Vault server ready"
}

init_vault_if_needed() {
    log_info "Checking Vault initialization status..."

    # Check if init file exists (persistent marker that vault was initialized)
    if [ -f "${VAULT_INIT_FILE}" ]; then
        log_info "Vault already initialized (init file exists)"
        return 0
    fi

    log_info "Init file not found at ${VAULT_INIT_FILE}, checking vault status..."
    # Use || true to prevent set -e from triggering on exit code 2 (sealed/uninitialized)
    local status_output=""
    status_output=$(vault status -address="${VAULT_ADDR}" 2>&1) || true

    # Check if initialized=true appears anywhere in the output
    if echo "$status_output" | grep -i "^initialized" | grep -qi "true"; then
        log_info "Vault already initialized according to status"
        return 0
    fi

    log_info "Initializing Vault..."
    local init_output
    init_output=$(vault operator init -key-shares=1 -key-threshold=1 -format=json -address="${VAULT_ADDR}" 2>&1)

    if echo "$init_output" | grep -q "already initialized"; then
        log_info "Vault operator init reports already initialized"
        # Try to extract root token from existing init file if available
        if [ ! -f "${VAULT_INIT_FILE}" ]; then
            log_error "Vault is initialized but init file not found"
            return 1
        fi
        return 0
    fi

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

    if ! command -v bws >/dev/null 2>&1; then
        log_warn "bws CLI not available in this image — Vault started empty. Add secrets via Vault UI: http://localhost:${VAULT_PORT:-8200}/ui"
        return 0
    fi

    log_info "Bootstrapping secrets from Bitwarden Secrets Manager..."

    local root_token bws_output
    root_token=$(jq -r '.root_token' "${VAULT_INIT_FILE}")
    export VAULT_TOKEN="$root_token"

    if ! bws_output=$(bws secret list --output json 2>&1); then
        log_warn "bws secret list failed — ${bws_output}. Vault started empty. Add secrets via Vault UI."
        unset BWS_ACCESS_TOKEN
        return 0
    fi

    local ai_args=()
    for key in ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY GEMINI_API_KEY TAVILY_API_KEY; do
        local val
        val=$(get_bws_value "$bws_output" "$key")
        [ -n "$val" ] && ai_args+=("${key}=${val}")
    done

    local idx=1
    while true; do
        local oauth_val api_val
        oauth_val=$(get_bws_value "$bws_output" "CLAUDE_OAUTH_TOKEN_${idx}")
        api_val=$(get_bws_value "$bws_output" "ANTHROPIC_API_KEY_${idx}")
        [ -z "$oauth_val" ] && [ -z "$api_val" ] && break
        [ -n "$oauth_val" ] && ai_args+=("CLAUDE_OAUTH_TOKEN_${idx}=${oauth_val}")
        [ -n "$api_val" ] && ai_args+=("ANTHROPIC_API_KEY_${idx}=${api_val}")
        idx=$((idx + 1))
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

    local postman_val
    postman_val=$(get_bws_value "$bws_output" "POSTMAN_API_KEY")
    [ -n "$postman_val" ] && write_vault_kv_path "mcp/postman" "POSTMAN_API_KEY=${postman_val}"

    local int_args=()
    for key in NEW_RELIC_API_KEY; do
        local val
        val=$(get_bws_value "$bws_output" "$key")
        [ -n "$val" ] && int_args+=("${key}=${val}")
    done
    write_vault_kv_path "integrations" "${int_args[@]+"${int_args[@]}"}"

    unset BWS_ACCESS_TOKEN
    log_success "Secrets bootstrapped from Bitwarden"
}

setup_approle_if_needed() {
    log_info "Setting up AppRole auth and service credentials..."

    local root_token
    root_token=$(jq -r '.root_token' "${VAULT_INIT_FILE}")
    export VAULT_TOKEN="$root_token"

    # Enable AppRole if not already
    if ! vault auth list -address="${VAULT_ADDR}" 2>&1 | grep -q '^approle/'; then
        vault auth enable -address="${VAULT_ADDR}" approle >/dev/null
        log_info "AppRole auth method enabled"
    fi

    # Apply all policy files
    for policy_file in /vault/policies/*.hcl; do
        local pname
        pname=$(basename "$policy_file" .hcl)
        vault policy write -address="${VAULT_ADDR}" "$pname" "$policy_file" >/dev/null
        log_info "Applied policy: ${pname}"
    done

    # Create AppRole roles and write credentials to shared /secrets volume
    mkdir -p /secrets && chmod 755 /secrets

    local mapping role policy cred_file role_id secret_id
    for mapping in "git-sidecar:git-sidecar-policy" "mcp:mcp-policy" "workspace:workspace-policy"; do
        role="${mapping%%:*}"
        policy="${mapping##*:}"
        cred_file="/secrets/vault-approle-${role}.env"

        if ! vault read -address="${VAULT_ADDR}" "auth/approle/role/${role}" >/dev/null 2>&1; then
            vault write -address="${VAULT_ADDR}" "auth/approle/role/${role}" \
                token_policies="${policy}" \
                token_ttl=1h \
                token_max_ttl=4h \
                secret_id_ttl=0 >/dev/null
            log_info "Created AppRole role: ${role}"
        fi

        # Refresh secret_id on each vault startup
        role_id=$(vault read -address="${VAULT_ADDR}" -field=role_id "auth/approle/role/${role}/role-id")
        secret_id=$(vault write -address="${VAULT_ADDR}" -field=secret_id -f "auth/approle/role/${role}/secret-id")

        printf 'VAULT_ROLE_ID=%s\nVAULT_SECRET_ID=%s\n' "$role_id" "$secret_id" > "$cred_file"
        chmod 644 "$cred_file"
        log_info "AppRole credentials written: ${cred_file}"
    done

    log_success "AppRole configured — credentials in /secrets/vault-approle-*.env"
}

setup_userpass_if_needed() {
    if [ -z "${ADMIN_EMAIL:-}" ] || [ -z "${ADMIN_PASSWORD:-}" ]; then
        log_warn "ADMIN_EMAIL or ADMIN_PASSWORD not set — skipping userpass auth setup"
        return 0
    fi

    log_info "Setting up userpass auth for admin..."

    local root_token
    root_token=$(jq -r '.root_token' "${VAULT_INIT_FILE}")
    export VAULT_TOKEN="$root_token"

    if ! vault auth list -address="${VAULT_ADDR}" 2>&1 | grep -q '^userpass/'; then
        vault auth enable -address="${VAULT_ADDR}" userpass >/dev/null
        log_info "Userpass auth method enabled"
    fi

    local vault_username="${ADMIN_EMAIL%%@*}"
    vault write -address="${VAULT_ADDR}" "auth/userpass/users/${vault_username}" \
        password="${ADMIN_PASSWORD}" \
        token_policies="admin-policy" >/dev/null
    log_success "Userpass admin configured: ${vault_username} (password same as admin)"
}

load_bws_token() {
    # Compose secrets mount to /run/secrets/ as tmpfs — never on disk, not in docker inspect
    local token_file="/run/secrets/bws_token"
    if [ -f "$token_file" ] && [ -s "$token_file" ]; then
        BWS_ACCESS_TOKEN=$(cat "$token_file")
        export BWS_ACCESS_TOKEN
    fi
}

install_bws_if_needed() {
    if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
        return 0
    fi
    if command -v bws >/dev/null 2>&1; then
        log_info "bws CLI already installed"
        return 0
    fi
    log_info "Installing bws CLI via Ansible..."
    ansible-playbook -i /vault/ansible/inventory.ini /vault/ansible/site.yml >/dev/null 2>&1 \
        && log_success "bws CLI installed" \
        || log_warn "bws CLI install failed — will operate in manual Vault UI mode"
}

start_vault_foreground() {
    log_info "Starting Vault server in foreground (PID 1)..."
    exec vault server -config="${VAULT_CONFIG_DIR}/vault.hcl"
}

main() {
    log_info "Initializing Vault production setup..."

    load_bws_token
    install_bws_if_needed
    start_vault_background
    init_vault_if_needed
    unseal_vault
    setup_vault_kv_if_needed
    generate_git_sidecar_keys
    bootstrap_secrets_from_bws
    setup_approle_if_needed
    setup_userpass_if_needed

    log_success "Vault setup complete. Vault is running as background process."
    log_info "Vault is running (PID $VAULT_BG_PID). Entrypoint will monitor it."

    # Keep entrypoint alive while monitoring vault process; unseal on restart
    while true; do
        if ! kill -0 "$VAULT_BG_PID" 2>/dev/null; then
            log_error "Vault process died (PID $VAULT_BG_PID). Restarting vault..."
            if start_vault_background; then
                unseal_vault || log_warn "Re-unseal failed — vault may be inaccessible"
            fi
        fi
        sleep 5
    done
}

main "$@"
