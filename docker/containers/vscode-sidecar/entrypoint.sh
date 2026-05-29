#!/usr/bin/env bash
# entrypoint.sh — VS Code Server container entrypoint
# workspace-server handles bootstrap; this only starts VS Code.
set -euo pipefail

export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

USER_RUN=()
VSCODE_CLI=""
SERVER_PID=""

# ── Setup environment ─────────────────────────────────────────────────────────
setup_env() {
    export NVM_DIR="/opt/tools/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
    export PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:$PATH
    export BROWSER=/usr/local/bin/browser-print
    export HOME=/home/user

    USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH" BROWSER="$BROWSER")
}

# ── Verify VS Code CLI ────────────────────────────────────────────────────────
verify_cli() {
    if ! command -v code >/dev/null 2>&1; then
        echo "ERROR: VS Code CLI not found in PATH." >&2
        echo "  workspace-server may not have completed runtime setup yet." >&2
        echo "  Ensure workspace-server container has finished bootstrap." >&2
        exit 1
    fi
}

# ── Setup Claude credentials ──────────────────────────────────────────────────
setup_claude_credentials() {
    if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        local cred_file="/home/user/.claude/.credentials.json"
        if [ -f "$cred_file" ]; then
            local token
            token=$(grep -oP '"accessToken":"\K[^"]+' "$cred_file" 2>/dev/null || true)
            if [ -n "$token" ]; then
                export CLAUDE_CODE_OAUTH_TOKEN="$token"
                USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH" BROWSER="$BROWSER" CLAUDE_CODE_OAUTH_TOKEN="$token")
            fi
        fi
    fi
}

# ── Prepare directories ───────────────────────────────────────────────────────
prepare_directories() {
    "${USER_RUN[@]}" mkdir -p /home/user/.vscode-server/data/Machine /home/user/.vscode-server/extensions
    chown -R user:user /home/user/.vscode-server 2>/dev/null || true

    local machine_settings=/home/user/.vscode-server/data/Machine/settings.json
    if [ ! -f "$machine_settings" ]; then
        "${USER_RUN[@]}" sh -c "cat > '$machine_settings'" <<'EOF'
{
  "python.defaultInterpreterPath": "/opt/tools/miniforge3/bin/python",
  "python.terminal.activateEnvironment": false
}
EOF
    fi
}

# ── Discover VS Code server ───────────────────────────────────────────────────
discover_server() {
    VSCODE_CLI=$(runuser -u user -- find /home/user/.vscode/cli/serve-web -name code-server -type f 2>/dev/null | grep -v '\.staging' | head -1 || true)

    if [ -z "$VSCODE_CLI" ]; then
        echo "VS Code inner binary not found — triggering download via code serve-web..."
        "${USER_RUN[@]}" code serve-web \
            --host 127.0.0.1 \
            --port 19999 \
            --without-connection-token \
            --accept-server-license-terms \
            --server-data-dir /home/user/.vscode-server &
        local download_pid=$!

        local i
        for i in $(seq 1 60); do
            if curl -s http://127.0.0.1:19999 -o /dev/null 2>/dev/null; then
                echo "Port 19999 ready — download triggered."
                break
            fi
            sleep 1
        done

        local cli_discovery_max="${CLI_DISCOVERY_MAX_ATTEMPTS:-600}"
        local cli_discovery_delay="${CLI_DISCOVERY_DELAY_SECONDS:-3}"
        for i in $(seq 1 "$cli_discovery_max"); do
            VSCODE_CLI=$(runuser -u user -- find /home/user/.vscode/cli/serve-web -name code-server -type f 2>/dev/null | grep -v '\.staging' | head -1 || true)
            [ -n "$VSCODE_CLI" ] && break
            sleep "$cli_discovery_delay"
        done

        kill "$download_pid" 2>/dev/null || true
        wait "$download_pid" 2>/dev/null || true
    fi

    if [ -z "$VSCODE_CLI" ]; then
        echo "ERROR: VS Code Server could not be downloaded." >&2
        exit 1
    fi
}

# ── Start VS Code server ──────────────────────────────────────────────────────
start_server() {
    "${USER_RUN[@]}" "$VSCODE_CLI" \
        --host 0.0.0.0 \
        --port "${VSCODE_PORT:-8080}" \
        --without-connection-token \
        --accept-server-license-terms \
        --server-data-dir /home/user/.vscode-server \
        --default-workspace "/home/user/${WORKSPACE_NAME:-zzaia}.code-workspace" &
    SERVER_PID=$!
}

# ── Install extensions ────────────────────────────────────────────────────────
install_extensions() {
    local ext_dir=/home/user/.vscode-server/extensions
    local ext_sentinel=/home/user/.vscode-server/.extensions-installed
    local ext_list_file="/usr/local/bin/vscode-extensions.txt"

    "${USER_RUN[@]}" mkdir -p "$ext_dir"

    local cli_ver
    cli_ver=$("$VSCODE_CLI" --version 2>/dev/null | head -1 || echo "unknown")
    if [ ! -f "$ext_sentinel" ] || [ "$(cat "$ext_sentinel" 2>/dev/null)" != "$cli_ver" ]; then
        _install_extension() {
            local ext="$1"
            local attempt=1
            local max=5
            local delay=10
            local out rc

            while [ "$attempt" -le "$max" ]; do
                if out=$("${USER_RUN[@]}" "$VSCODE_CLI" --extensions-dir "$ext_dir" --install-extension "$ext" --target linux-x64 2>&1); then
                    rc=0
                else
                    rc=$?
                fi
                if echo "$out" | grep -qiE "successfully installed|already installed"; then
                    echo "$out" | grep -v "already installed" || true
                    return 0
                fi
                echo "WARN: $ext attempt $attempt/$max failed (exit=${rc}); retrying in ${delay}s..." >&2
                sleep "$delay"
                attempt=$((attempt + 1))
                delay=$((delay * 2))
            done
            echo "WARN: $ext could not be installed after $max attempts; continuing." >&2
        }

        while IFS= read -r ext || [ -n "$ext" ]; do
            [ -z "$ext" ] && continue
            _install_extension "$ext"
        done < "$ext_list_file"

        "${USER_RUN[@]}" sh -c "echo '$cli_ver' > '$ext_sentinel'" || true
    fi
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    setup_env
    verify_cli
    setup_claude_credentials
    prepare_directories
    discover_server
    start_server
    install_extensions
    wait "$SERVER_PID"
}

main "$@"
