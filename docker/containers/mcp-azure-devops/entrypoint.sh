#!/bin/sh
set -eu

ADO_MCP_AUTH_TOKEN=""
AZURE_DEVOPS_ORGANIZATION=""

# Try to fetch from Vault
if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
    VAULT_DATA=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/mcp/azure-devops" 2>/dev/null || echo "{}")

    ADO_MCP_AUTH_TOKEN=$(echo "$VAULT_DATA" | grep -o '"ADO_MCP_AUTH_TOKEN":"[^"]*' | cut -d'"' -f4 || echo "")
    AZURE_DEVOPS_ORGANIZATION=$(echo "$VAULT_DATA" | grep -o '"AZURE_DEVOPS_ORGANIZATION":"[^"]*' | cut -d'"' -f4 || echo "")
fi

if [ -z "${ADO_MCP_AUTH_TOKEN}" ] || [ -z "${AZURE_DEVOPS_ORGANIZATION}" ]; then
    echo "ADO_MCP_AUTH_TOKEN or AZURE_DEVOPS_ORGANIZATION not set - mcp-azure-devops idle."
    trap 'exit 0' TERM INT
    while :; do sleep 3600; done
fi

export ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION

exec supergateway --port 3002 --outputTransport streamableHttp --stdio "npx -y @azure-devops/mcp@next ${AZURE_DEVOPS_ORGANIZATION} -a envvar"
