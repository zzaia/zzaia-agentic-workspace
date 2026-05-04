---
name: ZZAIA Agentic Workspace — AI Optimization Stack Research
date: 2026-05-02
version: 1.0
scope: ZZAIA Docker Compose stack (feature/improve-agentic-system)
status: Complete
---

# ZZAIA Agentic Workspace — AI Optimization Stack Research

Research and decision record for three LLM optimization capabilities: context compression, session memory, and workspace semantic search. Evaluated multiple solutions per capability, assessed proxy-level vs MCP-tool-level automation, and produced tool selection recommendations for the ZZAIA Docker Compose stack.

---

### ADR 001: Headroom for Context Compression Only

**Decision**: Adopt Headroom as a transparent HTTP reverse proxy for automatic context compression. Agents configure `ANTHROPIC_BASE_URL`, `OPENAI_BASE_URL`, and `GEMINI_API_BASE` to `http://headroom:8787`.

- **Approach**: HTTP reverse proxy with content-aware compressors (AST, JSON, logs, text)
- **Transparency**: Zero agent code changes; compression failure always forwards original content unchanged
- **Performance**: 34–90% token reduction reported; <5ms overhead
- **Coverage**: Supports Anthropic, OpenAI, Google, AWS Bedrock, Azure
- **Implementation**: Headroom service added to docker-compose on port 8787

**Rationale**: Headroom is production-proven for transparent compression. It is retained exclusively for this capability — session memory and semantic search are delegated to purpose-built tools that provide superior retrieval quality, code-awareness, and MCP-native integration unavailable in Headroom.

---

### ADR 002: OpenMemory MCP for Session Memory / Conversation Persistence

**Decision**: Adopt OpenMemory (with Mem0 as fallback) for session memory. Agents invoke `search_memory`, `add_memories`, and `list_memories` via automatic MCP discovery.

- **Architecture**: Postgres + Qdrant (already in ZZAIA stack) backend, native MCP tools
- **Storage**: Automatic proxy-level capture of all conversations; no agent overhead
- **Retrieval**: Agent-initiated via MCP tool calls when prior context is needed
- **Deployment**: Single compose service (`openmemory`) with zero additional infrastructure
- **Fallback**: Mem0 if hybrid summarization/pruning or advanced relevance ranking needed

**Rationale**: Fully automatic proxy-level injection (where the proxy enriches every request without agent action) is architecturally infeasible — it requires the proxy to have filesystem access and an intent parser, essentially rebuilding an agent kernel inside the proxy. The MCP tool pattern is accepted as correct: agents explicitly call `search_memory` when they need context, avoiding irrelevant memory pollution. OpenMemory provides explicit MCP tools, local-first deployment, and indexing quality superior to Headroom's memory stack.

---

### ADR 003: Continue.dev + LanceDB + ast-grep for Workspace Semantic Search

**Decision**: Adopt Continue.dev + LanceDB for code-aware workspace semantic search, augmented with ast-grep for structural pattern matching.

- **Architecture**: LanceDB on-disk index (sub-millisecond lookups) on `workspace-repos` volume
- **Retrieval**: Hybrid semantic (embeddings) + structural (patterns) via Reciprocal Rank Fusion
- **Code-awareness**: AST-aware chunking, function/class definition indexing
- **Infrastructure**: No GPU required; no additional vector database (LanceDB is embedded)
- **MCP Integration**: FastAPI wrapper exposes `semantic_search` / `code_search` as standard MCP Tools

**Rationale**: Workspace semantic search cannot be automated at proxy level — the proxy has no filesystem access and cannot index files or determine which files are relevant to inject. A code-aware embeddings model, local-first deployment, and structural pattern matching are required. Continue.dev + LanceDB is purpose-built for exactly this use case and already deployed in enterprise production. ast-grep provides syntactic precision where embeddings alone fail (e.g., finding all function calls to a specific method).

---

## C4 Context Diagram

```mermaid
C4Context
    title ZZAIA Agentic Workspace Optimization Stack

    Person(agent, "ZZAIA Agent", "Multi-task orchestrator")
    System(mainSystem, "ZZAIA Agentic Workspace", "Agent orchestration and optimization infrastructure")
    System_Ext(anthropicAPI, "Anthropic API", "Upstream LLM provider")
    System_Ext(openaiAPI, "OpenAI / Other LLMs", "Alternative LLM providers")

    Rel(agent, mainSystem, "Invokes MCP tools for memory/search; sends LLM requests", "HTTP")
    Rel(mainSystem, anthropicAPI, "Context-compressed requests", "HTTP via Headroom")
    Rel(mainSystem, openaiAPI, "Context-compressed requests", "HTTP via Headroom")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
```

---

## C4 Container Diagram

```mermaid
C4Container
    title Optimization Stack Services and Dependencies

    System_Boundary(proxy, "Proxy Layer") {
        Container(headroom, "Headroom", "HTTP Reverse Proxy", "Context compression via AST/JSON/logs/text")
    }

    System_Boundary(memory, "Session Memory Layer") {
        Container(openmemory, "OpenMemory MCP", "MCP Server", "Conversation storage and retrieval")
        Container(postgres, "PostgreSQL", "Database", "Memory metadata and embeddings")
        Container(qdrant, "Qdrant", "Vector DB", "Memory semantic index")
    }

    System_Boundary(codeSearch, "Workspace Search Layer") {
        Container(continue, "Continue.dev + LanceDB", "MCP Server", "Workspace semantic search, hybrid retrieval")
        Container(astgrep, "ast-grep", "Pattern Matcher", "Structural code pattern matching")
    }

    System_Boundary(workspace, "Workspace Layer") {
        Container(workspaceRepos, "Workspace Repositories", "Volume", "Source code indexed by Continue.dev")
    }

    Rel(headroom, anthropicAPI, "Forwards compressed requests", "HTTP")
    Rel(openmemory, postgres, "Stores/queries memory", "SQL")
    Rel(openmemory, qdrant, "Semantic indexing", "gRPC")
    Rel(continue, workspaceRepos, "Indexes files and history", "Filesystem")
    Rel(continue, astgrep, "Structural matching", "In-process")
    Rel(continue, qdrant, "Optional: shared vector backend", "gRPC")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
```

---

## Architecture Components

### Proxy Layer
- **Headroom**: HTTP reverse proxy for transparent context compression. All LLM requests (Anthropic, OpenAI, Google, AWS Bedrock, Azure) routed through port 8787.

### Session Memory Layer
- **OpenMemory MCP**: Server exposing MCP tools for conversation storage and semantic retrieval
- **PostgreSQL**: Stores memory metadata, embeddings, timestamps, and relationships
- **Qdrant**: Vector database for semantic similarity search (shared with workspace search layer)

### Workspace Semantic Search Layer
- **Continue.dev + LanceDB**: Local-first code indexing with hybrid retrieval (semantic + structural)
- **ast-grep**: In-process pattern matching for syntactic code queries (function definitions, call sites)

### Workspace Layer
- **Workspace Repositories**: Volume containing all indexed source code and git history

---

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Proxy** | Headroom (HTTP reverse proxy, multi-provider support) |
| **Memory Storage** | PostgreSQL (metadata), Qdrant (vector index) |
| **Memory MCP** | OpenMemory (native MCP tools) |
| **Code Search** | Continue.dev + LanceDB (embeddings), ast-grep (AST patterns) |
| **Infrastructure** | Docker Compose, shared volume for workspace indexing |

---

## Implementation Requirements

### Services to Add to docker-compose.yml

**OpenMemory MCP** (replaces Headroom memory stack):
```yaml
openmemory:
  image: skpassegna/openmemory-mcp:latest
  environment:
    DATABASE_URL: postgresql://user:password@postgres:5432/openmemory
    QDRANT_URL: http://qdrant:6333
  depends_on:
    - postgres
    - qdrant
  ports:
    - "5005:5005"
```

**Continue.dev + LanceDB**:
```yaml
continue-backend:
  image: continue-dev/lancedb-server:latest
  environment:
    WORKSPACE_PATH: /workspace
    QDRANT_URL: http://qdrant:6333
  volumes:
    - workspace-repos:/workspace
  ports:
    - "8001:8001"
```

**Headroom** (context compression):
```yaml
headroom:
  image: chopratejas/headroom:latest
  environment:
    LOG_LEVEL: info
  ports:
    - "8787:8787"
```

### Services to Remove
- `neo4j` — replaced by LanceDB for code graph indexing (LanceDB is more efficient for hybrid retrieval)
- Headroom's standalone Qdrant role — Qdrant now shared by OpenMemory and Continue.dev

### Agent Configuration

**Environment variables** (agents set on startup):
```bash
ANTHROPIC_BASE_URL=http://headroom:8787
OPENAI_BASE_URL=http://headroom:8787
GEMINI_API_BASE=http://headroom:8787
MEMORY_MCP_ENDPOINT=openmemory:5005
SEARCH_MCP_ENDPOINT=continue-backend:8001
```

**Agent code changes**: None required. Agents discover MCP tools automatically via MCP server registration.

---

## Capability-Level Design Decisions

### Context Compression: Proxy-Level Automation
✅ **100% transparent** — no agent action required. Headroom is inserted as a reverse proxy; all requests are automatically compressed. Failure mode: compression fails → original content forwarded unchanged.

### Session Memory: MCP-Level Tool Pattern
⚠️ **Agent-initiated retrieval** — agents call `search_memory` when they need prior context. This is correct and superior to blind injection because:
- Avoids irrelevant memory pollution (not every request needs all prior history)
- Allows agents to control what context is retrieved
- Supports structured memory search (by date, topic, agent, etc.)
- Reduces token usage compared to always-on memory injection

### Workspace Semantic Search: MCP-Level Tool Pattern
⚠️ **Agent-initiated search** — agents call `semantic_search` or `code_search` when they need workspace context. Proxy-level automation is impossible because:
- Proxy has no filesystem access
- Cannot determine file relevance without intent parsing
- Cannot index codebase without a file crawler and AST parser
- Would require rebuilding an agent kernel inside the proxy

---

## Evaluation Rationale

### Context Compression Candidates

| Tool | Approach | Docker | Maturity | Selection |
|---|---|---|---|---|
| **Headroom** | HTTP reverse proxy, content-aware (AST, JSON, text, images) | ✅ | Community, active | ✅ **Selected** |
| LiteLLM | Multi-provider router — no native compression | ✅ | Mature | Rejected — routing only |
| LLMlingua | Research-grade prompt compression library | ❌ no proxy mode | Research | Rejected — not production-ready as proxy |

### Session Memory Candidates

| Tool | Storage | Retrieval | Code | Local-first | Maturity | Selection |
|---|---|---|---|---|---|---|
| **OpenMemory** | Postgres + Qdrant | MCP tools (`search_memory`) | ❌ | ✅ | Early prod | ✅ **Selected** |
| Mem0 | Managed SaaS or self-hosted | MCP tools | ❌ | ⚠️ | Prod, vendor-backed | Fallback |
| Zep / Graphiti | Postgres + Vector DB | MCP tools | ❌ | ✅ | Mature, SOC2 | Alternative |
| Headroom memory stack | Qdrant | `headroom_retrieve()` tool | ❌ | ✅ | Community | Rejected — lower retrieval quality |

### Workspace Semantic Search Candidates

| Tool | Approach | Docker | Code-aware | Local-first | Maturity | Selection |
|---|---|---|---|---|---|---|
| **Continue.dev + LanceDB** | Code embeddings + LanceDB, hybrid retrieval | ✅ | ✅ AST-aware | ✅ | OSS prod | ✅ **Selected** |
| Greptile (self-hosted) | AST graph + embeddings | ✅ | ✅ | ⚠️ GPU needed | Prod, SOC2 | Alternative |
| Sourcegraph Cody | Structural + semantic, BYOK | ✅ | ✅ | ⚠️ Enterprise | Enterprise | Rejected — enterprise only |
| Headroom + Qdrant/Neo4j | Conversation embeddings (not workspace files) | ✅ | ❌ | ✅ | Community | Rejected — no file indexing |

---

## Related Documentation

- [Headroom GitHub](https://github.com/chopratejas/headroom) — Transparent LLM proxy compression
- [OpenMemory MCP Announcement](https://mem0.ai/blog/introducing-openmemory-mcp) — Session memory with MCP tools
- [Continue.dev Docs](https://docs.continue.dev/reference) — Code-aware embeddings and search
- [LanceDB Blog](https://lancedb.com/blog/ai-native-development-local-continue-lancedb) — Local vector database
- [ast-grep GitHub](https://github.com/ast-grep/ast-grep) — Structural code pattern matching

---

**Document completed**: 2026-05-02  
**Status**: Ready for docker-compose implementation
