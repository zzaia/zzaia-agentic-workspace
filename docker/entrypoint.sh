#!/bin/bash
# entrypoint.sh — Secrets init, code-server, SSH server
set -euo pipefail

SECRETS_FILE=/secrets/.env

ssh-keygen -A 2>/dev/null || true

# ── Docker socket group ───────────────────────────────────────────────────────
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    groupadd -f -g "$DOCKER_GID" docker 2>/dev/null || true
    usermod -aG docker zzaia 2>/dev/null || true
fi

# ── SSH authorized key ────────────────────────────────────────────────────────
if [ ! -s /home/zzaia/.ssh/authorized_keys ] && [ -n "${SSH_PUBLIC_KEY:-}" ]; then
    printf '%s\n' "$SSH_PUBLIC_KEY" > /home/zzaia/.ssh/authorized_keys
    chmod 600 /home/zzaia/.ssh/authorized_keys
    chown zzaia:zzaia /home/zzaia/.ssh/authorized_keys
fi

# ── Secrets — write on first start, reload on restart ────────────────────────
mkdir -p /secrets
if [ ! -f "$SECRETS_FILE" ]; then
    cat > "$SECRETS_FILE" <<EOF
TAVILY_API_KEY=${TAVILY_API_KEY:-}
ADO_MCP_AUTH_TOKEN=${ADO_MCP_AUTH_TOKEN:-}
AZURE_DEVOPS_ORGANIZATION=${AZURE_DEVOPS_ORGANIZATION:-}
POSTMAN_API_KEY=${POSTMAN_API_KEY:-}
NEW_RELIC_API_KEY=${NEW_RELIC_API_KEY:-}
EOF
    chmod 600 "$SECRETS_FILE"
fi

# Copy to zzaia home so .bashrc sources it in terminals and SSH sessions
cp "$SECRETS_FILE" /home/zzaia/.env
chown zzaia:zzaia /home/zzaia/.env
chmod 600 /home/zzaia/.env

# ── Start code-server (extension host inherits all secrets) ───────────────────
su -s /bin/bash zzaia -c "
    set -a; source /home/zzaia/.env; set +a
    export PATH=/home/zzaia/.local/share/mise/shims:/home/zzaia/.local/bin:\$PATH
    export BROWSER=/usr/local/bin/browser-print
    code-server --bind-addr 0.0.0.0:8080 --auth none \
        /home/zzaia/zzaia-main.code-workspace >> /tmp/code-server.log 2>&1 &
"

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
