#!/bin/bash
# build-install.sh — System-level tool installation (Dockerfile build time, root)
# Installs: apt packages, Docker CLI, VS Code CLI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities and system packages module
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=packages/system.sh
source "$SCRIPT_DIR/packages/system.sh"

main() {
    log_info "Starting Docker build-time system installation..."

    system::install_apt_packages
    system::install_docker_cli
    system::install_vscode_cli

    log_success "Build-time system installation complete"
}

main "$@"
