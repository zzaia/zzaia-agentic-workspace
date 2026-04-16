#!/bin/bash
# install-compose-mac.sh — ZZAIA Docker Compose installer (macOS)
# Run once per company environment. Fetches secrets from Bitwarden, starts the stack,
# then discards all secret material — no .env file left on disk.
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

# ── Prerequisites ─────────────────────────────────────────────────────────────
if ! command -v bw &>/dev/null; then
    echo "ERROR: Bitwarden CLI 'bw' not found." >&2
    echo "       Install: brew install bitwarden-cli" >&2
    exit 1
fi
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker not found. Install Docker Desktop for Mac first." >&2
    exit 1
fi
if ! command -v jq &>/dev/null; then
    echo "ERROR: 'jq' not found. Install: brew install jq" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Bitwarden ─────────────────────────────────────────────────────────────────
echo "→ Logging into Bitwarden..."
BW_SESSION=$(bw login --raw)
BW_ITEMS=$(bw list items --session "$BW_SESSION")

get_secret() {
    local name="$1"
    local val
    val=$(echo "$BW_ITEMS" | jq -r ".[] | select(.name==\"$name\") | .login.password // empty")
    [[ -z "$val" ]] && echo "  WARNING: Bitwarden item '$name' not found — left empty." >&2
    echo "$val"
}

echo "→ Fetching secrets from vault..."
SSH_PUBLIC_KEY=$(get_secret "ssh-public-key")
TAVILY_API_KEY=$(get_secret "tavily")
ADO_MCP_AUTH_TOKEN=$(get_secret "azure-devops-pat")
AZURE_DEVOPS_ORGANIZATION=$(get_secret "azure-devops-org")
POSTMAN_API_KEY=$(get_secret "postman")
NEW_RELIC_API_KEY=$(get_secret "new-relic")

bw logout 2>/dev/null || true
unset BW_SESSION BW_ITEMS

if [[ -z "$AZURE_DEVOPS_ORGANIZATION" ]]; then
    echo "ERROR: 'azure-devops-org' is required — it becomes the compose project name." >&2
    exit 1
fi

# ── Temp env file — deleted on exit ──────────────────────────────────────────
TMPENV=$(mktemp /tmp/zzaia-env.XXXXXX)
trap "rm -f '$TMPENV'" EXIT
chmod 600 "$TMPENV"

cat > "$TMPENV" <<EOF
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY}
TAVILY_API_KEY=${TAVILY_API_KEY}
ADO_MCP_AUTH_TOKEN=${ADO_MCP_AUTH_TOKEN}
AZURE_DEVOPS_ORGANIZATION=${AZURE_DEVOPS_ORGANIZATION}
POSTMAN_API_KEY=${POSTMAN_API_KEY}
NEW_RELIC_API_KEY=${NEW_RELIC_API_KEY}
EOF

# ── Start compose stack ───────────────────────────────────────────────────────
echo "→ Starting ZZAIA stack for '$AZURE_DEVOPS_ORGANIZATION'..."
docker compose \
    -f "$SCRIPT_DIR/docker/docker-compose.yml" \
    -p "$AZURE_DEVOPS_ORGANIZATION" \
    --env-file "$TMPENV" \
    up -d

echo ''
echo "✓ ZZAIA workspace running  (project: $AZURE_DEVOPS_ORGANIZATION)"
echo "  VS Code : http://localhost:8080"
echo "  SSH     : ssh -p 2222 zzaia@localhost"
echo ''
echo "  Subsequent starts: use Docker Desktop or"
echo "  docker compose -f docker/docker-compose.yml -p $AZURE_DEVOPS_ORGANIZATION start"
echo "  To recreate containers: re-run this script."
