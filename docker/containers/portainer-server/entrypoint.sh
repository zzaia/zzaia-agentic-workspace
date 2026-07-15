#!/bin/sh
# entrypoint.sh — Portainer bootstrap with automatic environment registration
set -euo pipefail

# ── Read admin password ───────────────────────────────────────────────────────
ADMIN_PASSWORD=$(cat /run/secrets/admin_password)

# ── Start Portainer in background ─────────────────────────────────────────────
echo "[portainer-bootstrap] Starting Portainer binary..."
/portainer --admin-password-file /run/secrets/admin_password &
PORTAINER_PID=$!

# ── Poll for readiness ───────────────────────────────────────────────────────
echo "[portainer-bootstrap] Waiting for Portainer API to be ready..."
max_attempts=120
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -sf http://127.0.0.1:9000/api/system/status >/dev/null 2>&1; then
        echo "[portainer-bootstrap] Portainer is ready"
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done

if [ $attempt -eq $max_attempts ]; then
    echo "[portainer-bootstrap] WARNING: Portainer did not become ready within 120 seconds" >&2
fi

# ── Authenticate and get JWT ──────────────────────────────────────────────────
echo "[portainer-bootstrap] Authenticating as admin..."
JWT=$(curl -sf -X POST http://127.0.0.1:9000/api/auth \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"admin\",\"Password\":\"$ADMIN_PASSWORD\"}" 2>/dev/null | \
    python3 -c "import sys, json; print(json.load(sys.stdin).get('jwt', ''))" 2>/dev/null || echo "")

if [ -z "$JWT" ]; then
    echo "[portainer-bootstrap] WARNING: Failed to authenticate with admin credentials — skipping environment registration" >&2
else
    echo "[portainer-bootstrap] Admin authenticated"

    # ── Register Docker environment ───────────────────────────────────────────
    echo "[portainer-bootstrap] Registering Docker environment (dind)..."
    if curl -sf -X POST http://127.0.0.1:9000/api/endpoints \
        -H "Authorization: Bearer $JWT" \
        -F "Name=dind" \
        -F "EndpointCreationType=1" \
        -F "URL=tcp://dind-server:2375" >/dev/null 2>&1; then
        echo "[portainer-bootstrap] Docker environment (dind) registered"
    else
        echo "[portainer-bootstrap] WARNING: Docker environment registration failed — add manually via Portainer UI: Environments -> Add -> Docker -> tcp://dind-server:2375" >&2
    fi

    # ── Register Kubernetes environment (if enabled) ──────────────────────────
    if [ "${KIND_ENABLED:-false}" = "true" ]; then
        echo "[portainer-bootstrap] Registering Kubernetes environment (dind-kind)..."
        # Portainer's multipart parser requires the TLSCACertFile/TLSCertFile/TLSKeyFile
        # fields to be PRESENT (even 0 bytes) whenever TLS=true, or it rejects the whole
        # request with a misleading "Invalid certificate file" error — their absence, not
        # their content, is what it checks. TLSSkipVerify makes the actual file content
        # irrelevant beyond that presence check.
        : > /tmp/empty-cert
        if curl -sf -X POST http://127.0.0.1:9000/api/endpoints \
            -H "Authorization: Bearer $JWT" \
            -F "Name=dind-kind" \
            -F "EndpointCreationType=2" \
            -F "URL=tcp://dind-server:30778" \
            -F "TLS=true" \
            -F "TLSSkipVerify=true" \
            -F "TLSSkipClientVerify=true" \
            -F "TLSCACertFile=@/tmp/empty-cert" \
            -F "TLSCertFile=@/tmp/empty-cert" \
            -F "TLSKeyFile=@/tmp/empty-cert" >/dev/null 2>&1; then
            echo "[portainer-bootstrap] Kubernetes environment (dind-kind) registered"
        else
            echo "[portainer-bootstrap] WARNING: Kubernetes environment registration failed — add manually via Portainer UI: Environments -> Add -> Agent -> tcp://dind-server:30778" >&2
        fi
    fi
fi

# ── Wait on Portainer process ─────────────────────────────────────────────────
# Synchronous approach: registration steps completed before waiting, so container
# lifecycle stays tied to the portainer process without being blocked by bootstrap steps.
wait $PORTAINER_PID
