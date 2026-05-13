#!/bin/sh
set -eu

if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
  echo "GITHUB_PERSONAL_ACCESS_TOKEN not set - mcp-github idle."
  trap 'exit 0' TERM INT
  while :; do sleep 3600; done
fi

exec npx -y supergateway@latest --port 3005 --outputTransport streamableHttp --stdio "npx -y mcp-remote@latest https://api.githubcopilot.com/mcp/ --header \"Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}\""
