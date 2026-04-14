#!/bin/bash
# Init-ubuntu-op.sh - ZZAIA Workspace Launcher (Ubuntu / WSL) with 1Password
set -euo pipefail

VAULT_NAME=""
SESSION_NAME=""
FULL_AUTOMATIC=false
USE_TMUX=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vault-name)     VAULT_NAME="$2"; shift 2 ;;
        --session-name)   SESSION_NAME="$2"; shift 2 ;;
        --full-automatic) FULL_AUTOMATIC=true; shift ;;
        --tmux)           USE_TMUX=true; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

if [[ -z "$VAULT_NAME" || -z "$SESSION_NAME" ]]; then
    echo "Usage: ./Init-ubuntu-op.sh --vault-name <vault> --session-name <name> [--full-automatic] [--tmux]"
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

warn_missing() {
    local secret_ref="$1"
    local var_name="$2"
    echo "WARN missing_secret ref=${secret_ref} var=${var_name}"
}

load_secret() {
    local var_name="$1"
    local secret_ref="$2"
    [[ -n "${!var_name:-}" ]] && return 0
    local secret_value
    secret_value=$(op read "$secret_ref" 2>/dev/null) || { warn_missing "$secret_ref" "$var_name"; return 0; }
    [[ -z "$secret_value" ]] && { warn_missing "$secret_ref" "$var_name"; return 0; }
    export "$var_name=$secret_value"
}

_OP_AUTH_TMP=$(mktemp)
op signin > "$_OP_AUTH_TMP" 2>/dev/null && source "$_OP_AUTH_TMP"; _OP_AUTH_STATUS=$?
rm -f "$_OP_AUTH_TMP"

if [[ $_OP_AUTH_STATUS -eq 0 ]]; then
    load_secret 'TAVILY_API_KEY'          "op://${VAULT_NAME}/tavily/credential"
    load_secret 'ADO_MCP_AUTH_TOKEN'      "op://${VAULT_NAME}/azure-devops/pat"
    load_secret 'AZURE_DEVOPS_ORGANIZATION' "op://${VAULT_NAME}/azure-devops/organization"
    load_secret 'POSTMAN_API_KEY'         "op://${VAULT_NAME}/postman/credential"
    load_secret 'NEW_RELIC_API_KEY'       "op://${VAULT_NAME}/new-relic/api-key"
    op signout >/dev/null 2>&1 || true
else
    echo 'WARN op_signin_failed'
fi

CLAUDE_FLAGS="--enable-auto-mode"
[[ "$FULL_AUTOMATIC" == true ]] && CLAUDE_FLAGS="--dangerously-skip-permissions"

SESSION_UUID=$(python3 -c 'import uuid, sys; print(uuid.uuid5(uuid.NAMESPACE_DNS, sys.argv[1] + "_" + sys.argv[2]))' "$VAULT_NAME" "$SESSION_NAME")

if [[ "$USE_TMUX" == true ]]; then
    TMUX_SESSION="${VAULT_NAME}_${SESSION_NAME}"
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        tmux attach-session -t "$TMUX_SESSION"; exit 0
    fi
    tmux new-session -s "$TMUX_SESSION" \
        "if ! claude ${CLAUDE_FLAGS} --resume ${SESSION_UUID}; then claude ${CLAUDE_FLAGS} --session-id ${SESSION_UUID}; fi; exec bash"
else
    claude $CLAUDE_FLAGS --resume "$SESSION_UUID" || claude $CLAUDE_FLAGS --session-id "$SESSION_UUID"
fi
