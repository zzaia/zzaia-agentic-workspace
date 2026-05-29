#!/bin/bash
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

GIT_SIDECAR_AGENT_PUBKEY=""
GITHUB_PAT=""
ADO_TOKEN=""

# ── Vault secrets ─────────────────────────────────────────────────────────────
fetch_vault_secrets() {
    log_info "Fetching secrets from Vault..."

    local max_retries=30
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
            local workspace_response
            workspace_response=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
                "${VAULT_ADDR}/v1/secret/data/workspace" 2>/dev/null || echo '{}')
            GIT_SIDECAR_AGENT_PUBKEY=$(extract_vault_secret "$workspace_response" "GIT_SIDECAR_AGENT_PUBKEY")

            local github_response
            github_response=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
                "${VAULT_ADDR}/v1/secret/data/mcp/github" 2>/dev/null || echo '{}')
            GITHUB_PAT=$(extract_vault_secret "$github_response" "GITHUB_PERSONAL_ACCESS_TOKEN")

            local ado_response
            ado_response=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
                "${VAULT_ADDR}/v1/secret/data/mcp/azure-devops" 2>/dev/null || echo '{}')
            ADO_TOKEN=$(extract_vault_secret "$ado_response" "ADO_MCP_AUTH_TOKEN")
        fi

        if [ -n "$GIT_SIDECAR_AGENT_PUBKEY" ] && [ -n "$GITHUB_PAT" ] && [ -n "$ADO_TOKEN" ]; then
            break
        fi

        retry_count=$((retry_count + 1))
        log_info "Waiting for Vault secrets... attempt $retry_count/$max_retries"
        sleep 5
    done

    if [ -z "${GIT_SIDECAR_AGENT_PUBKEY}" ] || [ -z "${GITHUB_PAT}" ] || [ -z "${ADO_TOKEN}" ]; then
        log_warn "Missing git secrets (GIT_SIDECAR_AGENT_PUBKEY, GITHUB_PAT, ADO_TOKEN) - git-sidecar idle."
        trap 'exit 0' TERM INT
        while :; do sleep 3600 & wait $!; done
    fi

    log_success "Secrets loaded"
}

# ── Token files ───────────────────────────────────────────────────────────────
write_proxy_tokens() {
    log_info "Writing proxy tokens..."

    mkdir -p /home/git/.git-proxy
    printf 'GITHUB_PAT="%s"\nADO_TOKEN="%s"\n' "$GITHUB_PAT" "$ADO_TOKEN" > /home/git/.git-proxy/tokens
    chown git:git /home/git/.git-proxy/tokens
    chmod 600 /home/git/.git-proxy/tokens

    log_success "Proxy tokens written"
}

# ── SSH authorized_keys ───────────────────────────────────────────────────────
setup_authorized_keys() {
    log_info "Setting up authorized_keys..."

    mkdir -p /home/git/.ssh
    chmod 700 /home/git/.ssh

    printf 'no-port-forwarding,no-x11-forwarding,no-agent-forwarding,no-pty,command="/usr/local/bin/git-proxy-cmd" %s\n' \
        "$GIT_SIDECAR_AGENT_PUBKEY" > /home/git/.ssh/authorized_keys
    chmod 600 /home/git/.ssh/authorized_keys

    chown -R git:git /home/git/.ssh

    log_success "Authorized keys configured"
}

# ── SSH daemon ────────────────────────────────────────────────────────────────
start_sshd() {
    log_info "Starting SSH daemon..."

    if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
        ssh-keygen -A 2>/dev/null || true
    fi

    log_success "SSH daemon starting on port 2223"
    exec /usr/sbin/sshd -D -p 2223
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    fetch_vault_secrets
    write_proxy_tokens
    setup_authorized_keys
    start_sshd
}

main "$@"
