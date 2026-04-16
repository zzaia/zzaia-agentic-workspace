#!/bin/bash
# entrypoint.sh — SSH key init, code-server, SSH server
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

# ── Warn if /secrets is not a real mount ──────────────────────────────────────
mountpoint -q /secrets 2>/dev/null \
    || echo "WARNING: /secrets is not mounted — SSH key will not persist across restarts" >&2

# ── Persist SSH public key on first start ─────────────────────────────────────
if [ ! -f "$SECRETS_FILE" ]; then
    printf 'SSH_PUBLIC_KEY=%s\n' "${SSH_PUBLIC_KEY:-}" > "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
fi

# ── SSH authorized key ────────────────────────────────────────────────────────
_SSH_KEY="${SSH_PUBLIC_KEY:-}"
if [ -z "$_SSH_KEY" ]; then
    _SSH_KEY=$(grep -m1 '^SSH_PUBLIC_KEY=' "$SECRETS_FILE" 2>/dev/null | cut -d= -f2- || true)
fi
if [ ! -s /home/zzaia/.ssh/authorized_keys ] && [ -n "$_SSH_KEY" ]; then
    printf '%s\n' "$_SSH_KEY" > /home/zzaia/.ssh/authorized_keys
    chmod 600 /home/zzaia/.ssh/authorized_keys
    chown zzaia:zzaia /home/zzaia/.ssh/authorized_keys
fi

# ── Start code-server ─────────────────────────────────────────────────────────
su -s /bin/bash zzaia -c "
    export PATH=/home/zzaia/.local/share/mise/shims:/home/zzaia/.local/bin:\$PATH
    export BROWSER=/usr/local/bin/browser-print
    code-server --bind-addr 0.0.0.0:8080 --auth none \
        /home/zzaia/zzaia-main.code-workspace >> /tmp/code-server.log 2>&1 &
"

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
