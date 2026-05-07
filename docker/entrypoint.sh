#!/bin/bash
# entrypoint.sh — SSH key init, vscode-server (code serve-web), SSH server
set -euo pipefail

WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

# Ensure the mounted home volume is usable by the non-root workspace user.
mkdir -p /home/user
chown user:user /home/user 2>/dev/null || true

# ── Home seed — run once on first start (flag file gates subsequent restarts) ─
HOME_SEED_MARKER=/home/user/.bootstrap/home.seeded
if [ ! -f "$HOME_SEED_MARKER" ] && [ -d /opt/zzaia/home-seed ]; then
    # Open up /home/user so root can write regardless of volume ownership
    chmod a+rwx /home/user
    # --skip-old-files: on crash-loop recovery, skip already-extracted files instead of failing.
    # tar restores directory attributes (including /home/user itself), so we re-apply chmod after.
    tar -C /opt/zzaia/home-seed -cf - . | tar -C /home/user -xf - --skip-old-files
    # Re-open after tar restored original dir attributes from the archive
    chmod a+rwx /home/user
    mkdir -p /home/user/.ssh /home/user/workspace/host \
             /home/user/.local/share/vscode-server /home/user/.bootstrap
    chmod 700 /home/user/.ssh
    chmod 755 /home/user
    touch /home/user/.bootstrap/home.seeded
    chown -R user:user /home/user
fi

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

# ── Sudo access — always allow passwordless sudo for bootstrap tasks ─────────
rm -f /etc/sudoers.d/user-admin
echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user-admin
chmod 440 /etc/sudoers.d/user-admin
if [ -n "${ADMIN_PASSWORD:-}" ]; then
    echo "user:${ADMIN_PASSWORD}" | chpasswd
fi
unset ADMIN_PASSWORD

# ── Apt sandbox configuration for containerized runtime installs ─────────────
# Keep downloads under _apt, which owns apt partial cache directories here.
echo 'APT::Sandbox::User "_apt";' > /etc/apt/apt.conf.d/99sandbox-user
chmod 644 /etc/apt/apt.conf.d/99sandbox-user

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

# ── .bashrc — ensure mise activate is present (volume may shadow image state) ─
su -s /bin/bash user -c "
    grep -qF 'mise activate bash' /home/user/.bashrc 2>/dev/null \\
        || echo 'eval \"\$(mise activate bash)\"' >> /home/user/.bashrc
"

# ── mise trust — ensure mise.toml is trusted (volume may shadow image state) ──
mise trust /home/user/mise.toml 2>/dev/null || true
su -s /bin/bash user -c "mise trust /home/user/mise.toml 2>/dev/null || true"

# ── Runtime mise bootstrap — block startup until tools are ready ──────────────
BOOTSTRAP_DIR=/home/user/.bootstrap
BOOTSTRAP_MARKER=${BOOTSTRAP_DIR}/mise.ready
mkdir -p "$BOOTSTRAP_DIR"
chown -R user:user "$BOOTSTRAP_DIR"

if [ ! -f "$BOOTSTRAP_MARKER" ]; then
    echo "[bootstrap] installing runtime tools and extensions via mise..."

    su -s /bin/bash user -c "
        set -e
        if [ ! -x /home/user/miniforge3/bin/conda ]; then
            curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
                -o /tmp/miniforge.sh
            bash /tmp/miniforge.sh -b -p /home/user/miniforge3
            rm /tmp/miniforge.sh
            /home/user/miniforge3/bin/conda init bash
        fi
        export PATH=/home/user/miniforge3/bin:/home/user/.local/share/mise/shims:/home/user/.local/bin:/home/user/.dotnet/tools:\$PATH
        # Allow higher GitHub API limits for mise backends that query GitHub
        [ -n \"${GITHUB_PERSONAL_ACCESS_TOKEN:-}\" ] && export GITHUB_TOKEN=\"${GITHUB_PERSONAL_ACCESS_TOKEN}\"
        [ -n \"${GITHUB_PERSONAL_ACCESS_TOKEN:-}\" ] && export AQUA_GITHUB_TOKEN=\"${GITHUB_PERSONAL_ACCESS_TOKEN}\"
        mise trust /home/user/mise.toml
        mise run install-git || true
        mise run install-azure-cli || true
        mise run install-tectonic || true
        _install_tool() {
            local _tool=\"\$1\" _attempt=1 _max=5 _delay=15
            while [ \"\$_attempt\" -le \"\$_max\" ]; do
                if mise install \"\$_tool\"; then
                    return 0
                fi
                if [ \"\$_attempt\" -ge \"\$_max\" ]; then
                    echo \"[bootstrap] WARN: \$_tool failed after \$_max attempts; continuing.\" >&2
                    return 0
                fi
                echo \"[bootstrap] WARN: \$_tool attempt \$_attempt/\$_max failed; retrying in \${_delay}s...\" >&2
                sleep \"\$_delay\"
                _delay=\$((_delay * 2))
                _attempt=\$((_attempt + 1))
            done
        }
        for _tool in gh tmux node dotnet k6 d2 dapr \
                     \"npm:@anthropic-ai/claude-code\" \"npm:@mermaid-js/mermaid-cli\" \
                     \"npm:@openai/codex\" \"npm:supergateway\" \"npm:@google/gemini-cli\"; do
            _install_tool \"\$_tool\"
        done
        mise run python-packages
        mise run conda-envs
        mise run dotnet-tools
        mise run rtk || true
        mise run claude-plugins || true
        mise run gh-extensions || true
        mise run vscode-extensions || true
    "
    su -s /bin/bash user -c "date -u +\"%Y-%m-%dT%H:%M:%SZ\" > /home/user/.bootstrap/mise.ready"
    echo "[bootstrap] runtime setup complete."
fi

# ── WORKSPACE_NAME templating — idempotent, runs on every start ───────────────
su -s /bin/bash user -c "
    find /home/user /home/user/.vscode-server /home/user/workspace \
        \( -name '*.json' -o -name '*.code-workspace' \) -maxdepth 4 2>/dev/null \
        | xargs sed -i 's/{{WORKSPACE_NAME}}/${WORKSPACE_NAME}/g' 2>/dev/null || true
    [ -f /home/user/zzaia.code-workspace ] \
        && mv /home/user/zzaia.code-workspace \
              /home/user/${WORKSPACE_NAME}.code-workspace 2>/dev/null || true
"

# ── Claude CLI credentials ───────────────────────────────────────────────────
if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
    su -s /bin/bash user -c "
        mkdir -p /home/user/.claude
        printf '{\"claudeAiOAuth\":{\"accessToken\":\"%s\",\"expiresAt\":9999999999,\"refreshToken\":null,\"scopes\":null,\"tokenType\":\"Bearer\"}}\n' \
            \"\$CLAUDE_CODE_OAUTH_TOKEN\" > /home/user/.claude/.credentials.json
        chmod 600 /home/user/.claude/.credentials.json
    "
fi

# ── GitHub auth ───────────────────────────────────────────────────────────────
if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
    su -s /bin/bash user -c "
        export PATH=/home/user/.local/share/mise/shims:/home/user/.local/bin:\$PATH
        echo \"\$GITHUB_PERSONAL_ACCESS_TOKEN\" | gh auth login --with-token 2>/dev/null || true

        gh extension install github/gh-copilot 2>/dev/null || gh extension upgrade github/gh-copilot 2>/dev/null || true
        gh extension upgrade --all 2>/dev/null || true

        git config --global credential.https://github.com.helper store
        grep -qF \"github.com\" /home/user/.git-credentials 2>/dev/null \
            || printf \"https://x-access-token:%s@github.com\\n\" \"\$GITHUB_PERSONAL_ACCESS_TOKEN\" \
               >> /home/user/.git-credentials
        chmod 600 /home/user/.git-credentials
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
    mkdir -p /home/user/.local/share/vscode-server
    export PATH=/home/user/.local/share/mise/shims:/home/user/.local/bin:\$PATH
    npx -y supergateway@latest --port 3007 --stdio 'aspire mcp start --dashboard-endpoint http://vscode-server:17001' \
        >> /home/user/.local/share/vscode-server/aspire-mcp.log 2>&1 &
"

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
