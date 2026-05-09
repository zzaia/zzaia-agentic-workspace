#!/bin/bash
# setup-user.sh — User account setup, home initialization, SSH keys
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ── Initialize home volume with proper ownership ──────────────────────────────
setup_user_home() {
    log_info "Initializing user home volume..."
    # Home volume may be initialized from image as user:user 700 (default home umask).
    # Root without DAC_READ_SEARCH cannot traverse a 700 dir it doesn't own, so the
    # chown of workspace-repos (mounted inside home) would fail silently.
    # FOWNER capability allows root to chmod a file it doesn't own — open traversal first.
    chmod 755 /home/user 2>/dev/null || true
    # Now root can traverse /home/user to reach the workspace volume mount point.
    chown user:user /home/user /home/user/workspace 2>/dev/null || true
}

# ── Seed home directory from image template ───────────────────────────────────
seed_home() {
    local home_seed_marker="/home/user/.bootstrap/home.seeded"
    local home_seed_dir="/opt/zzaia/home-seed"

    if [ ! -f "$home_seed_marker" ] && [ -d "$home_seed_dir" ]; then
        log_info "Seeding home directory from template..."

        # /home/user is owned by user:user — run extraction as user to avoid
        # DAC_OVERRIDE requirement (root drops that cap in this container).
        tar -C "$home_seed_dir" -cf - . \
            | su -s /bin/bash user -c "tar -C /home/user -xf - --skip-old-files"

        su -s /bin/bash user -c "
            mkdir -p /home/user/.ssh /home/user/workspace/host \
                     /home/user/.local/share/vscode-server /home/user/.bootstrap
            chmod 700 /home/user/.ssh
            touch /home/user/.bootstrap/home.seeded
        "

        log_success "Home directory seeded"
    fi
}

# ── SSH port runtime override ─────────────────────────────────────────────────
configure_ssh_port() {
    local port="${SSH_PORT:-}"
    [ -z "$port" ] && return 0
    log_info "Configuring SSH port: $port"
    sed -i "s/^Port .*/Port ${port}/" /etc/ssh/sshd_config.d/workspace.conf
    echo "${port}" > /etc/ssh-port
    log_success "SSH port set to $port"
}

# ── SSH host key persistence ──────────────────────────────────────────────────
setup_ssh_host_keys() {
    log_info "Setting up SSH host keys..."
    
    ensure_dir "/run/sshd"
    ensure_dir "/secrets" "root:root" "700"
    
    if compgen -G "/secrets/ssh_host_*" > /dev/null 2>&1; then
        log_info "Restoring SSH keys from secrets volume"
        cp /secrets/ssh_host_* /etc/ssh/
        chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
        chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true
    else
        log_info "Generating new SSH host keys..."
        ssh-keygen -A
        cp /etc/ssh/ssh_host_* /secrets/ 2>/dev/null || true
        chmod 600 /secrets/ssh_host_*_key 2>/dev/null || true
        chmod 644 /secrets/ssh_host_*_key.pub 2>/dev/null || true
    fi
    
    log_success "SSH host keys ready"
}

# ── Docker socket access ──────────────────────────────────────────────────────
setup_docker_socket() {
    if [ -S /var/run/docker.sock ]; then
        log_info "Configuring Docker socket access..."
        local docker_gid
        docker_gid=$(stat -c '%g' /var/run/docker.sock)
        groupadd -f -g "$docker_gid" docker 2>/dev/null || true
        usermod -aG docker user 2>/dev/null || true
        log_success "Docker socket configured"
    fi
}

# ── Sudo configuration ────────────────────────────────────────────────────────
setup_sudo() {
    log_info "Configuring passwordless sudo..."
    rm -f /etc/sudoers.d/user-admin
    echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user-admin
    chmod 440 /etc/sudoers.d/user-admin
    
    if [ -n "${ADMIN_PASSWORD:-}" ]; then
        echo "user:${ADMIN_PASSWORD}" | chpasswd
    fi
    
    log_success "Sudo configured"
}

# ── Apt sandbox for container installs ────────────────────────────────────────
setup_apt_sandbox() {
    log_info "Configuring Apt sandbox..."
    # Remove stale partial files and reset ownership/permissions.
    # In rootless Docker contexts, root and _apt may not be able to clean up
    # each other's partial files, causing repeated EPERM failures.
    find /var/cache/apt/archives/partial /var/lib/apt/lists/partial \
        -maxdepth 1 -type f -delete 2>/dev/null || true
    chown root:root \
        /var/cache/apt/archives/partial \
        /var/lib/apt/lists/partial 2>/dev/null || true
    chmod 755 /var/cache/apt/archives/partial /var/lib/apt/lists/partial 2>/dev/null || true
    echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/99sandbox-user
    chmod 644 /etc/apt/apt.conf.d/99sandbox-user
    log_success "Apt sandbox configured"
}

# ── SSH authorized keys from SSH_PUBLIC_KEY ──────────────────────────────────
setup_ssh_auth() {
    log_info "Setting up SSH authorized keys..."
    
    # Persist public key on first start
    if [ ! -f "$SECRETS_FILE" ]; then
        local key_to_write="${SSH_PUBLIC_KEY:-}"
        if [[ "$key_to_write" != ssh-* ]] && [[ "$key_to_write" != ecdsa-* ]] && [[ "$key_to_write" != sk-* ]]; then
            log_warn "SSH_PUBLIC_KEY is not valid (must start with ssh-*, ecdsa-*, or sk-*)"
            key_to_write=""
        fi
        if [ -n "$key_to_write" ]; then
            ensure_dir "/secrets" "root:root" "700"
            printf 'SSH_PUBLIC_KEY=%s\n' "$key_to_write" > "$SECRETS_FILE"
            chmod 600 "$SECRETS_FILE"
        fi
    fi
    
    # Load key from environment or secrets file
    local ssh_key="${SSH_PUBLIC_KEY:-}"
    if [ -z "$ssh_key" ]; then
        ssh_key=$(grep -m1 '^SSH_PUBLIC_KEY=' "$SECRETS_FILE" 2>/dev/null \
            | sed 's/^SSH_PUBLIC_KEY=//;s/^"//;s/"$//' || true)
    fi
    
    if [ -n "$ssh_key" ]; then
        printf '%s\n' "$ssh_key" \
            | su -s /bin/bash user -c "cat > /home/user/.ssh/authorized_keys && chmod 600 /home/user/.ssh/authorized_keys"
        log_success "SSH authorized keys set"
    fi
}

# ── Bashrc mise activation ────────────────────────────────────────────────────
setup_bashrc() {
    log_info "Ensuring bashrc has mise activation..."
    su -s /bin/bash user -c "
        grep -qF 'mise activate bash' /home/user/.bashrc 2>/dev/null \
            || echo 'eval \"\$(mise activate bash)\"' >> /home/user/.bashrc
    "
    log_success "Bashrc configured"
}

# ── Mise trust ────────────────────────────────────────────────────────────────
setup_mise_trust() {
    log_info "Trusting mise.toml..."
    mise trust /home/user/mise.toml 2>/dev/null || true
    su -s /bin/bash user -c "mise trust /home/user/mise.toml 2>/dev/null || true"
    log_success "Mise trust configured"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    setup_user_home
    seed_home
    configure_ssh_port
    setup_ssh_host_keys
    setup_docker_socket
    setup_sudo
    setup_apt_sandbox
    setup_ssh_auth
    setup_bashrc
    setup_mise_trust
}

main "$@"
