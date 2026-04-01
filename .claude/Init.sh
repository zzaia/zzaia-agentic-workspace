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

SESSION_UUID=$(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, '${SESSION_NAME}'))")

tmux new-session -s "$SESSION_NAME" "
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
eval \$(op signin) && \
export TAVILY_API_KEY=\$(op read 'op://${VAULT_NAME}/tavily/credential') && \
export ADO_MCP_AUTH_TOKEN=\$(op read 'op://${VAULT_NAME}/azure-devops/pat') && \
export AZURE_DEVOPS_ORGANIZATION=\$(op read 'op://${VAULT_NAME}/azure-devops/organization') && \
export POSTMAN_API_KEY=\$(op read 'op://${VAULT_NAME}/postman/credential') && \
export NEW_RELIC_API_KEY=\$(op read 'op://${VAULT_NAME}/new-relic/api-key') && \
if ! claude --dangerously-skip-permissions --resume ${SESSION_UUID}; then
    claude --dangerously-skip-permissions --session-id ${SESSION_UUID}
fi
op signout
exec bash
"

exit 0
