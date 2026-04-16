#!/bin/bash
# Init-ubuntu.sh - ZZAIA Workspace Launcher (Ubuntu / WSL)
set -euo pipefail

SESSION_NAME=""
FULL_AUTOMATIC=false
USE_TMUX=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session-name)   SESSION_NAME="$2"; shift 2 ;;
        --full-automatic) FULL_AUTOMATIC=true; shift ;;
        --tmux)           USE_TMUX=true; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

if [[ -z "$SESSION_NAME" ]]; then
    echo "Usage: ./Init-ubuntu.sh --session-name <name> [--full-automatic] [--tmux]"
    exit 1
fi

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
BW_SESSION=$(bw login --raw)
BW_ITEMS=$(bw list items --session "$BW_SESSION")
export TAVILY_API_KEY=$(echo "$BW_ITEMS" | jq -r '.[] | select(.name=="tavily") | .login.password')
export ADO_MCP_AUTH_TOKEN=$(echo "$BW_ITEMS" | jq -r '.[] | select(.name=="azure-devops-pat") | .login.password')
export AZURE_DEVOPS_ORGANIZATION=$(echo "$BW_ITEMS" | jq -r '.[] | select(.name=="azure-devops-org") | .login.password')
export POSTMAN_API_KEY=$(echo "$BW_ITEMS" | jq -r '.[] | select(.name=="postman") | .login.password')
export NEW_RELIC_API_KEY=$(echo "$BW_ITEMS" | jq -r '.[] | select(.name=="new-relic") | .login.password')
bw logout 2>/dev/null; unset BW_SESSION BW_ITEMS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CLAUDE_CONFIG_DIR="$SCRIPT_DIR/.claude"

CLAUDE_FLAGS="--enable-auto-mode"
[[ "$FULL_AUTOMATIC" == true ]] && CLAUDE_FLAGS="--dangerously-skip-permissions"

SESSION_UUID=$(python3 -c 'import uuid, sys; print(uuid.uuid5(uuid.NAMESPACE_DNS, sys.argv[1]))' "$SESSION_NAME")

if [[ "$USE_TMUX" == true ]]; then
    TMUX_SESSION="$SESSION_NAME"
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        tmux attach-session -t "$TMUX_SESSION"; exit 0
    fi
    tmux new-session -s "$TMUX_SESSION" \
        "if ! claude ${CLAUDE_FLAGS} --resume ${SESSION_UUID}; then claude ${CLAUDE_FLAGS} --session-id ${SESSION_UUID}; fi; exec bash"
else
    claude $CLAUDE_FLAGS --resume "$SESSION_UUID" || claude $CLAUDE_FLAGS --session-id "$SESSION_UUID"
fi
