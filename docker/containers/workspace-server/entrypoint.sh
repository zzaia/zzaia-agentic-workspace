#!/bin/bash
# entrypoint.sh — Workspace server bootstrap via Ansible
set -euo pipefail

SCRIPT_DIR="/usr/local/lib/zzaia/scripts"
export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"
export INSTALL_PREFIX="/opt/tools"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# ── Load admin password for Ansible ──────────────────────────────────────────
# ADMIN_PASSWORD is projected into the pod environment by External Secrets Operator
# (Bitwarden Secrets Manager → ESO → Kubernetes Secret → envFrom). Fall back to the legacy Docker
# secret file for docker-compose back-compat. Exported only during bootstrap_workspace
# (Ansible run), then unset before sshd exec, so agents connecting via SSH cannot see
# it in /proc/1/environ (sshd won't have it).
load_admin_password() {
    if [ -n "${ADMIN_PASSWORD:-}" ]; then
        return 0
    fi
    # cap_drop:ALL removes DAC_OVERRIDE — must read as uid 1000 (file owner), not root.
    # DAC_OVERRIDE was re-added to cap_add for apt/dpkg support, but we still read as uid 1000 for defense-in-depth.
    local pw
    pw=$(runuser -u user -- cat /run/secrets/admin_password 2>/dev/null || echo "")
    [ -n "$pw" ] && export ADMIN_PASSWORD="$pw" || log_warn "ADMIN_PASSWORD not set — sudo will be passwordless"
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
        -e "opencode_enabled=${OPENCODE_ENABLED:-false}" \
        -e "codex_enabled=${CODEX_ENABLED:-false}" \
        -e "gemini_enabled=${GEMINI_ENABLED:-false}" \
        -e "copilot_enabled=${COPILOT_ENABLED:-false}" \
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

    # Secrets (GIT_SIDECAR_AGENT_KEY, AZURE_DEVOPS_ORGANIZATION, ADMIN_PASSWORD, …) are
    # projected into the pod environment by External Secrets Operator (Bitwarden Secrets Manager →
    # Kubernetes Secret → envFrom); the consumers below read them directly from the env.
    load_admin_password
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
