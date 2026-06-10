#!/bin/bash
set -euo pipefail

# ── Logging ───────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    _G='\033[0;32m'; _Y='\033[1;33m'; _B='\033[0;34m'; _R='\033[0;31m'; _N='\033[0m'
else
    _G=''; _Y=''; _B=''; _R=''; _N=''
fi
log_info()    { echo -e "${_B}[signoz-server]${_N} $*"; }
log_warn()    { echo -e "${_Y}[signoz-server] WARN:${_N} $*" >&2; }
log_error()   { echo -e "${_R}[signoz-server] ERROR:${_N} $*" >&2; }
log_success() { echo -e "${_G}[signoz-server] ✓${_N} $*"; }

SIGNOZ_PID=""
SIGNOZ_URL="${SIGNOZ_URL:-http://localhost:8080}"
WORKSPACE_NAME="${WORKSPACE_NAME:-zzaia}"
SIGNOZ_ADMIN_PASSWORD="${SIGNOZ_ADMIN_PASSWORD:-}"
ADMIN_EMAIL="admin@${WORKSPACE_NAME}.local"
DB_PATH="${SIGNOZ_SQLSTORE_SQLITE_PATH:-/var/lib/signoz/signoz.db}"

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
    local max_attempts=60 attempt=0
    log_info "Waiting for SigNoz health check..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "${SIGNOZ_URL}/api/v1/health" >/dev/null 2>&1; then
            log_success "SigNoz is healthy"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 3
    done
    log_error "SigNoz health check failed after $max_attempts attempts"
    return 1
}

# ── Get org ID (from DB fallback) ─────────────────────────────────────────────
get_org_id_from_db() {
    sqlite3 "$DB_PATH" "SELECT id FROM organizations LIMIT 1" 2>/dev/null || true
}

# ── Register admin (first boot only) ─────────────────────────────────────────
# Returns: sets ORG_ID global variable
ORG_ID=""
register_admin() {
    log_info "Registering admin account..."
    if [ -z "$SIGNOZ_ADMIN_PASSWORD" ]; then
        log_error "SIGNOZ_ADMIN_PASSWORD not set"
        return 1
    fi

    local resp
    resp=$(curl -s -X POST "${SIGNOZ_URL}/api/v1/register" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${SIGNOZ_ADMIN_PASSWORD}\",\"name\":\"Admin\",\"orgName\":\"${WORKSPACE_NAME}\"}")

    # Extract orgId from success response (wrapped in {"status":"success","data":{...}})
    if echo "$resp" | grep -q '"orgId"'; then
        ORG_ID=$(echo "$resp" | jq -r '.data.orgId // .orgId // empty' 2>/dev/null || echo "")
        [ -z "$ORG_ID" ] && ORG_ID=$(get_org_id_from_db)
        log_success "Admin registered (orgId: $ORG_ID)"
        return 0
    fi

    # Self-registration disabled = admin already exists
    if echo "$resp" | grep -q 'self-registration is disabled'; then
        log_info "Admin already exists — fetching orgId from DB"
        ORG_ID=$(get_org_id_from_db)
        if [ -z "$ORG_ID" ]; then
            log_error "Could not fetch orgId from DB"
            return 1
        fi
        log_info "orgId: $ORG_ID"
        return 0
    fi

    # Already registered variants
    if echo "$resp" | grep -q '"already'; then
        log_info "Admin account already exists (idempotent)"
        ORG_ID=$(get_org_id_from_db)
        return 0
    fi

    log_warn "Unexpected register response: $resp"
    return 1
}

# ── Login (SigNoz v0.127.1: /api/v2/sessions/email_password) ─────────────────
JWT=""
get_jwt() {
    log_info "Logging in to SigNoz..."
    if [ -z "$SIGNOZ_ADMIN_PASSWORD" ] || [ -z "$ORG_ID" ]; then
        log_error "Missing SIGNOZ_ADMIN_PASSWORD or ORG_ID for login"
        return 1
    fi

    local resp
    resp=$(curl -s -X POST "${SIGNOZ_URL}/api/v2/sessions/email_password" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${SIGNOZ_ADMIN_PASSWORD}\",\"orgId\":\"${ORG_ID}\"}")

    JWT=$(echo "$resp" | jq -r '.data.accessToken // empty' 2>/dev/null || echo "")
    if [ -z "$JWT" ]; then
        log_error "Failed to get JWT. Response: $(echo "$resp" | head -c 200)"
        return 1
    fi
    log_success "JWT token obtained"
    return 0
}

# ── Generate ULID ─────────────────────────────────────────────────────────────
gen_ulid() {
    python3 -c "
import time, random
ENC='0123456789ABCDEFGHJKMNPQRSTVWXYZ'
t=int(time.time()*1000); ts=''
for _ in range(10): ts=ENC[t%32]+ts; t//=32
print(ts+''.join(random.choices(ENC,k=16)))
" 2>/dev/null || date +%s%N | sha256sum | head -c26 | tr '[:lower:]' '[:upper:]'
}

# ── Create or find service account ───────────────────────────────────────────
SA_ID=""
get_or_create_service_account() {
    log_info "Setting up mcp-signoz service account..."

    # List existing service accounts
    local list_resp
    list_resp=$(curl -s "${SIGNOZ_URL}/api/v1/service_accounts" \
        -H "Authorization: Bearer ${JWT}")

    SA_ID=$(echo "$list_resp" | jq -r '.data[]? | select(.name=="mcp-signoz" and .status!="deleted") | .id' 2>/dev/null | head -1 || echo "")

    if [ -n "$SA_ID" ]; then
        log_info "Service account mcp-signoz already exists (id: $SA_ID)"
        assign_viewer_role
        return 0
    fi

    # Create service account
    local create_resp
    create_resp=$(curl -s -X POST "${SIGNOZ_URL}/api/v1/service_accounts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${JWT}" \
        -d '{"name":"mcp-signoz","role":"VIEWER"}')

    SA_ID=$(echo "$create_resp" | jq -r '.data.id // empty' 2>/dev/null || echo "")
    if [ -z "$SA_ID" ]; then
        log_error "Failed to create service account. Response: $(echo "$create_resp" | head -c 200)"
        return 1
    fi
    log_success "Service account created (id: $SA_ID)"
    assign_viewer_role
    return 0
}

# ── Assign viewer role via SpiceDB tuple (SigNoz v0.127+) ────────────────────
assign_viewer_role() {
    [ -z "$SA_ID" ] && return 0
    [ -z "$ORG_ID" ] && return 0
    [ ! -f "$DB_PATH" ] && return 0

    local existing
    existing=$(sqlite3 "$DB_PATH" \
        "SELECT COUNT(*) FROM tuple WHERE object_id LIKE '%signoz-viewer%' AND user_object_id LIKE '%${SA_ID}%'" 2>/dev/null || echo "0")
    if [ "$existing" -gt 0 ] 2>/dev/null; then
        log_info "Viewer role already assigned to service account"
        return 0
    fi

    local store_id
    store_id=$(sqlite3 "$DB_PATH" "SELECT DISTINCT store FROM tuple LIMIT 1" 2>/dev/null || echo "")
    if [ -z "$store_id" ]; then
        log_warn "Could not determine authorization store ID — viewer role not assigned"
        return 0
    fi

    local ulid; ulid=$(gen_ulid)
    sqlite3 "$DB_PATH" \
        "INSERT OR IGNORE INTO tuple (store,object_type,object_id,relation,user_object_type,user_object_id,user_relation,user_type,ulid,inserted_at) VALUES (
          '${store_id}','role','organization/${ORG_ID}/role/signoz-viewer',
          'assignee','serviceaccount',
          'organization/${ORG_ID}/serviceaccount/${SA_ID}',
          '','user','${ulid}',datetime('now')
        )" 2>/dev/null && log_success "Viewer role assigned to service account" || log_warn "Could not assign viewer role"
}

# ── Create API key for service account ───────────────────────────────────────
API_KEY=""
create_api_key() {
    log_info "Creating API key for mcp-signoz service account..."

    local resp
    resp=$(curl -s -X POST "${SIGNOZ_URL}/api/v1/service_accounts/${SA_ID}/keys" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${JWT}" \
        -d '{"name":"mcp-signoz-key","expiresAt":0}')

    API_KEY=$(echo "$resp" | jq -r '.data.key // empty' 2>/dev/null || echo "")
    if [ -z "$API_KEY" ]; then
        log_error "Failed to create API key. Response: $(echo "$resp" | head -c 200)"
        return 1
    fi
    log_success "API key created"
    return 0
}

# ── Write API key to shared volume ────────────────────────────────────────────
write_api_key() {
    log_info "Writing API key to /signoz-data/mcp-api-key..."
    mkdir -p /signoz-data
    printf '%s' "$API_KEY" > /signoz-data/mcp-api-key
    chmod 644 /signoz-data/mcp-api-key
    log_success "API key written to /signoz-data/mcp-api-key"
}

# ── Idempotency check ─────────────────────────────────────────────────────────
is_provisioned() {
    [ -f /signoz-data/mcp-api-key ] && [ -s /signoz-data/mcp-api-key ]
}

# ── Main flow ─────────────────────────────────────────────────────────────────
main() {
    log_info "Initializing SigNoz provisioning setup..."

    start_signoz

    if ! wait_for_health; then
        log_error "Failed to start SigNoz"
        cat /tmp/signoz.log >&2
        return 1
    fi

    if is_provisioned; then
        log_success "SigNoz already provisioned (API key exists)"
    else
        if register_admin && get_jwt && get_or_create_service_account && create_api_key; then
            write_api_key
            log_success "SigNoz provisioning complete"
        else
            log_warn "Provisioning failed — mcp-signoz will operate without API key"
        fi
    fi

    log_info "SigNoz is running (PID $SIGNOZ_PID). Entrypoint will monitor it."
    wait "$SIGNOZ_PID" || true
}

main "$@"
