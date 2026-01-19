#!/bin/bash
# SessionStart Hook - 1Password Secret Injection
# Automatically injects secrets from 1Password into Claude Code session
# Uses CLAUDE_ENV_FILE mechanism for environment variable persistence
# Requires: 1Password CLI (op) installed and configured
# Performance: Single op inject call resolves all secrets at once

echo "🔐 Loading secrets from 1Password..." >&2

eval $(op signin)

if [ -n "$CLAUDE_ENV_FILE" ]; then
  op inject -i <(cat << 'EOF'
export TAVILY_API_KEY="op://bloquo/tavily/credential"
export AZURE_DEVOPS_ORGANIZATION="op://bloquo/azure-devops/organization"
export AZURE_DEVOPS_PAT="op://bloquo/azure-devops/pat"
export AZURE_DEVOPS_PROJECT="op://bloquo/azure-devops/project"
EOF
) >> "$CLAUDE_ENV_FILE" 2>&1 && \
    echo "✓ Secrets exported to session" >&2 || \
    echo "✗ Failed to inject secrets" >&2
else
  echo "⚠️  CLAUDE_ENV_FILE not set" >&2
fi

exit 0
