#!/bin/sh
set -eu

POSTMAN_API_KEY=""

# Try to fetch from Vault
if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
    POSTMAN_API_KEY=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/mcp/postman" 2>/dev/null | \
        grep -o '"POSTMAN_API_KEY":"[^"]*' | cut -d'"' -f4 || echo "")
fi

if [ -z "${POSTMAN_API_KEY}" ]; then
    echo "POSTMAN_API_KEY not set - mcp-postman idle."
    trap 'exit 0' TERM INT
    while :; do sleep 3600; done
fi

export POSTMAN_API_KEY

exec supergateway --port 3003 --outputTransport streamableHttp --stdio "npx -y @postman/postman-mcp-server --minimal --region us"
