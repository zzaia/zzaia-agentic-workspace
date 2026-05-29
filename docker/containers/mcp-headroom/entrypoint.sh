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

log_info()    { echo -e "${_B}[mcp-headroom]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-headroom] WARN:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-headroom] ✓${_N} $*"; }

# ── Start server ──────────────────────────────────────────────────────────────
start_server() {
    log_info "Starting Headroom MCP server..."
    exec supergateway --port 3008 --outputTransport streamableHttp --stateful --stdio "headroom mcp serve --proxy-url http://ml-server:8787"
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    start_server
}

main "$@"
