---
project: zzaia-agentic-workspace
branch: feature/improve-agentic-system
document-type: research
created: 2026-05-04
updated: 2026-05-04
---

# ZZAIA Agentic Workspace — AI Optimization Stack Research

Raw research findings for three LLM optimization capabilities across all candidate solutions evaluated. This document captures architecture constraints, trade-offs, and the reasoning behind final recommendations.

## CAPABILITY 1: Context Compression

Goal: Reduce token count sent to remote LLM APIs transparently, without agent code changes.

### A. Headroom (chopratejas/headroom)

**What it is**: Transparent HTTP reverse proxy that intercepts requests to LLM APIs before forwarding them.

**How compression works**:
- CCR (Compress-Cache-Retrieve) architecture
- Content-aware compressors for: AST (code), JSON, logs, plain text, images
- Caches compressed prompts in Qdrant with semantic indexing
- Retrieves from cache on semantic match for future requests
- Falls back to full compression if no cache hit

**Deployment**:
- Docker image available
- Set `ANTHROPIC_BASE_URL`, `OPENAI_BASE_URL`, `GEMINI_API_BASE` to `http://headroom:8787`
- All agents transparently use it without code changes

**Transparency guarantee**: Compression failures never drop requests — always forwards original content unchanged if compression fails or overhead would exceed token savings.

**Supported providers**: Anthropic, OpenAI, Google Gemini, AWS Bedrock, Azure OpenAI

**Endpoints**: `/health`, `/stats`, `/dashboard` for monitoring

**Infrastructure**: Headroom core + Qdrant (semantic cache) + Neo4j (session knowledge graph)

**Performance claims**: 34–90% token reduction, <5ms overhead

**Source**: https://github.com/chopratejas/headroom

**Verdict**: ✅ **BEST** — only production-ready transparent proxy-level compression option. Passthrough guarantee makes it safe for production use.

---

### B. LLMLingua / LLMLingua-2 (Microsoft Research)

**What it is**: Python library implementing prompt compression algorithms (coarse-grained and fine-grained token pruning).

**Approach**:
- Analyzes token importance using smaller LLM models
- Prunes low-importance tokens while preserving semantic meaning
- Compression ratios: 3–10x reported
- Two variants: LLMLingua (coarse) and LLMLingua-2 (fine-grained)

**Implementation required**: Explicit integration in agent code at every LLM call site. Not transparent.

**Example code pattern**:
```python
from llmlingua import PromptCompressor
compressor = PromptCompressor()
compressed = compressor.compress_prompt(prompt)
```

**Maturity**: Research-grade; published in academic venues

**Source**: https://github.com/microsoft/LLMLingua

**Verdict**: ❌ **REJECTED** — requires per-agent code changes; breaks the "automatic, context-independent" requirement. Would require either:
1. Wrapping every agent's LLM call
2. Modifying all 8+ agent implementations
3. Creating a custom LLM client wrapper that all agents use

This violates the design goal of transparency.

---

### C. ContextGem

**What it is**: Structured data extraction tool designed to pull facts from documents into knowledge graphs.

**Use case**: Knowledge extraction, not compression.

**Verdict**: ❌ **REJECTED** — wrong use case. Not designed for prompt compression.

---

### D. OpenAI / Anthropic Native Context Caching

**What it is**: Built-in API feature for automatic prompt caching on repeated queries.

**Anthropic implementation**: `cache_control` parameter on system prompts; costs ~10% of input tokens instead of full cost.

**OpenAI implementation**: Automatic for prompts >1024 tokens; ~50% cost reduction on cache hits.

**Key limitation**: Does NOT reduce token count sent to API. It only reduces cost on repeated prompts.

**Architecture**: Stateful caching — requires maintaining request history per session.

**Verdict**: ⚠️ **COMPLEMENTARY** — not a replacement for Headroom. Reduces cost but doesn't reduce actual tokens sent. Works alongside proxy-level compression.

---

## CAPABILITY 2: Session Memory

Goal: Persist agent session context across conversations so agents remember prior work without re-reading all history.

### A. Headroom Memory Stack (Neo4j-backed)

**What it is**: Knowledge graph stored in Neo4j; retrieved via Headroom proxy at request time.

**Architecture**:
- Neo4j stores session entities (agents, tasks, documents) and relationships
- Headroom proxy supposedly retrieves relevant entities
- Retrieved data returned in request context somehow

**MCP interface**: Non-standard. Requires Headroom-specific `headroom_retrieve()` tool call; not native MCP.

**Integration problem**: Cannot surface memory to agent without a tool call — there's no proxy-level auto-injection mechanism that:
1. Knows what memories are relevant
2. Injects them into every request without agent intent
3. Avoids memory pollution from irrelevant prior context

**Maturity**: Community project; memory retrieval quality unclear.

**Verdict**: ⚠️ **FUNCTIONAL but non-standard** — works but vendor lock-in to Headroom; non-standard MCP interface; unclear retrieval quality.

---

### B. OpenMemory MCP (mem0.ai)

**What it is**: Native MCP memory server with Postgres storage and Qdrant vector backend.

**Architecture**:
- Postgres: stores memory metadata, embeddings, timestamps, relationships
- Qdrant: vector search for semantic similarity
- MCP tools: `add_memories`, `search_memories`, `list_memories`, `delete_all_memories`

**MCP tools exposed**:
```
add_memories(messages: List[str], metadata: Dict) → UUID[]
search_memories(query: str, limit: int) → Memory[]
list_memories() → Memory[]
delete_all_memories()
```

**Integration**: Any MCP-capable agent can use via standard MCP discovery. No Headroom dependency.

**Deployment**: Docker image `mem0/mem0-mcp`, port 5005

**Backend**: Uses Postgres (structured) + Qdrant (vector) — both already in ZZAIA stack

**Automatic capture**: Can proxy LLM conversations at HTTP level (option for optional auto-capture)

**Source**: https://github.com/mem0ai/mem0 (openmemory subpackage)

**Verdict**: ✅ **PREFERRED** — standard MCP interface, local-first, best interoperability with ZZAIA agent ecosystem, Postgres + Qdrant already deployed.

---

### C. Zep (Long-Term Memory for AI Assistants)

**What it is**: Purpose-built memory service with structured and unstructured memory types.

**Architecture**: Hosted or self-hosted; includes memory APIs (add_memory, search_memory, forget)

**Features**:
- Hierarchical memory: facts, summaries, embeddings
- Multi-agent memory sharing
- Token optimization
- LLM-agnostic

**Maturity**: Production-ready, SOC2 certified

**Deployment**: Self-hosted Docker or managed SaaS

**Source**: https://github.com/getzep/zep

**Verdict**: ⚠️ **VIABLE alternative** — more complex deployment than OpenMemory MCP; adds external dependency; comparable feature set to OpenMemory.

---

### D. MemGPT / Letta

**What it is**: Research project implementing OS-style memory management (context windows, virtual memory) for infinite-context LLMs.

**Approach**: Paging memory in/out of LLM context windows; hierarchical memory tiers.

**Maturity**: Research quality, not production-ready.

**Source**: https://github.com/cpacker/MemGPT

**Verdict**: ❌ **RESEARCH QUALITY** — not suitable for production ZZAIA use.

---

### E. Claude Code's Built-In MEMORY.md System

**What it is**: File-based memory system already in ZZAIA codebase at `.claude/projects/*/memory/`.

**Scope**: Stores user-level and project-level facts, preferences, decisions that persist across all Claude Code sessions.

**Example memories**:
- Project conventions (naming, architecture patterns)
- User preferences (communication style, output format)
- Prior decisions and rationale

**Persistence**: Automatic; survives session restarts.

**Verdict**: ✅ **COMPLEMENTARY** — handles cross-session user/project facts; does NOT handle agent working memory within a single session.

---

### F. Proxy-Level Auto-Injection (Theoretical)

**Question**: Could Headroom automatically inject memories into every request without agent action?

**Analysis**:

Memory injection requires:
1. **Query context** — What is the agent working on right now?
2. **Memory retrieval** — Which prior memories are relevant?
3. **Injection** — Prepend retrieved memories to the prompt

A pure HTTP proxy sees only:
- LLM API requests (text)
- Responses (text)

The proxy does NOT see:
- Agent intent or task context
- Filesystem or workspace state
- What the agent is trying to accomplish

To make proxy-level injection work, the proxy would need to:
1. Parse agent prompts to extract task context
2. Build an intent parser (understanding what the agent is doing)
3. Query a memory service (based on inferred intent)
4. Inject retrieved memories
5. Account for token counting and truncation

This essentially requires rebuilding an agent kernel inside the proxy.

**Verdict**: ❌ **ARCHITECTURALLY IMPOSSIBLE** — Proxy can compress (content-agnostic) but cannot retrieve (requires intent parsing). Memory retrieval MUST be agent-initiated via MCP tool calls.

---

## CAPABILITY 3: Workspace Semantic Search

Goal: Agent can query the workspace codebase semantically ("find all services that handle authentication") without full file reads.

### A. Headroom + Qdrant Semantic Cache

**What it is**: Qdrant vector database storing embeddings of prior LLM exchanges.

**Indexed data**: Previous conversations and their embeddings.

**Key limitation**: Does NOT index source code files. Headroom's Qdrant stores conversation cache, not code.

**Cannot answer**: "Where is AuthService defined?" or "Which endpoints handle authentication?"

**Verdict**: ❌ **WRONG TOOL** — Qdrant in Headroom is a conversation cache, not a code index. Architecturally unsuitable for workspace search.

---

### B. Continue.dev + LanceDB

**What it is**: Open-source AI coding assistant with code-aware indexing and hybrid retrieval.

**Architecture**:
- **Continue.dev**: Codegen model with deep understanding of code semantics
- **LanceDB**: Embedded vector database (disk-based, no separate service)
- **Retrieval**: Hybrid approach combining semantic embeddings + structural matching

**Indexing**:
- Source files (all extensions)
- Symbols (functions, classes, methods via tree-sitter)
- AST nodes (syntax-aware chunks)
- Git history (commits, diffs)
- Cross-file references and imports

**Chunking strategy**: AST-aware — chunks respect function/class boundaries, not arbitrary token counts.

**MCP integration**: Exposes `semantic_search` and `code_search` as standard MCP tools.

**Deployment**: Runs as a Docker service; indexes workspace volume on startup.

**Performance**: Sub-millisecond lookups (LanceDB on disk).

**GPU requirement**: No GPU required (unlike some alternatives).

**Code-awareness**:
- Understands language-specific syntax
- Supports 20+ languages
- Can find function calls, class definitions, type signatures

**Source**: https://github.com/continuedev/continue

**LanceDB blog**: https://lancedb.com/blog/ai-native-development-local-continue-lancedb

**Verdict**: ✅ **BEST for workspace semantic search** — code-aware, MCP-native, runs locally, hybrid retrieval, no GPU needed.

---

### C. ast-grep

**What it is**: Structural code search using AST patterns (not text matching).

**Approach**: Pattern matching on Abstract Syntax Trees; not based on embeddings.

**Query style**: 
```
sg --pattern 'class $A implements $B'
sg --pattern 'function $FUNC()'
```

**Language support**: 20+ languages

**Performance**: Fast native binary (Rust).

**Use case**: Finding exact structural patterns — "all classes that inherit from Service", "all method calls to logger.info".

**Limitation**: Not semantic — requires knowing the pattern you're searching for. Won't find "authentication-related services" by intent.

**Source**: https://github.com/ast-grep/ast-grep

**Verdict**: ✅ **COMPLEMENTARY to Continue.dev** — handles structural/syntactic search where embeddings alone fail.

---

### D. Sourcegraph (Self-Hosted)

**What it is**: Enterprise code search platform with semantic capabilities.

**Features**: Cross-repo search, code intelligence, refactoring.

**Infrastructure**: Significant overhead; requires Kubernetes, PostgreSQL, worker pool.

**Maturity**: Enterprise-grade, SOC2 certified.

**Verdict**: ❌ **OVERKILL for single-workspace use** — requires enterprise infrastructure; ZZAIA is single-workspace, not multi-repo enterprise.

---

### E. ctags / Universal Ctags

**What it is**: Symbol indexing tool; creates tag database of all definitions.

**Speed**: Very fast.

**Capability**: Exact symbol matching only. Cannot answer semantic queries.

**Use case**: Jump-to-definition, symbol navigation (IDE features).

**Limitation**: No semantic capability.

**Verdict**: ⚠️ **USEFUL for symbol lookup** but not semantic search. Complementary to Continue.dev for quick symbol navigation.

---

### F. Tree-sitter Based Indexing

**What it is**: Parser library for building incremental syntax trees. Used internally by many tools.

**Used by**:
- Continue.dev (for AST-aware chunking)
- Neovim (for syntax highlighting, code folding)
- GitHub Copilot (for context understanding)

**Standalone capability**: Not a standalone solution. Requires a wrapper/application.

**Verdict**: ⚠️ **INFRASTRUCTURE** — use via Continue.dev rather than as a standalone index.

---

### G. Proxy-Level Code Indexing (Theoretical)

**Question**: Could Headroom or another proxy automatically index workspace code and inject relevant files into prompts?

**Analysis**:

Code indexing requires:
1. **Filesystem access** — Read source files
2. **File discovery** — Walk directory tree, discover relevant files
3. **Chunking** — Break files into semantic chunks
4. **Embedding** — Generate embeddings for each chunk
5. **Query understanding** — Parse agent prompts to extract "what code is needed?"
6. **Injection** — Prepend relevant files to prompt

A pure HTTP proxy has:
- No filesystem access
- No understanding of code structure
- No way to determine which files are relevant without parsing agent intent

Even with filesystem mounted, the proxy would need to:
- Understand what the agent is trying to do
- Determine which files/functions are relevant
- Rank by relevance
- Truncate to fit token budget

This is essentially building a code-understanding agent inside the proxy.

**Verdict**: ❌ **ARCHITECTURALLY IMPOSSIBLE** — Proxy operates on HTTP streams, not filesystems. Code search MUST be agent-initiated via MCP tool calls.

---

## ARCHITECTURAL INSIGHT: Proxy vs. Tool Trade-Off

### Why Compression is Proxy-Level

**Compression is content-agnostic**:
- Proxy sees: "This is a text/JSON/code payload"
- Proxy does: "Reduce token count via AST, JSON, or text compression"
- No intent parsing needed
- Failure mode: Return original if compression fails (safe)

**Result**: 100% transparency. No agent action required.

### Why Memory & Search are Tool-Level

**Both require intent**:
- Memory: "What context do I need from prior work?"
- Search: "Which code files are relevant to my task?"

**A proxy cannot infer intent** from HTTP payloads:
- Proxy sees: "Send this prompt to Claude"
- Proxy does NOT see: "This prompt is about authentication, so retrieve auth-related memories"

**Intent comes from the agent**, not the HTTP layer.

**Result**: Agent-initiated MCP tool calls are the correct pattern. Proxy-level auto-injection would require intent parsing, which is building an agent inside the proxy.

---

## Final Recommendation Table

| Capability | Tool | Why This One | Automation Level |
|---|---|---|---|
| **Context Compression** | Headroom | Only transparent proxy option; passthrough guarantee; supports all major LLM providers | 100% proxy-level, zero agent code changes |
| **Session Memory** | OpenMemory MCP | Standard MCP interface; local Postgres+Qdrant; no Headroom lock-in; retrieval quality | Agent-initiated via `search_memories()` tool |
| **Workspace Search** | Continue.dev + LanceDB + ast-grep | Code-aware indexing; MCP-native; hybrid semantic+structural; runs locally | Agent-initiated via `semantic_search()` tool |

---

## Trade-Off Analysis

### Token Savings vs. Latency

**Headroom compression**:
- Saves 34–90% of prompt tokens
- Adds <5ms overhead
- Worth it for agents with large prompts (e.g., code review agents, synthesis tasks)

**Memory retrieval**:
- Agent decides when to retrieve (saves tokens on irrelevant requests)
- On retrieval: adds latency of semantic search (~50–200ms via Qdrant)
- Saves overall tokens by avoiding irrelevant context injection

**Code search**:
- Agent decides when needed
- Sub-millisecond retrieval (LanceDB on disk)
- Saves time re-reading files; allows agents to reference without file content

### Infrastructure Overhead

**Current ZZAIA stack**:
- PostgreSQL (already deployed)
- Qdrant (already deployed)
- Headroom (add: new service)
- Continue.dev + LanceDB (add: new service, uses Qdrant)
- OpenMemory MCP (add: new service, uses Postgres+Qdrant)

**No new databases required** — Postgres and Qdrant already present.

**Removal**:
- Neo4j (replaced by LanceDB for code indexing)

---

## Implementation Pathway

### Phase 1: Context Compression (Quick Win)
1. Add Headroom service to docker-compose.yml
2. Set `ANTHROPIC_BASE_URL=http://headroom:8787` in agent environment
3. Agents transparently compressed; measure token savings

### Phase 2: Session Memory (Medium Effort)
1. Add OpenMemory MCP service to docker-compose.yml
2. Expose MCP tools to agents via standard MCP discovery
3. Update agents to call `search_memories()` when retrieving context
4. Agents gain cross-conversation memory

### Phase 3: Workspace Search (Largest Effort)
1. Add Continue.dev backend service (indexes workspace on startup)
2. Expose `semantic_search()` and `code_search()` as MCP tools
3. Update agents (especially code review, synthesis) to query workspace
4. Agents gain code-aware context without re-reading files

---

## Risk Assessment

### Headroom Compression
- **Risk**: Compression failures silently drop requests
- **Mitigation**: Passthrough guarantee in design; always forwards original on failure
- **Monitoring**: `/stats` and `/dashboard` endpoints

### OpenMemory MCP
- **Risk**: Memory pollution (too much irrelevant context retrieved)
- **Mitigation**: Agents control retrieval via `search_memories()`; structured queries allow filtering
- **Monitoring**: Memory growth monitoring; pruning strategies for old memories

### Continue.dev Indexing
- **Risk**: Large codebase causes slow indexing on startup
- **Mitigation**: LanceDB is incremental; only re-indexes changed files
- **Monitoring**: Index size, query latency percentiles

---

## Future Considerations

### Compression + Caching Synergy
- Headroom compresses; Qdrant caches compressed prompts
- Subsequent identical queries hit cache (zero latency, zero token cost)
- Semantic cache hits (similar queries) reduce compression overhead

### Memory + Search Integration
- Agents can store findings from code search in memory
- Future agents retrieve prior findings without re-searching
- Compounds savings over multiple iterations

### Cost Monitoring
- Measure token usage before/after Headroom (expect 34–90% reduction)
- Measure memory retrieval coverage (% of tasks that benefit from memory)
- Measure code search hit rate (% of relevant files found in first query)

---

## Related Resources

- [Headroom GitHub](https://github.com/chopratejas/headroom)
- [OpenMemory MCP Announcement](https://mem0.ai/blog/introducing-openmemory-mcp)
- [Continue.dev Documentation](https://docs.continue.dev/reference)
- [LanceDB: AI-Native Development with Local Continue + LanceDB](https://lancedb.com/blog/ai-native-development-local-continue-lancedb)
- [ast-grep GitHub](https://github.com/ast-grep/ast-grep)
- [Zep Documentation](https://docs.getzep.com/)

---

**Research completed**: 2026-05-04  
**Status**: Ready for architecture decision and implementation planning
