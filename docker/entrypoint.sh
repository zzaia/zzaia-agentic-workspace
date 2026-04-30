#!/bin/bash
# entrypoint.sh — SSH key init, vscode-server (code serve-web), SSH server
set -euo pipefail

WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

# /secrets stays root-owned so root can always read/write it
SECRETS_FILE=/secrets/.env
mkdir -p /secrets
chmod 700 /secrets 2>/dev/null || true

mkdir -p /run/sshd

# ── SSH host keys — persist in secrets volume to avoid client fingerprint changes
if compgen -G "/secrets/ssh_host_*" > /dev/null 2>&1; then
    cp /secrets/ssh_host_* /etc/ssh/
    chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
    chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true
else
    ssh-keygen -A
    cp /etc/ssh/ssh_host_* /secrets/ 2>/dev/null || true
    chmod 600 /secrets/ssh_host_*_key 2>/dev/null || true
    chmod 644 /secrets/ssh_host_*_key.pub 2>/dev/null || true
fi

# ── Docker socket group ───────────────────────────────────────────────────────
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    groupadd -f -g "$DOCKER_GID" docker 2>/dev/null || true
    usermod -aG docker ${WORKSPACE_NAME} 2>/dev/null || true
fi

# ── Sudo access — enabled when ADMIN_PASSWORD is set ─────────────────────────
if [ -n "${ADMIN_PASSWORD:-}" ]; then
    echo "${WORKSPACE_NAME}:${ADMIN_PASSWORD}" | chpasswd
    chmod u+w /etc/sudoers.d/${WORKSPACE_NAME}-admin 2>/dev/null || true
    echo "${WORKSPACE_NAME} ALL=(ALL) ALL" > /etc/sudoers.d/${WORKSPACE_NAME}-admin
    chmod 440 /etc/sudoers.d/${WORKSPACE_NAME}-admin
fi
unset ADMIN_PASSWORD

# ── Persist SSH public key on first start ─────────────────────────────────────
if [ ! -f "$SECRETS_FILE" ]; then
    _KEY_TO_WRITE="${SSH_PUBLIC_KEY:-}"
    if [[ "$_KEY_TO_WRITE" != ssh-* ]] && [[ "$_KEY_TO_WRITE" != ecdsa-* ]] && [[ "$_KEY_TO_WRITE" != sk-* ]]; then
        echo "WARNING: SSH_PUBLIC_KEY is not a valid public key (must start with ssh-*, ecdsa-*, or sk-*; keys with an options prefix are not supported) — skipping." >&2
        _KEY_TO_WRITE=""
    fi
    if [ -n "$_KEY_TO_WRITE" ]; then
        # Write as root — /secrets is root-owned so root can write here
        printf 'SSH_PUBLIC_KEY=%s\n' "$_KEY_TO_WRITE" > "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
    fi
    unset _KEY_TO_WRITE
fi

# ── SSH authorized key — write as WORKSPACE_NAME (.ssh is WORKSPACE_NAME-owned 700) ─────────────
_SSH_KEY="${SSH_PUBLIC_KEY:-}"
unset SSH_PUBLIC_KEY
if [ -z "$_SSH_KEY" ]; then
    _SSH_KEY=$(grep -m1 '^SSH_PUBLIC_KEY=' "$SECRETS_FILE" 2>/dev/null \
        | sed 's/^SSH_PUBLIC_KEY=//;s/^"//;s/"$//' || true)
fi
if [ -n "$_SSH_KEY" ]; then
    printf '%s\n' "$_SSH_KEY" \
        | su -s /bin/bash ${WORKSPACE_NAME} -c "cat > /home/${WORKSPACE_NAME}/.ssh/authorized_keys && chmod 600 /home/${WORKSPACE_NAME}/.ssh/authorized_keys"
fi

# ── GitHub auth ───────────────────────────────────────────────────────────────
if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
    su -s /bin/bash ${WORKSPACE_NAME} -c "
        export PATH=/home/${WORKSPACE_NAME}/.local/share/mise/shims:/home/${WORKSPACE_NAME}/.local/bin:\$PATH
        echo \"\$GITHUB_PERSONAL_ACCESS_TOKEN\" | gh auth login --with-token 2>/dev/null || true
        gh extension upgrade --all 2>/dev/null || true
    "
fi

# ── Git credentials — Azure DevOps (shared across all agent HOMs) ────────────
if [ -n "${ADO_MCP_AUTH_TOKEN:-}" ]; then
    ADO_MCP_AUTH_TOKEN="$ADO_MCP_AUTH_TOKEN" \
    su -s /bin/bash ${WORKSPACE_NAME} -c "
        git config --global credential.https://dev.azure.com.helper store
        grep -qF \"dev.azure.com\" /home/${WORKSPACE_NAME}/.git-credentials 2>/dev/null \
            || printf \"https://anything:%s@dev.azure.com\n\" \"\$ADO_MCP_AUTH_TOKEN\" \
               >> /home/${WORKSPACE_NAME}/.git-credentials
        chmod 600 /home/${WORKSPACE_NAME}/.git-credentials
    "
fi

unset GITHUB_PERSONAL_ACCESS_TOKEN
unset ADO_MCP_AUTH_TOKEN

# ── Aspire MCP — single shared instance for all agents ───────────────────────
su -s /bin/bash ${WORKSPACE_NAME} -c "
    export PATH=/home/${WORKSPACE_NAME}/.local/share/mise/shims:/home/${WORKSPACE_NAME}/.local/bin:\$PATH
    npx -y supergateway@latest --port 3007 --stdio 'aspire mcp start --dashboard-endpoint http://aspire-dashboard:18888' \
        >> /home/${WORKSPACE_NAME}/.local/share/vscode-server/aspire-mcp.log 2>&1 &
"

# ── Start VS Code server ──────────────────────────────────────────────────────
su -s /bin/bash ${WORKSPACE_NAME} -c "
    export PATH=/home/${WORKSPACE_NAME}/.local/share/mise/shims:/home/${WORKSPACE_NAME}/.local/bin:\$PATH
    export BROWSER=/usr/local/bin/browser-print
    code serve-web \
        --host 0.0.0.0 \
        --port ${VSCODE_PORT:-8080} \
        --without-connection-token \
        --accept-server-license-terms \
        --server-data-dir /home/${WORKSPACE_NAME}/.vscode-server \
        --default-workspace /home/${WORKSPACE_NAME}/workspace/${WORKSPACE_NAME}.code-workspace \
        >> /home/${WORKSPACE_NAME}/.local/share/vscode-server/serve-web.log 2>&1 &
"

# ── VS Code extensions — install once on first start, persisted in home volume ─
su -s /bin/bash ${WORKSPACE_NAME} -c "
    export PATH=/home/${WORKSPACE_NAME}/.local/share/mise/shims:/home/${WORKSPACE_NAME}/.local/bin:\$PATH
    mise run vscode-extensions >> /home/${WORKSPACE_NAME}/.local/share/vscode-server/extensions-install.log 2>&1 &
"

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
