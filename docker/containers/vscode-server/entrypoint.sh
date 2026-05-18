#!/usr/bin/env bash
# entrypoint.sh — VS Code Server container entrypoint
# workspace-server handles bootstrap; this only starts VS Code.
set -euo pipefail

export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

USER_RUN=()
VSCODE_CLI=""
SERVER_PID=""

vscode::setup_env() {
    export NVM_DIR="/opt/tools/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
    export PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:$PATH
    export BROWSER=/usr/local/bin/browser-print
    export HOME=/home/user

    USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH" BROWSER="$BROWSER")
}

vscode::install_cli() {
    if ! command -v code >/dev/null 2>&1; then
        echo "VS Code CLI not found — installing..."
        curl -fsSL "https://update.code.visualstudio.com/latest/cli-linux-x64/stable" | tar xz -C /usr/local/bin \
            && echo "VS Code CLI installed." \
            || { echo "ERROR: VS Code CLI install failed." >&2; exit 1; }
    fi
}

vscode::setup_credentials() {
    if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        local _cred_file="/home/user/.claude/.credentials.json"
        if [ -f "$_cred_file" ]; then
            local _token
            _token=$(grep -oP '"accessToken":"\K[^"]+' "$_cred_file" 2>/dev/null || true)
            if [ -n "$_token" ]; then
                export CLAUDE_CODE_OAUTH_TOKEN="$_token"
                USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH" BROWSER="$BROWSER" CLAUDE_CODE_OAUTH_TOKEN="$_token")
            fi
        fi
    fi
}

vscode::prepare_dirs() {
    "${USER_RUN[@]}" mkdir -p /home/user/.vscode-server/data/Machine /home/user/.vscode-server/extensions
    chown -R user:user /home/user/.vscode-server 2>/dev/null || true

    # Write Machine settings so the Python extension finds the tools-volume interpreter
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

vscode::discover_server() {
    VSCODE_CLI=$(runuser -u user -- find /home/user/.vscode/cli/serve-web -name code-server -type f 2>/dev/null | grep -v '\.staging' | head -1 || true)

    if [ -z "$VSCODE_CLI" ]; then
        echo "VS Code inner binary not found — triggering download via code serve-web..."
        "${USER_RUN[@]}" code serve-web \
            --host 127.0.0.1 \
            --port 19999 \
            --without-connection-token \
            --accept-server-license-terms \
            --server-data-dir /home/user/.vscode-server &
        local DOWNLOAD_PID=$!

        local i
        for i in $(seq 1 60); do
            if curl -s http://127.0.0.1:19999 -o /dev/null 2>/dev/null; then
                echo "Port 19999 ready — download triggered."
                break
            fi
            sleep 1
        done

        local CLI_DISCOVERY_MAX="${CLI_DISCOVERY_MAX_ATTEMPTS:-600}"
        local CLI_DISCOVERY_DELAY="${CLI_DISCOVERY_DELAY_SECONDS:-3}"
        for i in $(seq 1 "$CLI_DISCOVERY_MAX"); do
            VSCODE_CLI=$(runuser -u user -- find /home/user/.vscode/cli/serve-web -name code-server -type f 2>/dev/null | grep -v '\.staging' | head -1 || true)
            [ -n "$VSCODE_CLI" ] && break
            sleep "$CLI_DISCOVERY_DELAY"
        done

        kill "$DOWNLOAD_PID" 2>/dev/null || true
        wait "$DOWNLOAD_PID" 2>/dev/null || true
    fi

    if [ -z "$VSCODE_CLI" ]; then
        echo "ERROR: VS Code Server could not be downloaded." >&2
        exit 1
    fi
}

vscode::start_server() {
    "${USER_RUN[@]}" "$VSCODE_CLI" \
        --host 0.0.0.0 \
        --port "${VSCODE_PORT:-8080}" \
        --without-connection-token \
        --accept-server-license-terms \
        --server-data-dir /home/user/.vscode-server \
        --default-workspace "/home/user/${WORKSPACE_NAME:-zzaia}.code-workspace" &
    SERVER_PID=$!
}

vscode::install_extensions() {
    local EXT_DIR=/home/user/.vscode-server/extensions
    local EXT_SENTINEL=/home/user/.vscode-server/.extensions-installed
    local EXT_LIST_FILE="/usr/local/bin/vscode-extensions.txt"

    "${USER_RUN[@]}" mkdir -p "$EXT_DIR"

    local _CLI_VER
    _CLI_VER=$("$VSCODE_CLI" --version 2>/dev/null | head -1 || echo "unknown")
    if [ ! -f "$EXT_SENTINEL" ] || [ "$(cat "$EXT_SENTINEL" 2>/dev/null)" != "$_CLI_VER" ]; then
        _install_ext() {
            local ext="$1" attempt=1 max=5 delay=10 out rc
            while [ "$attempt" -le "$max" ]; do
                if out=$("${USER_RUN[@]}" "$VSCODE_CLI" --extensions-dir "$EXT_DIR" --install-extension "$ext" --target linux-x64 2>&1); then
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
            _install_ext "$ext"
        done < "$EXT_LIST_FILE"

        "${USER_RUN[@]}" sh -c "echo '$_CLI_VER' > '$EXT_SENTINEL'" || true
    fi
}

main() {
    vscode::setup_env
    vscode::install_cli
    vscode::setup_credentials
    vscode::prepare_dirs
    vscode::discover_server
    vscode::start_server
    vscode::install_extensions
    wait "$SERVER_PID"
}

main "$@"
