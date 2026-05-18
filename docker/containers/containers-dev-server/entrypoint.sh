#!/bin/bash
# entrypoint.sh — Dev-server container (workspace-server handles bootstrap)
set -euo pipefail

export WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"

# Install devcontainer config into shared home if not already present
if [ ! -f /home/user/.devcontainer/devcontainer.json ]; then
    mkdir -p /home/user/.devcontainer
    cp /opt/zzaia/devcontainer.json /home/user/.devcontainer/devcontainer.json
    chown -R user:user /home/user/.devcontainer 2>/dev/null || true
fi

echo "Dev-server ready — container available for devcontainer connection"
exec sleep infinity
