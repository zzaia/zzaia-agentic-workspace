#!/bin/bash
set -euo pipefail

# ── Logging ───────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    _G='\033[0;32m'
    _Y='\033[1;33m'
    _B='\033[0;34m'
    _R='\033[0;31m'
    _N='\033[0m'
else
    _G=''
    _Y=''
    _B=''
    _R=''
    _N=''
fi

log_info()    { echo -e "${_B}[signoz-server]${_N} $*"; }
log_warn()    { echo -e "${_Y}[signoz-server] WARN:${_N} $*" >&2; }
log_error()   { echo -e "${_R}[signoz-server] ERROR:${_N} $*" >&2; }
log_success() { echo -e "${_G}[signoz-server] ✓${_N} $*"; }

SIGNOZ_PID=""
SIGNOZ_URL="${SIGNOZ_URL:-http://localhost:8080}"
WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"
SIGNOZ_ADMIN_PASSWORD="${SIGNOZ_ADMIN_PASSWORD:-}"

# ── Cleanup handler ───────────────────────────────────────────────────────────
cleanup() {
    if [ -n "$SIGNOZ_PID" ] && kill -0 "$SIGNOZ_PID" 2>/dev/null; then
        log_info "Stopping SigNoz (PID $SIGNOZ_PID)..."
        kill "$SIGNOZ_PID" 2>/dev/null || true
        wait "$SIGNOZ_PID" 2>/dev/null || true
    fi
}

trap cleanup SIGTERM SIGINT EXIT

# ── Start SigNoz ──────────────────────────────────────────────────────────────
start_signoz() {
    log_info "Starting SigNoz server..."
    ./signoz server >> /tmp/signoz.log 2>&1 &
    SIGNOZ_PID=$!
    log_info "SigNoz started (PID $SIGNOZ_PID)"
}

# ── Health check ──────────────────────────────────────────────────────────────
wait_for_health() {
    local max_attempts=60
    local attempt=0
    log_info "Waiting for SigNoz health check..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "${SIGNOZ_URL}/api/v1/health" >/dev/null 2>&1; then
            log_success "SigNoz is healthy"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 3
    done
    log_error "SigNoz health check failed after $max_attempts attempts (180s)"
    return 1
}

# ── Provision admin user ──────────────────────────────────────────────────────
register_admin() {
    log_info "Registering admin account..."

    if [ -z "$SIGNOZ_ADMIN_PASSWORD" ]; then
        log_error "SIGNOZ_ADMIN_PASSWORD not set"
        return 1
    fi

    local resp
    resp=$(curl -s -X POST "${SIGNOZ_URL}/api/v1/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"admin@${WORKSPACE_NAME}.local\",
            \"password\": \"${SIGNOZ_ADMIN_PASSWORD}\",
            \"name\": \"Admin\",
            \"orgName\": \"${WORKSPACE_NAME}\"
        }")

    # Check for error (non-400 errors)
    if echo "$resp" | grep -q '"message".*"already exists"' || echo "$resp" | grep -q '"message".*"already registered"'; then
        log_info "Admin account already exists (idempotent)"
        return 0
    fi

    if echo "$resp" | grep -q '"error"' && ! echo "$resp" | grep -q '"message".*"already'; then
        log_warn "Register response: $resp"
        return 1
    fi

    log_success "Admin account registered"
    return 0
}

# ── Login and get JWT ─────────────────────────────────────────────────────────
get_jwt() {
    log_info "Logging in to get JWT token..."

    if [ -z "$SIGNOZ_ADMIN_PASSWORD" ]; then
        log_error "SIGNOZ_ADMIN_PASSWORD not set"
        return 1
    fi

    local resp
    resp=$(curl -s -X POST "${SIGNOZ_URL}/api/v1/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"admin@${WORKSPACE_NAME}.local\",
            \"password\": \"${SIGNOZ_ADMIN_PASSWORD}\"
        }")

    JWT=$(echo "$resp" | jq -r '.accessJWT // empty' 2>/dev/null || echo "")

    if [ -z "$JWT" ]; then
        log_error "Failed to get JWT. Response: $resp"
        return 1
    fi

    log_success "JWT token obtained"
    return 0
}

# ── Create PAT ────────────────────────────────────────────────────────────────
create_pat() {
    log_info "Creating PAT token for MCP..."

    if [ -z "$JWT" ]; then
        log_error "JWT token not available"
        return 1
    fi

    local resp
    resp=$(curl -s -X POST "${SIGNOZ_URL}/api/v1/pat" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${JWT}" \
        -d '{
            "name": "mcp-signoz",
            "role": "ADMIN"
        }')

    PAT=$(echo "$resp" | jq -r '.token // empty' 2>/dev/null || echo "")

    if [ -z "$PAT" ]; then
        log_error "Failed to create PAT. Response: $resp"
        return 1
    fi

    log_success "PAT token created"
    return 0
}

# ── Write PAT to shared volume ────────────────────────────────────────────────
write_pat_to_volume() {
    log_info "Writing PAT to /signoz-data/mcp-api-key..."

    if [ -z "$PAT" ]; then
        log_error "PAT token not available"
        return 1
    fi

    mkdir -p /signoz-data
    printf '%s' "$PAT" > /signoz-data/mcp-api-key
    chmod 644 /signoz-data/mcp-api-key

    log_success "PAT written to /signoz-data/mcp-api-key"
    return 0
}

# ── Idempotency check ─────────────────────────────────────────────────────────
is_provisioned() {
    if [ -f /signoz-data/mcp-api-key ] && [ -s /signoz-data/mcp-api-key ]; then
        log_info "SigNoz already provisioned (PAT exists)"
        return 0
    fi
    return 1
}

# ── Main flow ─────────────────────────────────────────────────────────────────
main() {
    log_info "Initializing SigNoz provisioning setup..."

    # Start SigNoz as background process
    start_signoz

    # Wait for health
    if ! wait_for_health; then
        log_error "Failed to start SigNoz"
        cat /tmp/signoz.log >&2
        return 1
    fi

    # Check idempotency
    if is_provisioned; then
        log_success "SigNoz setup complete (already provisioned)"
    else
        # Provision: register → login → create PAT → write to volume
        if register_admin; then
            if get_jwt; then
                if create_pat; then
                    if write_pat_to_volume; then
                        log_success "SigNoz setup complete"
                    else
                        log_warn "Failed to write PAT to volume"
                    fi
                else
                    log_warn "Failed to create PAT"
                fi
            else
                log_warn "Failed to login"
            fi
        else
            log_warn "Failed to register admin"
        fi
    fi

    log_info "SigNoz is running (PID $SIGNOZ_PID). Entrypoint will monitor it."

    # Wait for SigNoz process
    wait "$SIGNOZ_PID" || true
}

main "$@"
