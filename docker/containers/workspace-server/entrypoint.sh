#!/bin/bash
# entrypoint.sh — Workspace server bootstrap via Ansible
set -euo pipefail

SCRIPT_DIR="/usr/local/lib/zzaia/scripts"
export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"
export INSTALL_PREFIX="/opt/tools"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# ── Load admin password from Docker secret for Ansible ───────────────────────
# Exported only during bootstrap_workspace (Ansible run), then unset before sshd exec.
# Agents connecting via SSH cannot see it in /proc/1/environ (sshd won't have it).
load_admin_password() {
    # cap_drop:ALL removes DAC_OVERRIDE — must read as uid 1000 (file owner), not root
    local pw
    pw=$(runuser -u user -- cat /run/secrets/admin_password 2>/dev/null || echo "")
    [ -n "$pw" ] && export ADMIN_PASSWORD="$pw" || log_warn "admin_password secret not found — sudo will be passwordless"
}

# ── Fetch Vault credentials via AppRole ───────────────────────────────────────
fetch_vault_credentials() {
    local cred_file="/secrets/vault-approle-workspace.env"
    if [ ! -f "$cred_file" ]; then
        log_warn "Vault AppRole credentials not found — starting without Vault secrets"
        return 0
    fi

    local role_id secret_id
    role_id=$(grep '^VAULT_ROLE_ID=' "$cred_file" | cut -d= -f2-)
    secret_id=$(grep '^VAULT_SECRET_ID=' "$cred_file" | cut -d= -f2-)

    if [ -z "$role_id" ] || [ -z "$secret_id" ]; then
        log_warn "Invalid AppRole credentials — starting without Vault secrets"
        return 0
    fi

    local login_response vault_token
    login_response=$(wget -q -O - \
        --post-data="{\"role_id\":\"${role_id}\",\"secret_id\":\"${secret_id}\"}" \
        --header="Content-Type: application/json" \
        "${VAULT_ADDR:-http://vault-server:8200}/v1/auth/approle/login" 2>/dev/null || echo '{}')

    vault_token=$(printf '%s' "$login_response" | jq -r '.auth.client_token // empty' 2>/dev/null || echo "")
    unset role_id secret_id

    if [ -z "$vault_token" ]; then
        log_warn "Vault AppRole login failed — starting without Vault secrets"
        return 0
    fi

    local vault="${VAULT_ADDR:-http://vault-server:8200}"

    # Fetch git-sidecar agent key for SSH routing setup
    local ws_data
    ws_data=$(wget -q -O - --header="X-Vault-Token: ${vault_token}" \
        "${vault}/v1/secret/data/workspace" 2>/dev/null || echo '{}')
    export GIT_SIDECAR_AGENT_KEY
    GIT_SIDECAR_AGENT_KEY=$(printf '%s' "$ws_data" | jq -r '.data.data.GIT_SIDECAR_AGENT_KEY // empty' 2>/dev/null || echo "")

    # Fetch ADO organization for org-specific git insteadOf routing
    local ado_data
    ado_data=$(wget -q -O - --header="X-Vault-Token: ${vault_token}" \
        "${vault}/v1/secret/data/mcp/azure-devops" 2>/dev/null || echo '{}')
    export AZURE_DEVOPS_ORGANIZATION
    AZURE_DEVOPS_ORGANIZATION=$(printf '%s' "$ado_data" | jq -r '.data.data.AZURE_DEVOPS_ORGANIZATION // empty' 2>/dev/null || echo "")

    unset vault_token
    log_success "Vault credentials loaded"
}

# ── Workspace bootstrap ───────────────────────────────────────────────────────
bootstrap_workspace() {
    log_info "Starting workspace bootstrap via Ansible..."
    ANSIBLE_CONFIG="/usr/local/lib/zzaia/ansible/ansible.cfg" \
        ansible-playbook /usr/local/lib/zzaia/ansible/site.yml \
        --skip-tags system \
        -e "install_prefix=${INSTALL_PREFIX}" \
        -e "workspace_name=${WORKSPACE_NAME}" \
        -e "gpu_enabled=${GPU_ENABLED:-false}" \
        -e "node_enabled=${NODE_ENABLED:-false}" \
        -e "node_frontend_enabled=${NODE_FRONTEND_ENABLED:-false}" \
        -e "java_enabled=${JAVA_ENABLED:-false}" \
        -e "rust_enabled=${RUST_ENABLED:-false}" \
        -e "lua_enabled=${LUA_ENABLED:-false}" \
        -e "cpp_enabled=${CPP_ENABLED:-false}" \
        -e "clojure_enabled=${CLOJURE_ENABLED:-false}" \
        -e "go_enabled=${GO_ENABLED:-false}" \
        -e "kotlin_enabled=${KOTLIN_ENABLED:-false}" \
        -e "ruby_enabled=${RUBY_ENABLED:-false}" \
        -e "php_enabled=${PHP_ENABLED:-false}" \
        -e "swift_enabled=${SWIFT_ENABLED:-false}" \
        2>&1

    log_success "Workspace bootstrap complete"
}

# ── Configure git-sidecar SSH routing ────────────────────────────────────────
setup_git_sidecar() {
    if [ -z "${GIT_SIDECAR_AGENT_KEY:-}" ]; then
        log_warn "GIT_SIDECAR_AGENT_KEY not available — skipping git-sidecar SSH setup"
        return 0
    fi

    GIT_SIDECAR_AGENT_KEY="$GIT_SIDECAR_AGENT_KEY" \
    su -s /bin/bash user -c '
        mkdir -p /home/user/.ssh
        printf "%s\n" "$GIT_SIDECAR_AGENT_KEY" > /home/user/.ssh/id_rsa_git_sidecar
        chmod 600 /home/user/.ssh/id_rsa_git_sidecar

        grep -qF "Host git-sidecar" /home/user/.ssh/config 2>/dev/null || cat >> /home/user/.ssh/config << EOF
Host git-sidecar
  HostName git-sidecar
  Port 2223
  User git
  IdentityFile ~/.ssh/id_rsa_git_sidecar
  StrictHostKeyChecking accept-new
  IdentitiesOnly yes
EOF
        chmod 600 /home/user/.ssh/config

        # Reset git-sidecar insteadOf entries clean on each start (prevents duplicates on volume persistence)
        git config --global --remove-section "url.git@git-sidecar:github/" 2>/dev/null || true
        git config --global --remove-section "url.git@git-sidecar:ado/" 2>/dev/null || true
        git config --global --add "url.git@git-sidecar:github/.insteadOf" "https://github.com/"
        git config --global --add "url.git@git-sidecar:github/.insteadOf" "git@github.com:"
        git config --global --add "url.git@git-sidecar:ado/.insteadOf" "https://dev.azure.com/"
        git config --global --add "url.git@git-sidecar:ado/.insteadOf" "git@ssh.dev.azure.com:v3/"
    '

    # Add org-specific ADO insteadOf when AZURE_DEVOPS_ORGANIZATION is known (handles user@host URL format)
    if [ -n "${AZURE_DEVOPS_ORGANIZATION:-}" ]; then
        ADO_ORG="${AZURE_DEVOPS_ORGANIZATION}" \
        su -s /bin/bash user -c '
            git config --global --add "url.git@git-sidecar:ado/.insteadOf" "https://${ADO_ORG}@dev.azure.com/" 2>/dev/null || true
        '
    fi

    unset GIT_SIDECAR_AGENT_KEY
    log_success "Git-sidecar SSH routing configured"
}

# ── Export AI proxy env vars to login shells ──────────────────────────────────
# Writes proxy-only values (no real secrets) to ~/.profile so all login shells
# (SSH, VS Code terminal, Jupyter) get the correct ANTHROPIC_BASE_URL for ml-server.
setup_profile_env() {
    local begin_marker="# BEGIN ZZAIA AI PROXY"
    local end_marker="# END ZZAIA AI PROXY"
    local anthropic_base="${ANTHROPIC_BASE_URL:-http://ml-server:8787}"
    local anthropic_key="${ANTHROPIC_API_KEY:-}"
    local openai_base="${OPENAI_BASE_URL:-http://ml-server:8787}"
    local openai_key="${OPENAI_API_KEY:-proxy-handled}"
    local gemini_base="${GOOGLE_GEMINI_BASE_URL:-http://ml-server:8787}"
    local gemini_key="${GEMINI_API_KEY:-}"

    # Must run as user — workspace-home volume is not writable by root
    ANTHROPIC_BASE_URL="$anthropic_base" \
    ANTHROPIC_API_KEY="$anthropic_key" \
    OPENAI_BASE_URL="$openai_base" \
    OPENAI_API_KEY="$openai_key" \
    GEMINI_BASE_URL="$gemini_base" \
    GEMINI_API_KEY="$gemini_key" \
    su -s /bin/bash user -c '
        profile_file="/home/user/.profile"
        sed -i "/# BEGIN ZZAIA AI PROXY/,/# END ZZAIA AI PROXY/d" "$profile_file" 2>/dev/null || true
        printf "\n# BEGIN ZZAIA AI PROXY\n"                            >> "$profile_file"
        printf "export ANTHROPIC_BASE_URL=%s\n"   "$ANTHROPIC_BASE_URL" >> "$profile_file"
        printf "export ANTHROPIC_API_KEY=%s\n"    "$ANTHROPIC_API_KEY"  >> "$profile_file"
        printf "export OPENAI_BASE_URL=%s\n"      "$OPENAI_BASE_URL"    >> "$profile_file"
        printf "export OPENAI_API_KEY=%s\n"       "$OPENAI_API_KEY"     >> "$profile_file"
        printf "export GOOGLE_GEMINI_BASE_URL=%s\n" "$GEMINI_BASE_URL"  >> "$profile_file"
        printf "export GEMINI_API_BASE=%s\n"      "$GEMINI_BASE_URL"    >> "$profile_file"
        printf "export GEMINI_API_KEY=%s\n"       "$GEMINI_API_KEY"     >> "$profile_file"
        printf "# END ZZAIA AI PROXY\n"                                >> "$profile_file"
    '

    log_success "AI proxy environment configured in user profile"
}

# ── Configure MCP servers in .mcp.json ───────────────────────────────────────
# Copies agents/claude/.mcp.json (home-seed) as the single source of truth,
# then injects the runtime bifrost key (only value not present in the static file).
setup_mcp_config() {
    local bifrost_key="${BIFROST_WORKSPACE_KEY:-sk-bf-workspace-agent-001}"

    BIFROST_WORKSPACE_KEY="$bifrost_key" su -s /bin/bash user -c '
        cp /opt/zzaia/home-seed/.mcp.json /home/user/.mcp.json
        python3 -c "
import json, os
key = os.environ[\"BIFROST_WORKSPACE_KEY\"]
with open(\"/home/user/.mcp.json\") as f:
    cfg = json.load(f)
cfg[\"mcpServers\"][\"bifrost\"][\"headers\"] = {\"x-api-key\": key}
with open(\"/home/user/.mcp.json\", \"w\") as f:
    json.dump(cfg, f, indent=2)
"
    '

    log_success "MCP server connections configured from home-seed .mcp.json"
}

# ── Mark bootstrap ready ──────────────────────────────────────────────────────
mark_bootstrap_ready() {
    su -s /bin/bash user -c "mkdir -p ${INSTALL_PREFIX}/.bootstrap && touch ${INSTALL_PREFIX}/.bootstrap/tools.ready"
}

# ── Start SSH daemon ──────────────────────────────────────────────────────────
start_sshd() {
    log_info "Starting SSH daemon..."
    exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    log_info "Starting zzaia workspace-server..."
    log_info "Workspace: $WORKSPACE_NAME"

    load_admin_password
    fetch_vault_credentials
    bootstrap_workspace
    setup_git_sidecar
    unset ADMIN_PASSWORD
    setup_profile_env
    setup_mcp_config
    cleanup_secrets
    mark_bootstrap_ready
    start_sshd
}

main "$@"
