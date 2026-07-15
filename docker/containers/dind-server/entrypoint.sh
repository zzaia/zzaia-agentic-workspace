#!/bin/bash
# entrypoint.sh — DinD entrypoint with conditional NVIDIA Container Toolkit configuration
set -euo pipefail

# ── Configure GPU ─────────────────────────────────────────────────────────────
configure_gpu() {
    if [ "${GPU_ENABLED:-false}" = "true" ]; then
        echo "[DinD] GPU_ENABLED=true — configuring nvidia runtime..."

        if command -v nvidia-ctk > /dev/null 2>&1; then
            nvidia-ctk runtime configure --runtime=docker 2>&1 | sed 's/^/[DinD] /'
            echo "[DinD] nvidia runtime configured"
        else
            echo "[DinD] WARNING: nvidia-ctk not available — Docker daemon will start without nvidia runtime"
        fi
    fi
}

# ── Bootstrap Kind cluster ────────────────────────────────────────────────────
bootstrap_kind() {
    if [ "${KIND_ENABLED:-false}" != "true" ]; then
        return
    fi

    echo "[DinD] KIND_ENABLED=true — bootstrapping Kind cluster..."

    # Kind's node image pulls fail on this host: the inherited DNS resolver is
    # unreliable for dockerd's own pull path (confirmed reproducible, not transient),
    # and IPv6 is resolvable but unroutable, causing "dial tcp: lookup ... no such
    # host" and "network is unreachable" errors. Force a known-reliable resolver and
    # disable IPv6 — scoped to the Kind path only, not a general dind-server change.
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true

    # Poll for Docker daemon readiness
    local max_attempts=120
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1; then
            echo "[DinD] Docker daemon is ready"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    if [ $attempt -eq $max_attempts ]; then
        echo "[DinD] WARNING: Docker daemon did not become ready within 120 seconds" >&2
        return
    fi

    # Check if Kind cluster already exists. kind's bookkeeping is derived entirely
    # from Docker container labels (no separate state file), so this survives
    # dind-server recreates since /var/lib/docker is a persistent volume — but the
    # node container itself is abruptly killed (not cleanly stopped) when dind-server
    # is recreated, so it comes back as Exited rather than Running. Detect that and
    # restart it instead of just skipping, or the cluster exists but is unreachable.
    if kind get clusters 2>/dev/null | grep -q "^dev\$"; then
        if docker ps --filter name=dev-control-plane --filter status=running --format '{{.Names}}' | grep -qx "dev-control-plane"; then
            echo "[DinD] Kind cluster 'dev' already exists and is running, skipping creation"
        else
            echo "[DinD] Kind cluster 'dev' exists but its node container is stopped — restarting it..."
            if docker start dev-control-plane 2>&1 | sed 's/^/[DinD] /' \
                && kind export kubeconfig --name dev 2>&1 | sed 's/^/[DinD] /'; then
                echo "[DinD] Kind cluster 'dev' node restarted"
            else
                echo "[DinD] WARNING: failed to restart Kind cluster 'dev' node container" >&2
            fi
        fi
        return
    fi

    # Create the Kind cluster
    echo "[DinD] Creating Kind cluster 'dev'..."
    if kind create cluster --name dev --config /etc/kind/kind-config.yaml 2>&1 | sed 's/^/[DinD] /'; then
        echo "[DinD] Kind cluster 'dev' created successfully"

        # Deploy Portainer agent
        echo "[DinD] Deploying Portainer agent to Kind cluster..."
        if ! kubectl --context kind-dev apply -n portainer -f /etc/kind/portainer-agent-k8s-nodeport.yaml 2>&1 | sed 's/^/[DinD] /'; then
            echo "[DinD] WARNING: Portainer agent deployment failed, but Kind cluster is still usable" >&2
        fi
    else
        echo "[DinD] WARNING: Kind cluster creation failed, but Docker functionality is unaffected" >&2
    fi
}

# ── Main entry point ──────────────────────────────────────────────────────────
main() {
    configure_gpu
    bootstrap_kind &
    disown
    # When TLS is disabled, add TCP listener so Portainer and other clients can connect
    if [ "${DOCKER_TLS_CERTDIR:-}" = "" ]; then
        exec "$@" --host tcp://0.0.0.0:2375 --host unix:///var/run/docker.sock
    else
        exec "$@"
    fi
}

main "$@"
