#!/bin/bash
set -euo pipefail

# Graphiti MCP Server — Agent memory backend via Neo4j knowledge graph
# Routes LLM calls (entity extraction) through ml-server (Headroom) → bifrost-server → Anthropic
# Embedder routing: GPU_ENABLED=true → local ml-server; else → cloud OpenAI.
# OPENAI_API_KEY (cloud embedder path) is projected into the pod environment by
# External Secrets Operator (Bitwarden Secrets Manager → ESO → Kubernetes Secret → envFrom).

if [ -t 1 ]; then
    _G='\033[0;32m'
    _Y='\033[1;33m'
    _B='\033[0;34m'
    _N='\033[0m'
else
    _G=''; _Y=''; _B=''; _N=''
fi

log_info()    { echo -e "${_B}[mcp-graphiti]${_N} $*"; }
log_warn()    { echo -e "${_Y}[mcp-graphiti] WARN:${_N} $*" >&2; }
log_success() { echo -e "${_G}[mcp-graphiti] ✓${_N} $*"; }

# ── Validate embedder credentials ─────────────────────────────────────────────
# OPENAI_API_KEY arrives via envFrom (ESO). Only the cloud embedder path needs it.
validate_secrets() {
    if [ "${GPU_ENABLED:-false}" = "true" ]; then
        log_info "GPU enabled — embedder will use local ml-server (no OpenAI key needed)"
    elif [ -z "${OPENAI_API_KEY:-}" ]; then
        log_warn "No OPENAI_API_KEY in environment — cloud embedder will be limited"
    else
        log_success "Embedder credentials present (OpenAI)"
    fi
}

# ── Wait for ml-server health (LLM on 8787 unconditional, embeddings on 8788 GPU-gated) ────
wait_for_ml_server() {
    log_info "Waiting for ml-server Headroom (LLM) on http://ml-server:8787/health..."

    local max_attempts=150
    local attempt=1
    local interval=2

    # Always wait for LLM health on port 8787 (Headroom)
    while [ $attempt -le $max_attempts ]; do
        if curl -sf http://ml-server:8787/health >/dev/null 2>&1; then
            log_success "ml-server Headroom (LLM) is ready"
            break
        fi
        log_info "ml-server Headroom not ready yet (attempt $attempt/$max_attempts)..."
        sleep $interval
        attempt=$((attempt + 1))
    done

    if [ $attempt -gt $max_attempts ]; then
        log_warn "ml-server Headroom did not become ready after $((max_attempts * interval))s — proceeding anyway"
    fi

    # If GPU enabled, also wait for embeddings health on port 8788
    if [ "${GPU_ENABLED:-false}" = "true" ]; then
        log_info "Waiting for ml-server embeddings on http://ml-server:8788/health (GPU mode)..."
        attempt=1
        while [ $attempt -le $max_attempts ]; do
            if curl -sf http://ml-server:8788/health >/dev/null 2>&1; then
                log_success "ml-server embeddings server is ready"
                return 0
            fi
            log_info "ml-server embeddings not ready yet (attempt $attempt/$max_attempts)..."
            sleep $interval
            attempt=$((attempt + 1))
        done

        log_warn "ml-server embeddings did not become ready after $((max_attempts * interval))s — proceeding anyway"
    fi

    return 0
}

# ── Prepare config YAML ───────────────────────────────────────────────────────
    # LLM: always route through ml-server (Headroom), regardless of GPU status.
    # ml-server itself forwards to bifrost-server (ANTHROPIC_TARGET_API_URL=http://bifrost-server:8080/anthropic,
    # see the ml-server env in deploy/k8s/Chart/values.yaml) — the same convention every other
    # client in this workspace uses (see docker/containers/workspace-server/entrypoint.sh's
    # setup_profile_env: ANTHROPIC_BASE_URL defaults to http://ml-server:8787). Pointing straight at
    # bifrost-server here would skip Headroom's compression/memory injection entirely.
prepare_config() {
    log_info "Preparing Graphiti config..."

    local neo4j_uri="${NEO4J_URI:-bolt://database-neo4j:7687}"
    local neo4j_user="${NEO4J_USER:-neo4j}"
    local neo4j_password="${NEO4J_PASSWORD:-zzaia1234}"
    local neo4j_database="${NEO4J_DATABASE:-neo4j}"
    local group_id="${GRAPHITI_GROUP_ID:-main}"
    local semaphore_limit="${SEMAPHORE_LIMIT:-10}"

    local llm_provider="anthropic"
    local llm_api_url="http://ml-server:8787"
    local llm_api_key="${BIFROST_WORKSPACE_KEY:-sk-bf-workspace-agent-001}"
    local llm_model="${GRAPHITI_LLM_MODEL:-claude-haiku-4-5-20251001}"

    # Embedder: branch on GPU_ENABLED
    local embedder_provider="openai"
    local embedder_api_url=""
    local embedder_api_key="${OPENAI_API_KEY:-}"
    local embedder_model="text-embedding-3-small"
    local embedder_dimensions="1536"

    if [ "${GPU_ENABLED:-false}" = "true" ]; then
        embedder_api_url="http://ml-server:8788/v1"
        embedder_api_key="local-embeddings"
        embedder_model="nomic-embed-text-v1.5"
        embedder_dimensions="768"
        log_info "GPU enabled — using local embedder from ml-server"
    else
        if [ -z "$embedder_api_key" ]; then
            log_warn "No OpenAI API key for embeddings — Graphiti will be limited"
        fi
        log_info "GPU disabled — using cloud OpenAI embedder"
    fi

    export OPENAI_API_KEY="${embedder_api_key}"

    # Create config directory
    mkdir -p /app/mcp/config

    # Generate config.yaml with interpolated values
    # Note: top-level provider scalars are required by LLMClientFactory/EmbedderFactory
    cat > /app/mcp/config/config.yaml << EOF
server:
  transport: http
  host: 0.0.0.0
  port: 8000

database:
  provider: neo4j
  uri: ${neo4j_uri}
  user: ${neo4j_user}
  password: ${neo4j_password}
  database: ${neo4j_database}

llm:
  provider: ${llm_provider}
  model: ${llm_model}
  providers:
    ${llm_provider}:
      api_key: ${llm_api_key}
      api_url: ${llm_api_url}

embedder:
  provider: ${embedder_provider}
  model: ${embedder_model}
  dimensions: ${embedder_dimensions}
  providers:
    ${embedder_provider}:
      api_key: ${embedder_api_key}
EOF

    # Only add api_url for embedder if explicitly set (cloud path has no override)
    if [ -n "$embedder_api_url" ]; then
        cat >> /app/mcp/config/config.yaml << EOF
      api_url: ${embedder_api_url}
EOF
    fi

    cat >> /app/mcp/config/config.yaml << EOF

graphiti:
  group_id: ${group_id}
  semaphore_limit: ${semaphore_limit}
EOF

    chmod 600 /app/mcp/config/config.yaml
    log_success "Config prepared at /app/mcp/config/config.yaml"
}

main() {
    log_info "Starting mcp-graphiti..."
    log_info "Neo4j URI: ${NEO4J_URI:-bolt://database-neo4j:7687}"

    validate_secrets
    wait_for_ml_server
    prepare_config

    log_info "Starting Graphiti HTTP server on port 8000..."
    cd /app/mcp && exec .venv/bin/python main.py
}

main "$@"
