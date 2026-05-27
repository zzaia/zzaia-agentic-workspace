#!/bin/bash
set -euo pipefail

echo ''
echo '  ███████╗███████╗ █████╗ ██╗ █████╗ '
echo '     ███╔╝   ███╔╝██╔══██╗██║██╔══██╗'
echo '    ███╔╝   ███╔╝ ███████║██║███████║ '
echo '   ███╔╝   ███╔╝  ██╔══██║██║██╔══██║ '
echo '  ███████╗███████╗██║  ██║██║██║  ██║ '
echo '  ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝'
echo ''
echo '         ⚡  Agentic Workspace  ⚡'
echo ''

if ! command -v bw &> /dev/null; then
    echo "Error: Bitwarden CLI 'bw' not found. Install from: https://bitwarden.com/help/cli"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' not found. Install with: apt-get install jq (or similar)"
    exit 1
fi

cleanup() {
    [ -n "${BW_SESSION:-}" ] && bw logout 2>/dev/null || true
    unset -v BW_SESSION BW_ITEMS DOCKER_REGISTRY DOCKER_USERNAME DOCKER_PASSWORD 2>/dev/null || true
}
trap cleanup EXIT

echo "Logging in to Bitwarden..."
BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")
if [ "$BW_STATUS" = "unauthenticated" ]; then
    BW_SESSION=$(bw login --raw)
else
    BW_SESSION=$(bw unlock --raw)
fi
if [ -z "$BW_SESSION" ]; then
    echo "Error: Bitwarden login/unlock failed."
    exit 1
fi
export BW_SESSION

BW_ITEMS=$(bw list items 2>/dev/null || echo "[]")

fetch_secret() {
    local item_name="$1"
    echo "$BW_ITEMS" | jq -r --arg n "$item_name" '.[] | select(.name==$n) | (.login.password // .sshKey.publicKey // .notes // "")' 2>/dev/null || echo ""
}

WORKSPACE_NAME=$(fetch_secret "workspace-name")
SSH_PUBLIC_KEY=$(fetch_secret "ssh-public-key")
ADMIN_PASSWORD=$(fetch_secret "admin-password")
VSCODE_PORT=$(fetch_secret "vscode-port")
SSH_PORT=$(fetch_secret "ssh-port")
ASPIRE_DASHBOARD_PORT=$(fetch_secret "aspire-dashboard-port")

ANTHROPIC_API_KEY=$(fetch_secret "anthropic-api-key")
CLAUDE_CODE_OAUTH_TOKEN=$(fetch_secret "claude-code-oauth-token")
OPENAI_API_KEY=$(fetch_secret "openai-api-key")
GEMINI_API_KEY=$(fetch_secret "gemini-api-key")
GITHUB_PERSONAL_ACCESS_TOKEN=$(fetch_secret "github-pat")
TAVILY_API_KEY=$(fetch_secret "tavily")
ADO_MCP_AUTH_TOKEN=$(fetch_secret "azure-devops-pat")
AZURE_DEVOPS_ORGANIZATION=$(fetch_secret "azure-devops-org")
POSTMAN_API_KEY=$(fetch_secret "postman")
NEW_RELIC_API_KEY=$(fetch_secret "new-relic")
DOCKER_REGISTRY=$(fetch_secret "docker-registry")
DOCKER_USERNAME=$(fetch_secret "docker-username")
DOCKER_PASSWORD=$(fetch_secret "docker-password")
DEPLOY_PROFILES=$(fetch_secret "server-profiles")
GPU_ENABLED=$(fetch_secret "gpu-enabled")

unset BW_ITEMS

[ -z "$WORKSPACE_NAME" ] && echo "Error: WORKSPACE_NAME (vault: workspace-name) not found or empty" && exit 1

VSCODE_PORT="${VSCODE_PORT:-8080}"
SSH_PORT="${SSH_PORT:-2222}"
ASPIRE_DASHBOARD_PORT="${ASPIRE_DASHBOARD_PORT:-18888}"

if ! [[ "$VSCODE_PORT" =~ ^[0-9]+$ ]] || [ "$VSCODE_PORT" -lt 1 ] || [ "$VSCODE_PORT" -gt 65535 ]; then
    VSCODE_PORT="8080"
fi
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    SSH_PORT="2222"
fi
if ! [[ "$ASPIRE_DASHBOARD_PORT" =~ ^[0-9]+$ ]] || [ "$ASPIRE_DASHBOARD_PORT" -lt 1 ] || [ "$ASPIRE_DASHBOARD_PORT" -gt 65535 ]; then
    ASPIRE_DASHBOARD_PORT="18888"
fi

export WORKSPACE_NAME SSH_PUBLIC_KEY ADMIN_PASSWORD VSCODE_PORT SSH_PORT ASPIRE_DASHBOARD_PORT
export ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY GEMINI_API_KEY
export GITHUB_PERSONAL_ACCESS_TOKEN TAVILY_API_KEY ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION
export POSTMAN_API_KEY NEW_RELIC_API_KEY DEPLOY_PROFILES

export AWS_ACCESS_KEY_ID="" AWS_SECRET_ACCESS_KEY="" AWS_REGION="" ANTHROPIC_BEDROCK_BASE_URL=""
export CLAUDE_CODE_USE_VERTEX="" ANTHROPIC_VERTEX_PROJECT_ID="" CLOUD_ML_REGION=""
export CLAUDE_CODE_USE_FOUNDRY="" AZURE_FOUNDRY_BASE_URL=""
GPU_ENABLED="${GPU_ENABLED:-false}"
export GPU_ENABLED

if [ -n "$DOCKER_REGISTRY" ] && [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
    echo "$DOCKER_PASSWORD" | docker login "$DOCKER_REGISTRY" -u "$DOCKER_USERNAME" --password-stdin
fi

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build --profile flags from the server-profiles secret
PROFILE_FLAGS=""
if [ -n "${DEPLOY_PROFILES:-}" ]; then
    for p in $DEPLOY_PROFILES; do
        case "$p" in
            vscode|devcontainer|jupyter|tunnel) PROFILE_FLAGS="$PROFILE_FLAGS --profile $p" ;;
            *) echo "Warning: Unknown server profile '$p' — valid: vscode, devcontainer, jupyter, tunnel" ;;
        esac
    done
fi

GPU_COMPOSE_FLAG=""
[ "${GPU_ENABLED:-false}" = "true" ] && GPU_COMPOSE_FLAG="-f $SCRIPT_DIR/../docker/docker-compose.gpu.yml"

# shellcheck disable=SC2086
docker compose -f "$SCRIPT_DIR/../docker/docker-compose.yml" $GPU_COMPOSE_FLAG -p "$WORKSPACE_NAME" $PROFILE_FLAGS up -d

echo ""
echo "✓ Workspace started. Access:"
echo "  SSH: ssh -p $SSH_PORT user@localhost"
[[ "${DEPLOY_PROFILES:-}" == *vscode* ]] && echo "  VS Code: http://localhost:$VSCODE_PORT"
[[ "${DEPLOY_PROFILES:-}" == *devcontainer* ]] && echo "  Dev Container: attach via VS Code Dev Containers extension"
[[ "${DEPLOY_PROFILES:-}" == *tunnel* ]] && echo "  VS Code Tunnel: Remote Tunnels extension → '$WORKSPACE_NAME' or https://vscode.dev/tunnel/$WORKSPACE_NAME"
echo "  AppHost Dashboard (when AppHost is running): http://localhost:$ASPIRE_DASHBOARD_PORT"
