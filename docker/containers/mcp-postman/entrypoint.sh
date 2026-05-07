#!/bin/sh
set -eu

if [ -z "${POSTMAN_API_KEY:-}" ]; then
  echo "POSTMAN_API_KEY not set - mcp-postman idle."
  trap 'exit 0' TERM INT
  while :; do sleep 3600; done
fi

exec npx -y supergateway@latest --port 3003 --outputTransport streamableHttp --stateful --stdio "npx -y @postman/postman-mcp-server --minimal --region us"
