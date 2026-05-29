#!/usr/bin/env bash
# entrypoint.sh — Dev Containers container entrypoint
# workspace-server handles bootstrap; this only pre-caches VS Code Server.
set -euo pipefail

export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

USER_RUN=()

# ── Setup environment ─────────────────────────────────────────────────────────
setup_env() {
    export NVM_DIR="/opt/tools/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
    export PATH=/opt/tools/.local/bin:/opt/tools/.npm-global/bin:/opt/tools/.dotnet:/opt/tools/.dotnet/tools:/opt/tools/miniforge3/bin:$PATH
    export HOME=/home/user

    USER_RUN=(runuser -u user -- env HOME=/home/user PATH="$PATH")
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

# ── Cache VS Code server ──────────────────────────────────────────────────────
cache_server() {
    echo "Caching VS Code Desktop Server for Dev Containers..."

    local commit
    commit=$(runuser -u user -- code --version 2>/dev/null | sed -n '2p')

    if [ -z "$commit" ]; then
        echo "WARN: Could not determine VS Code commit hash; skipping server cache." >&2
        return 0
    fi

    local server_dir="/home/user/.vscode-server/bin/$commit"

    if [ -f "$server_dir/server.sh" ]; then
        echo "VS Code Server for commit $commit already cached."
        return 0
    fi

    echo "Downloading VS Code Server for commit $commit..."
    mkdir -p "$server_dir"

    if curl -fsSL "https://update.code.visualstudio.com/commit:$commit/server-linux-x64/stable" \
        | tar xz --strip-components=1 -C "$server_dir/"; then
        echo "VS Code Server cached successfully."
    else
        echo "WARN: Failed to cache VS Code Server; Dev Containers may download it on first attach." >&2
        return 0
    fi

    chown -R user:user /home/user/.vscode-server 2>/dev/null || true
}

# ── Seed dev container config ─────────────────────────────────────────────────
seed_config() {
    if [ ! -f /home/user/.devcontainer/devcontainer.json ]; then
        mkdir -p /home/user/.devcontainer
        cp /opt/zzaia/devcontainer.json /home/user/.devcontainer/devcontainer.json
        chown -R user:user /home/user/.devcontainer 2>/dev/null || true
        echo "Dev container config seeded to /home/user/.devcontainer/"
    fi
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    setup_env
    verify_cli
    cache_server
    seed_config
    echo "Dev Containers ready — container available for Dev Containers connection"
    exec sleep infinity
}

main "$@"
