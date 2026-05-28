#!/bin/sh
set -eu

GITHUB_SSH_DEPLOY_KEY=""
ADO_SSH_DEPLOY_KEY=""
GIT_SIDECAR_AGENT_PUBKEY=""

# Try to fetch from Vault
if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
    GITHUB_SSH_DEPLOY_KEY=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/git/github" 2>/dev/null | \
        grep -o '"GITHUB_SSH_DEPLOY_KEY":"[^"]*' | cut -d'"' -f4 || echo "")

    ADO_SSH_DEPLOY_KEY=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/git/ado" 2>/dev/null | \
        grep -o '"ADO_SSH_DEPLOY_KEY":"[^"]*' | cut -d'"' -f4 || echo "")

    GIT_SIDECAR_AGENT_PUBKEY=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/workspace" 2>/dev/null | \
        grep -o '"GIT_SIDECAR_AGENT_PUBKEY":"[^"]*' | cut -d'"' -f4 || echo "")
fi

if [ -z "${GITHUB_SSH_DEPLOY_KEY}" ] || [ -z "${ADO_SSH_DEPLOY_KEY}" ] || [ -z "${GIT_SIDECAR_AGENT_PUBKEY}" ]; then
    echo "Missing git secrets (GITHUB_SSH_DEPLOY_KEY, ADO_SSH_DEPLOY_KEY, GIT_SIDECAR_AGENT_PUBKEY) - git-sidecar idle."
    trap 'exit 0' TERM INT
    while :; do sleep 3600; done
fi

mkdir -p /home/git/.ssh
chmod 700 /home/git/.ssh

echo "$GITHUB_SSH_DEPLOY_KEY" > /home/git/.ssh/id_rsa_github
chmod 600 /home/git/.ssh/id_rsa_github

echo "$ADO_SSH_DEPLOY_KEY" > /home/git/.ssh/id_rsa_ado
chmod 600 /home/git/.ssh/id_rsa_ado

# Write authorized_keys with ForceCommand restriction
printf 'no-port-forwarding,no-x11-forwarding,no-agent-forwarding,no-pty,command="/usr/local/bin/git-proxy-cmd" %s\n' \
    "$GIT_SIDECAR_AGENT_PUBKEY" > /home/git/.ssh/authorized_keys
chmod 600 /home/git/.ssh/authorized_keys

chown -R git:git /home/git/.ssh

# Generate SSH host keys if not present
ssh-keygen -A 2>/dev/null || true

exec /usr/sbin/sshd -D -p 2223
