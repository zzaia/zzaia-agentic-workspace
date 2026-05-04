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
    usermod -aG docker user 2>/dev/null || true
fi

# ── Sudo access — enabled when ADMIN_PASSWORD is set ─────────────────────────
if [ -n "${ADMIN_PASSWORD:-}" ]; then
    echo "user:${ADMIN_PASSWORD}" | chpasswd
    rm -f /etc/sudoers.d/user-admin
    echo "user ALL=(ALL) ALL" > /etc/sudoers.d/user-admin
    chmod 440 /etc/sudoers.d/user-admin
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
        printf 'SSH_PUBLIC_KEY=%s\n' "$_KEY_TO_WRITE" > "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
    fi
    unset _KEY_TO_WRITE
fi

# ── SSH authorized key ────────────────────────────────────────────────────────
_SSH_KEY="${SSH_PUBLIC_KEY:-}"
unset SSH_PUBLIC_KEY
if [ -z "$_SSH_KEY" ]; then
    _SSH_KEY=$(grep -m1 '^SSH_PUBLIC_KEY=' "$SECRETS_FILE" 2>/dev/null \
        | sed 's/^SSH_PUBLIC_KEY=//;s/^"//;s/"$//' || true)
fi
if [ -n "$_SSH_KEY" ]; then
    printf '%s\n' "$_SSH_KEY" \
        | su -s /bin/bash user -c "cat > /home/user/.ssh/authorized_keys && chmod 600 /home/user/.ssh/authorized_keys"
fi

# ── mise trust — ensure mise.toml is trusted (volume may shadow image state) ──
su -s /bin/bash user -c "mise trust /home/user/mise.toml 2>/dev/null || true"

# ── WORKSPACE_NAME templating — idempotent, runs on every start ───────────────
su -s /bin/bash user -c "
    find /home/user/.vscode-server /home/user/workspace \
        \( -name '*.json' -o -name '*.code-workspace' \) 2>/dev/null \
        | xargs sed -i 's/{{WORKSPACE_NAME}}/${WORKSPACE_NAME}/g' 2>/dev/null || true
    [ -f /home/user/workspace/zzaia.code-workspace ] \
        && mv /home/user/workspace/zzaia.code-workspace \
              /home/user/workspace/${WORKSPACE_NAME}.code-workspace || true
"

# ── GitHub auth ───────────────────────────────────────────────────────────────
if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
    su -s /bin/bash user -c "
        export PATH=/home/user/.local/share/mise/shims:/home/user/.local/bin:\$PATH
        echo \"\$GITHUB_PERSONAL_ACCESS_TOKEN\" | gh auth login --with-token 2>/dev/null || true
        gh extension upgrade --all 2>/dev/null || true
    "
fi

# ── Git credentials — Azure DevOps ───────────────────────────────────────────
if [ -n "${ADO_MCP_AUTH_TOKEN:-}" ]; then
    ADO_MCP_AUTH_TOKEN="$ADO_MCP_AUTH_TOKEN" \
    su -s /bin/bash user -c "
        git config --global credential.https://dev.azure.com.helper store
        grep -qF \"dev.azure.com\" /home/user/.git-credentials 2>/dev/null \
            || printf \"https://anything:%s@dev.azure.com\n\" \"\$ADO_MCP_AUTH_TOKEN\" \
               >> /home/user/.git-credentials
        chmod 600 /home/user/.git-credentials
    "
fi

unset GITHUB_PERSONAL_ACCESS_TOKEN
unset ADO_MCP_AUTH_TOKEN

# ── Aspire MCP — single shared instance for all agents ───────────────────
su -s /bin/bash user -c "
    export PATH=/home/user/.local/share/mise/shims:/home/user/.local/bin:\$PATH
    npx -y supergateway@latest --port 3007 --stdio 'aspire mcp start --dashboard-endpoint http://aspire-dashboard:18888' \
        >> /home/user/.local/share/vscode-server/aspire-mcp.log 2>&1 &
"

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
