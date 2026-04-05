#!/bin/bash
# Init Hook - Claude Code Terminal Initialization
# Initializes the Claude Code terminal environment
# Signs in to 1Password for secret management
# Launches Claude Code with disabled permission checks
#
# Usage: ./Init.sh --vault-name <vault> --session-name <name>

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vault-name)   VAULT_NAME="$2";   shift 2 ;;
        --session-name) SESSION_NAME="$2"; shift 2 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

if [[ -z "$VAULT_NAME" || -z "$SESSION_NAME" ]]; then
    echo "Usage: ./Init.sh --vault-name <vault> --session-name <name>"
    exit 1
fi

SESSION_UUID=$(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, '${VAULT_NAME}_${SESSION_NAME}'))")

if tmux has-session -t "${VAULT_NAME}_${SESSION_NAME}" 2>/dev/null; then
    tmux attach-session -t "${VAULT_NAME}_${SESSION_NAME}"
    exit 0
fi

tmux new-session -s "${VAULT_NAME}_${SESSION_NAME}" "
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
    local secret_ref=\"\$1\"
    local var_name=\"\$2\"
    local path_part=\"\${secret_ref#op://}\"
    local vault_name=\"\${path_part%%/*}\"
    local route_name=\"\${path_part#*/}\"
    if [[ \"\$path_part\" == \"\$route_name\" ]]; then
        route_name='-'
    fi
    echo \"WARN missing_secret vault=\$vault_name route=\$route_name var=\$var_name\"
}
load_secret() {
    local var_name=\"\$1\"
    local default_ref=\"\$2\"
    local override_name=\"\$3\"
    local secret_ref=\"\${!override_name:-\$default_ref}\"
    local secret_value=''
    if [[ -n \"\${!var_name}\" ]]; then
        return 0
    fi
    secret_value=\$(op read \"\$secret_ref\" 2>/dev/null)
    if [[ \$? -ne 0 || -z \"\$secret_value\" ]]; then
        warn_missing \"\$secret_ref\" \"\$var_name\"
        return 0
    fi
    export \"\$var_name=\$secret_value\"
    tmux set-environment -t \"\$(tmux display-message -p '#S')\" \"\$var_name\" \"\$secret_value\" >/dev/null 2>&1 || true
}
if eval \"\$(op signin)\" >/dev/null 2>&1; then
    load_secret 'TAVILY_API_KEY' 'op://${VAULT_NAME}/tavily/credential' 'TAVILY_API_KEY_OP_REF'
    load_secret 'ADO_MCP_AUTH_TOKEN' 'op://${VAULT_NAME}/azure-devops/pat' 'ADO_MCP_AUTH_TOKEN_OP_REF'
    load_secret 'AZURE_DEVOPS_ORGANIZATION' 'op://${VAULT_NAME}/azure-devops/organization' 'AZURE_DEVOPS_ORGANIZATION_OP_REF'
    load_secret 'POSTMAN_API_KEY' 'op://${VAULT_NAME}/postman/credential' 'POSTMAN_API_KEY_OP_REF'
    load_secret 'NEW_RELIC_API_KEY' 'op://${VAULT_NAME}/new-relic/api-key' 'NEW_RELIC_API_KEY_OP_REF'
    op signout >/dev/null 2>&1 || true
else
    echo 'WARN op_signin_failed'
fi
if ! claude --dangerously-skip-permissions --resume ${SESSION_UUID}; then
    claude --dangerously-skip-permissions --session-id ${SESSION_UUID}
fi
exec bash
"

exit 0
