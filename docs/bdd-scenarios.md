---
title: BDD Scenarios — ZZAIA Agentic Workspace Improved Architecture
---

# BDD Scenarios — ZZAIA Agentic Workspace Improved Architecture

## Overview

**Feature**: ZZAIA Agentic Workspace with decoupled VS Code browser UI, Dev Containers attachment, headroom AI proxy, and single image multi-purpose deployment
**Domain**: Cloud Infrastructure, Developer Experience, AI Agent Orchestration

---

## Feature: Decoupled VS Code Browser UI

Enables VS Code browser access independent of workspace container lifecycle while supporting SSH-only deployments and eliminating watchdog processes.

### Background

```gherkin
Background:
  Given zzaia-agentic-workspace:latest image is built
  And docker compose orchestrates workspace and vscode-server containers
  And workspace-home volume is shared between containers
```

---

### Scenario: VS Code browser access survives workspace restart

```gherkin
Scenario: VS Code browser access survives workspace restart
  Given vscode-server container is running and healthy
  And workspace container restarts
  When workspace restarts and SSH healthcheck passes (TCP/2222)
  Then vscode-server reconnects to shared workspace-home volume
  And browser session becomes available again
  And all extensions remain loaded from shared volume
```

---

### Scenario: vscode-server disabled for SSH-only deployments

```gherkin
Scenario: vscode-server disabled for SSH-only deployments
  Given VSCODE profile not specified in docker compose command
  When docker compose up runs without --profile vscode
  Then vscode-server container does not start
  And workspace SSH and Dev Containers operate normally
  And no port 8080 is exposed on the host
```

---

### Scenario: vscode-server healthcheck replaces watchdog

```gherkin
Scenario: vscode-server healthcheck replaces watchdog
  Given vscode-server container starts with code serve-web
  When serve-web exits unexpectedly
  Then Docker restart: unless-stopped policy restarts the container
  And healthcheck detects recovery at http://localhost:8080
  And no watchdog bash loop is needed in entrypoint
```

---

## Feature: Dev Containers Attach

Enables VS Code Remote to attach directly to workspace container via Dev Containers protocol with consistent profile application across all connection types.

### Background

```gherkin
Background:
  Given devcontainer.json present in the workspace container image
  And Docker socket mounted at /var/run/docker.sock in workspace
  And vscode/ directory baked into image with profile zzaia-workspace
```

---

### Scenario: VS Code Remote attaches to workspace via Dev Containers

```gherkin
Scenario: VS Code Remote attaches to workspace via Dev Containers
  Given devcontainer.json present in the workspace container image
  And Docker socket mounted at /var/run/docker.sock in workspace
  When user opens VS Code Remote → Attach to Running Container → workspace
  Then VS Code attaches to workspace container as user user
  And profile Main - Zzaia is applied via devcontainer.json customizations
  And extensions match those in vscode-server (same mise.toml list)
```

---

### Scenario: Profile consistency across all connection types

```gherkin
Scenario: Profile consistency across all connection types
  Given vscode/ directory baked into image with profile zzaia-workspace
  And workspace-home volume shared between workspace and vscode-server
  When user connects via browser (vscode-server)
  Then Ayu theme and pre-installed extensions are active
  When user connects via Dev Containers
  Then same profile applied via devcontainer.json customizations block
  When user connects via VS Code Remote SSH
  Then server-side extensions are installed from .vscode-server/extensions (shared volume)
```

---

## Feature: Headroom AI Proxy — Layer 1 (Primary)

Routes agent API requests through headroom proxy for automatic context compression and memory injection at the proxy pipeline level.

### Background

```gherkin
Background:
  Given headroom container is running with --memory --code-graph flags
  And qdrant vector database is running and healthy
  And neo4j graph database is running and healthy
  And ANTHROPIC_BASE_URL=http://headroom:8787 set in workspace environment
  And OPENAI_BASE_URL=http://headroom:8787 set in workspace environment
  And GEMINI_API_BASE=http://headroom:8787 set in workspace environment
  And code-graph file watcher monitors source files in background
  And memory injection happens automatically at proxy pipeline level (no agent action required)
```

---

### Scenario: Agent session with automatic context compression via headroom

```gherkin
Scenario: Agent session with automatic context compression via headroom
  Given headroom container running on mcp network at port 8787 with --memory flag
  When Claude Code sends a request with context exceeding 32k tokens
  Then headroom automatically compresses context using rolling memory
  And forwards compressed request to upstream Anthropic API
  And stores conversation state in headroom memory stack
  And agent receives valid API response (no agent tool call needed)
```

---

### Scenario: Gemini CLI routes through headroom proxy

```gherkin
Scenario: Gemini CLI routes through headroom proxy
  Given GEMINI_API_BASE=http://headroom:8787 set in workspace environment
  When gemini CLI sends a request to Google Gemini API
  Then headroom intercepts the request
  And applies context compression if context exceeds threshold
  And forwards to upstream Google Gemini API
  And stores session state in headroom memory stack
```

---

### Scenario: Headroom passthrough on compression failure

```gherkin
Scenario: Headroom passthrough on compression failure
  Given headroom is running with qdrant and neo4j healthy
  When a request cannot be compressed (format incompatible or compression error)
  Then headroom forwards the original unmodified content to upstream API
  And the agent receives a valid API response
  And no agent call is dropped or errored due to compression failure
```

---

### Scenario: Semantic search retrieval via qdrant and neo4j

```gherkin
Scenario: Semantic search retrieval via qdrant and neo4j
  Given qdrant vector database contains embeddings from prior agent sessions
  And neo4j knowledge graph contains session relationships
  When headroom processes a new agent request
  Then headroom queries qdrant for semantically similar prior context
  And queries neo4j for related knowledge graph nodes
  And enriches the request with retrieved context before compression
  And upstream API receives enriched, compressed request
```

---

### Scenario: Background code-graph indexing auto-improves context scoring

```gherkin
Scenario: Background code-graph indexing auto-improves context scoring
  Given headroom started with --code-graph flag
  When code-graph file watcher detects source file changes
  Then affected AST nodes are re-parsed in background
  And semantic code index is updated automatically
  And next agent request benefits from improved context scoring
  And no agent action required for index maintenance
```

---

## Feature: Headroom Automatic Memory Injection (Proxy Pipeline) — Layer 1 Primary

Automatically injects relevant prior memories into agent requests at the Headroom proxy pipeline level, without requiring agent tool calls.

### Background

```gherkin
Background:
  Given headroom proxy is running with --memory flag
  And qdrant vector database contains memories from prior agent sessions
  And x-headroom-user-id header scopes memory by user or shared context
  And all API traffic routes through ANTHROPIC_BASE_URL=http://headroom:8787
  And VS Code extensions and all CLIs route through same proxy endpoint
```

---

### Scenario: Agent request receives automatic memory injection from proxy

```gherkin
Scenario: Agent request receives automatic memory injection from proxy
  Given agent sends request through Headroom proxy
  When request enters proxy pipeline
  Then Headroom queries qdrant for semantically similar prior memories
  And relevant memories are automatically injected into system context
  And compressed request with enriched memory is forwarded to upstream API
  And agent receives response with memory-informed context (no agent tool call needed)
```

---

### Scenario: Agent response automatically stored as memory by proxy

```gherkin
Scenario: Agent response automatically stored as memory by proxy
  Given agent completes a task and receives response from upstream API
  When response returns through Headroom proxy
  Then Headroom extracts key findings and decisions from response
  And memory is automatically indexed in Qdrant with semantic embeddings
  And metadata (timestamp, user_id, task_context) stored in backing store
  And memory becomes available for automatic injection in future requests
```

---

### Scenario: Memory scoped by x-headroom-user-id header

```gherkin
Scenario: Memory scoped by x-headroom-user-id header
  Given Claude Code and Gemini CLI both route through http://headroom:8787
  When Claude Code request includes x-headroom-user-id=claude-user
  And Gemini request includes x-headroom-user-id=gemini-user
  Then Headroom maintains separate memory contexts for each user
  And Claude Code receives only Claude-scoped memories in injection
  And Gemini receives only Gemini-scoped memories
  And no cross-user memory contamination occurs
```

---

### Scenario: VS Code extension gets automatic memory injection through proxy

```gherkin
Scenario: VS Code extension gets automatic memory injection through proxy
  Given VS Code extension routes API requests through ANTHROPIC_BASE_URL=http://headroom:8787
  When extension sends agent request to Anthropic API via proxy
  Then Headroom automatically injects relevant prior memories before forwarding
  And memory injection happens transparently at proxy level
  And extension code requires no changes to benefit from memory injection
  And all previous context becomes available to the editor-integrated agent
```

---



## Feature: Connection Type Matrix

Supports SSH, Dev Containers, and VS Code Remote attachment with consistent workspace initialization and credential wiring.

### Background

```gherkin
Background:
  Given workspace container is built and available
  And SSH_PUBLIC_KEY configured in workspace environment
  And GitHub and ADO credential wiring configured
```

---

### Scenario: SSH connection to workspace

```gherkin
Scenario: SSH connection to workspace
  Given workspace container running and SSH daemon healthy (TCP/2222)
  And SSH_PUBLIC_KEY configured in workspace environment
  When user connects via ssh user@localhost -p 2222
  Then shell session opens as user user in /home/user
  And full mise toolchain is available
  And docker socket access is available
```

---

### Scenario: Workspace startup sequence

```gherkin
Scenario: Workspace startup sequence
  Given docker compose up with vscode profile
  When qdrant and neo4j start and become healthy
  And headroom starts (after qdrant and neo4j healthy)
  And headroom healthcheck passes at http://localhost:8787/health
  When workspace starts (after headroom healthy)
  Then SSH daemon is ready (healthcheck: TCP/2222)
  And credential wiring completes (GitHub, ADO)
  And workspace-home volume is initialized with WORKSPACE_NAME templating
  When vscode-server starts (after workspace healthy)
  Then code serve-web binds 0.0.0.0:8080
  And mounts same workspace-home (reads pre-wired auth, profile, extensions)
  And healthcheck passes at http://localhost:8080
```

---

## Feature: Single Image Multi-Purpose Deployment

Enables same container image to serve as workspace and vscode-server with runtime configuration via ENTRYPOINT override and WORKSPACE_NAME templating.

### Background

```gherkin
Background:
  Given zzaia-agentic-workspace:latest image is built
  And image contains VS Code extensions layer and mise tools
  And devcontainer.json and docker-compose.yml are included in image
```

---

### Scenario: Same image runs as workspace and vscode-server

```gherkin
Scenario: Same image runs as workspace and vscode-server
  Given zzaia-agentic-workspace:latest image is built
  When workspace container starts with default ENTRYPOINT
  Then SSH daemon, credential wiring, and Aspire MCP start
  When vscode-server container starts with command override
  Then only code serve-web starts (no SSH setup)
  And both containers share the same VS Code extensions layer from the image
```

---

### Scenario: WORKSPACE_NAME runtime templating

```gherkin
Scenario: WORKSPACE_NAME runtime templating
  Given WORKSPACE_NAME=myteam set in docker compose environment
  When workspace entrypoint runs
  Then all {{WORKSPACE_NAME}} placeholders in .json and .code-workspace files are replaced with myteam
  And zzaia.code-workspace is renamed to myteam.code-workspace
  And vscode-server uses /home/user/workspace/myteam.code-workspace as default workspace
```

---

## Acceptance Criteria Mapping

| Scenario | Domain | Layer | Status |
|----------|--------|-------|--------|
| VS Code browser access survives workspace restart | Decoupled VS Code Browser UI | - | ✅ Covered |
| vscode-server disabled for SSH-only deployments | Decoupled VS Code Browser UI | - | ✅ Covered |
| vscode-server healthcheck replaces watchdog | Decoupled VS Code Browser UI | - | ✅ Covered |
| VS Code Remote attaches to workspace via Dev Containers | Dev Containers Attach | - | ✅ Covered |
| Profile consistency across all connection types | Dev Containers Attach | - | ✅ Covered |
| Agent session with automatic context compression via headroom | Headroom AI Proxy | Layer 1 | ✅ Covered |
| Gemini CLI routes through headroom proxy | Headroom AI Proxy | Layer 1 | ✅ Covered |
| Headroom passthrough on compression failure | Headroom AI Proxy | Layer 1 | ✅ Covered |
| Semantic search retrieval via qdrant and neo4j | Headroom AI Proxy | Layer 1 | ✅ Covered |
| Background code-graph indexing auto-improves context scoring | Headroom AI Proxy | Layer 1 | ✅ Covered |
| Agent request receives automatic memory injection from proxy | Headroom Automatic Memory Injection | Layer 1 | ✅ Covered |
| Agent response automatically stored as memory by proxy | Headroom Automatic Memory Injection | Layer 1 | ✅ Covered |
| Memory scoped by x-headroom-user-id header | Headroom Automatic Memory Injection | Layer 1 | ✅ Covered |
| VS Code extension gets automatic memory injection through proxy | Headroom Automatic Memory Injection | Layer 1 | ✅ Covered |
| Agent explicitly calls search_memory for filtered memory queries | OpenMemory MCP (Supplementary) | Layer 2 | ✅ Covered |
| Agent explicitly stores structured memory via OpenMemory | OpenMemory MCP (Supplementary) | Layer 2 | ✅ Covered |
| Agent explicitly calls find_callers for structured code queries | CodeGraphContext MCP (Supplementary) | Layer 2 | ✅ Covered |
| Agent explicitly navigates class hierarchy via MCP | CodeGraphContext MCP (Supplementary) | Layer 2 | ✅ Covered |
| Agent identifies dead code via code graph analysis | CodeGraphContext MCP (Supplementary) | Layer 2 | ✅ Covered |
| Agent leverages two-layer context for complex refactoring | Two-Layer Interaction | Layer 1 + 2 | ✅ Covered |
| SSH connection to workspace | Connection Type Matrix | - | ✅ Covered |
| Workspace startup sequence | Connection Type Matrix | - | ✅ Covered |
| Same image runs as workspace and vscode-server | Single Image Multi-Purpose Deployment | - | ✅ Covered |
| WORKSPACE_NAME runtime templating | Single Image Multi-Purpose Deployment | - | ✅ Covered |
| VS Code extension receives Layer 1 automatic memory injection via proxy | Two-Layer Triple-Stack Coverage | Layer 1 | ✅ Covered |
| VS Code extension accesses Layer 2 supplementary MCP tools | Two-Layer Triple-Stack Coverage | Layer 2 | ✅ Covered |

---

## Feature: Session Memory via OpenMemory MCP — Layer 2 (Supplementary)

Provides explicit agent-initiated MCP tools for structured queries and filtering beyond automatic Headroom memory injection, backed by Postgres and Qdrant vector search.

### Background

```gherkin
Background:
  Given openmemory service is running on port 5005
  And Postgres database is healthy and initialized
  And Qdrant vector database is healthy
  And agent has MCP tools auto-discovered (search_memory, add_memories, list_memories)
  And Headroom Layer 1 automatic memory injection is active
```

---

### Scenario: Agent explicitly calls search_memory for filtered memory queries

```gherkin
Scenario: Agent explicitly calls search_memory for filtered memory queries
  Given agent needs memories from specific date range or topic
  When agent explicitly calls search_memory MCP tool with filters (date_range, agent_id, topic)
  Then OpenMemory returns semantically similar memories ranked by relevance
  And results are filtered by agent-specified constraints
  And Headroom Layer 1 automatic injection complements this structured query
  And agent can combine automatic context with explicit filtered results
```

---

### Scenario: Agent explicitly stores structured memory via OpenMemory

```gherkin
Scenario: Agent explicitly stores structured memory via OpenMemory
  Given agent completes a complex task requiring explicit memory documentation
  When add_memories MCP tool is called with rich metadata (tags, relationships, importance)
  Then memory is indexed in Qdrant with semantic embeddings
  And metadata (timestamp, task_id, agent_id, tags) is stored in Postgres
  And memory becomes available for both automatic Headroom injection and explicit searches
  And structured tagging improves future filtering and relevance scoring
```

---

### Scenario: Memory persists across container restarts

```gherkin
Scenario: Memory persists across container restarts
  Given memories stored in openmemory service
  And Postgres database has persistent volume
  When openmemory container restarts
  Then all memories are recovered from Postgres
  And Qdrant index is rebuilt from Postgres data
  And agent sessions resume with full memory context
```

---

### Scenario: Multiple agents share the same memory store

```gherkin
Scenario: Multiple agents share the same memory store
  Given Claude Code and Codex agents running in parallel
  When Claude Code adds a memory via add_memories
  Then Codex can search and retrieve that memory immediately
  And all agents operate on consistent memory state
  And memory updates are atomic across the store
```

---

### Scenario: Agent searches memory with specific query and gets ranked results

```gherkin
Scenario: Agent searches memory with specific query and gets ranked results
  Given multiple memories stored from different tasks and sessions
  When agent calls search_memory with query "database migration failure"
  Then Qdrant returns results ranked by semantic similarity
  And results include memory_id, content, relevance_score, and timestamp
  And agent can rank-filter results by score threshold
```

---

## Feature: Workspace Semantic Search via CodeGraphContext — Layer 2 (Supplementary)

Provides explicit agent-initiated MCP tools for precise code structure queries beyond Headroom's automatic background code-graph indexing, using tree-sitter and file watching.

### Background

```gherkin
Background:
  Given code-graph service is running
  And workspace-repos volume is mounted in code-graph container
  And tree-sitter AST parser initialized for supported languages
  And MCP tools auto-discovered (find_callers, find_callees, class_hierarchy, call_chain)
  And file watcher monitors source file changes in real-time
  And Headroom Layer 1 background code-graph indexing is active
```

---

### Scenario: Agent explicitly calls find_callers for structured code queries

```gherkin
Scenario: Agent explicitly calls find_callers for structured code queries
  Given a function exportData exists in workspace/repo/src/core/export.ts
  When agent explicitly calls find_callers MCP tool with function_name=exportData
  Then results include all call sites across the workspace with precise locations
  And each result includes file_path, line_number, and code_context
  And cross-repository calls are included if function is exported
  And Headroom Layer 1 background index complements this explicit query with relevance scoring
```

---

### Scenario: Agent explicitly navigates class hierarchy via MCP

```gherkin
Scenario: Agent explicitly navigates class hierarchy via MCP
  Given class UserService extends BaseService in workspace
  When agent explicitly calls class_hierarchy MCP tool with class_name=UserService
  Then results include parent classes and all child classes with inheritance chain
  And inheritance chain is returned in order (root → leaf)
  And interface implementations are listed with method signatures
  And CodeGraphContext MCP provides structured hierarchy beyond Headroom's automatic context
```

---

### Scenario: Agent traces call chain from entry point to implementation

```gherkin
Scenario: Agent traces call chain from entry point to implementation
  Given entry point function processRequest in workspace/app.ts
  When call_chain MCP tool is called with start_function=processRequest
  And target_function=databaseQuery
  Then results include ordered path from entry to target
  Each step includes function_name, file_path, and line_number
  And dead-end branches are flagged for code cleanup
```

---

### Scenario: Index updates automatically when source files change

```gherkin
Scenario: Index updates automatically when source files change
  Given code-graph service running with file watcher active
  When developer modifies file workspace/repo/src/models/user.ts
  Then file watcher detects change within 500ms
  And affected AST nodes are re-parsed for modified functions
  And semantic index is refreshed incrementally
  And subsequent queries reflect updated code structure
```

---

### Scenario: Agent queries code graph across multiple repository worktrees

```gherkin
Scenario: Agent queries code graph across multiple repository worktrees
  Given workspace contains multiple repository worktrees
  And code-graph service has visibility into all worktrees
  When find_callers is called for a shared function
  Then results include callers from all worktrees
  And results are deduplicated and ranked by distance
  And cross-repo dependencies are made explicit
```

---

### Scenario: Agent identifies dead code via code graph analysis

```gherkin
Scenario: Agent identifies dead code via code graph analysis
  Given function unused_helper exists in workspace/repo/src/utils/helpers.ts
  When agent explicitly calls find_callers for unused_helper
  And find_callers returns empty result set
  Then agent flags unused_helper as dead code candidate
  And Headroom Layer 1 background index supports this analysis with historical context
  And recommendation includes removal severity and audit trail
```

---

### Scenario: Agent leverages two-layer context for complex refactoring

```gherkin
Scenario: Agent leverages two-layer context for complex refactoring
  Given agent begins refactoring a widely-used service class
  When agent receives Headroom Layer 1 automatic memory injection
  Then automatic context includes prior refactoring decisions and patterns from this codebase
  When agent explicitly calls class_hierarchy and find_callers MCP tools
  Then structured code queries provide precise call sites and inheritance chains
  When agent calls search_memory with filters (date_range, refactoring-tag)
  Then filtered Layer 2 results complement automatic memory with specific prior attempts
  And agent makes refactoring decision informed by automatic + explicit context layers
```

---

## Feature: Two-Layer Triple-Stack Coverage Across All Clients

Ensures Layer 1 (Headroom automatic) and Layer 2 (OpenMemory and CodeGraphContext MCP) are accessible via all CLI and UI entry points with consistent credential and network configuration.

### Background

```gherkin
Background:
  Given Headroom proxy running with --memory --code-graph flags at http://headroom:8787
  And workspace container has OpenMemory MCP service on port 5005 (Layer 2)
  And workspace container has CodeGraphContext MCP service running (Layer 2)
  And ANTHROPIC_BASE_URL=http://headroom:8787 routes all API traffic through proxy
  And GEMINI_API_BASE=http://headroom:8787 set in all CLI environments
  And VS Code extension discovers MCP tools via stdio protocol
```

---

### Scenario: VS Code extension receives Layer 1 automatic memory injection via proxy

```gherkin
Scenario: VS Code extension receives Layer 1 automatic memory injection via proxy
  Given VS Code extension routes requests through ANTHROPIC_BASE_URL=http://headroom:8787
  When GitHub Copilot in Agent mode sends agent request
  Then Headroom proxy automatically injects relevant prior memories (Layer 1)
  And extension receives memory-enriched response transparently
  And no extension code changes required to benefit from automatic memory
  And memory injection works for all agent decisions in editor
```

---

### Scenario: VS Code extension accesses Layer 2 OpenMemory and CodeGraphContext MCP tools

```gherkin
Scenario: VS Code extension accesses Layer 2 supplementary MCP tools
  Given GitHub Copilot in Agent mode running in VS Code
  And workspace folder is open with multiple repositories
  When extension starts and autodiscovers MCP tools
  Then Layer 2 OpenMemory tools available (search_memory, add_memories, list_memories)
  And Layer 2 CodeGraphContext tools available (find_callers, find_callees, class_hierarchy, call_chain)
  And agent can explicitly call these tools from VS Code chat for filtered/structured queries
  And suggestions are informed by Layer 1 automatic context + Layer 2 explicit tools
```

---

### Scenario: Gemini CLI gets compression via GEMINI_API_BASE proxy

```gherkin
Scenario: Gemini CLI gets compression via GEMINI_API_BASE proxy
  Given gemini CLI is configured with GEMINI_API_BASE=http://headroom:8787
  When gemini CLI sends a request
  Then headroom proxy intercepts the request
  And applies context compression if context exceeds threshold
  And forwards to upstream Google Gemini API
  And agent receives valid response without configuration changes
```

---

### Scenario: All CLIs share the same OpenMemory memory store

```gherkin
Scenario: All CLIs share the same OpenMemory memory store
  Given Claude Code, Codex, and Gemini CLIs all configured to use port 5005
  When Claude Code adds a memory via add_memories
  And Codex CLI searches the same memory store in a subsequent session
  Then Codex retrieves the memory added by Claude Code
  And all agents operate on consistent, shared memory state
  And no memory isolation or duplication occurs
```

---

## Out of Scope

- Kubernetes deployment patterns (Docker Compose only)
- Multi-workspace container orchestration beyond docker compose
- GUI-based container management tools
- Windows-native Docker socket access
