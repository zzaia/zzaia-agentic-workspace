#!/bin/bash
# Init-ubuntu.sh - ZZAIA Workspace Launcher (Ubuntu / WSL)
set -euo pipefail
bw login 2>/dev/null || true
BW_SESSION=$(bw unlock --raw)
export TAVILY_API_KEY=$(bw get password tavily --session "$BW_SESSION")
export ADO_MCP_AUTH_TOKEN=$(bw get password azure-devops-pat --session "$BW_SESSION")
export AZURE_DEVOPS_ORGANIZATION=$(bw get password azure-devops-org --session "$BW_SESSION")
export POSTMAN_API_KEY=$(bw get password postman --session "$BW_SESSION")
export NEW_RELIC_API_KEY=$(bw get password new-relic --session "$BW_SESSION")
bw lock --session "$BW_SESSION" >/dev/null 2>&1; unset BW_SESSION
claude --enable-auto-mode
