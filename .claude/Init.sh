#!/bin/bash
# Init Hook - Claude Code Terminal Initialization
# Initializes the Claude Code terminal environment
# Signs in to 1Password for secret management
# Launches Claude Code with disabled permission checks

echo "� ⚡ ZZAIA Agentic Workspace⚡ 🚀" 

# Sign in to 1Password to enable secret injection
eval $(op signin)

# Laungh claude code terminal with disabled permission checks
claude --dangerously-skip-permissions --verbose

exit 0
