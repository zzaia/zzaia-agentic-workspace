#!/bin/bash
# entrypoint.sh — Start code-server, SSH server, and inject authorized key
set -euo pipefail

ssh-keygen -A 2>/dev/null || true

# Match docker group GID to host socket so zzaia can use Docker CLI
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    groupadd -f -g "$DOCKER_GID" docker 2>/dev/null || true
    usermod -aG docker zzaia 2>/dev/null || true
fi

# Docker: inject public key from environment variable
# Kubernetes: authorized_keys mounted directly from Secret — env var is skipped
if [ ! -s /home/zzaia/.ssh/authorized_keys ] && [ -n "${SSH_PUBLIC_KEY:-}" ]; then
    printf '%s\n' "$SSH_PUBLIC_KEY" > /home/zzaia/.ssh/authorized_keys
    chmod 600 /home/zzaia/.ssh/authorized_keys
    chown zzaia:zzaia /home/zzaia/.ssh/authorized_keys
fi

# Start code-server in background as zzaia user
su -s /bin/bash zzaia -c '
    export PATH="/home/zzaia/.local/share/mise/shims:/home/zzaia/.local/bin:$PATH"
    export BROWSER=/usr/local/bin/browser-print
    code-server --bind-addr 0.0.0.0:8080 --auth none \
        /home/zzaia/zzaia-main.code-workspace >> /tmp/code-server.log 2>&1 &
'

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
