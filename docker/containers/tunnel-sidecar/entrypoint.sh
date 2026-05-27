#!/usr/bin/env bash
# entrypoint.sh — VS Code Tunnel container entrypoint
# workspace-server handles bootstrap; this only runs the tunnel daemon.
set -euo pipefail

export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

USER_RUN=()

tunnel::setup_env() {
    export NVM_DIR="/opt/tools/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
    export PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:$PATH
    export HOME=/home/user
    # VSCODE_CLI_DISABLE_KEYCHAIN_ENCRYPT=1 required: Docker containers have no system keyring
    USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH" VSCODE_CLI_DISABLE_KEYCHAIN_ENCRYPT=1)
}

tunnel::check_cli() {
    # code comes from workspace-server's /opt/tools volume
    if ! command -v code >/dev/null 2>&1; then
        echo "ERROR: VS Code CLI not found in PATH — workspace-server may not have completed setup." >&2
        exit 1
    fi
}

tunnel::start_tunnel() {
    echo "Starting VS Code tunnel '${WORKSPACE_NAME}'..."
    echo "Connect via VS Code Desktop: Remote Tunnels extension → '${WORKSPACE_NAME}'"
    echo "Browser access: https://vscode.dev/tunnel/${WORKSPACE_NAME}"
    echo "First-time auth: SSH into workspace-server and run: code tunnel user login --provider github"
    exec "${USER_RUN[@]}" code tunnel \
        --name "${WORKSPACE_NAME:-zzaia}" \
        --accept-server-license-terms
}

main() {
    tunnel::setup_env
    tunnel::check_cli
    tunnel::start_tunnel
}

main "$@"
