#!/bin/bash
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ── Load tokens ───────────────────────────────────────────────────────────────
load_tokens() {
    if [ ! -f /home/git/.git-proxy/tokens ]; then
        log_error "Tokens file not found"
        exit 1
    fi
    # shellcheck disable=SC1091
    . /home/git/.git-proxy/tokens
}

# ── Parse SSH command ─────────────────────────────────────────────────────────
parse_ssh_command() {
    if [ -z "${SSH_ORIGINAL_COMMAND:-}" ]; then
        log_error "Direct shell access not permitted"
        exit 1
    fi

    cmd=$(printf '%s' "$SSH_ORIGINAL_COMMAND" | sed -E "s/(git-[a-z-]+).*/\1/")
    path=$(printf '%s' "$SSH_ORIGINAL_COMMAND" | sed -E "s/git-[a-z-]+ '?([^']+)'?/\1/")
}

# ── Validate command ──────────────────────────────────────────────────────────
validate_command() {
    case "$cmd" in
        git-upload-pack|git-receive-pack) ;;
        *)
            log_error "Command not allowed: $cmd"
            exit 1
            ;;
    esac
}

# ── Validate path ─────────────────────────────────────────────────────────────
validate_path() {
    case "$path" in
        *[!A-Za-z0-9_./-]*|'')
            log_error "Invalid path: $path"
            exit 1
            ;;
    esac
}

# ── Build upstream URL ────────────────────────────────────────────────────────
build_upstream_url() {
    case "$path" in
        github/*)
            local repo="${path#github/}"
            repo="${repo%.git}"  # strip trailing .git to avoid double suffix
            echo "https://x-access-token:${GITHUB_PAT}@github.com/${repo}.git"
            ;;
        ado/*)
            # Pass through full path — preserves _git/ segment already present in URL rewrites
            local rest="${path#ado/}"
            echo "https://anything:${ADO_TOKEN}@dev.azure.com/${rest}"
            ;;
        *)
            log_error "Unknown path prefix: $path"
            exit 1
            ;;
    esac
}

# ── Serve upload-pack ─────────────────────────────────────────────────────────
serve_upload_pack() {
    local upstream_url="$1"
    _proxy_tmpdir=$(mktemp -d /tmp/git-proxy.XXXXXX)
    trap 'rm -rf "${_proxy_tmpdir:-}"' EXIT

    GIT_TERMINAL_PROMPT=0 \
    git clone --quiet --mirror "$upstream_url" "$_proxy_tmpdir/r.git" 2>/dev/null || {
        log_error "Remote repository not found or access denied"
        exit 128
    }
    git-upload-pack "$_proxy_tmpdir/r.git"
}

# ── Serve receive-pack ────────────────────────────────────────────────────────
serve_receive_pack() {
    local upstream_url="$1"
    _proxy_tmpdir=$(mktemp -d /tmp/git-proxy.XXXXXX)
    trap 'rm -rf "${_proxy_tmpdir:-}"' EXIT

    GIT_TERMINAL_PROMPT=0 \
    git clone --quiet --mirror "$upstream_url" "$_proxy_tmpdir/r.git" 2>/dev/null || {
        git init --bare "$_proxy_tmpdir/r.git" >/dev/null 2>&1
    }
    git-receive-pack "$_proxy_tmpdir/r.git"

    local push_err
    push_err=$(GIT_TERMINAL_PROMPT=0 \
        git -C "$_proxy_tmpdir/r.git" push --quiet --mirror "$upstream_url" 2>&1) || {
        log_error "Upstream push failed: $push_err"
        exit 1
    }
}

# Script-level cleanup dir — persists after function returns so EXIT trap can access it
_proxy_tmpdir=""

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    load_tokens
    parse_ssh_command
    validate_command
    validate_path
    local upstream_url
    upstream_url=$(build_upstream_url)

    case "$cmd" in
        git-upload-pack)  serve_upload_pack "$upstream_url" ;;
        git-receive-pack) serve_receive_pack "$upstream_url" ;;
    esac
}

main "$@"
