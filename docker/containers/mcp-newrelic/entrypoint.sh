#!/bin/sh
set -eu

if [ -z "${NEW_RELIC_API_KEY:-}" ]; then
  echo "NEW_RELIC_API_KEY not set - mcp-newrelic idle."
  trap 'exit 0' TERM INT
  while :; do sleep 3600; done
fi

exec npx -y supergateway@latest --port 3004 --outputTransport streamableHttp --stateful --stdio "npx -y mcp-remote@latest https://mcp.newrelic.com/mcp/ --header \"Api-Key: ${NEW_RELIC_API_KEY}\""
