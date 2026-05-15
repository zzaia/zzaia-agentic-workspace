#!/bin/bash
# setup-tools.sh — Delegates to runtime-install.sh for user-space tool installation
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

main() {
    log_info "Delegating to runtime-install.sh (runs as user)..."
    su -s /bin/bash user -c "bash /usr/local/lib/zzaia/scripts/runtime-install.sh ${*}"
    log_success "Runtime tool installation complete"
}

main "$@"
