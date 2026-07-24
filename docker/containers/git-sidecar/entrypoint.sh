#!/bin/bash
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

GIT_SIDECAR_AGENT_PUBKEY=""
GITHUB_PAT=""
ADO_TOKEN=""

# ── Load secrets from environment ─────────────────────────────────────────────
# Secrets are projected into the pod environment by External Secrets Operator
# (Bitwarden Secrets Manager → ESO → Kubernetes Secret → envFrom), so they are already present.
# The git-sidecar agent public key is derived from its private key
# (GIT_SIDECAR_AGENT_KEY); no separate public-key secret is provisioned.
load_secrets() {
    log_info "Loading secrets from environment..."

    GITHUB_PAT="${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
    ADO_TOKEN="${ADO_MCP_AUTH_TOKEN:-}"

    if [ -n "${GIT_SIDECAR_AGENT_KEY:-}" ]; then
        local keyfile
        keyfile=$(mktemp)
        chmod 600 "$keyfile"
        printf '%s\n' "${GIT_SIDECAR_AGENT_KEY}" > "$keyfile"
        GIT_SIDECAR_AGENT_PUBKEY=$(ssh-keygen -y -f "$keyfile" 2>/dev/null || echo "")
        rm -f "$keyfile"
    fi

    if [ -z "${GIT_SIDECAR_AGENT_PUBKEY}" ] || [ -z "${GITHUB_PAT}" ] || [ -z "${ADO_TOKEN}" ]; then
        log_error "Missing git secrets (need GIT_SIDECAR_AGENT_KEY, GITHUB_PERSONAL_ACCESS_TOKEN, ADO_MCP_AUTH_TOKEN) — cannot start git-sidecar. Check the workspace credentials secret projection."
        exit 1
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
    load_secrets
    write_proxy_tokens
    setup_authorized_keys
    start_sshd
}

main "$@"
