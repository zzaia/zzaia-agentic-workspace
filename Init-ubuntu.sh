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

BW_SESSION=$(bw login --raw)
export TAVILY_API_KEY=$(bw get password tavily --session "$BW_SESSION")
export ADO_MCP_AUTH_TOKEN=$(bw get password azure-devops-pat --session "$BW_SESSION")
export AZURE_DEVOPS_ORGANIZATION=$(bw get password azure-devops-org --session "$BW_SESSION")
export POSTMAN_API_KEY=$(bw get password postman --session "$BW_SESSION")
export NEW_RELIC_API_KEY=$(bw get password new-relic --session "$BW_SESSION")
bw logout 2>/dev/null; unset BW_SESSION

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
