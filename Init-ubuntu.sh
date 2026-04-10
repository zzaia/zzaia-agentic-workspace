#!/bin/bash
# Init-ubuntu.sh - ZZAIA Workspace Launcher (Ubuntu / WSL)
# Unlocks Bitwarden vault, loads secrets, and launches Claude Code.
#
# Usage: bash Init-ubuntu.sh

set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

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
command -v bw &>/dev/null || die "Bitwarden CLI not found. Run Install-ubuntu.sh first."

echo "[1/2] Unlocking Bitwarden vault..."

BW_STATUS=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unauthenticated")
if [[ "$BW_STATUS" == "unauthenticated" ]]; then
    timeout 300 bw login || die "Bitwarden login failed or timed out"
fi

BW_SESSION=$(timeout 120 bw unlock --raw) || die "Bitwarden unlock failed or timed out"

load_secret() {
    local var_name="$1"
    local item_name="$2"
    local secret_value
    secret_value=$(bw get password "$item_name" --session "$BW_SESSION" 2>/dev/null || true)
    if [[ -z "$secret_value" ]]; then
        echo "WARN missing_secret item=$item_name var=$var_name"
        return 0
    fi
    printf -v "$var_name" '%s' "$secret_value"
    export "$var_name"
}

load_secret "TAVILY_API_KEY"            "tavily"
load_secret "ADO_MCP_AUTH_TOKEN"        "azure-devops-pat"
load_secret "AZURE_DEVOPS_ORGANIZATION" "azure-devops-org"
load_secret "POSTMAN_API_KEY"           "postman"
load_secret "NEW_RELIC_API_KEY"         "new-relic"

bw lock --session "$BW_SESSION" >/dev/null 2>&1 || true
unset BW_SESSION

# ── Launch Claude Code ───────────────────────────────────────────────────────
echo "[2/2] Launching Claude Code..."
echo ""
claude --enable-auto-mode
