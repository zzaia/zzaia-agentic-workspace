#!/bin/bash
set -euo pipefail

show_usage() {
    cat << 'EOF'
Usage: ./deploy/ubuntu.sh [OPTIONS]

Options:
  --workspace-name NAME         Workspace name (required)
  --ssh-public-key KEY          SSH public key (required)
  --gpu                         Enable GPU support (default: false)
  --vault-port PORT             Vault server port (default: 8200)
  --ssh-port PORT               SSH server port (default: 2222)
  --vscode-port PORT            VS Code server port (default: 8080)
  --aspire-dashboard-port PORT  Aspire Dashboard port (default: 18890)
  --jupyter-port PORT           Jupyter port (default: 8888)
  --profiles PROFILES           Comma-separated server profiles: vscode, jupyter, devcontainer, tunnel
  --help                        Show this help message

Examples:
  ./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..."
  ./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..." --gpu --profiles vscode
EOF
}

WORKSPACE_NAME=""
SSH_PUBLIC_KEY=""
GPU_ENABLED="false"
VAULT_PORT="8200"
SSH_PORT="2222"
VSCODE_PORT="8080"
ASPIRE_DASHBOARD_PORT="18890"
JUPYTER_PORT="8888"
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
        --gpu)
            GPU_ENABLED="true"
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

if [ -z "$WORKSPACE_NAME" ] || [ -z "$SSH_PUBLIC_KEY" ]; then
    echo "Error: --workspace-name and --ssh-public-key are required"
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
if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
    read -s -p "Bitwarden Secrets Manager Access Token (press Enter to skip — use Vault UI): " BWS_ACCESS_TOKEN
    echo ""
    [ -z "$BWS_ACCESS_TOKEN" ] && BWS_MODE="manual"
fi

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../docker/.env"

cat > "$ENV_FILE" << EOF
WORKSPACE_NAME=$WORKSPACE_NAME
SSH_PUBLIC_KEY=$SSH_PUBLIC_KEY
GPU_ENABLED=$GPU_ENABLED
VAULT_PORT=$VAULT_PORT
SSH_PORT=$SSH_PORT
VSCODE_PORT=$VSCODE_PORT
ASPIRE_DASHBOARD_PORT=$ASPIRE_DASHBOARD_PORT
JUPYTER_PORT=$JUPYTER_PORT
DEPLOY_PROFILES=$DEPLOY_PROFILES
EOF

PROFILE_FLAGS=""
if [ -n "$DEPLOY_PROFILES" ]; then
    for p in $DEPLOY_PROFILES; do
        case "$p" in
            vscode|devcontainer|jupyter|tunnel) PROFILE_FLAGS="$PROFILE_FLAGS --profile $p" ;;
            *) echo "Warning: Unknown server profile '$p' — valid: vscode, devcontainer, jupyter, tunnel" ;;
        esac
    done
fi

GPU_COMPOSE_FLAG=""
[ "$GPU_ENABLED" = "true" ] && GPU_COMPOSE_FLAG="-f ${SCRIPT_DIR}/../docker/docker-compose.gpu.yml"

echo ""
echo "Starting workspace..."
export BWS_ACCESS_TOKEN
# shellcheck disable=SC2086
docker compose -f "${SCRIPT_DIR}/../docker/docker-compose.yml" $GPU_COMPOSE_FLAG -p "$WORKSPACE_NAME" $PROFILE_FLAGS up -d
unset BWS_ACCESS_TOKEN

echo ""
echo "✓ Workspace started. Access:"
echo "  SSH: ssh -p $SSH_PORT user@localhost"
[[ "$DEPLOY_PROFILES" == *vscode* ]] && echo "  VS Code: http://localhost:$VSCODE_PORT"
[[ "$DEPLOY_PROFILES" == *devcontainer* ]] && echo "  Dev Container: attach via VS Code Dev Containers extension"
[[ "$DEPLOY_PROFILES" == *tunnel* ]] && echo "  VS Code Tunnel: Remote Tunnels extension → '$WORKSPACE_NAME'"
echo "  Vault UI: http://localhost:$VAULT_PORT/ui"
echo "  AppHost Dashboard (when AppHost is running): http://localhost:$ASPIRE_DASHBOARD_PORT"
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
