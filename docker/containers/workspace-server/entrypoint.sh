#!/bin/bash
# entrypoint.sh — Workspace server bootstrap via Ansible
set -euo pipefail

SCRIPT_DIR="/usr/local/lib/zzaia/scripts"
export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"
export INSTALL_PREFIX="/opt/tools"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

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

    fetch_vault_credentials
    bootstrap_workspace
    setup_git_sidecar
    cleanup_secrets
    mark_bootstrap_ready
    start_sshd
}

main "$@"
