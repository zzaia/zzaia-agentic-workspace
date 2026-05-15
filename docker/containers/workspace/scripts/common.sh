#!/bin/bash
# common.sh — Shared utilities and environment
set -euo pipefail

# ── Default values ────────────────────────────────────────────────────────────
WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"
SECRETS_FILE="/secrets/.env"
BOOTSTRAP_DIR="/home/user/.bootstrap"
BOOTSTRAP_MARKER="${BOOTSTRAP_DIR}/tools.ready"

# ── Color output (optional, can be disabled) ──────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# ── Logging functions ─────────────────────────────────────────────────────────
log_info() {
    echo -e "${BLUE}[bootstrap]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[bootstrap] WARN:${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[bootstrap] ERROR:${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[bootstrap] ✓${NC} $*"
}

# ── Retry helper for flaky operations ─────────────────────────────────────────
retry_with_backoff() {
    local max_attempts="${1:-5}"
    local delay="${2:-15}"
    local cmd=("${@:3}")
    local attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if "${cmd[@]}"; then
            return 0
        fi
        
        if [ "$attempt" -ge "$max_attempts" ]; then
            log_warn "${cmd[*]} failed after $max_attempts attempts"
            return 0
        fi
        
        log_warn "${cmd[*]} attempt $attempt/$max_attempts failed; retrying in ${delay}s..."
        sleep "$delay"
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

# ── Ensure directory with proper permissions ─────────────────────────────────
ensure_dir() {
    local dir="$1"
    local owner="${2:-root:root}"
    local perms="${3:-755}"
    
    mkdir -p "$dir"
    chmod "$perms" "$dir" 2>/dev/null || true
    chown "$owner" "$dir" 2>/dev/null || true
}

# ── File cleanup on exit ──────────────────────────────────────────────────────
cleanup_secrets() {
    unset -v BW_SESSION BW_ITEMS DOCKER_REGISTRY DOCKER_USERNAME DOCKER_PASSWORD 2>/dev/null || true
    unset -v SSH_PUBLIC_KEY ADMIN_PASSWORD 2>/dev/null || true
    unset -v GITHUB_PERSONAL_ACCESS_TOKEN ADO_MCP_AUTH_TOKEN 2>/dev/null || true
    unset -v ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY CLAUDE_CODE_OAUTH_TOKEN 2>/dev/null || true
}

trap cleanup_secrets EXIT

export -f log_info log_warn log_error log_success retry_with_backoff ensure_dir cleanup_secrets
