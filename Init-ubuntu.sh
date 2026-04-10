#!/bin/bash
# Init-ubuntu.sh - ZZAIA Workspace Launcher (Ubuntu / WSL)
# Installs Bitwarden CLI if missing, loads secrets, and launches Claude Code.
#
# Usage: bash Init-ubuntu.sh

set -e

is_installed() { command -v "$1" &>/dev/null; }

echo ""
echo "  ███████╗███████╗ █████╗ ██╗ █████╗ "
echo "     ███╔╝   ███╔╝██╔══██╗██║██╔══██╗"
echo "    ███╔╝   ███╔╝ ███████║██║███████║ "
echo "   ███╔╝   ███╔╝  ██╔══██║██║██╔══██║ "
echo "  ███████╗███████╗██║  ██║██║██║  ██║ "
echo "  ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝"
echo ""
echo "         Agentic Workspace"
echo ""

# ── Bitwarden login ──────────────────────────────────────────────────────────
if ! command -v bw &>/dev/null; then
    echo "ERROR: Bitwarden CLI not found. Run Install-ubuntu.sh first."
    exit 1
fi

echo "[1/2] Unlocking Bitwarden vault..."
BW_STATUS=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unauthenticated")
if [[ "$BW_STATUS" == "unauthenticated" ]]; then
    bw login
fi
BW_SESSION=$(bw unlock --raw)

load_secret() {
    local var_name="$1"
    local item_name="$2"
    local secret_value
    secret_value=$(bw get password "$item_name" --session "$BW_SESSION" 2>/dev/null || true)
    if [[ -z "$secret_value" ]]; then
        echo "WARN missing_secret item=$item_name var=$var_name"
        return 0
    fi
    export "$var_name=$secret_value"
}

load_secret "TAVILY_API_KEY"            "tavily"
load_secret "ADO_MCP_AUTH_TOKEN"        "azure-devops-pat"
load_secret "AZURE_DEVOPS_ORGANIZATION" "azure-devops-org"
load_secret "POSTMAN_API_KEY"           "postman"
load_secret "NEW_RELIC_API_KEY"         "new-relic"

bw lock --session "$BW_SESSION" >/dev/null 2>&1 || true

# ── Launch Claude Code ───────────────────────────────────────────────────────
echo "[2/2] Launching Claude Code..."
echo ""
claude --enable-auto-mode
