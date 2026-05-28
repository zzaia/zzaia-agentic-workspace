#!/bin/sh
set -eu

TAVILY_API_KEY=""

# Try to fetch from Vault
if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
    TAVILY_API_KEY=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/mcp/tavily" 2>/dev/null | \
        grep -o '"TAVILY_API_KEY":"[^"]*' | cut -d'"' -f4 || echo "")
fi

if [ -z "${TAVILY_API_KEY}" ]; then
    echo "TAVILY_API_KEY not set - mcp-tavily idle."
    trap 'exit 0' TERM INT
    while :; do sleep 3600; done
fi

export TAVILY_API_KEY

exec supergateway --port 3001 --outputTransport streamableHttp --stdio "npx -y tavily-mcp@latest"
