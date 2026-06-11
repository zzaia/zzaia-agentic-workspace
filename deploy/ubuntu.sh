#!/bin/bash
set -euo pipefail

show_usage() {
    cat << 'EOF'
Usage: ./deploy/ubuntu.sh [OPTIONS]

Options:
  --workspace-name NAME         Workspace name (required)
  --ssh-public-key KEY          SSH public key (required)
  --admin-email EMAIL           Admin email for SigNoz and Vault (required)
  --admin-password PASSWORD     Admin password for SigNoz and Vault (required)
  --gpu                         Enable GPU support (default: false)
  --observability               Enable observability stack: SigNoz, Fluent Bit, OTel Collector, cAdvisor (default: false)
  --no-bws                      Skip Bitwarden token prompt, use Vault UI only (default: false)
  --vault-port PORT             Vault server port (default: 8200)
  --ssh-port PORT               SSH server port (default: 2222)
  --signoz-port PORT            SigNoz UI port (default: 3301)
  --mcp-signoz-port PORT        SigNoz MCP port (default: 3009)
  --vscode-port PORT            VS Code server port (default: 8080)
  --aspire-dashboard-port PORT  Aspire Dashboard port (default: 18890)
  --jupyter-port PORT           Jupyter port (default: 8888)
  --portainer-port PORT         Portainer UI port (default: 9000)
  --profiles PROFILES           Comma-separated server profiles: vscode, jupyter, devcontainer, tunnel, portainer
  --help                        Show this help message

Examples:
  ./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..." --admin-email admin@example.com --admin-password MyPass1!
  ./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..." --admin-email admin@example.com --admin-password MyPass1! --gpu --profiles vscode
  ./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..." --admin-email admin@example.com --admin-password MyPass1! --observability --signoz-port 3301
  ./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..." --admin-email admin@example.com --admin-password MyPass1! --no-bws
EOF
}

WORKSPACE_NAME=""
SSH_PUBLIC_KEY=""
ADMIN_EMAIL=""
ADMIN_PASSWORD=""
GPU_ENABLED="false"
OBSERVABILITY_ENABLED="false"
NO_BWS="false"
VAULT_PORT="8200"
SSH_PORT="2222"
SIGNOZ_PORT="3301"
MCP_SIGNOZ_PORT="3009"
VSCODE_PORT="8080"
ASPIRE_DASHBOARD_PORT="18890"
JUPYTER_PORT="8888"
PORTAINER_PORT="9000"
DEPLOY_PROFILES=""

while [ $# -gt 0 ]; do
    case "$1" in
        --workspace-name)
            WORKSPACE_NAME="$2"
            shift 2
            ;;
        --ssh-public-key)
            SSH_PUBLIC_KEY="$2"
            shift 2
            ;;
        --admin-email)
            ADMIN_EMAIL="$2"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --gpu)
            GPU_ENABLED="true"
            shift
            ;;
        --observability)
            OBSERVABILITY_ENABLED="true"
            shift
            ;;
        --no-bws)
            NO_BWS="true"
            shift
            ;;
        --vault-port)
            VAULT_PORT="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        --signoz-port)
            SIGNOZ_PORT="$2"
            shift 2
            ;;
        --mcp-signoz-port)
            MCP_SIGNOZ_PORT="$2"
            shift 2
            ;;
        --vscode-port)
            VSCODE_PORT="$2"
            shift 2
            ;;
        --aspire-dashboard-port)
            ASPIRE_DASHBOARD_PORT="$2"
            shift 2
            ;;
        --jupyter-port)
            JUPYTER_PORT="$2"
            shift 2
            ;;
        --portainer-port)
            PORTAINER_PORT="$2"
            shift 2
            ;;
        --profiles)
            DEPLOY_PROFILES="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

if [ -z "$WORKSPACE_NAME" ] || [ -z "$SSH_PUBLIC_KEY" ] || [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo "Error: --workspace-name, --ssh-public-key, --admin-email and --admin-password are required"
    show_usage
    exit 1
fi

echo ""
echo "  ███████╗███████╗ █████╗ ██╗ █████╗ "
echo "     ███╔╝   ███╔╝██╔══██╗██║██╔══██╗"
echo "    ███╔╝   ███╔╝ ███████║██║███████║ "
echo "   ███╔╝   ███╔╝  ██╔══██║██║██╔══██║ "
echo "  ███████╗███████╗██║  ██║██║██║  ██║ "
echo "  ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝"
echo ""
echo "         ⚡  Agentic Workspace  ⚡"
echo ""

BWS_MODE="bitwarden"
if [ "$NO_BWS" = "true" ]; then
    BWS_ACCESS_TOKEN=""
    BWS_MODE="manual"
elif [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
    read -s -p "Bitwarden Secrets Manager Access Token (press Enter to skip — use Vault UI): " BWS_ACCESS_TOKEN
    echo ""
    [ -z "$BWS_ACCESS_TOKEN" ] && BWS_MODE="manual"
fi

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../docker/.env"

# Preserve SIGNOZ_JWT_SECRET across re-deployments; generate once if missing
SIGNOZ_JWT_SECRET=""
if [ -f "$ENV_FILE" ]; then
    SIGNOZ_JWT_SECRET=$(grep '^SIGNOZ_JWT_SECRET=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)
fi
[ -z "$SIGNOZ_JWT_SECRET" ] && SIGNOZ_JWT_SECRET=$(openssl rand -hex 32)
SIGNOZ_ADMIN_EMAIL="$ADMIN_EMAIL"

cat > "$ENV_FILE" << EOF
WORKSPACE_NAME=$WORKSPACE_NAME
SSH_PUBLIC_KEY=$SSH_PUBLIC_KEY
GPU_ENABLED=$GPU_ENABLED
OBSERVABILITY_ENABLED=$OBSERVABILITY_ENABLED
VAULT_PORT=$VAULT_PORT
SSH_PORT=$SSH_PORT
SIGNOZ_PORT=$SIGNOZ_PORT
MCP_SIGNOZ_PORT=$MCP_SIGNOZ_PORT
VSCODE_PORT=$VSCODE_PORT
ASPIRE_DASHBOARD_PORT=$ASPIRE_DASHBOARD_PORT
JUPYTER_PORT=$JUPYTER_PORT
PORTAINER_PORT=$PORTAINER_PORT
DEPLOY_PROFILES=$DEPLOY_PROFILES
SIGNOZ_JWT_SECRET=$SIGNOZ_JWT_SECRET
SIGNOZ_ADMIN_EMAIL=$SIGNOZ_ADMIN_EMAIL
SIGNOZ_ADMIN_PASSWORD=$ADMIN_PASSWORD
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF

PROFILE_FLAGS=""
if [ -n "$DEPLOY_PROFILES" ]; then
    # Support both comma-separated and space-separated profile lists
    normalized_profiles=$(echo "$DEPLOY_PROFILES" | tr ',' ' ')
    for p in $normalized_profiles; do
        case "$p" in
            vscode|devcontainer|jupyter|tunnel|portainer) PROFILE_FLAGS="$PROFILE_FLAGS --profile $p" ;;
            *) echo "Warning: Unknown server profile '$p' — valid: vscode, devcontainer, jupyter, tunnel" ;;
        esac
    done
fi

GPU_COMPOSE_FLAG=""
[ "$GPU_ENABLED" = "true" ] && GPU_COMPOSE_FLAG="-f ${SCRIPT_DIR}/../docker/docker-compose.gpu.yml"

OBSERVABILITY_COMPOSE_FLAG=""
[ "$OBSERVABILITY_ENABLED" = "true" ] && OBSERVABILITY_COMPOSE_FLAG="-f ${SCRIPT_DIR}/../docker/docker-compose.observability.yml"

# Write BWS token to a tmpfile sourced by Compose secrets — token reaches vault-server
# via tmpfs /run/secrets/ (never in docker inspect, never in container env)
BWS_SECRET_FILE=""
if [ -n "${BWS_ACCESS_TOKEN:-}" ]; then
    BWS_SECRET_FILE=$(mktemp)
    chmod 600 "$BWS_SECRET_FILE"
    printf '%s' "$BWS_ACCESS_TOKEN" > "$BWS_SECRET_FILE"
    export BWS_SECRET_FILE
    unset BWS_ACCESS_TOKEN
    trap 'rm -f "$BWS_SECRET_FILE"; unset BWS_SECRET_FILE' EXIT
fi

echo ""
echo "Starting workspace..."
# shellcheck disable=SC2086
docker compose -f "${SCRIPT_DIR}/../docker/docker-compose.yml" $GPU_COMPOSE_FLAG $OBSERVABILITY_COMPOSE_FLAG -p "$WORKSPACE_NAME" $PROFILE_FLAGS up -d --build

echo ""
echo "✓ Workspace started. Access:"
echo "  SSH: ssh -p $SSH_PORT user@localhost"
[[ "$DEPLOY_PROFILES" == *vscode* ]] && echo "  VS Code: http://localhost:$VSCODE_PORT"
[[ "$DEPLOY_PROFILES" == *devcontainer* ]] && echo "  Dev Container: attach via VS Code Dev Containers extension"
[[ "$DEPLOY_PROFILES" == *tunnel* ]] && echo "  VS Code Tunnel: Remote Tunnels extension → '$WORKSPACE_NAME'"
echo "  Vault UI: http://localhost:$VAULT_PORT/ui"
[[ "$DEPLOY_PROFILES" == *portainer* ]] && echo "  Portainer: http://localhost:$PORTAINER_PORT"
echo "  AppHost Dashboard (when AppHost is running): http://localhost:$ASPIRE_DASHBOARD_PORT"
[ "$OBSERVABILITY_ENABLED" = "true" ] && echo "  SigNoz UI: http://localhost:$SIGNOZ_PORT"
[ "$OBSERVABILITY_ENABLED" = "true" ] && echo "  SigNoz MCP: http://localhost:$MCP_SIGNOZ_PORT/mcp"
echo ""
if [ "$BWS_MODE" = "manual" ]; then
    echo "Vault started empty (no Bitwarden token). Enter secrets via Vault UI:"
    echo "  1. Wait ~30s for vault-server to initialize, then open http://localhost:$VAULT_PORT/ui"
    echo "  2. Get root token: docker exec ${WORKSPACE_NAME}-vault-server-1 cat /vault/data/.init | grep root_token"
    echo "  3. Log in and add secrets under: secret/ai, secret/mcp/github, secret/mcp/azure-devops, secret/cloud, secret/integrations"
else
    echo "Secrets bootstrapped from Bitwarden. Manage via Vault UI with root token:"
    echo "  docker exec ${WORKSPACE_NAME}-vault-server-1 cat /vault/data/.init | grep root_token"
fi
