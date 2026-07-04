---
name: ZZAIA Agentic Workspace — LLM API Cost & Account Longevity Recommendations
date: 2026-07-02
version: 1.0
scope: ZZAIA multi-agent orchestration system (feature/improve-agentic-system)
status: Proposed
---

# ZZAIA Agentic Workspace — LLM API Cost & Account Longevity Recommendations

Prioritized research and recommendations for reducing LLM API costs and protecting account health in the ZZAIA multi-agent orchestration system. Identifies gaps in the existing Bifrost credential pooling and Headroom optimization stack, then proposes targeted interventions (model routing, spend caps, cost attribution, cache control enforcement, local fallback) ranked by impact and implementation effort. This document complements the finalized optimization stack (RTK, Headroom triple-stack, OpenMemory, CodeGraphContext) with provider-layer controls and observability.

---

## Architecture Overview

The ZZAIA system routes all LLM requests through a Bifrost credential pooling layer (ADR 008, 013) before forwarding to Headroom's optimization proxy (ADR 001 et al.). Today, Bifrost handles credential rotation and circuit-breaking for 401/429 errors, while Headroom manages context compression and memory injection. However, neither layer currently:

- **Routes requests by task complexity** — all requests pay full Sonnet/Opus cost regardless of task scope
- **Enforces spend caps or budget alerts** — circuit-breaker reacts to 429 *after* the provider sees the request, not before budget is spent
- **Handles 529 (overloaded) gracefully** — no separate backoff strategy for capacity pressure
- **Guarantees cache_control injection** — Anthropic's prompt caching feature is opt-in per-agent and not centrally enforced
- **Attributes costs to agents or sessions** — SigNoz observability (ADR 016) covers infrastructure metrics only, not $ per task

This document proposes four high-priority interventions and three medium-priority refinements to close these gaps.

---

## Already Implemented (Context)

The following capabilities are already operational and require no remediation:

- **RTK shell compression** (ADR 010): 81% average token reduction on command outputs via bash hooks
- **Headroom triple-stack** (ADR 011): HTTP reverse proxy with context compression, session memory injection, and code-graph indexing; deployed with `--memory --code-graph`
- **Bifrost credential pooling and rotation** (ADR 008, 013): Multi-key rotation, 401/429 circuit-breaker, per-provider credential scoping
- **Vault secret isolation** (ADR 002, 004): Credential storage and injection via HashiCorp Vault
- **SigNoz observability stack** (ADR 016): Infrastructure-level monitoring (container CPU, memory, network); does NOT include LLM cost attribution
- **OpenMemory MCP** (ADR 012): Supplementary structured memory queries via agent-initiated MCP tools
- **CodeGraphContext MCP** (ADR 003): Supplementary code graph queries for call-graph and symbol navigation

No changes to these components are required by this recommendation. Cost and longevity interventions build on top.

---

## Implementation Phases

**Phase 1 (Implement First)**: Model routing — reuse existing Bifrost layer, add a simple classifier or static rule router. Highest $ impact, moderate effort. Unblocks cost attribution.

**Phase 2 (Implement After Phase 1)**: Spend caps and cost attribution — add virtual-key-level budget scoping in Bifrost + plug in Helicone or Langfuse for cost-per-agent tracking. Prerequisite for visibility.

**Phase 3 (Implement After Phase 1)**: 529 (overloaded) handling — extend Bifrost circuit-breaker with exponential backoff strategy. Low risk, cheap insurance against capacity-pressure cascades.

**Phase 4 (Implement After Phase 2)**: Anthropic cache_control enforcement — add Bifrost-level cache breakpoint injection and validation. Ties to OpenCode credential scoping work.

**Phase 5 (Implement After Phases 1–4)**: Local model fallback + sub-agent context isolation. Incremental, lower impact.

---

## Recommendation 1: Model Routing and Task Complexity Cascading

**Decision**: Add a router layer in front of Bifrost that classifies incoming requests by task complexity and routes to appropriate model tiers (Haiku → Sonnet → Opus), using either a trained classifier (RouteLLM-style) or static rules (simpler, faster to deploy).

**What it does**:
- Intercepts all agent requests before Bifrost sends them downstream
- Applies a routing strategy: classify request by task (e.g., task-clarifier, doc-specialist → Haiku; developer-specialist, tech-leader → Sonnet; edge cases → Opus)
- Routes each request to a corresponding credential pool within Bifrost (separate Haiku keys, Sonnet keys, Opus keys)
- Falls back to higher tier if lower tier fails (429, 401, 529)
- Logs routing decision for later cost attribution per agent

**Implementation approach**:

*Option A (Fast path — static rules, ~1 week)*:
```yaml
router:
  image: custom-llm-router:latest  # simple HTTP server
  environment:
    - ROUTING_RULES=config/routing.yaml  # see below
  expose:
    - "8888"
  depends_on:
    - bifrost
```

Example routing config (`config/routing.yaml`):
```yaml
routes:
  task_clarifier:
    primary: claude-3-5-haiku-20241022
    fallback: [claude-3-5-sonnet-20241022]
    max_tokens: 512
  doc_specialist:
    primary: claude-3-5-haiku-20241022
    fallback: [claude-3-5-sonnet-20241022]
    max_tokens: 1024
  developer_specialist:
    primary: claude-3-5-sonnet-20241022
    fallback: [claude-3-opus-20250729]
    max_tokens: 8192
  tech_leader:
    primary: claude-3-5-sonnet-20241022
    fallback: [claude-3-opus-20250729]
    max_tokens: 12000
  code_reviewer:
    primary: claude-3-5-sonnet-20241022
    fallback: [claude-3-opus-20250729]
    max_tokens: 8192
  default:
    primary: claude-3-5-sonnet-20241022
    fallback: [claude-3-opus-20250729]
```

*Option B (ML-based, 2–3 weeks)*:
- Fine-tune RouteLLM (arxiv 2406.18665) classifier on ZZAIA agent logs to predict which agent requests need Haiku vs. Sonnet vs. Opus
- Deploy as a TensorFlow Serving or ONNX Runtime sidecar
- Training data: existing Bifrost request logs tagged with {agent, model, success, latency}

**Rationale**: RouteLLM demonstrated 85% cost savings while preserving 95% GPT-4-Turbo quality on MT Bench (Ong et al., 2024). Production routers (Not Diamond, Martian) claim 20–97% savings with similar quality preservation on customer workloads. For ZZAIA specifically:
- task-clarifier and doc-specialist are inherently simpler (structured analysis, document parsing); Haiku is sufficient and costs ~60% less than Sonnet
- developer-specialist and tech-leader need reasoning depth; Sonnet is the sweet spot
- code-reviewer can use Sonnet for most cases, Opus only for edge cases

Static rules are faster to deploy and tune by hand (watch agent logs for 1–2 weeks). Option B (trained classifier) is more adaptive but requires 2–3 weeks of setup.

**Infrastructure**: 
- Reuse Bifrost's existing multi-key credential pools (ADR 008, 013) — no new provider accounts
- Router sits between agent clients and Bifrost; agents point their `ANTHROPIC_BASE_URL` to `http://router:8888`, router forwards to `http://bifrost:8000`
- No new databases or external services; routing decisions logged to Bifrost's existing request ledger

**Estimated impact**: 30–50% reduction in API costs (assuming Haiku:Sonnet:Opus cost ratio of 1:3:6 and task-clarifier/doc-specialist are ~40% of total request volume).

---

## Recommendation 2: Hard Spend Caps and Budget Alerts

**Decision**: Add per-session and per-day token/$ ceiling enforcement at the Bifrost virtual-key level, rejecting or throttling requests *before* they reach the upstream provider.

**What it does**:
- Tracks cumulative tokens or $ spent per session, per day, per agent within Bifrost
- Rejects new requests if adding them would exceed a configured budget
- Emits alerts (log, SigNoz metric, webhook) when spend approaches 80%, 95%, 100% of budget
- Supports hierarchical scoping: virtual-key → agent → session → provider

**Implementation approach**:

Use **Portkey** (open-source gateway, built-in budget scoping) or **LiteLLM** (open-source multi-provider router with budget routing mode):

```yaml
bifrost-with-budget:
  image: portkey/gateway:latest
  environment:
    - DATABASE_URL=postgresql://user:pass@postgres:5432/portkey
    - REDIS_URL=redis://redis:6379
  config:
    virtual_keys:
      - key: haiku-pool-001
        provider: anthropic
        credentials: [${ANTHROPIC_API_KEY_1}, ${ANTHROPIC_API_KEY_2}]
        budget:
          daily_tokens: 1000000  # ~$0.30 at Haiku rates
          session_tokens: 100000  # ~$0.03 per agent session
          alert_thresholds: [0.80, 0.95]
      - key: sonnet-pool-001
        provider: anthropic
        credentials: [${ANTHROPIC_API_KEY_3}, ${ANTHROPIC_API_KEY_4}]
        budget:
          daily_tokens: 5000000  # ~$1.50 at Sonnet rates
          session_tokens: 500000
          alert_thresholds: [0.80, 0.95]
      - key: opus-pool-001
        provider: anthropic
        credentials: [${ANTHROPIC_API_KEY_5}]
        budget:
          daily_tokens: 500000  # ~$1.50 at Opus rates (expensive)
          session_tokens: 50000
          alert_thresholds: [0.50, 0.80]  # stricter for expensive model
```

**Rationale**: ADR 013's circuit-breaker only reacts to 429/401 *after* the provider has processed the request. A budget cap prevents runaway agent loops from burning the entire monthly budget in minutes. Portkey's hierarchical scoping lets you set per-agent budgets (task-clarifier = $10/day, tech-leader = $50/day) and per-session budgets (prevent a single orchestrator run from exceeding $500).

**Integration**:
- Replaces or wraps the existing Bifrost layer (both use HTTP + credential pooling)
- All agents and router point `ANTHROPIC_BASE_URL=http://portkey-gateway:8000` instead of current Bifrost URL
- Portkey exposes budget metrics to SigNoz via Prometheus endpoint (`/metrics`)
- Alerts integrate with existing SigNoz dashboard (ADR 016)

**Estimated impact**: Prevents catastrophic overruns; enables per-agent cost accountability. No direct savings, but budgets force optimization focus (e.g., "task-clarifier hit $10 budget — why?" → triggers investigation of unnecessary reruns or context inflation).

---

## Recommendation 3: Graceful 529 (Overloaded) Handling

**Decision**: Extend the Bifrost circuit-breaker (ADR 013) to treat HTTP 529 (service overloaded) separately from 401/429, applying exponential backoff + jitter with a capped retry limit, then failing over to alternative pools.

**What it does**:
- Detects 529 responses from Anthropic API
- Applies exponential backoff: wait 1s, then 2s, 4s, 8s, 16s (capped at 5 retries, ~30s total)
- Adds jitter (±20% random) to prevent thundering herd
- After final retry, fails over to next credential pool (if available) instead of returning error immediately
- Logs 529 event with timestamp for SigNoz dashboard (separate from 429/401 metrics)

**Implementation approach**:

Extend Bifrost's retry middleware (ADR 013):
```python
async def bifrost_retry_middleware(request, call_next):
    """Circuit-breaker with 529 handling."""
    max_retries = {
        401: 0,  # don't retry auth errors
        429: 3,  # existing circuit-breaker for rate-limit
        529: 5,  # new: retry capacity errors aggressively
    }
    
    for attempt in range(max_retries.get(response.status_code, 1)):
        try:
            response = await call_upstream(request)
            if response.status_code != 529:
                return response
            
            # 529-specific handling
            wait_time = min(2 ** attempt * (1 + random.uniform(-0.2, 0.2)), 30)
            logger.warning(f"529 capacity error; waiting {wait_time:.1f}s before retry")
            metrics.counter("bifrost.529", tags={"pool": pool_id})
            await asyncio.sleep(wait_time)
        except Exception as e:
            # final retry exhausted, try next pool
            if attempt == max_retries[529] - 1:
                logger.error(f"529 retries exhausted for {request.path}; failing over")
                return await bifrost_failover_pool()
            continue
    
    return response
```

**Rationale**: 529 is not an account or rate-limit issue — it signals Anthropic's API is under capacity load. The default HTTP behavior (fail fast) is incorrect here. Exponential backoff with jitter is the standard pattern for capacity backpressure (TCP congestion control, Kubernetes pod eviction). Capping retries at 5 (~30s) prevents indefinite waits for runaway requests.

**Infrastructure**: No new services; modifies existing Bifrost error handling code. Logs metrics to SigNoz for visibility into Anthropic API capacity events.

**Estimated impact**: Increases availability during Anthropic API capacity events; prevents cascading agent failures. Unmeasured but likely prevents 1–2 critical incidents per quarter (based on Anthropic API incident history).

---

## Recommendation 4: Anthropic cache_control Enforcement

**Decision**: Add Bifrost-level validation and injection of `cache_control` breakpoints to ensure Anthropic's prompt caching feature is systematically applied across all Claude Code and OpenCode traffic.

**What it does**:
- Bifrost intercepts all Anthropic API calls and checks for `cache_control` in the request
- If missing, injects a default `cache_control` for known high-cache-hit patterns (system prompts, code snippets, documentation)
- Validates cache control syntax and compatibility (cache_control only valid on Claude 3.5 Sonnet / Opus, not Haiku)
- Logs cache injection decisions to SigNoz for audit

**Implementation approach**:

```python
async def bifrost_cache_control_middleware(request: Request, call_next):
    """Inject cache_control for known high-hit patterns."""
    body = json.loads(request.body)
    
    # Identify high-cache-hit patterns
    cache_eligible = (
        "cache_control" not in body and  # not already set
        any(msg["role"] == "system" for msg in body.get("messages", [])) and
        body.get("model") in ["claude-3-5-sonnet-20241022", "claude-3-opus-20250729"]
    )
    
    if cache_eligible:
        # Add cache control to system message
        for msg in body["messages"]:
            if msg["role"] == "system":
                msg["cache_control"] = {"type": "ephemeral"}
                metrics.counter("bifrost.cache_control_injected", tags={"agent": agent_id})
                break
    
    return await call_next(request)
```

**Rationale**: Anthropic's prompt caching reduces cost by ~90% for subsequent requests with the same (cached) prompt prefix. OpenCode known issues (#20110, #14642) document that agents sometimes forget to set `cache_control` on eligible requests. Bifrost can enforce this centrally, ensuring no request is accidentally left uncached.

**CRITICAL NOTE**: OpenCode must use a **dedicated, non-pooled API key** (not shared via Bifrost credential pooling in ADR 008) for two reasons:
1. **ToS compliance**: Anthropic's terms require OpenCode traffic to use a distinct key for billing/attribution separation
2. **Cache-scoping integrity**: Prompt caching is scoped per API key; mixing OpenCode and Claude Code on a single pooled key corrupts the cache hit rate

Recommendation: Create a separate `openmemory-opencode-key` in Vault (ADR 002, 004), point OpenCode agents to it directly (bypass Bifrost/router), and apply cache_control enforcement as a pre-agent hook in OpenCode's MCP configuration.

**Infrastructure**: Modifies Bifrost request/response interceptor. No new services. Cache metrics integrated into SigNoz.

**Estimated impact**: 5–15% additional cost savings on re-executed tasks (assuming 30–50% of requests are cache-eligible and currently missing cache_control). Higher impact if task-clarifier or doc-specialist are frequently called with the same system prompts.

---

## Recommendation 5: Local Model Fallback for Trivial Tasks

**Decision**: Route lightweight tasks (task-clarifier on simple input, lint/format jobs, syntax validation) to a local Ollama instance running Mistral-7B or similar, bypassing the API entirely.

**What it does**:
- Deploys a local Ollama container with Mistral-7B (6GB VRAM, single-digit ms latency)
- Router classifies requests as "trivial" (e.g., request token count < 500, no agentic reasoning needed)
- Sends trivial requests to Ollama; routes complex requests to Anthropic API
- Falls back to API if Ollama is unavailable (503 or timeout)
- Logs local vs. API routing decision for cost tracking

**Implementation approach**:

```yaml
ollama:
  image: ollama/ollama:latest
  volumes:
    - ollama-cache:/root/.ollama
  expose:
    - "11434"
  environment:
    - OLLAMA_NUM_PARALLEL=2
    - OLLAMA_NUM_THREAD=4
```

Router rule:
```yaml
routes:
  task_clarifier:
    primary: local:ollama/mistral  # new: try local first
    fallback: [claude-3-5-haiku-20241022]  # fallback to API
    trivial_threshold_tokens: 500
```

**Rationale**: Local Mistral-7B is sufficient for basic text classification, parsing, and syntax checks. Zero marginal cost after initial GPU amortization (already provisioned for other workloads). Reduces API call volume by ~5–10% on typical ZZAIA runs.

**Caveat**: Requires GPU (or high-end CPU). If the deployment environment lacks GPU, skip this recommendation.

**Estimated impact**: 2–5% API cost reduction + reduced latency for trivial tasks. Low effort (Ollama is drop-in).

---

## Recommendation 6: Sub-Agent Context Isolation Audit

**Decision**: Audit all sub-agent prompts (task-clarifier, doc-specialist, developer-specialist, code-reviewer, tester-specialist, devops-specialist) to ensure each receives only minimal task-scoped context, not full conversation history.

**What it does**:
- Review agent definitions in `.claude/agents/sub/` and their prompt templates
- Verify that each sub-agent receives only: {parent task description, file paths, minimal context needed to complete the task}
- Removes unnecessary conversation history, build logs, previous run results
- Implements context slicing: pass only the 2–3 most relevant lines of context, not full 50-line error trace

**Rationale**: Sub-agents that inherit full parent context inflate token cost by 30–50% on average (2026 benchmark). Each sub-agent dispatch becomes more expensive if parents pass the entire conversation to them. Simple slicing (keep top-3 context lines by relevance, discard the rest) can reduce sub-agent input tokens ~67% with minimal quality loss.

**Implementation approach**:

Example current behavior (bad):
```
Parent prompts task-clarifier:
"Full conversation history [2000 tokens] + task description [100 tokens] + file excerpt [500 tokens]"
→ Task-clarifier makes request [2600 tokens]
```

Example improved behavior:
```
Parent prompts task-clarifier:
"Task description [100 tokens] + top-3 relevant file excerpts [200 tokens]"
→ Task-clarifier makes request [300 tokens]  (~88% savings)
```

**Estimated impact**: 2–10% API cost reduction across all orchestration workflows. Low effort (code review + prompt tweaking, ~1 week).

---

## Recommendation 7: Credential Pools for Alternative Providers

**Decision**: Extend Bifrost's multi-key pooling (ADR 008, 013) to support fallback to Bedrock (AWS), Vertex (Google Cloud), and Foundry (on-premise), not just Anthropic/OpenAI.

**What it does**:
- Adds credential pools for AWS Bedrock Claude models, Google Cloud Vertex Claude, and private Foundry deployments
- Router can fall back to alternative providers if Anthropic API is down or over quota
- Cost comparison: Bedrock + Vertex are slightly cheaper (~5–10% per token) than direct Anthropic API; Foundry is on-premise (amortized infra cost, variable)

**Rationale**: Provides resilience against Anthropic API outages and compliance flexibility (e.g., run on Google Cloud for data residency, Bedrock for AWS-only orgs). Lower priority because:
1. ZZAIA is not currently deployed on AWS/GCP (no Bedrock/Vertex accounts provisioned)
2. Requires separate credential management and contract negotiations per provider
3. ROI is low unless outage frequency is high

**Implementation approach**: Extend Bifrost config to support provider fallback:
```yaml
bifrost:
  credentials:
    anthropic: [${ANTHROPIC_API_KEY_1}, ${ANTHROPIC_API_KEY_2}]
    bedrock: [${AWS_ACCESS_KEY}, ${AWS_SECRET_KEY}]  # optional fallback
    vertex: [${GCP_SERVICE_ACCOUNT_JSON}]             # optional fallback
```

**Estimated impact**: Prevents unplanned downtime (value depends on Anthropic API incident frequency). Recommended only if ZZAIA needs multi-cloud support.

---

## Recommendation 8: ToS-Violation and Abuse-Pattern Detection (Future)

**Decision**: In a future phase, add heuristic detection for request patterns that may violate Anthropic's terms or indicate abuse (e.g., excessive agent looping, token waste, intentional overload stress testing).

**What it does**:
- Monitors for patterns: same request retried 10+ times, agent loop timeout > 30 min, token waste > 50% of input, repeated 429s in short window
- Logs suspicious patterns for manual review
- Optionally triggers alerts or auto-pauses suspicious agents

**Rationale**: Low immediate ROI; primarily defensive. Useful if ZZAIA is deployed in multi-tenant or publicly exposed scenarios.

---

## Recommended Implementation Sequence

| Phase | Recommendation | Effort | Impact | Blocker | Status |
|-------|---|---|---|---|---|
| 1 | Model Routing (Rec. 1) | Medium (1–2 wks) | High ($), 30–50% savings | None | Ready |
| 2 | Spend Caps + Cost Attribution (Rec. 2) | Low–Medium (1 wk) | High (visibility) | Phase 1 | Ready |
| 3 | 529 Handling (Rec. 3) | Low (2–3 days) | Medium (reliability) | None | Ready |
| 4 | cache_control Enforcement (Rec. 4) | Low (3–5 days) | Medium (5–15% savings) | OpenCode credential scoping | Blocked by ADR work |
| 5 | Local Model Fallback (Rec. 5) | Low (2–3 days) | Low–Medium (2–5% savings) | Requires GPU | Ready |
| 6 | Sub-Agent Context Isolation (Rec. 6) | Low–Medium (1 wk) | Medium (2–10% savings) | None | Ready |
| 7 | Alt. Provider Pools (Rec. 7) | Medium (2 wks) | Low (compliance/resilience) | AWS/GCP infrastructure | Backlog |
| 8 | Abuse Detection (Rec. 8) | Low–Medium (1 wk) | Low (defensive) | None | Future |

**Critical path**: 1 → 2 → {3, 4, 5, 6} (phases 3–6 are independent). Phases 7–8 are optional.

---

## Related Documentation

- [RouteLLM (arxiv 2406.18665)](https://arxiv.org/abs/2406.18665) — ML-based request routing for cost-quality tradeoff
- [Not Diamond](https://www.notdiamond.ai/) — Production routing service, 20–97% claimed savings
- [Martian](https://martian.ai/) — Production routing service, LLM cascade optimization
- [Portkey Gateway](https://github.com/Portkey-AI/gateway) — Open-source LLM gateway with budget scoping, multi-provider pooling
- [LiteLLM](https://github.com/BerriAI/litellm) — Open-source multi-provider router with budget routing mode
- [Helicone](https://www.helicone.ai/) — Cost attribution proxy, integrates with any LLM provider
- [Langfuse](https://langfuse.com/) — Full-trace cost attribution and observability
- [Anthropic Prompt Caching Docs](https://docs.anthropic.com/en/docs/build-a-system-with-claude/prompt-caching) — cache_control feature reference
- [OpenCode Known Issues #20110, #14642](https://github.com/anthropics/anthropic-sdk-python) — cache_control injection bugs
- [Ollama](https://ollama.ai/) — Local LLM runtime (Mistral-7B, Llama-2, etc.)

---

**Document version**: 1.0  
**Status**: Proposed — ready for pilot implementation of Phase 1 (model routing)  
**Next step**: Implement static rules router (Option A, Rec. 1) in feature branch, measure cost savings on sample orchestration runs, then propose Phase 2.
