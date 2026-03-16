#!/bin/bash
# Init Hook - Claude Code Terminal Initialization
# Initializes the Claude Code terminal environment
# Signs in to 1Password for secret management
# Launches Claude Code with disabled permission checks

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

# Accept vault name and session ID as args (re-exec path) or prompt the user
if [ -n "$1" ] && [ -n "$2" ]; then
    VAULT_NAME="$1"
    SESSION_ID="$2"
else
    read -p "Enter 1Password vault name: " VAULT_NAME
    read -p "Enter session ID: " SESSION_ID
fi
export VAULT_NAME SESSION_ID

# Ensure session runs inside tmux for persistent terminal support
if [ -z "$TMUX" ]; then
    tmux new-session -A -s "${VAULT_NAME}-${SESSION_ID}" "$0" "$VAULT_NAME" "$SESSION_ID"
    exit $?
fi

# Sign in to 1Password to enable secret injection
eval $(op signin)

# Export global secret variables in claude's environment
export NEW_RELIC_API_KEY=$(op read "op://${VAULT_NAME}/new-relic/api-key")

# Launch Claude Code terminal with auto mode enabled
claude --dangerously-skip-permissions

# Sign out of 1Password to clean up session
eval $(op signout)

exit 0
