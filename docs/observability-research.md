# Observability Tooling Research — zzaia-agentic-workspace

**Date:** May 2026  
**Scope:** Comprehensive evaluation of observability tools for Docker Compose multi-container AI agent workspace

---

## System Context

### Stack Overview

- **Workspace Container:** Ubuntu 24.04, AI agents (Claude, Gemini, Codex, Copilot)
- **LLM Proxy:** proxy-headroom (ghcr.io/chopratejas/headroom:latest, port 8787)
- **Vector Database:** database-qdrant (port 6333)
- **Graph Database:** database-neo4j (port 7687)
- **MCP Services:** 5× mcp-* (node:lts-alpine + supergateway)
- **Browser Automation:** mcp-playwright
- **Development Environment:** vscode-server
- **Network:** Single Docker bridge network named `mcp`

### Current Observability Gaps

- No centralized logging infrastructure
- No metrics collection or aggregation
- No distributed tracing across containers
- No visibility into LLM request pipelines
- No performance metrics for vector/graph database operations

---

## Tools Evaluated

### Grafana

**Role:** Visualization and dashboard platform  
**RAM:** ~256 MB  
**MCP Support:** Official MCP server (2025), queries Prometheus + Loki via MCP interface  
**Capabilities:**
- Web UI for metric and log visualization
- Query builder for PromQL and LogQL
- Alert rule engine
- Dashboard templating and annotations

**Limitations:**
- Not a data source itself; requires Prometheus for metrics, Loki for logs
- No native trace visualization (requires integration with Jaeger/Tempo)

---

### Prometheus

**Role:** Metrics scraping and time-series database  
**RAM:** 256–512 MB  
**Integration:** Reachable via Grafana MCP interface  
**Capabilities:**
- Scrapes `/metrics` endpoints from instrumented services
- Time-series data storage with compression
- Alert evaluation and rule firing
- PromQL query language

**Limitations:**
- High memory usage with high-cardinality metrics (many unique label combinations)
- No built-in support for logs or traces
- Retention window bounded by disk space

---

### Loki + Promtail

**Role:** Log aggregation and query system  
**Loki RAM:** ~1 GB  
**Promtail RAM:** ~50–100 MB  
**Log Collection:** Promtail reads `/var/lib/docker/containers/<container-id>/<container-id>-json.log` via read-only volume mount — **zero privileged containers required**

**Capabilities:**
- Centralized log collection from all containers
- LogQL query language (similar syntax to PromQL)
- Label-based log filtering and aggregation
- Retention policies and compression

**Advantages:**
- Low overhead per container
- Can run without elevated privileges
- Works with Docker's native JSON logging driver

---

### Fluent Bit

**Role:** Lightweight log collection and forwarding  
**RAM:** 8–10 MB  
**Log Collection:** Reads Docker JSON log files via read-only volume mount  
**Outputs:** Can forward logs to Loki, SigNoz, Elasticsearch, Splunk, or other backends

**Capabilities:**
- Minimal memory footprint
- Auto-discovers container metadata (name, image, labels)
- Filter, parse, and enrich logs before forwarding
- Structured log output (JSON)

**Advantages:**
- Extremely lightweight compared to Promtail
- Single unified log pipeline to any backend
- No privileged container required

---

### Jaeger All-in-One

**Role:** Distributed tracing backend  
**RAM:** 512 MB–2 GB  
**OTLP Support:** Native OTLP on ports 4317 (gRPC) and 4318 (HTTP)  
**UI:** Dedicated trace UI on port 16686

**Capabilities:**
- Receives and stores distributed traces
- Span visualization with latency breakdown
- Service dependency graph generation
- Trace search and filtering

**Limitations:**
- No MCP server available
- No native Prometheus metrics support
- Trace UI less feature-rich than commercial solutions
- No log correlation

---

### Grafana Tempo

**Role:** Lightweight tracing backend  
**RAM:** 200–500 MB  
**OTLP Support:** Native OTLP on ports 4317 (gRPC) and 4318 (HTTP)  
**Integration:** Native Grafana datasource

**Capabilities:**
- Minimal footprint for trace storage
- Integrates directly with Grafana dashboards
- Trace correlation with Loki logs

**Limitations:**
- No MCP server available
- Requires Grafana for visualization
- No built-in trace UI

---

### SigNoz

**Role:** Unified observability platform (logs + metrics + traces)  
**RAM:** 2–3 GB (all-in-one)  
**Backend:** ClickHouse (time-series database)  
**Collector:** Ships with internal `signoz-otel-collector`  
**OTLP Support:** Native OTLP on ports 4317 (gRPC) and 4318 (HTTP)  
**MCP Server:** Official MCP server released May 1, 2026  
  - GitHub: SigNoz/signoz-mcp-server  
  - Written in Go

**MCP Tools Available:**
- `signoz_search_logs` — full-text search and filter logs
- `signoz_aggregate_logs` — group and aggregate log metrics
- `signoz_query_metrics` — query time-series metrics
- `signoz_list_metrics` — enumerate available metric names
- `signoz_search_traces` — find traces by filter criteria
- `signoz_get_trace_details` — retrieve full trace with spans
- `signoz_aggregate_traces` — group and analyze traces

**Capabilities:**
- Unified UI for logs, metrics, and traces
- ClickHouse backend for scalability
- Built-in alerting and anomaly detection
- Docker Compose self-hosted deployment
- Cost attribution per service/span

**Advantages:**
- Single system for all observability signals
- MCP integration allows agents to query observability data
- Production-ready self-hosted option

---

### Grafana Beyla

**Role:** eBPF-based zero-code auto-instrumentation  
**RAM:** ~80 MB per instance  
**CPU Overhead:** 0.4–1.2% per instance  
**Language Support:** Go, Python, Node.js, Java, .NET, Rust, C/C++

**Capabilities:**
- Intercepts HTTP/gRPC traffic between containers without code changes
- Generates distributed traces from network calls
- Works with any OTLP backend (Jaeger, SigNoz, Grafana Tempo)

**Execution Models:**
- As Docker Compose sidecar with `pid: "service:<target>"` — traces one target
- Can run 1:1 with each service for complete coverage

**Privilege Requirements:**
- Requires either `privileged: true` OR specific Linux capabilities
- Capabilities: `SYS_ADMIN`, `BPF`, `PERFMON`, `NET_ADMIN`
- Note: Even with capabilities, not all cloud providers allow `SYS_ADMIN`

**Limitations:**
- Cannot trace internal service→service calls (qdrant internal, neo4j internal)
- Captures HTTP/gRPC only; binary protocols (Neo4j Bolt) not visible
- Debugging eBPF issues can be complex

---

### Envoy Proxy

**Role:** HTTP proxy with native OTLP tracing  
**Privilege:** Zero privileged containers required  
**Trace Output:** Native OTLP to any backend (SigNoz, Jaeger, Tempo)

**Capabilities:**
- Can sit in front of headroom (proxy-headroom) to trace workspace→headroom HTTP calls
- Emits traces for request/response latency, HTTP status, request size, response size
- Request/response header and body logging (optional)
- Can route to multiple backends based on headers

**Limitations:**
- Only traces calls passing through the proxy
- Cannot trace internal headroom→qdrant/neo4j calls unless proxy sits in front of each

**Use Case in Workspace:**
- Replace or sit in front of headroom on port 8787
- Trace all agent→LLM requests with timing and status codes
- Forward traces to SigNoz OTLP endpoint

---

### OTel Collector (otel/opentelemetry-collector-contrib)

**Role:** Standardized telemetry collection and processing  
**RAM:** ~200–500 MB  
**Image:** `otel/opentelemetry-collector-contrib:latest`

**Capabilities:**
- Receives OTLP from instrumented services (gRPC + HTTP)
- Scrapes Prometheus `/metrics` endpoints
- Processes and enriches telemetry (batching, sampling, attribute mutation)
- Exports to multiple backends (SigNoz, Datadog, Splunk, etc.)

**Limitations:**
- Requires application instrumentation or separate eBPF agent to capture traces
- Cannot intercept network traffic on its own
- Bridges metrics from services but not traces from uninstrumented services

---

### Langfuse

**Role:** LLM-specific observability and evaluation platform  
**RAM:** 500 MB–1 GB  
**Scope:** Not an infrastructure observability tool — complements SigNoz/Jaeger

**Capabilities:**
- Captures LLM prompt/response content (structured format)
- Token count tracking per request
- Cost calculation per model and API call
- Session tree visualization for multi-turn interactions
- Evaluation/scoring framework (human and automated)
- Prompt playground for experimentation
- Human annotation and feedback loops
- Dataset creation for fine-tuning

**Integration Points:**
- SDK: `langfuse==2.x` Python package
- Headroom can emit Langfuse traces via `HEADROOM_LANGFUSE_ENABLED=true`
- Bifrost LLM gateway can call Langfuse API to log requests

**Use Case:**
- For agent development and tuning — not for infrastructure monitoring
- Best paired with SigNoz for complete observability

**MCP Server:** No official MCP server currently available

---

### Bifrost (Maxim AI)

**Role:** LLM gateway/proxy with observability and context compression  
**RAM:** 100–200 MB  
**License:** Apache 2.0 (open source)  
**Language:** Go  
**Latency Overhead:** ~11µs (50× faster than LiteLLM)

**Capabilities:**
- Routes requests to 20+ LLM providers (Anthropic, OpenAI, Google, Azure, etc.)
- Virtual keys and budget management
- Cost tracking and attribution per request
- Request/response logging
- OTLP trace export (gRPC + HTTP)
- Prometheus `/metrics` endpoint
- Plugin system: Go native plugins + WASM
- MCP gateway mode (client + server)

**Plugin Architecture:**
- Hooks: `PreLLMHook`, `PostLLMHook`, `HTTPTransportPreHook`, `HTTPTransportPostHook`
- Go plugins compiled at runtime
- WASM plugin support for safety isolation

**Docker:** `docker run -p 8080:8080 maximhq/bifrost`

**Replacement for headroom:**
- Bifrost can replace proxy-headroom entirely
- Headroom Python SDK can run inside a Bifrost PreLLMHook for context compression, memory injection, and code-graph lookup
- All timing is traced in OTLP

**Integration with Headroom:**
- Bifrost Go plugin (PreLLMHook) calls headroom Python SDK as subprocess
- headroom.compress(messages) applies context compression
- Memory injection from Qdrant called inside the hook
- Code-graph lookup from Neo4j called inside the hook
- Bifrost traces the entire pipeline including compression duration as a span
- Result: Full observability of compression time, memory latency, and code-graph latency

**OTLP Configuration:**
```bash
BIFROST_OTEL_EXPORTER_OTLP_ENDPOINT=http://observability-signoz:4317
```

---

## OTLP Trace Support Analysis

### By Container — Zero-Code Coverage

| Service | OTLP Native | Method | Notes |
|---------|-------------|--------|-------|
| proxy-headroom | Partial | ENV vars | `HEADROOM_OTEL_METRICS_ENABLED` (metrics only). Traces via Langfuse SDK (Langfuse only). No generic OTLP trace export. |
| Bifrost | Yes | Native | Full OTLP trace export on gRPC + HTTP. Includes PreLLMHook sub-spans. |
| database-qdrant | No | Metrics only | Prometheus `/metrics` on :6333. Metrics via OTel Collector scrape. No trace export. |
| database-neo4j | No | Metrics only | Prometheus metrics with `metrics.prometheus.enabled=true`. No OTLP. |
| mcp-* (5 Node.js services) | Yes | NODE_OPTIONS | `NODE_OPTIONS=--require @opentelemetry/auto-instrumentations-node/register` + `OTEL_EXPORTER_OTLP_ENDPOINT` env vars. Full zero-code instrumentation. |
| mcp-playwright | No | File traces only | Playwright generates JSON trace files. No OTLP export. |
| workspace / vscode-server | No | Custom image | No OTLP in base image. Would require SDK installation. |

### Summary

- **Traces (agent→LLM pipeline):** 100% coverage via Bifrost native OTLP
- **Traces (Node.js MCP services):** 100% coverage via NODE_OPTIONS auto-instrumentation
- **Traces (qdrant/neo4j internals):** 0% (covered by metrics instead)
- **Metrics (all services):** 100% via Prometheus scrape + OTLP Collector

---

## Privileged Container Risks in Production

### Why `privileged: true` is Dangerous

| Risk | Impact | Compliance |
|------|--------|-----------|
| Container escape → root on host | Full compromise of host OS | Critical failure |
| Access to all host devices | Kernel exploit exposure | PCI DSS, SOC2 failure |
| Can mount arbitrary host filesystems | Data exfiltration | ISO 27001 failure |
| Can load kernel modules | Persistence and lateral movement | CIS Benchmark failure |
| Bypasses SELinux/AppArmor | Security policy void | NIST CSF failure |

### CI/CD Impact

- Security scanners (Trivy, Snyk, Prisma Cloud) flag `privileged: true` as **CRITICAL**
- Blocks image promotion to production registries
- Fails most enterprise compliance checks
- Unacceptable in cloud-hosted environments (AWS ECS, GKE, AKS)

### Acceptable Use Cases

- **Local development only** — acceptable on developer machines
- **Not acceptable:** staging, production, or shared infrastructure

---

## Docker Log Collection — Zero Privilege Approach

### Mechanism

Both Fluent Bit and Promtail can read Docker container logs **without privileged containers:**

1. Docker daemon writes container stdout/stderr to `/var/lib/docker/containers/<container-id>/<container-id>-json.log`
2. Log shipper mounts `/var/lib/docker/containers` as **read-only** bind mount
3. Reads JSON log files directly; no Docker API calls or socket mounting needed
4. Auto-extracts container metadata from log file path

### Configuration Example

```yaml
volumes:
  - /var/lib/docker/containers:/var/lib/docker/containers:ro
  - /var/run/docker.sock:/var/run/docker.sock:ro  # optional, for container metadata
```

### Alternative: Docker Loki Logging Driver

- Configure Docker daemon to push logs directly to Loki
- No agent needed
- Centralized configuration in `daemon.json`
- Automatic label mapping

---

## Headroom SDK in Bifrost Callback Architecture

### Request Flow

```
Workspace Agent
  ↓ ANTHROPIC_BASE_URL / OPENAI_BASE_URL / GEMINI_API_BASE
Bifrost LLM Gateway (:8787)
  ↓ Request received
Bifrost PreLLMHook (Go plugin)
  ├─ Call headroom Python SDK (subprocess or library)
  │   ├── headroom.compress(messages)        # Context compression
  │   ├── headroom.inject_memory(...)        # Query Qdrant vector DB
  │   └── headroom.lookup_code_graph(...)    # Query Neo4j graph DB
  │
  └─ Return enriched messages
  ↓ Enriched request to LLM
LLM Provider API
  ↓ Response
Bifrost PostLLMHook (optional)
  └─ Cost tracking, response logging
  ↓ Response to Agent

Bifrost → OTLP → SigNoz
  (includes PreLLMHook sub-spans with durations)
```

### Observability Integration

- **Compression time:** Captured in PreLLMHook span duration
- **Memory injection latency:** Sub-span under PreLLMHook
- **Code-graph lookup latency:** Sub-span under PreLLMHook
- **LLM request/response:** Main span under Bifrost
- **Cost attribution:** Bifrost metadata spans

**Result:** Full end-to-end visibility of agent→compression→memory→code-graph→LLM pipeline

---

## Langfuse vs Bifrost Observability Overlap

| Signal | Bifrost | Langfuse |
|--------|---------|----------|
| Prompt/response logging | Yes | Yes |
| Token counts | Yes | Yes |
| Cost per request | Yes | Yes |
| OTLP traces | Yes | No |
| Request/response timing | Yes | Yes |
| Session/conversation tree | No | Yes |
| Evaluation/scoring framework | No | Yes |
| Prompt playground | No | Yes |
| Human annotation | No | Yes |
| Dataset creation | No | Yes |
| Infrastructure focus | Yes | No |
| LLM tuning focus | No | Yes |

### When to Use Each

- **Bifrost alone:** Infrastructure observability, cost tracking, request routing, context compression timing
- **Langfuse + Bifrost:** Agent prompt tuning, evals, feedback loops, fine-tuning datasets
- **For dev workspace (infrastructure focus):** Bifrost + SigNoz sufficient
- **Add Langfuse later** when optimizing agent behavior and prompt engineering

---

## Summary Table: All Tools Evaluated

| Tool | Primary Role | RAM | Privileged | MCP | OTLP Native | Key Advantage |
|------|--------------|-----|-----------|-----|-------------|---------------|
| Grafana | Visualization | 256 MB | No | Yes | No | Dashboard UI for metrics/logs |
| Prometheus | Metrics DB | 256–512 MB | No | No | No | Industry standard metrics |
| Loki + Promtail | Log aggregation | ~1 GB | No | No | No | LogQL query language |
| Fluent Bit | Log forwarding | 8–10 MB | No | No | No | Ultra-lightweight shipper |
| Jaeger | Tracing | 512 MB–2 GB | No | No | Yes | Distributed trace UI |
| Tempo | Trace DB | 200–500 MB | No | No | Yes | Minimal footprint |
| SigNoz | Unified observability | 2–3 GB | No | Yes | Yes | Logs + metrics + traces + MCP |
| Beyla | eBPF tracing | 80 MB | Partial | No | No | Zero-code HTTP/gRPC traces |
| Envoy | HTTP proxy + tracing | Variable | No | No | Yes | Layer 7 visibility |
| OTel Collector | Telemetry pipeline | 200–500 MB | No | No | Yes | Standardized collection |
| Langfuse | LLM-specific obs | 500 MB–1 GB | No | No | No | Evals + prompt playground |
| Bifrost | LLM gateway + traces | 100–200 MB | No | No | Yes | Headroom callback integration |
