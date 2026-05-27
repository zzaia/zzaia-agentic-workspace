#!/bin/sh
set -eu

if [ -z "${ADO_MCP_AUTH_TOKEN:-}" ] || [ -z "${AZURE_DEVOPS_ORGANIZATION:-}" ]; then
  echo "ADO_MCP_AUTH_TOKEN or AZURE_DEVOPS_ORGANIZATION not set - mcp-azure-devops idle."
  trap 'exit 0' TERM INT
  while :; do sleep 3600; done
fi

exec supergateway --port 3002 --outputTransport streamableHttp --stdio "npx -y @azure-devops/mcp@next ${AZURE_DEVOPS_ORGANIZATION} -a envvar"
