#!/bin/bash
# common.sh — Shared utilities for git-sidecar
set -euo pipefail

if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_info()    { echo -e "${BLUE}[git-sidecar]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[git-sidecar] WARN:${NC} $*" >&2; }
log_error()   { echo -e "${RED}[git-sidecar] ERROR:${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[git-sidecar] ✓${NC} $*"; }

extract_vault_secret() {
    local response="$1"
    local key="$2"
    printf '%s' "$response" | jq -r ".data.data.${key} // empty" 2>/dev/null || echo ""
}
