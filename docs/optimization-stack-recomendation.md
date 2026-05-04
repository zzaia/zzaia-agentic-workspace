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

**Decision**: Adopt OpenMemory for session memory. Agents invoke `search_memory`, `add_memories`, and `list_memories` via automatic MCP discovery.

- **Architecture**: Postgres + Qdrant (already in ZZAIA stack) backend, native MCP tools
- **Storage**: Automatic proxy-level capture of all conversations; no agent overhead
- **Retrieval**: Agent-initiated via MCP tool calls when prior context is needed
- **Deployment**: Single compose service (`openmemory`) with zero additional infrastructure

**Rationale**: Fully automatic proxy-level injection (where the proxy enriches every request without agent action) is architecturally infeasible — it requires the proxy to have filesystem access and an intent parser, essentially rebuilding an agent kernel inside the proxy. The MCP tool pattern is accepted as correct: agents explicitly call `search_memory` when they need context, avoiding irrelevant memory pollution. OpenMemory provides explicit MCP tools, local-first deployment, and indexing quality superior to Headroom's memory stack. MCP-based delivery ensures uniform access across all CLIs and VS Code extensions — unlike Headroom's `--memory` flag which only works for CLIs that support `headroom wrap`.

---

### ADR 003: CodeGraphContext for Workspace Semantic Search

**Decision**: Adopt CodeGraphContext as the agent-agnostic MCP server for code graph indexing and workspace semantic search.

- **Architecture**: Tree-sitter AST parsing → graph database (KûzuDB embedded by default, Neo4j for Docker); real-time file watching via `cgc watch`
- **Retrieval**: Symbol resolution, call graphs, class hierarchies, import graphs, dead code detection
- **Code-awareness**: 14 languages; resolves callers/callees, type hierarchies, cross-file references
- **Agent-agnostic**: Exposes standard MCP tools; works with Claude Code, Gemini CLI, Codex, Cline, any MCP client — no IDE dependency
- **MCP Integration**: `cgc mcp start` — zero config, single command, stdio transport compatible with all agents

**Rationale**: Continue.dev is coupled to an IDE session (VS Code extension) and requires a custom MCP wrapper to expose indexing without an IDE running. CodeGraphContext is purpose-built as an agent-agnostic MCP server — no IDE, no coding assistant dependency. It exposes code graph queries (`find_callers`, `find_callees`, `class_hierarchy`, `call_chain`) as standard MCP tools to any MCP client. For ZZAIA's Docker Compose multi-agent stack, this is architecturally correct: agents are CLI processes, not IDE sessions.

**Alternative**: `codebase-memory` (DeusData) — single static binary, 66 languages, SQLite, 14 MCP tools, 120x token reduction, peer-reviewed (arXiv 2603.27277). Preferred if token reduction at search time is the priority over call graph depth.

**Rejected**: Continue.dev + LanceDB — tied to Continue.dev coding assistant; requires custom MCP wrapper; no Docker service variant; index refresh requires IDE filesystem watcher not available in CLI-only environments.

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
        Container(cgc, "CodeGraphContext", "MCP Server", "Agent-agnostic code graph: call graphs, symbols, hierarchies")
    }

    System_Boundary(workspace, "Workspace Layer") {
        Container(workspaceRepos, "Workspace Repositories", "Volume", "Source code indexed by Continue.dev")
    }

    Rel(headroom, anthropicAPI, "Forwards compressed requests", "HTTP")
    Rel(openmemory, postgres, "Stores/queries memory", "SQL")
    Rel(openmemory, qdrant, "Semantic indexing", "gRPC")
    Rel(cgc, workspaceRepos, "Indexes files and builds call graph", "Filesystem")
    Rel(cgc, qdrant, "Optional: shared vector backend", "gRPC")

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
- **CodeGraphContext**: Agent-agnostic MCP server for code graph queries — call graphs, symbol resolution, class hierarchies, import graphs, dead code detection. Uses KûzuDB (embedded) or Neo4j (Docker). Real-time file watching via `cgc watch`. Zero IDE dependency.

### Workspace Layer
- **Workspace Repositories**: Volume containing all indexed source code and git history

---

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Proxy** | Headroom (HTTP reverse proxy, multi-provider support) |
| **Memory Storage** | PostgreSQL (metadata), Qdrant (vector index) |
| **Memory MCP** | OpenMemory (native MCP tools) |
| **Code Search** | CodeGraphContext (call graphs, symbols, AST), KûzuDB / Neo4j (graph storage) |
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

**CodeGraphContext** (agent-agnostic code graph MCP server):
```yaml
code-graph:
  image: python:3.12-slim
  command: >-
    sh -c "pip install codegraphcontext -q && cgc watch /workspace & cgc mcp start"
  environment:
    CGC_PROJECT_ROOT: /workspace
  volumes:
    - workspace-repos:/workspace
    - code-graph-db:/root/.cgc
  restart: unless-stopped
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
- `neo4j` — replaced by CodeGraphContext's embedded KûzuDB (no separate graph DB service needed)
- Headroom's standalone Qdrant role — Qdrant now shared by OpenMemory and optionally CodeGraphContext

### Agent Configuration

**Environment variables** (agents set on startup):
```bash
ANTHROPIC_BASE_URL=http://headroom:8787
OPENAI_BASE_URL=http://headroom:8787
GEMINI_API_BASE=http://headroom:8787
MEMORY_MCP_ENDPOINT=openmemory:5005
SEARCH_MCP_ENDPOINT=code-graph:8001
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
⚠️ **Agent-initiated search** — agents call `find_callers`, `find_callees`, `class_hierarchy`, `call_chain` via CodeGraphContext MCP tools when they need workspace context. Proxy-level automation is impossible because:
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
| Zep / Graphiti | Postgres + Vector DB | MCP tools | ❌ | ✅ | Mature, SOC2 | Alternative |
| Mem0 | Managed SaaS or self-hosted | MCP tools | ❌ | ⚠️ | Prod, vendor-backed | Rejected — external SaaS dependency, not local-first |
| Headroom memory stack | Qdrant | `headroom_retrieve()` tool | ❌ | ✅ | Community | Rejected — lower retrieval quality |

### Workspace Semantic Search Candidates

| Tool | Approach | Docker | Code-aware | Agent-agnostic | Local-first | Maturity | Selection |
|---|---|---|---|---|---|---|---|
| **CodeGraphContext** | Tree-sitter → call graph + symbol index (KûzuDB) | ✅ | ✅ | ✅ any MCP client | ✅ | OSS, 3.1k stars | ✅ **Selected** |
| codebase-memory (DeusData) | Tree-sitter → SQLite FTS5 + vectors, single binary | ✅ | ✅ 66 langs | ✅ | ✅ | peer-reviewed (arXiv) | Alternative (token-reduction focus) |
| CodeGraph (Rust, suatkocar) | Tree-sitter → SQLite, 44 MCP tools, PageRank | ✅ | ✅ 32 langs | ✅ | ✅ | OSS, 3.1k stars | Alternative (deeper graph analysis) |
| Continue.dev + LanceDB | Embeddings + LanceDB, hybrid retrieval | ⚠️ custom | ✅ AST-aware | ❌ IDE-coupled | ✅ | OSS prod | Rejected — VS Code extension dependency |
| Greptile (self-hosted) | AST graph + embeddings | ✅ | ✅ | ✅ | ⚠️ GPU needed | Prod, SOC2 | Rejected — GPU required |
| Sourcegraph Cody | Structural + semantic | ✅ | ✅ | ✅ | ⚠️ Enterprise | Enterprise | Rejected — enterprise only |
| Headroom + Qdrant/Neo4j | Conversation embeddings (not files) | ✅ | ❌ | ✅ | ✅ | Community | Rejected — no file indexing |

---

## Related Documentation

- [Headroom GitHub](https://github.com/chopratejas/headroom) — Transparent LLM proxy compression
- [OpenMemory MCP Announcement](https://mem0.ai/blog/introducing-openmemory-mcp) — Session memory with MCP tools
- [CodeGraphContext GitHub](https://github.com/CodeGraphContext/CodeGraphContext) — Agent-agnostic code graph MCP server
- [codebase-memory (DeusData)](https://github.com/DeusData/codebase-memory-mcp) — Alternative: single binary, 66 languages, 14 MCP tools
- [CodeGraph Rust (suatkocar)](https://github.com/suatkocar/codegraph) — Alternative: 44 MCP tools, PageRank, hybrid BM25+cosine

---

**Document completed**: 2026-05-02  
**Status**: Ready for docker-compose implementation
