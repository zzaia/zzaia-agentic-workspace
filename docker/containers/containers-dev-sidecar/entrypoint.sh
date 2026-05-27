#!/usr/bin/env bash
# entrypoint.sh — Dev Containers container entrypoint
# workspace-server handles bootstrap; this only pre-caches VS Code Server.
set -euo pipefail

export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

USER_RUN=()

devcontainer::setup_env() {
    export NVM_DIR="/opt/tools/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
    export PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:$PATH
    export HOME=/home/user

    USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH")
}

devcontainer::install_cli() {
    if ! command -v code >/dev/null 2>&1; then
        echo "ERROR: VS Code CLI not found in PATH." >&2
        echo "  workspace-server may not have completed runtime setup yet." >&2
        echo "  Ensure workspace-server container has finished bootstrap." >&2
        exit 1
    fi
}

devcontainer::cache_server() {
    echo "Caching VS Code Desktop Server for Dev Containers..."

    # Get commit hash from code --version
    local COMMIT
    COMMIT=$(runuser -u user -- code --version 2>/dev/null | sed -n '2p')

    if [ -z "$COMMIT" ]; then
        echo "WARN: Could not determine VS Code commit hash; skipping server cache." >&2
        return 0
    fi

    local SERVER_DIR="/home/user/.vscode-server/bin/$COMMIT"

    # Check if server already cached
    if [ -f "$SERVER_DIR/server.sh" ]; then
        echo "VS Code Server for commit $COMMIT already cached."
        return 0
    fi

    # Download and extract server
    echo "Downloading VS Code Server for commit $COMMIT..."
    mkdir -p "$SERVER_DIR"

    if curl -fsSL "https://update.code.visualstudio.com/commit:$COMMIT/server-linux-x64/stable" \
        | tar xz --strip-components=1 -C "$SERVER_DIR/"; then
        echo "VS Code Server cached successfully."
    else
        echo "WARN: Failed to cache VS Code Server; Dev Containers may download it on first attach." >&2
        return 0
    fi

    # Set ownership
    chown -R user:user /home/user/.vscode-server 2>/dev/null || true
}

devcontainer::seed_config() {
    # Install devcontainer config into shared home if not already present
    if [ ! -f /home/user/.devcontainer/devcontainer.json ]; then
        mkdir -p /home/user/.devcontainer
        cp /opt/zzaia/devcontainer.json /home/user/.devcontainer/devcontainer.json
        chown -R user:user /home/user/.devcontainer 2>/dev/null || true
        echo "Dev container config seeded to /home/user/.devcontainer/"
    fi
}

main() {
    devcontainer::setup_env
    devcontainer::install_cli
    devcontainer::cache_server
    devcontainer::seed_config
    echo "Dev Containers ready — container available for Dev Containers connection"
    exec sleep infinity
}

main "$@"
