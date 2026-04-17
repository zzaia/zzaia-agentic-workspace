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

# ── OS-aware install hints ─────────────────────────────────────────────────────
OS=$(uname -s)
if [[ "$OS" == "Darwin" ]]; then
    BW_HINT="brew install bitwarden-cli"
    JQ_HINT="brew install jq"
else
    BW_HINT="sudo snap install bw"
    JQ_HINT="sudo apt-get install jq"
fi

for cmd in bw docker jq; do
    if ! command -v "$cmd" &>/dev/null; then
        case "$cmd" in
            bw)     echo "ERROR: Bitwarden CLI not found. Install: $BW_HINT" >&2 ;;
            docker) echo "ERROR: Docker not found. Install Docker Desktop first." >&2 ;;
            jq)     echo "ERROR: jq not found. Install: $JQ_HINT" >&2 ;;
        esac
        exit 1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Bitwarden — unlock if already logged in, login otherwise ──────────────────
echo "→ Unlocking Bitwarden vault..."
BW_SESSION=$(bw unlock --raw 2>/dev/null || bw login --raw)
if [[ -z "$BW_SESSION" ]]; then
    echo "ERROR: Failed to obtain a Bitwarden session." >&2
    exit 1
fi

BW_ITEMS=$(bw list items --session "$BW_SESSION" 2>/dev/null) \
    || { echo "ERROR: Failed to list vault items — check your session." >&2; exit 1; }

get_secret() {
    local name="$1"
    local val
    val=$(printf '%s' "$BW_ITEMS" | jq -r ".[] | select(.name==\"$name\") | .login.password // empty")
    if [[ -z "$val" ]]; then
        echo "  WARNING: Bitwarden item '$name' not found — left empty." >&2
    elif [[ "$val" == *$'\n'* ]]; then
        echo "ERROR: Bitwarden item '$name' contains a newline — cannot be used as an env var." >&2
        exit 1
    fi
    printf '%s' "$val"
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

[[ -z "$AZURE_DEVOPS_ORGANIZATION" ]] && { echo "ERROR: 'azure-devops-org' is required." >&2; exit 1; }

# ── Pipe secrets in-memory — nothing written to disk ─────────────────────────
echo "→ Starting ZZAIA stack..."
docker compose \
    -f "$SCRIPT_DIR/docker/docker-compose.yml" \
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
