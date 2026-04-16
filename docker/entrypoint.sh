#!/bin/bash
# entrypoint.sh — Secrets init, code-server, SSH server
set -euo pipefail

SECRETS_FILE=/secrets/.env
mkdir -p /secrets

ssh-keygen -A 2>/dev/null || true

# ── Docker socket group ───────────────────────────────────────────────────────
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    groupadd -f -g "$DOCKER_GID" docker 2>/dev/null || true
    usermod -aG docker zzaia 2>/dev/null || true
    id zzaia | grep -q "docker" \
        || echo "WARNING: zzaia not in docker group" >&2
fi

# ── Warn if /secrets is not a real mount (secrets won't persist) ──────────────
mountpoint -q /secrets 2>/dev/null \
    || echo "WARNING: /secrets is not mounted — secrets will not persist across restarts" >&2

# ── Secrets — write on first start, reload on restart ────────────────────────
if [ ! -f "$SECRETS_FILE" ]; then
    cat > "$SECRETS_FILE" <<EOF
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-}
TAVILY_API_KEY=${TAVILY_API_KEY:-}
ADO_MCP_AUTH_TOKEN=${ADO_MCP_AUTH_TOKEN:-}
AZURE_DEVOPS_ORGANIZATION=${AZURE_DEVOPS_ORGANIZATION:-}
POSTMAN_API_KEY=${POSTMAN_API_KEY:-}
NEW_RELIC_API_KEY=${NEW_RELIC_API_KEY:-}
EOF
    chmod 600 "$SECRETS_FILE"
fi

# Copy to zzaia home so .bashrc sources it in terminals and SSH sessions
install -m 600 -o zzaia -g zzaia "$SECRETS_FILE" /home/zzaia/.env

# ── SSH authorized key (sourced from secrets on restart) ─────────────────────
_SSH_KEY="${SSH_PUBLIC_KEY:-}"
if [ -z "$_SSH_KEY" ]; then
    _SSH_KEY=$(grep -m1 '^SSH_PUBLIC_KEY=' "$SECRETS_FILE" 2>/dev/null | cut -d= -f2- || true)
fi
if [ ! -s /home/zzaia/.ssh/authorized_keys ] && [ -n "$_SSH_KEY" ]; then
    printf '%s\n' "$_SSH_KEY" > /home/zzaia/.ssh/authorized_keys
    chmod 600 /home/zzaia/.ssh/authorized_keys
    chown zzaia:zzaia /home/zzaia/.ssh/authorized_keys
fi

# ── Start code-server (extension host inherits all secrets) ───────────────────
# /var/run/docker.sock grants full host Docker access — trusted local dev only
su -s /bin/bash zzaia -c "
    set -a; source /home/zzaia/.env; set +a
    export PATH=/home/zzaia/.local/share/mise/shims:/home/zzaia/.local/bin:\$PATH
    export BROWSER=/usr/local/bin/browser-print
    code-server --bind-addr 0.0.0.0:8080 --auth none \
        /home/zzaia/zzaia-main.code-workspace >> /tmp/code-server.log 2>&1 &
"

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
