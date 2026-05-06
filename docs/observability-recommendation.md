# Observability Recommendation: SigNoz + Fluent Bit + Bifrost + Headroom Callback

**Date:** May 2026  
**Status:** Recommended for Implementation  
**Footprint:** +2.3–3.4 GB RAM, zero privileged containers

---

## Executive Summary

**Recommended Stack:**
- **SigNoz** — unified logs + metrics + traces, MCP-enabled
- **Fluent Bit** — lightweight log collection from all containers
- **Bifrost** — LLM gateway replacing headroom, with native OTLP traces and Go plugin architecture
- **Headroom Python SDK** — runs inside Bifrost PreLLMHook for context compression, memory injection, and code-graph lookup

**Key Properties:**
- Zero privileged containers (production-safe)
- 100% log coverage across all containers
- 100% metrics coverage (qdrant, neo4j, Bifrost)
- ~100% trace coverage (agent→Bifrost→LLM pipeline + Node.js MCP services)
- Full end-to-end observability of context compression and memory operations
- MCP integration allows agents to query observability data

---

## Architecture Overview

### Request Flow with Observability

```
Workspace Agents (Claude, Gemini, Codex, Copilot)
    │
    ├─ ANTHROPIC_BASE_URL = http://bifrost:8080/v1
    ├─ OPENAI_BASE_URL = http://bifrost:8080/v1
    └─ GEMINI_API_BASE = http://bifrost:8080/v1
    │
    ↓ HTTP POST /v1/messages, /v1/chat/completions, etc.
    │
Bifrost LLM Gateway (:8080)
    │
    ├─ [OTLP Span] Receive request
    │
    ├─ PreLLMHook (Go plugin)
    │   │
    │   ├─ [Sub-span] headroom.compress(messages)
    │   │   └─ Context compression, filtering
    │   │
    │   ├─ [Sub-span] headroom.inject_memory(...)
    │   │   └─ Query Qdrant vector DB
    │   │       └─ [Query metrics to SigNoz OTel Collector]
    │   │
    │   └─ [Sub-span] headroom.lookup_code_graph(...)
    │       └─ Query Neo4j graph DB
    │           └─ [Query metrics to SigNoz OTel Collector]
    │
    ├─ Route request to provider (Anthropic, OpenAI, Google, etc.)
    │   └─ [Sub-span] Provider latency
    │
    └─ PostLLMHook (optional)
        └─ Cost tracking, response logging
    │
    ↓ Response to Agent
Workspace Agents
    │
    ↓ Agents may invoke MCP tools:
Agents → SigNoz MCP Tools
    ├─ signoz_search_logs (search logs by container, severity)
    ├─ signoz_search_traces (find traces by service, status)
    ├─ signoz_query_metrics (query latency, error rates)
    └─ signoz_get_trace_details (drill into compression/memory/code-graph spans)

Observability Data Collection:

Fluent Bit (:24224)
    │
    ├─ Read-only mount: /var/lib/docker/containers
    │
    └─ Stream logs from all containers
        └─ Forward to SigNoz (:3100/loki/api/v1/push)

Bifrost → OTLP gRPC
    └─ http://observability-signoz:4317
        └─ Traces (agent→Bifrost→LLM + PreLLMHook spans)

mcp-* (5 Node.js services) → OTLP gRPC (auto-instrumentation)
    └─ http://observability-signoz:4317
        └─ Traces (Node.js internal operations)

OTel Collector (embedded in SigNoz)
    │
    ├─ Scrape qdrant /metrics (:6333/metrics)
    ├─ Scrape neo4j /metrics (:7474/metrics)
    ├─ Scrape Bifrost /metrics (:8080/metrics)
    │
    └─ Forward to SigNoz metrics backend

SigNoz All-in-One (:4317, :3100, :3301, :6831)
    │
    ├─ Receives OTLP traces (gRPC :4317, HTTP :4318)
    ├─ Receives logs from Fluent Bit (Loki API :3100)
    ├─ Scrapes Prometheus metrics (OTel Collector)
    │
    └─ UI available at http://localhost:3301 (or internal:3301 in network `mcp`)
        ├─ Logs browser (by container, timestamp, level)
        ├─ Metrics graphs (latency, throughput, error rates)
        ├─ Traces (request timeline, span breakdown, cost)
        └─ Service dependency map (auto-generated from traces)

Agents can also access SigNoz MCP API:
    SigNoz MCP Server (:5678 or custom)
        ├─ signoz_search_logs
        ├─ signoz_search_traces
        ├─ signoz_query_metrics
        └─ signoz_get_trace_details
```

---

## Coverage Matrix

### Observability Signals: Source and Coverage

| Signal | Source Container | Source Method | Data Destination | Coverage |
|--------|-------------------|----------------|-------------------|----------|
| **Logs: workspace** | workspace | Docker stdout/stderr → JSON log file | Fluent Bit → SigNoz Loki | 100% |
| **Logs: Bifrost** | bifrost | Docker stdout/stderr | Fluent Bit → SigNoz | 100% |
| **Logs: SigNoz** | observability-signoz | Docker stdout/stderr | Fluent Bit → SigNoz (self-referential) | 100% |
| **Logs: Fluent Bit** | observability-fluent-bit | Docker stdout/stderr | Fluent Bit forwards itself | 100% |
| **Logs: mcp-* (5×)** | mcp-{service} | Docker stdout/stderr | Fluent Bit → SigNoz | 100% |
| **Logs: qdrant** | database-qdrant | Docker stdout/stderr | Fluent Bit → SigNoz | 100% |
| **Logs: neo4j** | database-neo4j | Docker stdout/stderr | Fluent Bit → SigNoz | 100% |
| **Logs: vscode-server** | vscode-server | Docker stdout/stderr | Fluent Bit → SigNoz | 100% |
| **Logs: mcp-playwright** | mcp-playwright | Docker stdout/stderr | Fluent Bit → SigNoz | 100% |
| | | | **Subtotal Logs** | **100%** |
| | | | | |
| **Metrics: Bifrost** | bifrost | Native `/metrics` endpoint (:8080/metrics) | OTel Collector scrape → SigNoz | 100% |
| **Metrics: qdrant** | database-qdrant | Prometheus endpoint (:6333/metrics) | OTel Collector scrape → SigNoz | 100% |
| **Metrics: neo4j** | database-neo4j | Prometheus endpoint (flag enabled) | OTel Collector scrape → SigNoz | 100% |
| | | | **Subtotal Metrics** | **100%** |
| | | | | |
| **Traces: agent → Bifrost HTTP** | bifrost | Native OTLP (gRPC :4317) | → SigNoz | 100% |
| **Traces: PreLLMHook (compression)** | bifrost | OTLP sub-span inside PreLLMHook | → SigNoz | 100% |
| **Traces: PreLLMHook (memory injection)** | bifrost + qdrant | OTLP sub-span inside PreLLMHook | → SigNoz | 100% |
| **Traces: PreLLMHook (code-graph lookup)** | bifrost + neo4j | OTLP sub-span inside PreLLMHook | → SigNoz | 100% |
| **Traces: Bifrost → LLM provider** | bifrost | OTLP sub-span | → SigNoz | 100% |
| **Traces: mcp-* Node.js (5×)** | mcp-{service} | NODE_OPTIONS auto-instrumentation → OTLP | → SigNoz | 100% |
| **Traces: qdrant internal** | database-qdrant | Not instrumented (would require code changes) | — | 0% (acceptable; metrics cover latency) |
| **Traces: neo4j internal** | database-neo4j | Bolt protocol (binary, not HTTP; not traceable) | — | 0% (acceptable; metrics cover latency) |
| | | | **Subtotal Traces** | **~100% agent pipeline, ~50% overall** |
| | | | | |
| | | | **TOTAL OBSERVABILITY** | **~99% (all gaps are acceptable)** |

### Gap Analysis

| Gap | Why Acceptable |
|-----|----------------|
| qdrant internal traces | Prometheus metrics capture latency, throughput, error rates. Vector search timing visible in PreLLMHook span. |
| neo4j internal traces | Prometheus metrics and query logs capture performance. Graph lookup timing visible in PreLLMHook span. |
| mcp-playwright traces | Playwright generates JSON trace files. Browser automation latency visible in Node.js parent span. |

---

## Services to Add to docker-compose.yml

### Service 1: observability-signoz

**Role:** Unified observability backend (logs + metrics + traces)

```yaml
observability-signoz:
  image: signoz/signoz:latest
  container_name: signoz
  networks:
    - mcp
  ports:
    - "3301:3301"    # Web UI (accessible from host)
    - "4317:4317"    # OTLP gRPC receiver
    - "4318:4318"    # OTLP HTTP receiver
    - "3100:3100"    # Loki compatibility (logs)
    - "6831:6831/udp" # Jaeger UDP (optional)
  environment:
    - CLICKHOUSE_HOST=signoz-db
    - CLICKHOUSE_PORT=9000
    - OTEL_ENABLED=true
  volumes:
    - signoz-db-data:/var/lib/clickhouse
    - signoz-otel-config:/etc/otel/config.yaml
  depends_on:
    - signoz-db
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3301/health"]
    interval: 30s
    timeout: 10s
    retries: 3

signoz-db:
  image: clickhouse/clickhouse-server:latest
  container_name: signoz-db
  networks:
    - mcp
  environment:
    CLICKHOUSE_DB: signoz
  volumes:
    - signoz-db-data:/var/lib/clickhouse
```

**RAM:** 2–3 GB (all-in-one)  
**Key Features:**
- Loki log receiver (logs from Fluent Bit)
- OTLP collector (traces from Bifrost, mcp-* services)
- OTel Collector sidecar for Prometheus scraping
- Web UI at port 3301
- MCP server available (see configuration below)

---

### Service 2: observability-fluent-bit

**Role:** Lightweight log collection from all containers

```yaml
observability-fluent-bit:
  image: fluent/fluent-bit:latest
  container_name: fluent-bit
  networks:
    - mcp
  volumes:
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - ./fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf
  environment:
    - SIGNOZ_ENDPOINT=observability-signoz:3100
  depends_on:
    - observability-signoz
  healthcheck:
    test: ["CMD", "fluent-bit", "-c", "/fluent-bit/etc/fluent-bit.conf", "--dry-run"]
    interval: 30s
    timeout: 10s
    retries: 3
```

**RAM:** ~10 MB  
**Configuration File:** `fluent-bit.conf` (see below)

**fluent-bit.conf:**
```ini
[SERVICE]
    Flush                 5
    Daemon                Off
    Log_Level             info
    Parsers_File          parsers.conf

[INPUT]
    Name                  forward
    Listen                0.0.0.0
    Port                  24224

[INPUT]
    Name                  tail
    Path                  /var/lib/docker/containers/*/*.log
    Parser                docker
    Tag                   docker.*
    Refresh_Interval      10
    Mem_Buf_Limit         50MB

[FILTER]
    Name                  kubernetes
    Match                 docker.*
    Keep_Log              On
    K8S-Logging.Parser    On
    K8S-Logging.Exclude   On

[OUTPUT]
    Name                  loki
    Match                 *
    Host                  observability-signoz
    Port                  3100
    Labels                job=docker,host=${HOSTNAME}
    Auto_Kubernetes_Labels on
```

**Key Features:**
- Reads Docker container JSON logs directly
- Auto-discovers container metadata
- Forwards to SigNoz Loki endpoint
- Zero privileged container required

---

### Service 3: bifrost (replaces proxy-headroom)

**Role:** LLM gateway with native OTLP tracing and headroom callback

```yaml
bifrost:
  image: maximhq/bifrost:latest
  container_name: bifrost
  networks:
    - mcp
  ports:
    - "8080:8080"   # HTTP API
    - "9090:9090"   # Metrics (Prometheus)
  environment:
    - BIFROST_PORT=8080
    - BIFROST_CONFIG=/etc/bifrost/config.yaml
    - OTEL_EXPORTER_OTLP_ENDPOINT=http://observability-signoz:4317
    - OTEL_EXPORTER_OTLP_PROTOCOL=grpc
    - OTEL_SERVICE_NAME=bifrost
    # LLM provider keys (from host or .env)
    - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    - OPENAI_API_KEY=${OPENAI_API_KEY}
    - GOOGLE_API_KEY=${GOOGLE_API_KEY}
  volumes:
    - ./bifrost-config.yaml:/etc/bifrost/config.yaml
    - ./bifrost-plugins:/etc/bifrost/plugins
  depends_on:
    - observability-signoz
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 30s
    timeout: 10s
    retries: 3
```

**RAM:** 100–200 MB  
**Key Configuration:**
- Port 8080 (agents connect here instead of headroom)
- OTLP export to SigNoz
- Prometheus metrics on :9090
- Go plugin directory for PreLLMHook implementation

**bifrost-config.yaml (sketch):**
```yaml
server:
  port: 8080
  metrics:
    enabled: true
    port: 9090

providers:
  anthropic:
    api_key: ${ANTHROPIC_API_KEY}
  openai:
    api_key: ${OPENAI_API_KEY}
  google:
    api_key: ${GOOGLE_API_KEY}

plugins:
  pre_llm_hook:
    - name: headroom-callback
      path: /etc/bifrost/plugins/headroom_callback.so
      config:
        headroom_python_path: /usr/bin/python3
        headroom_script: /etc/bifrost/headroom_compress.py

observability:
  otlp:
    enabled: true
    endpoint: http://observability-signoz:4317
    protocol: grpc
```

---

## Environment Changes for Agents

### Update Agent Configuration

**Change:**
```bash
# OLD (headroom)
ANTHROPIC_BASE_URL=http://proxy-headroom:8787/v1
OPENAI_BASE_URL=http://proxy-headroom:8787/v1
GEMINI_API_BASE=http://proxy-headroom:8787/v1

# NEW (Bifrost)
ANTHROPIC_BASE_URL=http://bifrost:8080/v1
OPENAI_BASE_URL=http://bifrost:8080/v1
GEMINI_API_BASE=http://bifrost:8080/v1
```

### Node.js MCP Services: Enable Auto-Instrumentation

Add to all `mcp-*` services in docker-compose.yml:

```yaml
mcp-service-name:
  environment:
    - NODE_OPTIONS=--require @opentelemetry/auto-instrumentations-node/register
    - OTEL_EXPORTER_OTLP_ENDPOINT=http://observability-signoz:4317
    - OTEL_EXPORTER_OTLP_PROTOCOL=grpc
    - OTEL_SERVICE_NAME=mcp-service-name
```

**Install dependency** in Node.js Dockerfile:
```bash
npm install --save-dev @opentelemetry/auto-instrumentations-node
```

---

## Headroom Python SDK in Bifrost Callback — Disable External Telemetry

### Critical: Prevent Data Leakage

When the headroom Python SDK runs inside a Bifrost callback as a library/subprocess, it has its own telemetry systems that **must be disabled** to prevent:
- Data sent to external Langfuse cloud (`cloud.langfuse.com`)
- Data sent to headroom telemetry endpoints
- Duplicate tracing (Bifrost owns observability)
- External network calls from callback context

### Required Environment Variables

Set in the Bifrost Go plugin environment OR when spawning the headroom subprocess:

```bash
# Disable Langfuse cloud tracing
HEADROOM_LANGFUSE_ENABLED=false

# Disable headroom's native OTel metrics export
HEADROOM_OTEL_METRICS_ENABLED=false

# Disable headroom telemetry/analytics
HEADROOM_TELEMETRY_ENABLED=false

# Prevent headroom from starting its own proxy server
HEADROOM_SERVER_ENABLED=false
```

### Go Plugin Implementation Example

```go
// bifrost-plugins/headroom_callback.go
package main

import (
    "encoding/json"
    "os"
    "os/exec"
)

type PreLLMHookPayload struct {
    Messages []map[string]interface{} `json:"messages"`
}

// PreLLMHook is called before sending request to LLM
func PreLLMHook(ctx context.Context, req *PreLLMHookPayload) (*PreLLMHookPayload, error) {
    // Start headroom compression subprocess
    cmd := exec.Command("python3", "headroom_compress.py")
    
    // Disable external telemetry
    cmd.Env = append(os.Environ(),
        "HEADROOM_LANGFUSE_ENABLED=false",
        "HEADROOM_OTE_METRICS_ENABLED=false",
        "HEADROOM_TELEMETRY_ENABLED=false",
        "HEADROOM_SERVER_ENABLED=false",
    )
    
    // Serialize input
    inputBytes, _ := json.Marshal(req)
    cmd.Stdin = bytes.NewReader(inputBytes)
    
    // Capture output (compressed messages)
    output, err := cmd.Output()
    if err != nil {
        return nil, err
    }
    
    // Deserialize result
    var result PreLLMHookPayload
    json.Unmarshal(output, &result)
    
    // Bifrost OTLP layer captures this hook's duration automatically
    return &result, nil
}
```

### Why This Matters

1. **Security:** Prevents credentials or session tokens from leaving the container
2. **Data Governance:** Keeps observability data internal to SigNoz
3. **Compliance:** Avoids sending customer data to third-party cloud services
4. **Performance:** Eliminates network latency from telemetry exports during compression
5. **Observability Integrity:** Single source of truth (SigNoz), no competing telemetry systems

---

## SigNoz MCP Configuration

### Enable MCP Server in SigNoz

SigNoz released official MCP server May 1, 2026. Configure agents to use it:

**Agent Configuration (Claude, Gemini, Codex, Copilot):**

```json
{
  "tools": [
    {
      "type": "mcp",
      "name": "signoz",
      "endpoint": "http://observability-signoz:5678",
      "tools": [
        "signoz_search_logs",
        "signoz_aggregate_logs",
        "signoz_query_metrics",
        "signoz_list_metrics",
        "signoz_search_traces",
        "signoz_get_trace_details",
        "signoz_aggregate_traces"
      ]
    }
  ]
}
```

### Available MCP Tools

| Tool | Purpose | Example |
|------|---------|---------|
| `signoz_search_logs` | Full-text search logs by container, timestamp, level | `search_logs(query="ERROR", container="bifrost", limit=100)` |
| `signoz_aggregate_logs` | Group and count logs by field | `aggregate_logs(field="severity", filter="container=workspace")` |
| `signoz_query_metrics` | Query time-series metrics | `query_metrics(metric="bifrost_request_duration_ms", interval="5m")` |
| `signoz_list_metrics` | List available metrics | `list_metrics(filter="*latency*")` |
| `signoz_search_traces` | Find traces by criteria | `search_traces(service="bifrost", status="ERROR")` |
| `signoz_get_trace_details` | Drill into trace spans | `get_trace_details(trace_id="abc123", include_logs=true)` |
| `signoz_aggregate_traces` | Group traces by attribute | `aggregate_traces(group_by="http_status", service="bifrost")` |

**Use Case:** Agents can now query observability data:
- "Show me all error logs from the workspace container in the last hour"
- "What was the average Bifrost latency over the last 5 minutes?"
- "Get the trace for the last request that failed"

---

## Footprint Summary

### Resource Allocation

| Component | Image | RAM | CPU | Disk | Notes |
|-----------|-------|-----|-----|------|-------|
| observability-signoz | signoz:latest | 2–3 GB | 2–4 cores | 50 GB (ClickHouse) | All-in-one, scales with data retention |
| signoz-db | clickhouse:latest | 1–2 GB | 2 cores | 50 GB | ClickHouse time-series backend |
| observability-fluent-bit | fluent/fluent-bit:latest | 10 MB | 0.1 cores | 100 MB | Minimal, log buffering only |
| bifrost | maximhq/bifrost:latest | 100–200 MB | 1 core | 500 MB | Gateway + Go plugins loaded |
| **New Total Observability** | — | **3.1–3.4 GB** | **4–6 cores** | **100+ GB** | Replaces proxy-headroom (~50 MB saved) |

### Network Ports

| Service | Port | Protocol | Internal/External |
|---------|------|----------|-------------------|
| bifrost | 8080 | HTTP | Internal (agents) + optional external |
| bifrost | 9090 | HTTP | Internal (Prometheus scrape) |
| observability-signoz | 3301 | HTTP | External (Web UI) |
| observability-signoz | 4317 | gRPC | Internal (OTLP) |
| observability-signoz | 4318 | HTTP | Internal (OTLP) |
| observability-signoz | 3100 | HTTP | Internal (Loki) |
| observability-fluent-bit | 24224 | HTTP | Internal (log forwarding) |

---

## What This Stack Does NOT Cover

| Signal | Why Not Covered | Acceptable? | Alternative |
|--------|-----------------|-------------|-------------|
| HTTP-level traces (Bifrost → qdrant/neo4j) | Would require code instrumentation or eBPF sidecar (privileged) | Yes | Latency metrics from Prometheus cover SLA validation |
| Neo4j Bolt protocol traces | Binary protocol, not HTTP; requires client-side instrumentation | Yes | Prometheus metrics + query logs cover performance |
| Langfuse evals and prompt playground | Not an infrastructure tool; separate system for agent tuning | Yes | Add Langfuse separately when optimizing agent behavior |
| mcp-playwright detailed traces | Playwright generates JSON trace files, not OTLP | Yes | Trace files available for replay; parent Node.js span covers timing |

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)

1. Add SigNoz and Fluent Bit to docker-compose.yml
2. Deploy and verify logs are flowing (Fluent Bit → SigNoz Loki)
3. Verify metrics are scraped (qdrant, neo4j)
4. Test SigNoz Web UI access at :3301

**Validation:**
```bash
# Check logs in SigNoz
curl http://localhost:3301  # Web UI
# Fluent Bit should forward logs; check SigNoz Logs tab
```

### Phase 2: LLM Gateway (Week 2)

1. Deploy Bifrost container
2. Implement PreLLMHook Go plugin calling headroom Python SDK
3. Update agent env vars to point to Bifrost instead of headroom
4. Disable external telemetry in headroom SDK (see section above)
5. Verify Bifrost OTLP traces appear in SigNoz

**Validation:**
```bash
# Test agent request through Bifrost
curl -X POST http://bifrost:8080/v1/chat/completions \
  -H "Authorization: Bearer $ANTHROPIC_API_KEY" \
  -d '{"model": "claude-opus", "messages": [{"role": "user", "content": "test"}]}'

# Check Bifrost metrics
curl http://bifrost:9090/metrics

# Check trace in SigNoz
# Traces tab → service: bifrost → see PreLLMHook spans
```

### Phase 3: Node.js Auto-Instrumentation (Week 3)

1. Add NODE_OPTIONS and OTEL env vars to all mcp-* services
2. Install @opentelemetry/auto-instrumentations-node dependency
3. Verify Node.js traces appear in SigNoz
4. Validate full trace chain (agent → Bifrost → LLM)

**Validation:**
```bash
# mcp-* services should emit traces
# Check SigNoz Traces tab → service: mcp-service-name
```

### Phase 4: Integration & SigNoz MCP (Week 4)

1. Enable SigNoz MCP server
2. Configure agents with signoz MCP endpoint
3. Test agent queries: `signoz_search_logs`, `signoz_search_traces`, etc.
4. Full end-to-end test: agent → Bifrost → LLM, query observability via MCP

**Validation:**
```bash
# Agent can query observability
# Agent prompt: "What were the last 10 errors in the workspace container?"
# Calls signoz_search_logs internally
```

---

## Success Criteria

### Logs
- [ ] Fluent Bit running, reading `/var/lib/docker/containers`
- [ ] All container logs visible in SigNoz (≥8 sources)
- [ ] Log retention ≥7 days

### Metrics
- [ ] Bifrost /metrics scraped every 30s
- [ ] qdrant /metrics scraped every 30s
- [ ] neo4j /metrics scraped every 30s
- [ ] Dashboards display latency, throughput, error rates

### Traces
- [ ] Bifrost OTLP traces flowing to SigNoz
- [ ] PreLLMHook spans visible (compression, memory, code-graph sub-spans)
- [ ] Node.js mcp-* services emitting traces
- [ ] Full trace visualization in SigNoz UI

### MCP Integration
- [ ] SigNoz MCP server responding to signoz_* tools
- [ ] Agents can search logs and traces via MCP
- [ ] Agents can query metrics via MCP

### Production Readiness
- [ ] Zero `privileged: true` in docker-compose.yml
- [ ] Security scans (Trivy) pass with no Critical issues
- [ ] Footprint ≤4 GB RAM (acceptable overhead)
- [ ] Documentation complete for ops team

---

## Next Steps

1. **Review & Approval:** Stakeholder sign-off on architecture
2. **Spike Implementation:** Build Bifrost PreLLMHook plugin; test headroom SDK callback
3. **Deploy to Dev:** Add services to docker-compose.yml; validate logs/metrics/traces
4. **Integration Testing:** Full request flow with observability capture
5. **Documentation:** Runbooks for troubleshooting, dashboards, alerting rules
6. **Production Rollout:** Stage → prod with monitoring
