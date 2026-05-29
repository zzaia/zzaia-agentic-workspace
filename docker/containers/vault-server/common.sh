#!/bin/bash
# common.sh — Shared utilities for vault-server
set -euo pipefail

if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    BLUE=''
    RED=''
    NC=''
fi

log_info()    { echo -e "${BLUE}[vault-server]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[vault-server] WARN:${NC} $*" >&2; }
log_error()   { echo -e "${RED}[vault-server] ERROR:${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[vault-server] ✓${NC} $*"; }
