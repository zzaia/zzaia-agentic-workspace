#!/bin/sh
set -eu

GITHUB_PERSONAL_ACCESS_TOKEN=""

# Try to fetch from Vault
if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
    GITHUB_PERSONAL_ACCESS_TOKEN=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/workspace" 2>/dev/null | \
        grep -o '"GITHUB_PERSONAL_ACCESS_TOKEN":"[^"]*' | cut -d'"' -f4 || echo "")
fi

if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN}" ]; then
    echo "GITHUB_PERSONAL_ACCESS_TOKEN not set - mcp-github idle."
    trap 'exit 0' TERM INT
    while :; do sleep 3600; done
fi

export GITHUB_PERSONAL_ACCESS_TOKEN

exec supergateway --port 3005 --outputTransport streamableHttp --stdio "npx -y mcp-remote@latest https://api.githubcopilot.com/mcp/ --header \"Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}\""
