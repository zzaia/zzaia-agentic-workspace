#!/bin/bash
# packages/vscode.sh — VS Code extension installation

set -euo pipefail

# ── Install individual VS Code extension with retries ────────────────────────
_vscode_install_extension() {
    local vscode_cli="$1"
    local ext_dir="$2"
    local ext="$3"
    local attempt=1 max=5 delay=10

    while [ "$attempt" -le "$max" ]; do
        local out
        out=$("$vscode_cli" --extensions-dir "$ext_dir" --install-extension "$ext" --target linux-x64 2>&1)
        if echo "$out" | grep -qiE "successfully installed|already installed"; then
            echo "$out" | grep -v "already installed" || true
            return 0
        fi
        log_warn "extension $ext attempt $attempt/$max failed; retrying in ${delay}s..."
        sleep "$delay"
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
    log_warn "extension $ext could not be installed after $max attempts; continuing"
}

# ── VS Code extensions ────────────────────────────────────────────────────────
vscode::install_extensions() {
    log_info "Installing VS Code extensions..."

    local vscode_cli
    vscode_cli=$(find "$HOME/.vscode" -name code-server -type f 2>/dev/null | head -1)

    if [ -z "$vscode_cli" ]; then
        log_info "code-server not found; skipping extension installation for now"
        return 0
    fi

    # Sentinel includes CLI version so it's invalidated when the image is rebuilt
    local ext_sentinel="$HOME/.vscode-server/.extensions-installed"
    local cli_ver
    cli_ver=$("$vscode_cli" --version 2>/dev/null | head -1 || echo "unknown")

    if [ -f "$ext_sentinel" ] && [ "$(cat "$ext_sentinel")" = "$cli_ver" ]; then
        log_info "VS Code extensions already installed (version match)"
        return 0
    fi

    local ext_dir="$HOME/.vscode-server/extensions"
    mkdir -p "$ext_dir"

    local ext_list_file="/usr/local/bin/vscode-extensions.txt"
    if [ ! -f "$ext_list_file" ]; then
        log_warn "vscode-extensions.txt not found at $ext_list_file; skipping extension installation"
        return 0
    fi

    while IFS= read -r ext || [ -n "$ext" ]; do
        [ -z "$ext" ] && continue
        _vscode_install_extension "$vscode_cli" "$ext_dir" "$ext"
    done < "$ext_list_file"

    echo "$cli_ver" > "$ext_sentinel" || true
    log_success "VS Code extensions installation complete"
}

# ── Verify VS Code (optional, may not be available at install time) ──────────
vscode::verify() {
    # VS Code server is optional at install time — it may be pulled on first connection
    return 0
}
