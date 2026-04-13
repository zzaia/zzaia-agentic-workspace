#!/bin/bash
# Init-ubuntu.sh - ZZAIA Workspace Launcher (Ubuntu / WSL)
set -euo pipefail

SESSION_NAME=""
EMAIL=""
FULL_AUTOMATIC=false
USE_TMUX=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session-name)   SESSION_NAME="$2"; shift 2 ;;
        --email)          EMAIL="$2"; shift 2 ;;
        --full-automatic) FULL_AUTOMATIC=true; shift ;;
        --tmux)           USE_TMUX=true; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

if [[ -n "$EMAIL" ]]; then
    bw login "$EMAIL" 2>/dev/null || true
else
    bw login 2>/dev/null || true
fi
BW_SESSION=$(bw unlock --raw)
export TAVILY_API_KEY=$(bw get password tavily --session "$BW_SESSION")
export ADO_MCP_AUTH_TOKEN=$(bw get password azure-devops-pat --session "$BW_SESSION")
export AZURE_DEVOPS_ORGANIZATION=$(bw get password azure-devops-org --session "$BW_SESSION")
export POSTMAN_API_KEY=$(bw get password postman --session "$BW_SESSION")
export NEW_RELIC_API_KEY=$(bw get password new-relic --session "$BW_SESSION")
bw lock --session "$BW_SESSION" >/dev/null 2>&1; unset BW_SESSION

CLAUDE_FLAGS="--enable-auto-mode"
[[ "$FULL_AUTOMATIC" == true ]] && CLAUDE_FLAGS="--dangerously-skip-permissions"

SESSION_UUID=""
[[ -n "$SESSION_NAME" ]] && SESSION_UUID=$(python3 -c 'import uuid, sys; print(uuid.uuid5(uuid.NAMESPACE_DNS, sys.argv[1]))' "$SESSION_NAME")

if [[ "$USE_TMUX" == true ]]; then
    TMUX_SESSION="${SESSION_NAME:-zzaia}"
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        tmux attach-session -t "$TMUX_SESSION"; exit 0
    fi
    if [[ -n "$SESSION_UUID" ]]; then
        tmux new-session -s "$TMUX_SESSION" \
            "if ! claude ${CLAUDE_FLAGS} --resume ${SESSION_UUID}; then claude ${CLAUDE_FLAGS} --session-id ${SESSION_UUID}; fi; exec bash"
    else
        tmux new-session -s "$TMUX_SESSION" "claude ${CLAUDE_FLAGS}; exec bash"
    fi
elif [[ -n "$SESSION_UUID" ]]; then
    claude $CLAUDE_FLAGS --resume "$SESSION_UUID" || claude $CLAUDE_FLAGS --session-id "$SESSION_UUID"
else
    claude $CLAUDE_FLAGS
fi
