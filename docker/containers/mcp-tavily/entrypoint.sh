#!/bin/sh
set -eu

if [ -z "${TAVILY_API_KEY:-}" ]; then
  echo "TAVILY_API_KEY not set - mcp-tavily idle."
  trap 'exit 0' TERM INT
  while :; do sleep 3600; done
fi

exec supergateway --port 3001 --outputTransport streamableHttp --stdio "npx -y tavily-mcp@latest"
