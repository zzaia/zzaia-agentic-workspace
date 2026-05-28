#!/bin/sh
set -eu

NEW_RELIC_API_KEY=""

# Try to fetch from Vault
if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
    NEW_RELIC_API_KEY=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/mcp/newrelic" 2>/dev/null | \
        grep -o '"NEW_RELIC_API_KEY":"[^"]*' | cut -d'"' -f4 || echo "")
fi

if [ -z "${NEW_RELIC_API_KEY}" ]; then
    echo "NEW_RELIC_API_KEY not set - mcp-newrelic idle."
    trap 'exit 0' TERM INT
    while :; do sleep 3600; done
fi

export NEW_RELIC_API_KEY

exec supergateway --port 3004 --outputTransport streamableHttp --stateful --stdio "npx -y mcp-remote@latest https://mcp.newrelic.com/mcp/ --header \"Api-Key: ${NEW_RELIC_API_KEY}\""
