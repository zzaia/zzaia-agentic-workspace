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

# Prompt for 1Password vault name
read -p "Enter 1Password vault name: " VAULT_NAME
export VAULT_NAME

# Sign in to 1Password to enable secret injection
eval $(op signin)

# Launch Claude Code terminal with auto mode enabled
claude --enable-auto-mode

# Sign out of 1Password to clean up session
eval $(op signout)

exit 0
