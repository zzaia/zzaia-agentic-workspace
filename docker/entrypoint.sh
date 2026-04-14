#!/bin/bash
# entrypoint.sh — Start SSH server and inject authorized key
set -euo pipefail

ssh-keygen -A 2>/dev/null || true

# Docker: inject public key from environment variable
# Kubernetes: authorized_keys mounted directly from Secret — env var is skipped
if [ ! -s /home/zzaia/.ssh/authorized_keys ] && [ -n "${SSH_PUBLIC_KEY:-}" ]; then
    printf '%s\n' "$SSH_PUBLIC_KEY" > /home/zzaia/.ssh/authorized_keys
    chmod 600 /home/zzaia/.ssh/authorized_keys
    chown zzaia:zzaia /home/zzaia/.ssh/authorized_keys
fi

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
