#!/bin/bash
set -euo pipefail

# ── Logging ───────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    _G='\033[0;32m'
    _Y='\033[1;33m'
    _B='\033[0;34m'
    _R='\033[0;31m'
    _N='\033[0m'
else
    _G=''
    _Y=''
    _B=''
    _R=''
    _N=''
fi

log_info()    { echo -e "${_B}[mcp-signoz]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-signoz] WARN:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-signoz] ✓${_N} $*"; }

# ── Validate secrets ──────────────────────────────────────────────────────────
validate_secrets() {
    local key_file="/signoz-data/mcp-api-key"
    local attempts=0
    local max_attempts=40  # 120s total

    while [ ! -s "$key_file" ] && [ $attempts -lt $max_attempts ]; do
        log_info "Waiting for SigNoz API key ($((attempts * 3))s)..."
        sleep 3
        attempts=$((attempts + 1))
    done

    if [ ! -s "$key_file" ]; then
        log_warn "SigNoz API key not provisioned after timeout - mcp-signoz idle."
        trap 'exit 0' TERM INT
        while :; do sleep 3600 & wait $!; done
    fi

    SIGNOZ_API_KEY=$(cat "$key_file")
    export SIGNOZ_API_KEY
}

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    log_info "Starting SigNoz MCP server..."
    export SIGNOZ_URL="${SIGNOZ_URL:-http://signoz-server:8080}"
    export SIGNOZ_API_KEY="${SIGNOZ_API_KEY}"
    exec supergateway --port 3009 --outputTransport streamableHttp --stateful --stdio "signoz-mcp-server"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    validate_secrets
    start_server
}

main "$@"
