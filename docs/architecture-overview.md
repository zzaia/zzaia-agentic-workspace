# ZZAIA Agentic Workspace — Architecture Overview

Multi-tenant agentic workspace running multiple AI coding agents (Claude Code, Gemini CLI, OpenAI Codex, GitHub Copilot) inside isolated Docker containers. Secrets are segregated into independent MCP sidecar containers so no secret is ever accessible from any agent's terminal, filesystem, or context. The workspace is accessible via browser VS Code, SSH, VS Code Remote SSH, and Dev Containers — all sharing the same VS Code profile, extensions, and agent configurations.

---

## Product ADRs — What the system must be

### PADR 001: Extensible Agent Runtime

**Decision**: The workspace supports multiple AI coding agent runtimes simultaneously — not coupled to any single agent vendor.

- Claude Code, Gemini CLI, OpenAI Codex, and GitHub Copilot are all installed and configured
- Each agent has its own native config folder and project instruction file under `agents/<agent>/`
- All agents share the same MCP tool surface via SSE endpoints
- Adopting a new agent means adding its CLI binary and native config — nothing else changes

**Rationale**: Multi-agent workspaces maximize optionality. Teams can choose the best agent for each task without reconfiguring the environment.

---

### PADR 002: Multiple Concurrent Instances on the Same Machine

**Decision**: The system supports running multiple independent workspace instances simultaneously on the same host.

- Each instance identified by `WORKSPACE_NAME` and runs on its own isolated Compose stack
- Instances do not share networks, volumes, or port bindings
- No coordination layer required between instances

**Rationale**: Development teams often work across multiple organizations or projects. A single-instance-per-machine constraint is a hard blocker to real-world usage.

---

### PADR 003: Any OS, Zero Host Dependencies Beyond Docker

**Decision**: The workspace runs identically on Ubuntu, macOS, and Windows. The only host prerequisite is Docker Desktop.

- A developer on any OS runs one command and gets a fully provisioned environment
- No manual tool installation, version management, or OS-specific setup on the host
- Remote machine deployments follow the same single-command pattern

**Rationale**: Eliminating host dependencies removes the "works on my machine" class of problems and dramatically reduces onboarding time.

---

### PADR 004: Segregated Execution Space for Autonomous Agents

**Decision**: Agents running in full-automatic mode must execute inside an isolated container that limits their access to the host machine.

- The container's Linux capabilities are reduced to the minimum required (`cap_drop: ALL` + explicit re-adds)
- The agent cannot read host files outside explicitly mounted volumes
- The blast radius of an autonomous agent is confined to the workspace container

**Rationale**: Full-automatic agent execution is a necessary productivity feature. Without isolation, it is also a security risk.

---

### PADR 005: Secrets Set Once at First Startup, Inaccessible Thereafter

**Decision**: All environment variables are provided once at the first `docker compose up`. After startup, secrets must not be readable from inside the running container.

- The developer does not manage secrets files or re-enter credentials on restarts
- Secret rotation requires an explicit operator action, not a container restart
- A running container cannot be used to exfiltrate the secrets that were used to start it

**Rationale**: Persistent secret accessibility inside containers is the most common vector for credential leakage in agentic systems.

---

### PADR 006: Developer-First UX — All Connection Types

**Decision**: The workspace must be operable through browser VS Code, SSH terminal, VS Code Remote SSH, and Dev Containers. No local IDE installation or plugin setup should be required.

- Browser access: open a URL, get a full VS Code environment with all extensions pre-installed
- SSH access: connect from any VS Code installation using standard Remote-SSH
- Dev Containers: attach to the running workspace container directly from VS Code
- All modes provide the same agentic capabilities, profile ("Main - Zzaia"), extensions, and VS Code settings

**Rationale**: Developer experience is a first-class architectural concern. Browser + SSH + Dev Containers covers every developer context.

---

### PADR 007: Secrets Never in Agent Context, Terminal, or SSH Session

**Decision**: API keys and sensitive credentials must never appear in the agent's context window, the vscode-server terminal, the SSH session environment, or any log.

- The agent calls tools via MCP SSE; the secret is consumed inside the sidecar and never returned
- `printenv`, shell history, and context inspection yield no API keys
- Each MCP sidecar is isolated: compromise of one sidecar does not expose other secrets

**Rationale**: Agents with access to secrets can leak them through tool calls, generated content, or context windows. The MCP sidecar pattern enforces a hard boundary.

---

## Implementation ADRs — How the system achieves it

### ADR 001: Docker Compose Project Namespacing for Multi-Tenancy

**Decision**: Each workspace instance is started with `docker compose -p $WORKSPACE_NAME`.

- `WORKSPACE_NAME` is a free-form slug chosen by the developer
- Port conflicts avoided via `VSCODE_PORT` and `SSH_PORT` per stack
- Three named Docker volumes scoped per workspace: `<WORKSPACE_NAME>-secrets`, `<WORKSPACE_NAME>-home`, `<WORKSPACE_NAME>-workspace`
- `WORKSPACE_NAME` is runtime-only — one image serves all workspace deployments; `{{WORKSPACE_NAME}}` placeholders in config files are substituted at container startup

**Rationale**: Compose project namespacing is native Docker isolation with zero extra infrastructure.

---

### ADR 002: MCP Sidecar Pattern for Secret Segregation

**Decision**: Every external API integration runs as a dedicated sidecar container receiving exactly one secret via environment variable.

| Sidecar | Port | Secret | Notes |
|---------|------|--------|-------|
| `mcp-tavily` | 3001 | `TAVILY_API_KEY` | Opt-in |
| `mcp-azure-devops` | 3002 | `ADO_MCP_AUTH_TOKEN` | Opt-in |
| `mcp-postman` | 3003 | `POSTMAN_API_KEY` | Opt-in |
| `mcp-newrelic` | 3004 | `NEW_RELIC_API_KEY` | Opt-in |
| `mcp-github` | 3005 | `GITHUB_PERSONAL_ACCESS_TOKEN` | Opt-in |
| `mcp-playwright` | 3006 | None | Always-on, headless Chromium |
| `aspire-mcp` | 3007 | None | Always-on, internal to workspace |
| `aspire-dashboard` | 18888 | None | Always-on, OTLP telemetry receiver |

- The `workspace` container holds zero API key environment variables for MCP integrations
- Each opt-in sidecar guards its own key: if empty, the process exits cleanly (code 0)

**Rationale**: Sidecar-per-secret is the minimal surface area principle applied to secrets.

---

### ADR 003: Minimal Linux Capabilities (`cap_drop: ALL`)

**Decision**: The `workspace` container drops all Linux capabilities and adds back only: `CHOWN`, `FOWNER`, `SETGID`, `SETUID`, `AUDIT_WRITE`.

- `DAC_OVERRIDE` and `DAC_READ_SEARCH` are intentionally absent — root inside the container cannot bypass file permission checks on files it does not own
- `--dangerously-skip-permissions` agents operate within these capability boundaries

**Rationale**: Reducing capabilities limits the blast radius of an autonomous agent.

---

### ADR 004: One-Time Secret Injection with Post-Startup Inaccessibility

**Decision**: Secrets are passed via environment variables at `docker compose up` time. On first start, only the SSH public key is written to `/secrets/.env` (mode 600). On all subsequent starts, the file already exists and env vars are ignored.

- Secrets exist only in the process environment during the first startup
- SSH terminal, vscode-server terminal, and agent shell have no access to API keys after startup

**Rationale**: One-time injection eliminates the need for a secrets manager while maintaining the invariant that API keys are not queryable from within the workspace after startup.

---

### ADR 005: Extensible Agent Runtime Interface

**Decision**: Multiple agent runtimes are installed and configured simultaneously.

| Agent | CLI Binary | Config Folder | Instruction File |
|-------|-----------|---------------|-----------------|
| Claude Code | `claude` (mise) | `agents/claude/.claude/` | `agents/claude/CLAUDE.md` |
| Gemini CLI | `gemini` (mise) | `agents/gemini/.gemini/` | `agents/gemini/GEMINI.md` |
| OpenAI Codex | `codex` (mise) | `agents/codex/.codex/` | `agents/codex/AGENTS.md` |
| GitHub Copilot | `gh copilot` | `agents/copilot/.github/` | `agents/copilot/.github/copilot-instructions.md` |

- All agents share the same MCP SSE endpoints — configured once, available everywhere

**Rationale**: Multi-agent support preserves team optionality. The shared MCP surface means integrations are configured once.

---

### ADR 006: Decoupled VS Code Server Container

**Decision**: `code serve-web` runs as a separate `vscode-server` container, not inside the `workspace` container. Both use the same Docker image.

- `workspace` entrypoint simplified to: SSH setup → credential wiring → WORKSPACE_NAME templating → Aspire MCP
- `vscode-server` uses a `command` override to run `code serve-web` only
- Watchdog restart loop removed; Docker `restart: unless-stopped` + native healthcheck (HTTP/8080) replaces it
- `vscode-server` starts after workspace is healthy (`depends_on: workspace: condition: service_healthy`)
- Browser UI is opt-in via Compose profile `vscode` — zero overhead for SSH-only or CI deployments

**Rationale**: Failure isolation, native recovery semantics, and simpler entrypoint logic. Browser UI and agent runtime have independent lifecycles.

---

### ADR 007: Tool Provisioning via `mise` and Dockerfile

**Decision**: All workspace tools are provisioned inside the Docker image via `mise.toml` and Dockerfile steps.

- `mise` manages language runtimes and CLI tools (Node.js, .NET, gh, agent CLIs)
- Miniforge3 (conda) is the sole Python provider
- The image is self-contained: any developer on Ubuntu, macOS, or Windows runs identically

**Rationale**: Zero-dependency host setup is the primary usability objective.

---

### ADR 008: Claude Code Authentication and Sudo Access

**Decision**: The workspace accepts environment variables for Claude Code authentication across five provider options (only one required).

| Priority | Provider | Variables |
|----------|----------|-----------|
| 1 | AWS Bedrock | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `ANTHROPIC_BEDROCK_BASE_URL` |
| 2 | Anthropic API Key | `ANTHROPIC_API_KEY` |
| 3 | Pro / Max OAuth | `CLAUDE_CODE_OAUTH_TOKEN` |
| 4 | Google Vertex AI | `CLAUDE_CODE_USE_VERTEX`, `ANTHROPIC_VERTEX_PROJECT_ID`, `CLOUD_ML_REGION` |
| 5 | Azure AI Foundry | `CLAUDE_CODE_USE_FOUNDRY`, `AZURE_FOUNDRY_BASE_URL` |

- `ADMIN_PASSWORD` — if set, enables password-based sudo; if empty, sudo is unavailable

**Rationale**: Agent auth credentials must exist in the process environment — unlike MCP sidecar secrets, agent auth cannot be moved to a sidecar.

---

### ADR 009: Single Image Strategy for Profile Consistency

**Decision**: Both `workspace` and `vscode-server` containers use the same Docker image (`zzaia-agentic-workspace:latest`).

- VS Code profile ("Main - Zzaia"), extensions, and settings are baked into the image once
- Both containers mount `workspace-home` volume → single `.vscode-server/extensions` directory
- `devcontainer.json` embedded in the image mirrors the same extension list for Dev Containers attach
- No duplication, no drift between connection types

**Rationale**: Profile and extension consistency across all entry points is critical for developer experience. Single-image enforces parity at build time.

---

### ADR 010: Headroom AI Proxy (Always-On Default)

**Decision**: `headroom` runs as a mandatory always-on proxy for all agent AI API calls (Anthropic and OpenAI), with Qdrant (vector DB) and Neo4j (graph DB) as backing services for full semantic search and session memory.

- `ANTHROPIC_BASE_URL=http://headroom:8787`, `OPENAI_BASE_URL=http://headroom:8787`, and `GEMINI_API_BASE=http://headroom:8787` are always set in the workspace environment
- No agent code changes required — transparent HTTP proxy; compression failure always passes through original content unchanged
- Three active features: **context compression** (reduces tokens for long sessions), **session memory** (rolling conversation state), **semantic search** (vector + graph retrieval via Qdrant + Neo4j)
- `workspace` depends on headroom healthy (`condition: service_healthy`) — Headroom readiness gates agent startup
- Headroom exposes `/health`, `/livez`, `/readyz` for orchestration; `/metrics` (Prometheus) for observability via Aspire Dashboard
- Passthrough guarantee: if compression fails, original content is forwarded unchanged — no agent call is ever dropped

**Rationale**: Compression, memory, and semantic search benefit every agent session — not just long ones. Making headroom always-on eliminates the "opt-in tax" where developers miss optimization benefits by default. Passthrough guarantee and health-gated startup preserve reliability without requiring a client-side fallback.

---

### ADR 011: OpenMemory MCP for Agent Session Memory

**Decision**: Deploy OpenMemory MCP service for persistent cross-session agent memory using Postgres and Qdrant backend; agents call `search_memory`, `add_memories`, and `list_memories` via MCP discovery.

- OpenMemory container runs `skpassegna/openmemory-mcp:latest` on port 5005
- Native MCP tools available to all agent CLIs and VS Code extensions without special wiring
- Postgres backend provides relational storage; Qdrant semantic index enables memory retrieval by relevance
- Local-first architecture — no external service dependencies; memory stays on-host
- Agent-initiated retrieval avoids memory pollution — agents request what they need, not pushed
- No lock-in to Headroom; works with any MCP client

**Rationale**: Standard MCP interface ensures compatibility across all agent toolchains. Postgres+Qdrant provide both relational queries and semantic search without external services. Agent-initiated access prevents spurious memory pollution that would degrade context quality.

---

### ADR 012: CodeGraphContext for Workspace Semantic Search

**Decision**: Deploy CodeGraphContext as MCP server for code graph queries across the workspace; agents call `find_callers`, `find_callees`, `class_hierarchy`, and `call_chain` via MCP.

- CodeGraphContext container runs `python:3.12-slim` with codegraphcontext package on stdio/MCP
- Tree-sitter AST parsing generates call graphs and class hierarchies in real-time
- Stores parsed graph in local KûzuDB or Neo4j database (`code-graph-db` named volume)
- Real-time file watching detects source changes and updates graph incrementally
- Agent-agnostic — any MCP client can query the workspace graph; no IDE dependency
- Replaces Headroom's undocumented `--code-graph` feature with explicit, observable MCP interface

**Rationale**: Tree-sitter AST parsing is language-agnostic and requires no IDE. Real-time file watching keeps the graph current without manual triggers. MCP makes code graph queries observable and agent-independent, enabling reuse across all coding tools.

---

### ADR 013: Headroom as Always-On Context Compression Proxy

**Decision**: Deploy Headroom as mandatory always-on HTTP reverse proxy for all agent AI API calls; all calls to Anthropic, OpenAI, and Gemini APIs route through `http://headroom:8787`.

- `ANTHROPIC_BASE_URL=http://headroom:8787`, `OPENAI_BASE_URL=http://headroom:8787`, `GEMINI_API_BASE=http://headroom:8787` are always set in workspace environment
- Achieves 34–90% token reduction on average; overhead <5ms per request
- Passthrough guarantee on failure — if compression fails, original content is forwarded unchanged; no agent call is ever dropped
- Covers Anthropic API, OpenAI API, Google Gemini API; transparent to agent code
- No agent changes required — standard HTTP proxy; compression transparent to clients

**Rationale**: Token reduction improves cost and latency for long-running agent sessions. Passthrough guarantee eliminates the reliability tax of adding a proxy. Making always-on defaults the optimization to all agents rather than requiring opt-in.

---

## C4 Context Diagram

```mermaid
C4Context
    title ZZAIA Agentic Workspace — System Context

    Person(dev, "Developer", "Browser / SSH / Dev Containers / VS Code Remote")
    System(workspace, "ZZAIA Workspace Stack", "Agentic workspace with isolated MCP integrations")
    System_Ext(ado, "Azure DevOps", "Work items, PRs, pipelines")
    System_Ext(tavily, "Tavily", "Web search and extract")
    System_Ext(postman, "Postman", "API collections and environments")
    System_Ext(newrelic, "New Relic", "Observability and log diagnostics")
    System_Ext(github, "GitHub", "Repositories, issues, actions")
    System_Ext(ai, "AI APIs", "Anthropic, OpenAI, Vertex, Bedrock, Foundry")
    System_Ext(docker, "Docker Desktop", "Container runtime on host OS")

    Rel(dev, workspace, "Accesses", "HTTP :8080 / SSH :2222 / Dev Containers")
    Rel(workspace, ado, "DevOps operations", "HTTPS via MCP sidecar")
    Rel(workspace, tavily, "Web search", "HTTPS via MCP sidecar")
    Rel(workspace, postman, "API management", "HTTPS via MCP sidecar")
    Rel(workspace, newrelic, "Log diagnostics", "HTTPS via MCP sidecar")
    Rel(workspace, github, "GitHub operations", "HTTPS via MCP sidecar")
    Rel(workspace, ai, "Agent API calls", "HTTPS (direct or via Headroom proxy)")
    Rel(docker, workspace, "Hosts", "Docker Compose")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## C4 Container Diagram

```mermaid
C4Container
    title ZZAIA Agentic Workspace — Container Architecture

    Person(dev, "Developer", "Browser or SSH")

    System_Boundary(stack, "<workspace> Compose Stack") {
        Container(ws, "workspace", "Ubuntu 24.04", "SSH :2222 + agent runtime (Claude/Gemini/Codex/Copilot) + mise + Aspire MCP :3007")
        Container(vscode, "vscode-server", "Same image, command override", "code serve-web :8080 [profile: vscode]")
        Container(headroom, "headroom", "Headroom proxy", "HTTP proxy :8787 — compression proxy for AI API calls [always-on]")
        Container(qdrant, "qdrant", "Qdrant v1.17", "Vector DB :6333 — semantic search embeddings for headroom and openmemory")
        Container(neo4j, "neo4j", "Neo4j 5.15", "Graph DB :7687 — knowledge graph retrieval for headroom")
        Container(openmemory, "openmemory-mcp", "skpassegna/openmemory-mcp", "Session memory MCP server, Postgres + Qdrant backend, MCP :5005 [always-on]")
        Container(codegraph, "code-graph-mcp", "python:3.12-slim + codegraphcontext", "Workspace code graph MCP — tree-sitter AST parsing, KûzuDB/Neo4j index [always-on]")
        Container(tavily, "mcp-tavily", "node:alpine + supergateway", "Holds TAVILY_API_KEY, exposes SSE :3001")
        Container(ado, "mcp-azure-devops", "node:alpine + supergateway", "Holds ADO_MCP_AUTH_TOKEN, exposes SSE :3002")
        Container(postman, "mcp-postman", "node:alpine + supergateway", "Holds POSTMAN_API_KEY, exposes SSE :3003")
        Container(newrelic, "mcp-newrelic", "node:alpine + supergateway", "Holds NEW_RELIC_API_KEY, exposes SSE :3004")
        Container(ghsidecar, "mcp-github", "node:alpine + supergateway", "Holds GITHUB_PERSONAL_ACCESS_TOKEN, exposes SSE :3005")
        Container(playwright, "mcp-playwright", "playwright/mcp", "Headless Chromium, always-on, SSE :3006")
        Container(aspireds, "aspire-dashboard", "dotnet/aspire-dashboard", "OTLP receiver + telemetry UI, always-on, :18888")
    }

    System_Boundary(host, "Docker Host") {
        ContainerDb(home, "<workspace>-home", "Named volume", "Persisted home dir — .vscode-server/, .claude/, agent configs, auth tokens")
        ContainerDb(repos, "<workspace>-workspace", "Named volume", "Git repositories and worktrees")
        ContainerDb(secrets, "<workspace>-secrets", "Named volume", "SSH host keys and public key")
        Container(dockersock, "/var/run/docker.sock", "Unix socket", "Docker API access for agent-initiated ops")
    }

    Rel(dev, ws, "SSH terminal / VS Code Remote SSH / Dev Containers", "127.0.0.1:SSH_PORT")
    Rel(dev, vscode, "VS Code browser", "127.0.0.1:VSCODE_PORT")
    Rel(ws, vscode, "Shares workspace-home volume", "named volume")
    Rel(ws, headroom, "All AI API calls (Anthropic + OpenAI + Gemini)", "ANTHROPIC_BASE_URL / OPENAI_BASE_URL / GEMINI_API_BASE :8787")
    Rel(headroom, qdrant, "Vector embeddings for compression", "semantic search :6333")
    Rel(headroom, neo4j, "Knowledge graph queries", "Bolt :7687")
    Rel(ws, openmemory, "MCP tool calls", "search_memory / add_memories / list_memories :5005")
    Rel(openmemory, qdrant, "Semantic memory index", "vector DB :6333")
    Rel(ws, codegraph, "MCP tool calls", "find_callers / find_callees / class_hierarchy / call_chain")
    Rel(codegraph, repos, "Parse source files", "named volume /home/user/workspace")
    Rel(ws, tavily, "MCP tool calls", "SSE mcp network")
    Rel(ws, ado, "MCP tool calls", "SSE mcp network")
    Rel(ws, postman, "MCP tool calls", "SSE mcp network")
    Rel(ws, newrelic, "MCP tool calls", "SSE mcp network")
    Rel(ws, ghsidecar, "MCP tool calls", "SSE mcp network")
    Rel(ws, playwright, "MCP tool calls", "SSE mcp network")
    Rel(ws, aspireds, "OTLP telemetry", "AppHost → :18889")
    Rel(ws, home, "Home directory", "named volume /home/user")
    Rel(ws, repos, "Repository storage", "named volume /home/user/workspace")
    Rel(ws, secrets, "SSH keys", "named volume /secrets")
    Rel(ws, dockersock, "Docker API", "bind mount")
    Rel(vscode, home, "Read VS Code state", "named volume /home/user")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")
```

## Project Structure

```
zzaia-agentic-workspace/
├── agents/                  # Per-agent configuration directories
│   ├── claude/              # Claude Code — CLAUDE.md, .mcp.json, .claudeignore, .claude/
│   ├── gemini/              # Gemini CLI — GEMINI.md, .gemini/
│   ├── codex/               # OpenAI Codex — AGENTS.md, .codex/
│   └── copilot/             # GitHub Copilot — .github/copilot-instructions.md
├── vscode/                  # VS Code profile — settings, extensions, launch configs, workspace file
├── docker/
│   ├── Dockerfile           # Single image — Ubuntu 24.04, mise, SSH, VS Code server pre-baked
│   ├── docker-compose.yml   # Stack — workspace + vscode-server + headroom (profiles) + 8 sidecars
│   ├── entrypoint.sh        # SSH setup, credential wiring, WORKSPACE_NAME templating, Aspire MCP
│   ├── mise.toml            # Tool versions — node, dotnet, agent CLIs, VS Code extensions
│   └── sshd_config          # SSH daemon hardening config
├── docs/
│   ├── architecture-overview.md  # This document
│   └── bdd-scenarios.md          # BDD scenarios for all workspace features
├── workspace/host/          # .NET Aspire AppHost for integrated local testing
├── workspace/               # Multi-repository git worktrees
├── QUICKSTART.md            # Setup instructions
└── README.md                # Project overview
```

## Architecture Components

### Deployment Units

| Container | Role | Port | Profile |
|-----------|------|------|---------|
| `workspace` | SSH daemon, agent runtime, mise toolchain, Aspire MCP | 2222 (SSH) | always |
| `vscode-server` | Browser VS Code (`code serve-web`) | 8080 | `vscode` |
| `headroom` | AI proxy — context compression for Anthropic, OpenAI, Gemini | 8787 (internal) | always |
| `qdrant` | Vector DB — semantic embeddings for headroom and openmemory | 6333 (internal) | always |
| `neo4j` | Graph DB — knowledge graph retrieval for headroom | 7687 (internal) | always |
| `openmemory-mcp` | Session memory MCP server — Postgres + Qdrant backend | 5005 (MCP) | always |
| `code-graph-mcp` | Workspace code graph MCP — tree-sitter AST parsing | stdio (MCP) | always |
| `mcp-tavily` | Web search MCP adapter | 3001 (internal) | conditional |
| `mcp-azure-devops` | Azure DevOps MCP adapter | 3002 (internal) | conditional |
| `mcp-postman` | Postman MCP adapter | 3003 (internal) | conditional |
| `mcp-newrelic` | New Relic MCP adapter | 3004 (internal) | conditional |
| `mcp-github` | GitHub MCP adapter | 3005 (internal) | conditional |
| `mcp-playwright` | Headless Chromium MCP | 3006 (internal) | always |
| `aspire-dashboard` | OTLP telemetry receiver + UI | 18888 | always |

### Shared State (Named Volumes)

| Volume | Mount | Contents |
|--------|-------|----------|
| `<ws>-home` | `/home/user` | `.vscode-server/`, `.claude/`, agent configs, auth tokens |
| `<ws>-workspace` | `/home/user/workspace` | Git repositories and worktrees |
| `<ws>-secrets` | `/secrets` | SSH host keys and public key |
| `<ws>-headroom-qdrant` | `/qdrant/storage` | Vector embeddings for headroom and openmemory |
| `<ws>-headroom-neo4j` | `/data` | Knowledge graph for headroom retrieval |
| `<ws>-openmemory-data` | `/var/lib/postgresql/data` | OpenMemory Postgres persistent memory store |
| `<ws>-code-graph-db` | `/data/code-graph` | CodeGraphContext graph index (KûzuDB or Neo4j) |

### Connection Types

| Type | Entry Point | Notes |
|------|-------------|-------|
| SSH | `workspace:2222` | sshd with pubkey auth |
| Browser | `vscode-server:8080` | `code serve-web`, no token (profile: vscode) |
| Dev Containers | Docker socket → workspace | `devcontainer.json` in image |
| VS Code Remote SSH | `workspace:2222` | Remote SSH extension |

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Container runtime | Docker Desktop (Linux / macOS / Windows) |
| Workspace OS | Ubuntu 24.04 LTS |
| Agent runtimes | Claude Code, Gemini CLI, OpenAI Codex, GitHub Copilot |
| Developer UI | `code serve-web` (Microsoft VS Code) + OpenSSH |
| Dev Containers | `devcontainer.json` embedded in workspace image |
| **AI proxy (Headroom)** | **HTTP reverse proxy — 34–90% token reduction, <5ms overhead, passthrough on failure** |
| **Session memory (OpenMemory MCP)** | **Postgres + Qdrant backend, native MCP tools: search_memory, add_memories, list_memories** |
| **Code graph (CodeGraphContext)** | **Tree-sitter AST → KûzuDB/Neo4j, MCP tools: find_callers, find_callees, class_hierarchy, call_chain** |
| Vector DB | Qdrant v1.17 (headroom compression + openmemory semantic index) |
| Graph DB | Neo4j 5.15 (headroom knowledge graph retrieval + codegraph optional backend) |
| Tool provisioning | mise (agent CLIs, node, dotnet) + Miniforge3 (Python/conda) |
| MCP bridge | supergateway (stdio → SSE) + native MCP servers (openmemory, codegraph) |
| Multi-tenancy | Docker Compose project namespacing |
| Secret lifecycle | Process env → one-time file write → sealed |
| Telemetry | .NET Aspire Standalone Dashboard (OTLP receiver) |

## Security Model

| Threat | Mitigation |
|--------|-----------|
| Agent exfiltrates API keys | Keys never in workspace container env after startup |
| Agent modifies host filesystem | Only `/secrets` and `/home/user/workspace` volumes mounted; `cap_drop: ALL` |
| Agent escapes container | No `SYS_ADMIN`, `NET_ADMIN`, or `DAC_OVERRIDE` capabilities |
| Secret visible in terminal | Env vars ephemeral after startup; SSH key persisted at `/secrets/.env` (root-owned, mode 600) |
| Cross-stack secret leakage | Each stack on isolated bridge network; no shared volumes |
| Port scanning from container | MCP ports bound to internal network only |
| VS Code server compromise | `vscode-server` container has no secrets — mounts workspace-home read-only for VS Code state |

## Related Documentation

- [QUICKSTART.md](../QUICKSTART.md) — Step-by-step setup instructions
- [README.md](../README.md) — Project overview
- [docker/](../docker/) — Dockerfile, Compose, entrypoint, and mise.toml
- [bdd-scenarios.md](bdd-scenarios.md) — BDD scenarios for all workspace features
- [agents/claude/CLAUDE.md](../agents/claude/CLAUDE.md) — Claude Code command hierarchy and standards
- [agents/claude/.mcp.json](../agents/claude/.mcp.json) — MCP server configuration
