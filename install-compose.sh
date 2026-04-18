#!/bin/bash
# install-compose.sh — ZZAIA Docker Compose installer (Linux / macOS / WSL)
# Run once per environment. Fetches secrets from Bitwarden and pipes them
# directly into docker compose — nothing written to disk.
set -euo pipefail

echo ''
echo '  ███████╗███████╗ █████╗ ██╗ █████╗ '
echo '     ███╔╝   ███╔╝██╔══██╗██║██╔══██╗'
echo '    ███╔╝   ███╔╝ ███████║██║███████║ '
echo '   ███╔╝   ███╔╝  ██╔══██║██║██╔══██║ '
echo '  ███████╗███████╗██║  ██║██║██║  ██║ '
echo '  ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝'
echo ''
echo '         ⚡  Docker Compose Installer  ⚡'
echo ''

# ── Pipe secrets in-memory — nothing written to disk ─────────────────────────
echo "→ Starting ZZAIA stack..."

SSH_PUBLIC_KEY=
TAVILY_API_KEY=
ADO_MCP_AUTH_TOKEN=
AZURE_DEVOPS_ORGANIZATION=
POSTMAN_API_KEY=
NEW_RELIC_API_KEY=

docker compose \
    -f "./docker/docker-compose.yml" \
    -p "$AZURE_DEVOPS_ORGANIZATION" \
    --env-file <(
        printf 'SSH_PUBLIC_KEY=%s\n'             "$SSH_PUBLIC_KEY"
        printf 'TAVILY_API_KEY=%s\n'            "$TAVILY_API_KEY"
        printf 'ADO_MCP_AUTH_TOKEN=%s\n'        "$ADO_MCP_AUTH_TOKEN"
        printf 'AZURE_DEVOPS_ORGANIZATION=%s\n'  "$AZURE_DEVOPS_ORGANIZATION"
        printf 'POSTMAN_API_KEY=%s\n'           "$POSTMAN_API_KEY"
        printf 'NEW_RELIC_API_KEY=%s\n'         "$NEW_RELIC_API_KEY"
    ) \
    up -d

unset SSH_PUBLIC_KEY TAVILY_API_KEY ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION POSTMAN_API_KEY NEW_RELIC_API_KEY

echo ''
echo "✓ ZZAIA workspace running"
echo "  VS Code : http://localhost:8080"
echo "  SSH     : ssh -p 2222 zzaia@localhost"
echo ''
echo "  Subsequent starts: use Docker Desktop or"
echo "  docker compose -f docker/docker-compose.yml start"
echo "  To recreate containers: re-run this script."
