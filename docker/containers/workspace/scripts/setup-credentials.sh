#!/bin/bash
# setup-credentials.sh — Authentication setup (Claude, GitHub, Azure DevOps)
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ── Template WORKSPACE_NAME in config files ──────────────────────────────────
apply_workspace_templating() {
    log_info "Applying WORKSPACE_NAME templating..."
    
    su -s /bin/bash user -c "
        find /home/user /home/user/.vscode-server /home/user/workspace \
            \( -name '*.json' -o -name '*.code-workspace' \) -maxdepth 4 2>/dev/null \
            | xargs sed -i 's/{{WORKSPACE_NAME}}/${WORKSPACE_NAME}/g' 2>/dev/null || true
        
        [ -f /home/user/zzaia.code-workspace ] \
            && mv /home/user/zzaia.code-workspace \
                  /home/user/${WORKSPACE_NAME}.code-workspace 2>/dev/null || true
    "
    
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

    # Install plugins after auth so claude plugin sync can apply MCP config
    CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
    su -s /bin/bash user -c "
        export PATH=/home/user/.local/bin:/home/user/.npm-global/bin:/home/user/.dotnet:/home/user/.dotnet/tools:/home/user/miniforge3/bin:\$PATH
        claude plugin marketplace add https://github.com/zzaia/zzaia-agentic-workspace.git#feature/improve-agentic-system || true
        claude plugin install agentic-workspace@zzaia || true
    "
}

# ── GitHub authentication and extensions ──────────────────────────────────────
setup_github_credentials() {
    if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
        log_warn "GITHUB_PERSONAL_ACCESS_TOKEN not set, skipping GitHub auth"
        return 0
    fi
    
    log_info "Configuring GitHub authentication..."
    
    GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
    su -s /bin/bash user -c "
        export PATH=/home/user/.local/bin:/home/user/.npm-global/bin:/home/user/.dotnet:/home/user/.dotnet/tools:/home/user/miniforge3/bin:\$PATH
        export GITHUB_TOKEN=\"\$GITHUB_PERSONAL_ACCESS_TOKEN\"

        # Authenticate gh CLI
        echo \"\$GITHUB_PERSONAL_ACCESS_TOKEN\" | gh auth login --with-token 2>/dev/null || true

        # Upgrade any existing extensions
        gh extension upgrade --all 2>/dev/null || true
        
        # Configure git credential helper
        git config --global credential.https://github.com.helper store
        grep -qF \"github.com\" /home/user/.git-credentials 2>/dev/null \
            || printf \"https://x-access-token:%s@github.com\\n\" \"\$GITHUB_PERSONAL_ACCESS_TOKEN\" \
               >> /home/user/.git-credentials
        chmod 600 /home/user/.git-credentials
    "
    
    log_success "GitHub authenticated"
}

# ── Azure DevOps git credentials ──────────────────────────────────────────────
setup_azure_devops_credentials() {
    if [ -z "${ADO_MCP_AUTH_TOKEN:-}" ]; then
        log_warn "ADO_MCP_AUTH_TOKEN not set, skipping Azure DevOps auth"
        return 0
    fi
    
    log_info "Configuring Azure DevOps git credentials..."
    
    ADO_MCP_AUTH_TOKEN="$ADO_MCP_AUTH_TOKEN" \
    su -s /bin/bash user -c "
        git config --global credential.https://dev.azure.com.helper store
        grep -qF \"dev.azure.com\" /home/user/.git-credentials 2>/dev/null \
            || printf \"https://anything:%s@dev.azure.com\n\" \"\$ADO_MCP_AUTH_TOKEN\" \
               >> /home/user/.git-credentials
        chmod 600 /home/user/.git-credentials
    "
    
    log_success "Azure DevOps authenticated"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    apply_workspace_templating
    setup_claude_credentials
    setup_github_credentials
    setup_azure_devops_credentials
    
    log_success "All credentials configured"
}

main "$@"
