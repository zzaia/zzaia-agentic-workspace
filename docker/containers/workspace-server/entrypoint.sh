#!/bin/bash
# entrypoint.sh — Workspace server bootstrap via Ansible
set -euo pipefail

SCRIPT_DIR="/usr/local/lib/zzaia/scripts"
export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"
export INSTALL_PREFIX="/opt/tools"

source "$SCRIPT_DIR/common.sh"

log_info "Starting zzaia workspace-server..."
log_info "Workspace: $WORKSPACE_NAME"

log_info "Starting workspace bootstrap via Ansible..."
ANSIBLE_CONFIG="/usr/local/lib/zzaia/ansible/ansible.cfg" \
    ansible-playbook /usr/local/lib/zzaia/ansible/site.yml \
    --skip-tags system \
    -e "install_prefix=${INSTALL_PREFIX}" \
    -e "workspace_name=${WORKSPACE_NAME}" \
    -e "gpu_enabled=${GPU_ENABLED:-false}" \
    2>&1

log_success "Workspace bootstrap complete"
su -s /bin/bash user -c "mkdir -p ${INSTALL_PREFIX}/.bootstrap && touch ${INSTALL_PREFIX}/.bootstrap/tools.ready"
log_info "Starting SSH daemon..."
exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
