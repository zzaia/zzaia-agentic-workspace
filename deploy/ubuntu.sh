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

# Check if bws is installed
if ! command -v bws &> /dev/null; then
    echo "Error: bws (Bitwarden Secrets Manager) not found. Install from:"
    echo "  https://bitwarden.com/help/secrets-manager/#download-the-cli"
    exit 1
fi

# Prompt for Bitwarden Secrets Manager access token (if not set via environment)
if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
    read -p "Bitwarden Secrets Manager Access Token: " BWS_ACCESS_TOKEN
    [ -z "$BWS_ACCESS_TOKEN" ] && echo "Error: BWS_ACCESS_TOKEN is required" && exit 1
fi

# Prompt for Vault Root Token
if [ -z "${VAULT_ROOT_TOKEN:-}" ]; then
    read -p "Vault Root Token (required — choose a strong value): " VAULT_ROOT_TOKEN
    [ -z "$VAULT_ROOT_TOKEN" ] && echo "Error: VAULT_ROOT_TOKEN is required" && exit 1
fi

# Fetch all secrets from Bitwarden Secrets Manager
echo "Fetching secrets from Bitwarden Secrets Manager..."
export BWS_ACCESS_TOKEN
SECRETS_JSON=$(bws secret list --output json 2>/dev/null || echo "[]")

if [ "$SECRETS_JSON" = "[]" ] || [ -z "$SECRETS_JSON" ]; then
    echo "Error: No secrets returned from Bitwarden or bws failed"
    exit 1
fi

# Helper function to extract a secret value by key
get_secret() {
    local key="$1"
    echo "$SECRETS_JSON" | jq -r ".[] | select(.key == \"$key\") | .value" 2>/dev/null || echo ""
}

# Extract all required and optional secrets
WORKSPACE_NAME=$(get_secret "WORKSPACE_NAME")
SSH_PUBLIC_KEY=$(get_secret "SSH_PUBLIC_KEY")
ADMIN_PASSWORD=$(get_secret "ADMIN_PASSWORD")
VSCODE_PORT=$(get_secret "VSCODE_PORT")
SSH_PORT=$(get_secret "SSH_PORT")
ASPIRE_DASHBOARD_PORT=$(get_secret "ASPIRE_DASHBOARD_PORT")

ANTHROPIC_API_KEY=$(get_secret "ANTHROPIC_API_KEY")
CLAUDE_CODE_OAUTH_TOKEN=$(get_secret "CLAUDE_CODE_OAUTH_TOKEN")
OPENAI_API_KEY=$(get_secret "OPENAI_API_KEY")
GEMINI_API_KEY=$(get_secret "GEMINI_API_KEY")
GITHUB_PERSONAL_ACCESS_TOKEN=$(get_secret "GITHUB_PERSONAL_ACCESS_TOKEN")

AWS_ACCESS_KEY_ID=$(get_secret "AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY=$(get_secret "AWS_SECRET_ACCESS_KEY")
AWS_REGION=$(get_secret "AWS_REGION")
ANTHROPIC_BEDROCK_BASE_URL=$(get_secret "ANTHROPIC_BEDROCK_BASE_URL")
CLAUDE_CODE_USE_VERTEX=$(get_secret "CLAUDE_CODE_USE_VERTEX")
ANTHROPIC_VERTEX_PROJECT_ID=$(get_secret "ANTHROPIC_VERTEX_PROJECT_ID")
CLOUD_ML_REGION=$(get_secret "CLOUD_ML_REGION")
CLAUDE_CODE_USE_FOUNDRY=$(get_secret "CLAUDE_CODE_USE_FOUNDRY")
AZURE_FOUNDRY_BASE_URL=$(get_secret "AZURE_FOUNDRY_BASE_URL")

TAVILY_API_KEY=$(get_secret "TAVILY_API_KEY")
ADO_MCP_AUTH_TOKEN=$(get_secret "ADO_MCP_AUTH_TOKEN")
AZURE_DEVOPS_ORGANIZATION=$(get_secret "AZURE_DEVOPS_ORGANIZATION")
POSTMAN_API_KEY=$(get_secret "POSTMAN_API_KEY")
NEW_RELIC_API_KEY=$(get_secret "NEW_RELIC_API_KEY")

DOCKER_REGISTRY=$(get_secret "DOCKER_REGISTRY")
DOCKER_USERNAME=$(get_secret "DOCKER_USERNAME")
DOCKER_PASSWORD=$(get_secret "DOCKER_PASSWORD")

DEPLOY_PROFILES=$(get_secret "DEPLOY_PROFILES")
GPU_ENABLED=$(get_secret "GPU_ENABLED")

# Validate required secrets
if [ -z "$WORKSPACE_NAME" ]; then
    echo "Error: WORKSPACE_NAME secret not found in Bitwarden"
    exit 1
fi

if [ -z "$SSH_PUBLIC_KEY" ]; then
    echo "Error: SSH_PUBLIC_KEY secret not found in Bitwarden"
    exit 1
fi

# Set defaults for optional values
VSCODE_PORT="${VSCODE_PORT:-8080}"
SSH_PORT="${SSH_PORT:-2222}"
ASPIRE_DASHBOARD_PORT="${ASPIRE_DASHBOARD_PORT:-18888}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-zzaia1234}"
GPU_ENABLED="${GPU_ENABLED:-false}"
DEPLOY_PROFILES="${DEPLOY_PROFILES:-}"

# Validate port numbers
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    return 0
}

validate_port "$VSCODE_PORT" || { echo "Error: Invalid VSCODE_PORT"; exit 1; }
validate_port "$SSH_PORT" || { echo "Error: Invalid SSH_PORT"; exit 1; }
validate_port "$ASPIRE_DASHBOARD_PORT" || { echo "Error: Invalid ASPIRE_DASHBOARD_PORT"; exit 1; }

# Export all secrets as environment variables for docker compose
export WORKSPACE_NAME SSH_PUBLIC_KEY ADMIN_PASSWORD
export VSCODE_PORT SSH_PORT ASPIRE_DASHBOARD_PORT
export VAULT_ROOT_TOKEN
export GPU_ENABLED DEPLOY_PROFILES
export ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
export OPENAI_API_KEY GEMINI_API_KEY GITHUB_PERSONAL_ACCESS_TOKEN
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION
export ANTHROPIC_BEDROCK_BASE_URL
export CLAUDE_CODE_USE_VERTEX ANTHROPIC_VERTEX_PROJECT_ID CLOUD_ML_REGION
export CLAUDE_CODE_USE_FOUNDRY AZURE_FOUNDRY_BASE_URL
export TAVILY_API_KEY ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION
export POSTMAN_API_KEY NEW_RELIC_API_KEY

# Optional Docker registry login
if [ -n "$DOCKER_REGISTRY" ] && [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
    echo "Logging in to Docker registry..."
    echo "$DOCKER_PASSWORD" | docker login "$DOCKER_REGISTRY" -u "$DOCKER_USERNAME" --password-stdin
fi

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build --profile flags
PROFILE_FLAGS=""
if [ -n "$DEPLOY_PROFILES" ]; then
    for p in $DEPLOY_PROFILES; do
        case "$p" in
            vscode|devcontainer|jupyter|tunnel) PROFILE_FLAGS="$PROFILE_FLAGS --profile $p" ;;
            *) echo "Warning: Unknown server profile '$p' — valid: vscode, devcontainer, jupyter, tunnel" ;;
        esac
    done
fi

# GPU compose flag
GPU_COMPOSE_FLAG=""
[ "$GPU_ENABLED" = "true" ] && GPU_COMPOSE_FLAG="-f $SCRIPT_DIR/../docker/docker-compose.gpu.yml"

# Start workspace
echo ""
echo "Starting workspace..."
# shellcheck disable=SC2086
docker compose -f "$SCRIPT_DIR/../docker/docker-compose.yml" $GPU_COMPOSE_FLAG -p "$WORKSPACE_NAME" $PROFILE_FLAGS up -d

echo ""
echo "✓ Workspace started. Access:"
echo "  SSH: ssh -p $SSH_PORT user@localhost"
[[ "$DEPLOY_PROFILES" == *vscode* ]] && echo "  VS Code: http://localhost:$VSCODE_PORT"
[[ "$DEPLOY_PROFILES" == *devcontainer* ]] && echo "  Dev Container: attach via VS Code Dev Containers extension"
[[ "$DEPLOY_PROFILES" == *tunnel* ]] && echo "  VS Code Tunnel: Remote Tunnels extension → '$WORKSPACE_NAME' or https://vscode.dev/tunnel/$WORKSPACE_NAME"
echo "  Vault UI: http://localhost:8200/ui"
echo "  AppHost Dashboard (when AppHost is running): http://localhost:$ASPIRE_DASHBOARD_PORT"

# Cleanup: unset BWS_ACCESS_TOKEN and all secret env vars
unset BWS_ACCESS_TOKEN
unset WORKSPACE_NAME SSH_PUBLIC_KEY ADMIN_PASSWORD
unset VSCODE_PORT SSH_PORT ASPIRE_DASHBOARD_PORT VAULT_ROOT_TOKEN
unset GPU_ENABLED DEPLOY_PROFILES
unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
unset OPENAI_API_KEY GEMINI_API_KEY GITHUB_PERSONAL_ACCESS_TOKEN
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION
unset ANTHROPIC_BEDROCK_BASE_URL
unset CLAUDE_CODE_USE_VERTEX ANTHROPIC_VERTEX_PROJECT_ID CLOUD_ML_REGION
unset CLAUDE_CODE_USE_FOUNDRY AZURE_FOUNDRY_BASE_URL
unset TAVILY_API_KEY ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION
unset POSTMAN_API_KEY NEW_RELIC_API_KEY
