#!/bin/bash
# setup-credentials.sh — Authentication setup (Claude, Git via sidecar)
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

trap cleanup_secrets EXIT

# ── Template WORKSPACE_NAME in config files ──────────────────────────────────
apply_workspace_templating() {
    log_info "Applying WORKSPACE_NAME templating..."

    WORKSPACE_NAME="$WORKSPACE_NAME" \
    su -s /bin/bash user -c '
        find /home/user /home/user/.vscode-server /home/user/workspace \
            \( -name "*.json" -o -name "*.code-workspace" \) -maxdepth 4 2>/dev/null \
            | xargs sed -i "s/{{WORKSPACE_NAME}}/${WORKSPACE_NAME}/g" 2>/dev/null || true

        # Rename any *.code-workspace that is not already named for this workspace
        for ws in /home/user/*.code-workspace; do
            [ -f "$ws" ] || continue
            target="/home/user/${WORKSPACE_NAME}.code-workspace"
            [ "$ws" = "$target" ] || mv "$ws" "$target" 2>/dev/null || true
        done
    '

    log_success "WORKSPACE_NAME templating complete"
}

# ── Claude CLI OAuth token ────────────────────────────────────────────────────
setup_claude_credentials() {
    if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        log_warn "CLAUDE_CODE_OAUTH_TOKEN not set, skipping Claude CLI auth"
        return 0
    fi
    
    log_info "Configuring Claude CLI credentials..."
    
    CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
    su -s /bin/bash user -c "
        mkdir -p /home/user/.claude
        printf '{\"claudeAiOAuth\":{\"accessToken\":\"%s\",\"expiresAt\":9999999999,\"refreshToken\":null,\"scopes\":null,\"tokenType\":\"Bearer\"}}\n' \
            \"\$CLAUDE_CODE_OAUTH_TOKEN\" > /home/user/.claude/.credentials.json
        chmod 600 /home/user/.claude/.credentials.json
    "
    
    log_success "Claude CLI authenticated"
}

# ── Git sidecar SSH authentication ───────────────────────────────────────────
setup_git_sidecar_authentication() {
    if [ -z "${VAULT_ADDR:-}" ] || [ -z "${VAULT_TOKEN:-}" ]; then
        log_warn "VAULT_ADDR or VAULT_TOKEN not set, skipping git-sidecar auth"
        return 0
    fi

    log_info "Configuring git-sidecar SSH authentication..."

    # Fetch workspace secrets from Vault (includes GIT_SIDECAR_AGENT_KEY)
    WORKSPACE_RESPONSE=$(wget -q -O - --header="X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/workspace" 2>/dev/null || echo '{}')

    if [ "$WORKSPACE_RESPONSE" = '{}' ]; then
        log_warn "Could not fetch workspace secrets from Vault, skipping git-sidecar setup"
        return 0
    fi

    # Extract GIT_SIDECAR_AGENT_KEY from Vault response (using jq for proper unescaping)
    GIT_SIDECAR_AGENT_KEY=$(printf '%s' "$WORKSPACE_RESPONSE" | jq -r '.data.data.GIT_SIDECAR_AGENT_KEY // empty' 2>/dev/null || echo "")

    if [ -z "$GIT_SIDECAR_AGENT_KEY" ]; then
        log_warn "GIT_SIDECAR_AGENT_KEY not found in Vault, skipping git-sidecar setup"
        return 0
    fi

    GIT_SIDECAR_AGENT_KEY="$GIT_SIDECAR_AGENT_KEY" \
    su -s /bin/bash user -c '
        mkdir -p /home/user/.ssh

        printf "%s\n" "$GIT_SIDECAR_AGENT_KEY" > /home/user/.ssh/id_rsa_git_sidecar
        chmod 600 /home/user/.ssh/id_rsa_git_sidecar

        cat >> /home/user/.ssh/config << EOF
Host git-sidecar
  HostName git-sidecar
  Port 2223
  User git
  IdentityFile ~/.ssh/id_rsa_git_sidecar
  StrictHostKeyChecking accept-new
  IdentitiesOnly yes
EOF
        chmod 600 /home/user/.ssh/config

        git config --global --add "url.git@git-sidecar:github/.insteadOf" "https://github.com/"
        git config --global --add "url.git@git-sidecar:github/.insteadOf" "git@github.com:"
        git config --global --add "url.git@git-sidecar:ado/.insteadOf" "git@ssh.dev.azure.com:v3/"
        git config --global --add "url.git@git-sidecar:ado/.insteadOf" "https://dev.azure.com/"
    '

    # Unset the variable immediately after use
    unset GIT_SIDECAR_AGENT_KEY

    log_success "Git-sidecar SSH authentication configured"
}

# ── Claude Code plugin installation ──────────────────────────────────────────
setup_claude_plugins() {
    log_info "Installing Claude Code plugins..."

    su -s /bin/bash user -c "
        export HOME=/home/user
        export NVM_DIR=/opt/tools/.nvm
        [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
        export PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:\$PATH
        claude plugin marketplace add https://github.com/zzaia/zzaia-agentic-workspace.git#feature/improve-agentic-system || true
        claude plugin install agentic-workspace@zzaia || true
    " && log_success "Claude Code plugins installed" \
      || log_warn "Claude Code plugin install failed; MCP config and settings are pre-seeded"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    apply_workspace_templating
    setup_claude_credentials
    setup_git_sidecar_authentication
    setup_claude_plugins

    log_success "All credentials configured"
}

main "$@"
