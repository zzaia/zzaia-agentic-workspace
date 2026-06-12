# ZZAIA Agentic Workspace — Architecture Overview

Multi-tenant agentic workspace running multiple AI coding agents (Claude Code, Gemini CLI, OpenAI Codex, GitHub Copilot) inside isolated Docker containers. Secrets are segregated into independent MCP sidecar containers so no secret is ever accessible from any agent's terminal, filesystem, or context. The workspace is accessible via browser VS Code, SSH, VS Code Remote SSH, and Dev Containers — all sharing the same VS Code profile, extensions, and agent configurations.

---

## Product ADRs — What the system must be

### PADR 001: Extensible Agent Runtime

**Decision**: The workspace supports multiple AI coding agent runtimes simultaneously — not coupled to any single agent vendor.

- Claude Code, Gemini CLI, OpenAI Codex, and GitHub Copilot are all installed and configured
- Each agent has its own native config folder and project instruction file under `agents/<agent>/`
- All agents share the same MCP tool surface via direct streamableHttp connections declared in `.mcp.json` (shared `workspace-home` volume)
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

### ADR 002: Central Vault with Sidecar Fetching

**Decision**: vault-server holds all secrets in HashiCorp Vault KV v2. At startup, the deploy script pushes all secrets to vault-server. MCP sidecars fetch only their needed secret at runtime via Vault API.

| Service | Port | Role | Notes |
|---------|------|------|-------|
| `vault-server` | 8200 | Production Vault (file backend, AES-256-GCM encryption at rest) | receives BWS_ACCESS_TOKEN only; fetches all secrets from Bitwarden at startup; generates git-sidecar SSH keypair; enables AppRole auth |
| `git-sidecar` | 2223 (SSH) | SSH git proxy — workspace agents clone/push private repos | Fetches SSH pubkey + PATs from Vault; ForceCommand restricts every session to `git-proxy-cmd`; no PAT ever visible in agent terminal |
| `mcp-tavily` | 3001 | Fetches `TAVILY_API_KEY` from Vault | Opt-in |
| `mcp-azure-devops` | 3002 | Fetches `ADO_MCP_AUTH_TOKEN` from Vault | Opt-in |
| `mcp-postman` | 3003 | Fetches `POSTMAN_API_KEY` from Vault | Opt-in |
| `mcp-newrelic` | 3004 | Fetches `NEW_RELIC_API_KEY` from Vault | Opt-in |
| `mcp-github` | 3005 | Fetches `GITHUB_PERSONAL_ACCESS_TOKEN` from Vault | Opt-in |
| `mcp-playwright` | 3006 | No secrets required | Always-on, headless Chromium |
| `mcp-headroom` | 3008 | No secrets required | Always-on, MCP gateway for ml-server |

- The `workspace` container holds zero API key environment variables
- MCP sidecars fetch secrets at runtime: `VAULT_ADDR=http://vault-server:8200`, `VAULT_TOKEN` injected at startup
- Vault UI at `http://localhost:8200/ui` (localhost only) for inspection and audit logs

**Rationale**: Central vault eliminates secret duplication and enables audit logging. Sidecars fetch only what they need at runtime, not at startup.

---

### ADR 003: Minimal Linux Capabilities (`cap_drop: ALL`)

**Decision**: The `workspace` container drops all Linux capabilities and adds back only: `CHOWN`, `FOWNER`, `SETGID`, `SETUID`, `AUDIT_WRITE`.

- `DAC_OVERRIDE` and `DAC_READ_SEARCH` are intentionally absent — root inside the container cannot bypass file permission checks on files it does not own
- `--dangerously-skip-permissions` agents operate within these capability boundaries

**Rationale**: Reducing capabilities limits the blast radius of an autonomous agent.

---

### ADR 004: Deploy-Time Secret Bootstrap via Bitwarden to Vault

**Decision**: Secrets are provided to vault-server via `BWS_ACCESS_TOKEN` at deploy time. vault-server performs a full initialization sequence at container startup: initialize Vault, unseal, enable KV v2, generate SSH keypair, bootstrap secrets from Bitwarden, configure AppRole auth.

**vault-server startup sequence:**

1. Start Vault in background → `vault operator init` (1 key share, threshold 1)
2. Store root token + unseal key in `/vault/data/.init` (chmod 600, inside encrypted volume)
3. `vault operator unseal` using the stored key
4. Enable KV v2 secret engine at `secret/`
5. Generate ed25519 SSH keypair; write `GIT_SIDECAR_AGENT_KEY` + `GIT_SIDECAR_AGENT_PUBKEY` to `secret/workspace`
6. If `BWS_ACCESS_TOKEN` set: run `bws secret list --output json` and write all secrets to KV paths (see below); unset token
7. Enable AppRole auth method; bind `git-sidecar-policy` to read `secret/workspace`, `secret/mcp/github`, `secret/mcp/azure-devops`
8. Kill background Vault; restart as foreground PID 1

**Vault KV paths:**

| Path | Contents |
|------|---------|
| `secret/ai` | `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TAVILY_API_KEY`; optional credential pool: `CLAUDE_OAUTH_TOKEN_1..N`, `ANTHROPIC_API_KEY_1..N` |
| `secret/mcp/github` | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `secret/mcp/azure-devops` | `ADO_MCP_AUTH_TOKEN`, `AZURE_DEVOPS_ORGANIZATION` |
| `secret/cloud` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, Bedrock/Vertex/Foundry vars |
| `secret/integrations` | `POSTMAN_API_KEY`, `NEW_RELIC_API_KEY` |
| `secret/workspace` | `GIT_SIDECAR_AGENT_KEY` (private), `GIT_SIDECAR_AGENT_PUBKEY` (public) |

**AppRole policies:**

| Policy | Paths |
|--------|-------|
| `git-sidecar-policy` | `secret/data/workspace` (read), `secret/data/mcp/github` (read), `secret/data/mcp/azure-devops` (read) |
| `mcp-policy` | `secret/data/mcp/*` (read) |
| `workspace-policy` | `secret/data/workspace/*` (read), `secret/data/infra/*` (read) |

**Rationale**: Vault production mode with file backend provides AES-256-GCM encryption at rest — no secret ever touches host disk or .env files. Bitwarden is an optional single source of truth for initial secret values; Vault is the runtime secret store with audit logging and access policies. The SSH keypair generation inside vault-server eliminates the chicken-and-egg problem of distributing git-sidecar credentials.

---

### ADR 005: Extensible Agent Runtime Interface

**Decision**: Multiple agent runtimes are installed and configured simultaneously.

| Agent | CLI Binary | Config Folder | Instruction File |
|-------|-----------|---------------|-----------------|
| Claude Code | `claude` (npm) | `agents/claude/.claude/` | `agents/claude/CLAUDE.md` |
| Gemini CLI | `gemini` (npm) | `agents/gemini/.gemini/` | `agents/gemini/GEMINI.md` |
| OpenAI Codex | `codex` (npm) | `agents/codex/.codex/` | `agents/codex/AGENTS.md` |
| GitHub Copilot | `gh copilot` | `agents/copilot/.github/` | `agents/copilot/.github/copilot-instructions.md` |

- All agents share the same MCP tool surface — `.mcp.json` on the shared `workspace-home` volume is configured once by workspace-server at startup

**Rationale**: Multi-agent support preserves team optionality. The shared MCP surface means integrations are configured once.

---

### ADR 006: Decoupled Server Containers with Optional Profiles

**Decision**: The workspace runs as a set of containers where `workspace-server` is the always-on authoritative container. Optional servers (`vscode-sidecar`, `containers-dev-sidecar`, `jupyter-sidecar`, `tunnel-sidecar`) depend on workspace-server and share its home volume.

| Server | Container | Profile | Purpose |
|--------|-----------|---------|---------|
| Primary workspace | `workspace-server` | _(none, always starts)_ | SSH daemon + Ansible bootstrap + shared home owner |
| Browser IDE | `vscode-sidecar` | `vscode` | `code serve-web` on VSCODE_PORT |
| Dev Containers | `containers-dev-sidecar` | `devcontainer` | VS Code Dev Containers extension attachment |
| Jupyter | `jupyter-sidecar` | `jupyter` | JupyterLab on JUPYTER_PORT |
| VS Code Tunnel | `tunnel-sidecar` | `tunnel` | VS Code Tunnel for remote access via vscode.dev |
| Docker UI | `portainer-server` | `portainer` | Portainer CE browser UI for DinD container management on PORTAINER_PORT |

- `workspace-server` always starts — it owns the shared `workspace-home` volume and exposes SSH
- All optional servers depend on `workspace-server: condition: service_healthy` — they start only after workspace-server completes Ansible bootstrap
- All containers share `workspace-home` — one consistent home directory, credentials, and tool installations
- SSH-only deployment: leave `server-profiles` empty — only `workspace-server` starts
- Profiles are read from `server-profiles` Bitwarden secret at startup time; installation scripts build dynamic `--profile` flags
- `portainer-server` depends on `dind-server: condition: service_healthy`; connects via `DOCKER_HOST=tcp://dind-server:2375` (internal bridge, no socket mount)

**Rationale**: Shared home eliminates configuration drift between access methods. workspace-server as authoritative owner simplifies initialization — tools, credentials, and home seed are set up once.

---

### ADR 007: Tool Provisioning via Ansible Roles

**Decision**: Tool installation uses Ansible roles running inside the workspace-server container at startup. Roles are organized by tool group and execute in three plays: system setup (root), user-space tools (become_user: user, INSTALL_PREFIX=/opt/tools), and credentials/GPU (root).

- Roles: `system`, `user-setup`, `vscode-cli`, `node`, `dotnet`, `python`, `cli`, `path-config`, `credentials`, `gpu`
- Version pins live in `docker/containers/workspace-server/ansible/group_vars/all.yml` — single file to bump tool versions
- All user-space tools install to `INSTALL_PREFIX=/opt/tools` (separate volume from /home/user)
- Bootstrap marker: `/opt/tools/.bootstrap/tools.ready`
- workspace-server runs Ansible playbook during entrypoint; optional servers skip it (tools already in shared tools volume)

**Rationale**: Ansible replaces shell script + mise with a declarative, modular, industry-standard infrastructure tool. Roles are composable, reusable, and idempotent. All tool versions centralized in a single YAML file.

---

### ADR 007A: MCP Transport via supergateway (streamableHttp, stateful)

**Decision**: All MCP containers use `supergateway@3.4.3` with `--outputTransport streamableHttp --stateful` for robust, session-isolated, long-lived connections.

- `--outputTransport streamableHttp` (not SSE): line-by-line streaming, no buffering delays, clients must send `Accept: application/json, text/event-stream`
- `--stateful`: one isolated child process per client session (identified by `Mcp-Session-Id` header). Multiple agent containers (workspace-server, vscode-sidecar, jupyter-sidecar, containers-dev-sidecar) connect concurrently — each session is fully independent. Stateless mode (one process per HTTP request) caused process crashes on disconnect and orphan leaks under concurrent agent load (#138, #143)
- supergateway@3.4.3 is the stable rollback from v3.3.0 which introduced concurrency regressions

**Rationale**: Stateful per-session isolation is required for multi-agent environments. Stateless mode is parallel-safe in theory but crashes under real concurrent disconnects. streamableHttp eliminates SSE buffering and connection pooling complexity.

---

### ADR 007B: bifrost MCP Architecture — Code Mode vs Direct Connections

**Decision**: bifrost's `/mcp` MCP endpoint exposes **Code Mode tools only** (Starlark sandbox). Upstream MCP server tools are accessed via direct connections in `.mcp.json`.

**bifrost `/mcp` endpoint behavior:**
- Returns Code Mode meta-tools (`listToolFiles`, `readToolFile`, `getToolDocs`, `executeToolCode`) for Starlark-based tool execution
- Does NOT proxy or aggregate tools from upstream MCP servers (tavily, azure_devops, etc.)
- Requires a valid bifrost virtual key (`sk-bf-workspace-agent-001`) in the `x-api-key` header to resolve the session

**Upstream MCP tool access (two modes):**

**`.mcp.json` entries per workspace agent (single source: `agents/claude/.mcp.json`):**

| Entry | URL / Transport | Purpose |
|-------|----------------|---------|
| `aspire` | `aspire agent mcp` (stdio) | .NET Aspire MCP integration |
| `headroom` | `http://mcp-headroom:3008/mcp` (streamableHttp) | Context compression tools |
| `bifrost` | `http://bifrost-server:8080/mcp` + `x-api-key` header | Code Mode Starlark tools + upstream tool access |
| `mcp-codegraph` | `http://mcp-codegraph:8000/api/v1/mcp/sse` (SSE) | 27 code graph tools (find_code, analyze_code_relationships, etc.) |

**Tool access via bifrost Code Mode** (NOT direct `.mcp.json` connections):

| Upstream | bifrost URL | Tools |
|----------|-------------|-------|
| `tavily` | `http://mcp-tavily:3001/mcp` | 5 search/crawl tools |
| `azure_devops` | `http://mcp-azure-devops:3002/mcp` | 90 work item / pipeline tools |
| `postman` | `http://mcp-postman:3003/mcp` | 41 API testing tools |
| `github` | `http://mcp-github:3005/mcp` | 47 GitHub Copilot tools |
| `playwright` | `http://mcp-playwright:3006/mcp` | 23 browser automation tools |

All upstream tools are configured as `is_code_mode_client: true` in bifrost — agents access them via Starlark `executeToolCode`, not as direct MCP connections.

**setup_mcp_config()** copies `agents/claude/.mcp.json` (the single source of truth, also deployed as `home-seed`) to `/home/user/.mcp.json`, then injects the runtime bifrost key via Python. All agent configs (copilot, gemini, codex) mirror the same server set.

**bifrost virtual key**: `sk-bf-workspace-agent-001` (static, `sk-bf-` prefix required by bifrost). Not a secret — grants code mode tool access only within the internal Docker network.

**Rationale**: Upstream tools (tavily, ADO, github, postman, playwright) go through bifrost Code Mode rather than direct agent connections. This keeps the agent `.mcp.json` minimal, enforces governance through bifrost policies, and avoids duplicating secret management across multiple direct connections. `mcp-codegraph` uses a direct SSE connection because it accesses the internal workspace volume and Neo4j — not an external API requiring bifrost governance.

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

### ADR 009: Workspace-Server as Authoritative Owner

**Decision**: `workspace-server` is the sole installer and authoritative owner of the shared volumes. Optional sidecars (`vscode-sidecar`, `containers-dev-sidecar`, `jupyter-sidecar`, `tunnel-sidecar`) use minimal base images and depend on workspace-server.

- VS Code profile ("Main - Zzaia"), extensions, and settings are baked into the image once
- All containers mount shared `workspace-home` volume → single `.vscode-server/extensions` directory
- `devcontainer.json` embedded in the workspace-server image mirrors the same extension list for Dev Containers attach
- No duplication, no drift between connection types — all servers share identical home state
- workspace-server installs tools once; optional servers skip installation (fast startup)

**Rationale**: Single authoritative owner (workspace-server) simplifies initialization and eliminates bootstrap race conditions. Shared home ensures parity across all access methods (SSH, browser, Dev Containers).

### ADR 009A: Explicit Workspace Volume Seeding

**Decision**: Repository seed content is baked into `/opt/zzaia/workspace-seed` and copied into `/home/user/workspace` only when the `workspace-repos` volume is empty.

- The image does not copy seed files directly into `/home/user/workspace`
- This avoids nested-volume shadowing when `workspace-home` and `workspace-repos` are both mounted
- Recreating the repos volume is the only action required to pick up updated seed workspace content from a rebuilt image

**Rationale**: Named volumes mounted at runtime hide image content at the same path. Seeding from a separate immutable location keeps first-run initialization deterministic and removes ambiguity after rebuilds.

---

### ADR 010: RTK for Shell Command Output Compression (Layer 0)

**Decision**: Install RTK (Rust Token Killer) binary in the workspace container image; configure per-agent hook integrations for automatic shell command output compression.

- RTK installed via GitHub releases curl in Dockerfile — zero external dependencies, no Docker service needed
- Operates at Layer 0 (shell I/O level) **before** all API requests, complementing Headroom's Layer 1 compression
- Configured via agent hooks: Claude Code `PreToolUse`, Gemini CLI `BeforeTool`, Cursor/Windsurf/Cline via config
- Supports 100+ commands out-of-box: git, cargo/build, docker, kubectl, ls/find/grep, pytest/jest, AWS CLI, and more
- Achieves 81% average token reduction on command outputs; cargo test: 4,823→11 tokens (99% reduction), git status: 2,000→200 tokens (90% reduction)
- Passthrough guarantee: if RTK fails, original output is returned unchanged — no command execution is ever blocked
- **Stacks with Headroom**: RTK compresses raw output at shell level; Headroom compresses LLM requests at API level

**Rationale**: Layer 0 shell-level compression is the first optimization gate before API-level compression. RTK's binary-only footprint and zero-dependency design fit the workspace's minimal-host-dependencies principle. Early compression at I/O level reduces Headroom's input load. All three layers (RTK→Headroom→Agent context) can stack without interference.

---

### ADR 011: Headroom Triple-Stack Primary Layer (Always-On Default)

**Decision**: `headroom` runs as a mandatory always-on proxy implementing the primary optimization layer: context compression, automatic memory injection, and background code-graph via a proxy pipeline.

- Started with `command: headroom proxy --memory --code-graph` — single command enables all three capabilities
- `ANTHROPIC_BASE_URL=http://headroom:8787`, `OPENAI_BASE_URL=http://headroom:8787`, and `GEMINI_API_BASE=http://headroom:8787` are always set in the workspace environment
- No agent code changes required — transparent HTTP proxy; all three features applied automatically to every request
- Three active features: **context compression** (reduces tokens 34–90%, <5ms overhead), **automatic memory injection** (proxy pipeline step `search_and_format_context()` runs before every LLM forward), **background code-graph** (file watcher on workspace-repos volume; exposes MCP tools)
- Backing services: Qdrant (semantic cache + memory embeddings) + Neo4j (knowledge graph + code-graph)
- `workspace` depends on headroom healthy (`condition: service_healthy`) — Headroom readiness gates agent startup
- Headroom exposes `/health`, `/livez`, `/readyz` for orchestration; `/metrics` (Prometheus) for observability via Aspire Dashboard
- Passthrough guarantee: if compression fails, original content is forwarded unchanged — no agent call is ever dropped

**Rationale**: Triple-stack primary layer automatically optimizes every agent session without opt-in overhead. Automatic memory injection via proxy pipeline eliminates the need for agent instrumentation. Background code-graph file watcher keeps code context current without manual triggers. Qdrant + Neo4j shared by all three features eliminates redundant infrastructure.

---

### ADR 011A: Single Main AppHost and On-Demand Dashboard

**Decision**: The workspace uses a single main AppHost orchestrator. The dashboard is the AppHost-native local dashboard and is exposed outside the container via `vscode-sidecar` port mapping.

- No standalone `aspire-dashboard` service exists in Docker Compose
- `vscode-sidecar` maps `${ASPIRE_DASHBOARD_PORT}` to AppHost dashboard port `17001`
- Dashboard is available only when the AppHost is running
- Future applications should be integrated into the same main AppHost model instead of introducing independent dashboard control planes

**Rationale**: A single AppHost keeps orchestration and control simple, avoids resource-service federation complexity, and provides a single operational dashboard endpoint for users when the AppHost is active.

---

### ADR 013: Anthropic Credential Pool and Rotation via bifrost

**Decision**: bifrost-server supports a credential pool for Anthropic requests. Multiple OAuth tokens or API keys are fetched from Vault and distributed across requests using weight-based round-robin, with automatic circuit-breaker fallback per credential.

**Credential pool configuration** (Vault `secret/ai`):

| Key Pattern | Type | Priority |
|-------------|------|----------|
| `CLAUDE_OAUTH_TOKEN_1..N` | OAuth token (Pro/Max subscription) | Higher — OAuth tokens are inserted first |
| `ANTHROPIC_API_KEY_1..N` | API key (pay-per-token) | Lower — used when OAuth token absent for same index |

- vault-server loops indexed keys at bootstrap: `bws secret list --output json` returns all secrets; `get_bws_value()` extracts each `CLAUDE_OAUTH_TOKEN_N` / `ANTHROPIC_API_KEY_N` and writes them to `secret/ai`
- bifrost-server fetches the full pool from Vault at startup and exports `ANTHROPIC_POOL_KEY_1..N`; sets `ANTHROPIC_POOL_ENABLED=true`
- bifrost `config.json` `keys[]` is generated dynamically: one entry per pool key with `"weight": 1` and `"value": "env.ANTHROPIC_POOL_KEY_N"`
- All pool keys route through `auth_proxy.py` which converts the bifrost-selected `x-api-key` header value to `Authorization: Bearer` for `api.anthropic.com`
- **Backward compatible**: if no indexed keys exist, singular `ANTHROPIC_EFFECTIVE_KEY` behavior is unchanged

**Rotation and fallback behavior:**

| Trigger | Behavior |
|---------|----------|
| Normal operation | Weight-based round-robin across all pool keys — traffic distributed even when all keys are healthy |
| `429 Too Many Requests` | bifrost cools down the rate-limited key and routes to remaining pool members |
| `401 Unauthorized` | bifrost marks the key unhealthy; remaining pool keys serve traffic |
| All pool keys exhausted | bifrost returns the upstream error to the caller |

**Rationale**: Single-credential setups are rate-limited by the quota of one account. A credential pool distributes load across multiple Pro/Max or API subscriptions, increasing effective throughput without changing any upstream agent or MCP configuration.

---

### ADR 012: OpenMemory MCP — Supplementary Structured Memory (Agent-Initiated)

**Decision**: Deploy OpenMemory MCP service as supplementary layer for explicit, filtered memory queries; agents call `search_memory`, `add_memories`, and `list_memories` via MCP when they need specific context.

- OpenMemory container runs `skpassegna/openmemory-mcp:latest` on port 5005
- Postgres + Qdrant backend (same Qdrant instance used by Headroom primary layer)
- Native MCP tools available to all agent CLIs and VS Code extensions without special wiring
- Local-first architecture — no external service dependencies; memory stays on-host
- **Supplements Headroom's automatic memory injection** — agents use explicit queries for fine-grained control
- Agent-initiated retrieval prevents memory pollution — agents request exactly what they need, not auto-injected
- No lock-in to Headroom; works with any MCP client

**Rationale**: Supplementary agent-initiated memory complements Headroom's automatic injection with explicit, filtered queries. Qdrant backend shared with Headroom eliminates redundant infrastructure. MCP interface ensures compatibility across all agent toolchains without requiring Headroom integration.

---

### ADR 013: CodeGraphContext — Supplementary Code Graph (Agent-Initiated)

**Decision**: Deploy CodeGraphContext as supplementary MCP server for explicit code graph queries; agents call `find_callers`, `find_callees`, `class_hierarchy`, and `call_chain` via MCP when they need structural context.

- CodeGraphContext container runs `python:3.12-slim` with codegraphcontext package on stdio/MCP
- Tree-sitter AST parsing generates call graphs and class hierarchies in real-time; file watcher integrated into Headroom's primary layer
- Stores parsed graph in local KûzuDB or Neo4j database (`code-graph-db` named volume)
- Real-time file watching detects source changes and updates graph incrementally
- **Supplements Headroom's background code-graph** — agents use explicit queries for targeted analysis
- Agent-agnostic — any MCP client can query the workspace graph; no IDE dependency
- MCP interface makes code graph queries observable and enables reuse across all coding tools

**Rationale**: Supplementary agent-initiated code graph complements Headroom's background file watcher with explicit, filtered queries. Tree-sitter AST parsing is language-agnostic and requires no IDE. MCP interface enables reuse across all agent toolchains without Headroom coupling.

---

### ADR 014: Implementation Phases — Primary Layer (Phase 1) + Supplementary Layers (Phase 2/3)

**Decision**: Implement the two-layer triple-stack architecture in three phases: Phase 1 deploys Headroom's full triple-stack primary layer, Phase 2 adds OpenMemory MCP, Phase 3 adds CodeGraphContext MCP (Phase 3 complete — `mcp-codegraph` deployed and running).

**Phase 1 — Primary Layer (Automatic via Headroom proxy)**:
- `headroom proxy --memory --code-graph` starts with all three features enabled
- Context compression: 34–90% token reduction, <5ms overhead
- Automatic memory injection: proxy pipeline `search_and_format_context()` runs before every LLM forward
- Background code-graph: file watcher on workspace-repos volume; Qdrant + Neo4j backing
- All agents benefit automatically without agent instrumentation

**Phase 2 — Supplementary Layer: OpenMemory MCP**:
- Agents explicitly call `search_memory`, `add_memories` for structured queries
- Uses same Qdrant + Postgres as Headroom's automatic layer
- Provides fine-grained control vs. automatic injection

**Phase 3 — Supplementary Layer: CodeGraphContext MCP** ✅ Implemented:
- `mcp-codegraph` container (python:3.12-slim + codegraphcontext v0.4.x) — always-on, Neo4j backend
- SSE MCP transport at `http://mcp-codegraph:8000/api/v1/mcp/sse` — 27 tools (find_code, analyze_code_relationships, execute_cypher_query, etc.)
- Indexes workspace worktree repositories at startup; agents call tools explicitly for code analysis
- Complements Headroom's background file watcher with targeted, structured code graph queries

**Rationale**: Phased rollout enables validation of each layer independently. Primary layer (Headroom) provides automatic benefits to all agents. Supplementary layers (OpenMemory + CodeGraphContext) add explicit control for agents that need fine-grained access. Shared infrastructure (Qdrant + Neo4j) eliminates redundancy.

---

### ADR 015: git-sidecar — SSH Proxy to Isolate Git PATs from Agent Containers

**Decision**: Private repository access (GitHub, Azure DevOps) is routed through a dedicated `git-sidecar` SSH proxy container. Agents clone and push using an SSH URL — they never receive or store a PAT.

**Problem**: Without a proxy, agents would need to embed PATs directly in clone URLs:

```bash
# Rejected pattern — PAT visible in shell history, ps aux, and agent context
git clone https://x-access-token:ghp_XXXX@github.com/my-org/my-repo
```

This violates PADR 007 (secrets never in agent context) and PADR 005 (secrets inaccessible after startup). The PAT would appear in:
- Shell history (`~/.bash_history`)
- Process table (`ps aux`) during clone
- Agent context window if the command is shown in output
- Docker inspect on the container env if passed as an env var

**Solution — `git-sidecar` SSH relay:**

- Agent uses a credential-free SSH URL: `ssh://git@git-sidecar:2223/github/my-org/my-repo`
- `git-sidecar` fetches `GITHUB_PERSONAL_ACCESS_TOKEN` and `ADO_MCP_AUTH_TOKEN` from Vault at startup; writes to `/home/git/.git-proxy/tokens` (chmod 600, never env vars)
- Every SSH session is locked to `git-proxy-cmd` via `ForceCommand` in `authorized_keys` — no shell, no port forwarding
- `git-proxy-cmd` validates the path prefix (`github/` or `ado/`), injects the PAT into the upstream HTTPS URL internally, and proxies `git-upload-pack` / `git-receive-pack`
- The PAT is consumed inside the proxy process and never returned to the caller

**Authentication chain:**

```
workspace-server                git-sidecar                    GitHub / ADO
      │                              │                              │
      │  ssh git@git-sidecar:2223    │                              │
      │  /github/my-org/my-repo ───► │  git clone (internal)        │
      │                              │  https://token@github.com ──►│
      │  git pack data ◄─────────────│  pack data ◄─────────────────│
```

- workspace-server authenticates with the ed25519 private key stored in Vault (`secret/workspace.GIT_SIDECAR_AGENT_KEY`), injected by Ansible credentials role at startup; unset from env after use
- git-sidecar only accepts the matching public key (`GIT_SIDECAR_AGENT_PUBKEY` from Vault) — no other key can connect
- Host keys are persisted in a named volume (`git-sidecar-hostkeys`) so `known_hosts` entries survive container restarts

**URL routing:**

| Agent SSH path | Upstream |
|----------------|---------|
| `github/<owner>/<repo>` | `https://x-access-token:<PAT>@github.com/<owner>/<repo>.git` |
| `ado/<org>/<project>/<repo>` | `https://anything:<TOKEN>@dev.azure.com/<org>/<project>/_git/<repo>` |

**Idle mode**: If `GIT_SIDECAR_AGENT_PUBKEY`, `GITHUB_PERSONAL_ACCESS_TOKEN`, or `ADO_MCP_AUTH_TOKEN` are absent from Vault, git-sidecar enters idle mode (sleeps indefinitely, exits cleanly on SIGTERM). The SSH daemon does not start; workspace agents can still operate without git access.

**Rationale**: The SSH proxy pattern is the only approach that satisfies all three constraints simultaneously: (1) agents need to clone private repos, (2) PATs must never appear in the agent environment or terminal, (3) no special agent instrumentation or code changes. The `ForceCommand` SSH restriction provides defense-in-depth — even if an attacker obtains the private key, they can only execute `git-proxy-cmd`, not gain shell access.

---

### ADR 016: Opt-In Observability Stack (SigNoz + Fluent Bit + OTel Collector + cAdvisor)

**Decision**: All observability infrastructure is opt-in via `docker-compose.observability.yml` overlay, activated by `--observability` flag at deploy time. The base `docker-compose.yml` has zero observability configuration.

**Components:**

| Component | Purpose | Port | Notes |
|-----------|---------|------|-------|
| `observability-signoz` | Unified logs + metrics + traces backend | 3301 (UI), 4317 (OTLP gRPC), 4318 (OTLP HTTP), 3100 (Loki) | ClickHouse-backed, web UI for querying logs, metrics, traces |
| `signoz-db` | ClickHouse data store for SigNoz | internal | 2G RAM allocation, encrypted volume mount |
| `observability-fluent-bit` | Docker container log collector | — | Tails `/var/lib/docker/containers/*/*.log` → SigNoz Loki :3100 |
| `observability-otel-collector` | Prometheus scraper | — | Scrapes qdrant, neo4j, vault, cAdvisor → SigNoz OTLP gRPC :4317 |
| `observability-cadvisor` | Container resource metrics | 8080 (internal) | CPU, memory, network, I/O per container; privileged access |

**OTEL Instrumentation — Services with observability env vars (only when overlay active):**

| Service | Instrumentation | Env Vars |
|---------|-----------------|----------|
| `bifrost-server` | OTEL SDK | `OTEL_EXPORTER_OTLP_ENDPOINT=http://observability-otel-collector:4317` |
| `ml-server` | Headroom native OTEL metrics | `HEADROOM_OTEL_METRICS_ENABLED=1` + OTEL endpoint vars |
| 7× MCP services | Node.js auto-instrumentation | `NODE_OPTIONS=--require @opentelemetry/auto-instrumentations-node/register` + OTEL endpoint vars; `@opentelemetry/auto-instrumentations-node` pre-installed in all 7 Dockerfiles |
| `vault-server` | Prometheus metrics endpoint | `VAULT_PROMETHEUS_RETENTION_TIME=30s` |
| Sidecars (workspace-server, git-sidecar, vscode-sidecar, jupyter-sidecar, containers-dev-sidecar, tunnel-sidecar) | OTEL endpoint consumption | OTEL endpoint env vars injected when overlay active |
| `database-neo4j` | Prometheus metrics | `NEO4J_metrics_prometheus_enabled=true` |

**mcp-signoz — External-Only MCP Server:**

`mcp-signoz` is the only MCP server with a host-bound port (`127.0.0.1:${MCP_SIGNOZ_PORT:-3009}:3009`). It is **not** added to `/home/user/.mcp.json` and is never used by workspace agents. Its sole purpose is to allow external agents — running on the host or in CI pipelines — to query SigNoz logs and metrics directly via `http://localhost:3009/mcp` without entering the Docker network.

| Property | Internal MCP servers (tavily, github, …) | `mcp-signoz` (external) |
|----------|------------------------------------------|-------------------------|
| Host port | None | `127.0.0.1:3009` |
| Added to `.mcp.json` | Yes | **No** |
| Consumer | Workspace agents (Claude Code inside containers) | External agents on host / CI |
| Access URL | `http://mcp-{name}:{port}/mcp` (internal) | `http://localhost:3009/mcp` (host) |

**Rationale**: Opt-in pattern ensures zero resource overhead when observability is not needed. The base stack is completely unaffected. Activation pattern matches the GPU overlay (`docker-compose.gpu.yml` + `--gpu` flag) for consistency. SigNoz provides a unified backend for logs, metrics, and traces with a local web UI — no external SaaS required. Fluent Bit, OTel Collector, and cAdvisor are industry-standard collection agents, ensuring portability if observability needs to move to a different backend in the future. `mcp-signoz` is intentionally external-only — observability tooling is infrastructure-level and must not appear in the workspace agent tool surface.

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
    title ZZAIA Agentic Workspace — Two-Layer Triple-Stack Architecture

    Person(dev, "Developer", "Browser or SSH")

    System_Boundary(stack, "<workspace> Compose Stack") {
        System_Boundary(layer0, "Layer 0 — Shell I/O Compression") {
            Container(rtk, "rtk", "Rust binary in-image", "Bash hook intercepts command outputs — 81% avg compression")
        }

        Container(dind, "dind-server", "Docker-in-Docker", "Docker daemon (privileged), no ports exposed")
        Container(ws, "workspace-server", "Ubuntu 24.04", "SSH :2222 + Ansible bootstrap + agent runtime (Claude/Gemini/Codex/Copilot)")
        Container(vscode, "vscode-sidecar", "Ubuntu 24.04 minimal", "code serve-web :VSCODE_PORT [profile: vscode], depends on workspace-server")
        Container(devcontainer, "containers-dev-sidecar", "Ubuntu 24.04 minimal", "Dev Containers support [profile: devcontainer], depends on workspace-server")
        Container(jupyter, "jupyter-sidecar", "Ubuntu 24.04", "JupyterLab :JUPYTER_PORT [profile: jupyter], depends on workspace-server")
        Container(tunnel, "tunnel-sidecar", "Ubuntu 24.04", "VS Code Tunnel [profile: tunnel], depends on workspace-server")

        System_Boundary(primary, "Layer 1 — Primary (Automatic via Headroom proxy)") {
            Container(mlserver, "ml-server", "ghcr.io/chopratejas/headroom", "HTTP proxy :8787 — compression + memory injection + code-graph [always-on]")
            Container(mcpheadroom, "mcp-headroom", "node:lts-alpine + supergateway@3.4.3", "MCP gateway for ml-server :3008 [always-on, non-root uid=999]")
            Container(qdrant, "database-qdrant", "Qdrant v1.17.1", "Vector DB :6333 — semantic cache + memory embeddings + code-graph [non-root uid=999]")
            Container(neo4j, "database-neo4j", "Neo4j 5.14.0", "Graph DB :7687 — knowledge graph + code-graph")
        }

        System_Boundary(supplementary, "Layer 2 — Supplementary (Agent-initiated via MCP)") {
            Container(openmemory, "openmemory-mcp", "skpassegna/openmemory-mcp", "Structured memory queries, Postgres + Qdrant backend, MCP :5005 [Phase 2 — not yet implemented]")
            Container(codegraph, "mcp-codegraph", "python:3.12-slim + codegraphcontext", "Code graph queries — tree-sitter AST parsing, Neo4j backend, SSE MCP :8000 [always-on]")
        }

        Container(tavily, "mcp-tavily", "node:lts-alpine + supergateway@3.4.3", "Holds TAVILY_API_KEY, streamableHttp :3001 [USER node]")
        Container(ado, "mcp-azure-devops", "node:lts-alpine + supergateway@3.4.3", "Holds ADO_MCP_AUTH_TOKEN, streamableHttp :3002 [USER node]")
        Container(postman, "mcp-postman", "node:lts-alpine + supergateway@3.4.3", "Holds POSTMAN_API_KEY, streamableHttp :3003 [USER node]")
        Container(newrelic, "mcp-newrelic", "node:lts-alpine + supergateway@3.4.3", "Holds NEW_RELIC_API_KEY, streamableHttp :3004 [USER node]")
        Container(ghsidecar, "mcp-github", "node:lts-alpine + supergateway@3.4.3", "Holds GITHUB_PERSONAL_ACCESS_TOKEN, streamableHttp :3005 [USER node]")
        Container(playwright, "mcp-playwright", "custom playwright image", "Headless Chromium, always-on, streamableHttp :3006 [USER node]")
    }

    System_Boundary(host, "Docker Host") {
        ContainerDb(home, "<workspace>-home", "Named volume", "Shared home dir — .vscode-server/, .claude/, agent configs, auth tokens, workspace repos")
        ContainerDb(tools, "<workspace>-tools", "Named volume", "Runtime tools at /opt/tools — Node.js, .NET, Python, CLIs (Ansible-installed)")
        ContainerDb(secrets, "<workspace>-secrets", "Named volume", "SSH host keys and public key")
        ContainerDb(mltools, "<workspace>-ml-tools", "Named volume", "Headroom ML tools and model cache")
    }

    Rel(dev, ws, "SSH terminal / VS Code Remote SSH", "127.0.0.1:SSH_PORT")
    Rel(dev, vscode, "VS Code browser", "127.0.0.1:VSCODE_PORT")
    Rel(dev, devcontainer, "Dev Containers attach", "Docker socket")
    Rel(dev, jupyter, "JupyterLab", "127.0.0.1:JUPYTER_PORT")
    Rel(ws, rtk, "Bash hook intercepts outputs", "stdin/stdout at shell level")
    Rel(ws, vscode, "Shares workspace-home + tools volumes", "named volumes")
    Rel(ws, devcontainer, "Shares workspace-home + tools volumes", "named volumes")
    Rel(ws, jupyter, "Shares workspace-home + tools volumes", "named volumes")
    Rel(vscode, ws, "Depends on", "service_healthy")
    Rel(devcontainer, ws, "Depends on", "service_healthy")
    Rel(jupyter, ws, "Depends on", "service_healthy")
    Rel(tunnel, ws, "Depends on", "service_healthy")
    Rel(ws, mlserver, "All AI API calls (Anthropic + OpenAI + Gemini)", "ANTHROPIC_BASE_URL / OPENAI_BASE_URL / GEMINI_API_BASE :8787")
    Rel(mlserver, qdrant, "Compression + memory + code-graph", "semantic search :6333")
    Rel(mlserver, neo4j, "Knowledge graph + code-graph", "Bolt :7687")
    Rel(mlserver, home, "Background file watcher", "code-graph on workspace-home volume")
    Rel(ws, mcpheadroom, "MCP tool calls via headroom", "streamableHttp :3008")
    Rel(mcpheadroom, mlserver, "Proxies MCP to Headroom", "HTTP :8787")
    Rel(ws, openmemory, "MCP tool calls (Phase 2)", "search_memory / add_memories :5005")
    Rel(openmemory, qdrant, "Semantic memory index", "vector DB :6333")
    Rel(ws, codegraph, "MCP tool calls (Phase 3)", "find_callers / class_hierarchy / call_chain")
    Rel(codegraph, home, "Parse source files", "named volume /home/user")
    Rel(ws, tavily, "MCP tool calls", "streamableHttp mcp network")
    Rel(ws, ado, "MCP tool calls", "streamableHttp mcp network")
    Rel(ws, postman, "MCP tool calls", "streamableHttp mcp network")
    Rel(ws, newrelic, "MCP tool calls", "streamableHttp mcp network")
    Rel(ws, ghsidecar, "MCP tool calls", "streamableHttp mcp network")
    Rel(ws, playwright, "MCP tool calls", "streamableHttp mcp network")
    Rel(ws, dind, "Docker API", "tcp://dind-server:2375")
    Rel(ws, home, "Home directory", "named volume /home/user")
    Rel(ws, tools, "Tools volume", "named volume /opt/tools")
    Rel(ws, secrets, "SSH keys", "named volume /secrets")
    Rel(mlserver, mltools, "ML model cache", "named volume /opt/ml-tools")
    Rel(vscode, home, "Read VS Code state + configs", "named volume /home/user")
    Rel(devcontainer, home, "Read home state + workspace", "named volume /home/user")

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
│   ├── docker-compose.yml   # Stack — workspace-server + optional servers + headroom + 8 sidecars
│   ├── docker-compose.gpu.yml # GPU overlay for NVIDIA hosts (opt-in)
│   ├── docker-compose.observability.yml  # Observability overlay (opt-in, activated by --observability flag)
│   ├── fluent-bit.conf                   # Fluent Bit Docker log collection config
│   ├── otel-collector-config.yaml        # OTel Collector Prometheus scraper config
│   ├── Makefile             # Docker build and compose helper commands
│   ├── sshd_config          # SSH daemon hardening config
│   └── containers/
│       ├── workspace-server/   # Dockerfile, entrypoint.sh, scripts/, ansible/
│       ├── ml-server/
│       ├── database-qdrant/
│       ├── database-neo4j/
│       ├── dind-server/
│       ├── mcp-{tavily,azure-devops,postman,newrelic,github,playwright,headroom}/
│       └── {vscode,jupyter,containers-dev,tunnel}-sidecar/
├── deploy/
│   ├── ubuntu.sh            # Bitwarden Secrets Manager deployment script (apt, curl, docker compose)
│   ├── mac.sh               # macOS deployment script (delegates to ubuntu.sh)
│   └── windows.ps1          # PowerShell deployment script (Bitwarden Secrets Manager, docker compose)
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

| Container | Role | Port | Profile | Notes |
|-----------|------|------|---------|-------|
| `vault-server` | Production Vault (file backend, AES-256-GCM encryption at rest) | 8200 | always | Bootstraps from Bitwarden at startup; generates git-sidecar SSH keypair; enables AppRole auth; UI at localhost:8200/ui |
| `git-sidecar` | SSH git proxy — routes clone/push to GitHub and Azure DevOps via PAT injection | 2223 (SSH, internal) | always | ForceCommand restricts every session to `git-proxy-cmd`; PATs never exposed to agents |
| `dind-server` | Docker-in-Docker daemon | (internal) | always | Privileged, no port exposure |
| `workspace-server` | SSH daemon + Ansible bootstrap + agent runtime | 2222 (SSH) | always | Always starts, owns shared home + tools |
| `ml-server` | Headroom AI proxy (compression + memory + code-graph) | 8787 (internal) | always | Non-root: uid=999(headroom) |
| `database-qdrant` | Vector DB (Qdrant v1.17.1) | 6333 (internal) | always | Semantic cache + memory embeddings + code-graph, non-root: uid=999(qdrant) |
| `database-neo4j` | Knowledge graph (Neo4j 5.14.0) | 7687/7474 (internal) | always | Knowledge graph + code-graph backend |
| `mcp-headroom` | MCP gateway for ml-server (supergateway → ml-server) | 3008 (internal) | always | Non-root: uid=999(headroom) |
| `mcp-playwright` | Headless Chromium MCP | 3006 (internal) | always | node:lts-alpine + supergateway, non-root: USER node |
| `vscode-sidecar` | Browser VS Code (`code serve-web`) | VSCODE_PORT | `vscode` | Opt-in, depends on workspace-server healthy |
| `jupyter-sidecar` | JupyterLab | JUPYTER_PORT | `jupyter` | Opt-in, depends on workspace-server healthy |
| `containers-dev-sidecar` | Dev Containers support | stdin | `devcontainer` | Opt-in, depends on workspace-server healthy |
| `tunnel-sidecar` | VS Code Tunnel (remote access via vscode.dev) | — | `tunnel` | Opt-in, depends on workspace-server healthy |
| **Conditional MCP Adapters** | | | | |
| `mcp-tavily` | Web search MCP adapter (node:lts-alpine + supergateway) | 3001 (internal) | conditional | USER node, fetches TAVILY_API_KEY from Vault |
| `mcp-azure-devops` | Azure DevOps MCP adapter (node:lts-alpine + supergateway) | 3002 (internal) | conditional | USER node, fetches ADO_MCP_AUTH_TOKEN from Vault |
| `mcp-postman` | Postman MCP adapter (node:lts-alpine + supergateway) | 3003 (internal) | conditional | USER node, fetches POSTMAN_API_KEY from Vault |
| `mcp-newrelic` | New Relic MCP adapter (node:lts-alpine + supergateway) | 3004 (internal) | conditional | USER node, fetches NEW_RELIC_API_KEY from Vault |
| `mcp-github` | GitHub MCP adapter (node:lts-alpine + supergateway) | 3005 (internal) | conditional | USER node, fetches GITHUB_PERSONAL_ACCESS_TOKEN from Vault |
| **Observability (opt-in)** | | | | |
| `observability-signoz` | Unified observability backend (logs/metrics/traces) | 3301 (UI), 4317, 4318, 3100 | opt-in | ClickHouse-backed; web UI at http://localhost:3301 (only when observability overlay is active) |
| `signoz-db` | ClickHouse storage for SigNoz | internal | opt-in | Database backend with 2G RAM allocation (only when observability overlay is active) |
| `observability-fluent-bit` | Docker log collector → SigNoz Loki | — | opt-in | Tails Docker container logs via host bind mount (only when observability overlay is active) |
| `observability-otel-collector` | Prometheus scraper → SigNoz OTLP | — | opt-in | Scrapes qdrant, neo4j, vault, cAdvisor metrics (only when observability overlay is active) |
| `observability-cadvisor` | Container resource metrics | 8080 (internal) | opt-in | Privileged container collecting CPU, memory, network, I/O metrics (only when observability overlay is active) |

### Shared State (Named Volumes)

| Volume | Mount | Contents |
|--------|-------|----------|
| `<ws>-home` | `/home/user` (all servers) | User configs, credentials, auth tokens, VS Code state, workspace repos |
| `<ws>-tools` | `/opt/tools` (workspace-server rw, optional servers ro) | Runtime tools: Node.js, .NET, Python, CLIs (Ansible-installed) |
| `<ws>-secrets` | `/secrets` | SSH host keys and public key |
| `<ws>-vault-data` | `/vault/data` (vault-server) | HashiCorp Vault KV v2 (file backend, AES-256-GCM encryption at rest); unseal keys at `/vault/data/.init` |
| `git-sidecar-hostkeys` | `/etc/ssh` (git-sidecar) | SSH host keys for the git-sidecar daemon — persisted so client known_hosts entries survive container restarts |
| `<ws>-database-qdrant` | `/qdrant/storage` | Vector embeddings (Qdrant) |
| `<ws>-database-neo4j` | `/data` | Knowledge graph (Neo4j) |
| `<ws>-signoz-db-data` | `/var/lib/clickhouse` (signoz-db) | SigNoz ClickHouse data (only present when observability overlay is active) |

### Connection Types

| Type | Entry Point | Notes |
|------|-------------|-------|
| SSH | `workspace:2222` | sshd with pubkey auth |
| Browser | `vscode-sidecar:VSCODE_PORT` | `code serve-web`, no token (profile: vscode) |
| Jupyter | `jupyter-sidecar:JUPYTER_PORT` | JupyterLab (profile: jupyter) |
| VS Code Tunnel | `tunnel-sidecar` | vscode.dev/tunnel/$WORKSPACE_NAME (profile: tunnel) |
| Dev Containers | Docker socket → workspace | `devcontainer.json` in image (profile: devcontainer) |
| VS Code Remote SSH | `workspace:2222` | Remote SSH extension |

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Container runtime | Docker Desktop (Linux / macOS / Windows) |
| Workspace OS | Ubuntu 24.04 LTS |
| Agent runtimes | Claude Code, Gemini CLI, OpenAI Codex, GitHub Copilot |
| Developer UI | Browser (code serve-web), SSH terminal, VS Code Dev Containers, VS Code Tunnel |
| Dev Containers | `devcontainer.json` embedded in workspace image |
| **Layer 0 — Shell I/O Compression** | |
| **RTK** | **Rust Token Killer binary (in-image) — 81% avg token reduction on command outputs via bash hook intercepts** |
| **Layer 1 — Primary (Automatic)** | |
| **ml-server** | **Headroom AI proxy: triple-stack compression (34–90% tokens, <5ms) + memory injection + code-graph, passthrough guarantee** |
| **Vector DB (Qdrant)** | **Semantic cache (compression) + memory embeddings + code-graph index** |
| **Graph DB (Neo4j)** | **Knowledge graph (memory + code-graph), shared backing for primary layer** |
| **Layer 2 — Supplementary (Agent-Initiated, Phase 2/3)** | |
| **OpenMemory MCP** | **Structured memory queries (Phase 2) — Postgres + Qdrant backend, explicit retrieval via search_memory/add_memories** |
| **CodeGraphContext MCP** | **Code graph queries (Phase 3) — Tree-sitter AST parsing, explicit retrieval via find_callers/class_hierarchy** |
| **Observability (opt-in)** | |
| **SigNoz** | **Unified logs + metrics + traces backend (ClickHouse-backed, OTLP receiver, Loki-compatible, Web UI :3301)** |
| **Fluent Bit** | **Docker container log collection → SigNoz Loki endpoint** |
| **OTel Collector** | **Prometheus scraper (qdrant, neo4j, vault, cAdvisor) → SigNoz OTLP gRPC** |
| **cAdvisor** | **Container resource metrics (CPU, memory, network, I/O) for all containers** |
| Tool provisioning | Ansible roles (workspace-server): system, user-setup, vscode-cli, node, dotnet, python, cli, path-config, credentials, gpu; version pins in `group_vars/all.yml` |
| MCP bridge | supergateway@3.4.3 (streamableHttp transport, pre-installed at build time) |
| Multi-tenancy | Docker Compose project namespacing |
| Secret lifecycle | BWS_ACCESS_TOKEN → vault-server bws fetch → Vault KV (AES-256-GCM at rest) → unset; manage via Vault UI |
| Telemetry | .NET Aspire Standalone Dashboard (OTLP receiver) |

## Security Model

| Threat | Mitigation |
|--------|-----------|
| Agent exfiltrates API keys | Keys never in workspace container env after startup |
| Agent modifies host filesystem | Only `/secrets` and `/home/user` volumes mounted; `cap_drop: ALL` |
| Agent escapes container | No `SYS_ADMIN`, `NET_ADMIN`, or `DAC_OVERRIDE` capabilities |
| Secret visible in terminal | Vault auto-unseals using keys sealed in encrypted volume; no unseal key in .env |
| Cross-stack secret leakage | Each stack on isolated bridge network; no shared volumes |
| Port scanning from container | MCP ports bound to internal network only |
| MCP container compromise | All MCP containers run as non-root (USER node / uid=999); isolation via bridge network |
| Database container compromise | qdrant runs as uid=999(qdrant); neo4j isolated volume; no mount-out capabilities |
| vault-server PAT exposure | vault-server is the only container that receives BWS_ACCESS_TOKEN; unset after bootstrap; no other container sees it |

## Related Documentation

- [QUICKSTART.md](../QUICKSTART.md) — Step-by-step setup instructions
- [README.md](../README.md) — Project overview
- [docker/](../docker/) — Dockerfile, Compose, entrypoint, and install scripts
- [bdd-scenarios.md](bdd-scenarios.md) — BDD scenarios for all workspace features
- [agents/claude/CLAUDE.md](../agents/claude/CLAUDE.md) — Claude Code command hierarchy and standards
- [agents/claude/.mcp.json](../agents/claude/.mcp.json) — MCP server configuration
