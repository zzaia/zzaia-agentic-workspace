---
project: zzaia-agentic-workspace
branch: feature/improve-agentic-system
document-type: implementation-plan
created: 2026-05-02
updated: 2026-05-04
---

# zzaia-agentic-workspace - Master Implementation Plan

## Overview

Decouple VS Code browser UI from workspace container, add Dev Containers support, integrate always-on Headroom AI proxy (with Qdrant vector DB for compression), add OpenMemory MCP for session memory, add CodeGraphContext for workspace semantic search, and fix missing VS Code extension installations. This modernizes the Docker architecture to support multiple development modes (browser, SSH, Dev Containers) with independent failure domains and comprehensive AI proxy + memory + search infrastructure.

**Effort**: 39 points (parallel) | **Tech**: Docker, Docker Compose, VS Code, Headroom AI proxy, OpenMemory MCP, CodeGraphContext, mise

> Effort estimated using Fibonacci sequence: 1, 2, 3, 5, 8, 13, 21, 34, 55

---

## Implementation Phase Hierarchy

```mermaid
gantt
    title Implementation Timeline - RTK Layer 0 + Phased Triple-Stack
    dateFormat 2026-05-02

    section Phase 0 (Prerequisite)
    Story 0.1: RTK installation and hooks        :done, phase0, story01, 2026-05-02, 2d

    section Phase 1 (Parallel)
    Story 1.2.1: Workspace healthcheck           :done, story121, after story01, 3d
    Story 3.1: Headroom triple-stack             :done, story31, after story01, 3d
    Story 4.1: Fix VS Code extensions            :done, story41, after story01, 2d

    section Phase 2 (After Phase 1)
    Story 1.1.1: vscode-server container         :done, story111, after story121, 2d
    Story 2.1: devcontainer.json                 :done, story21, after story41, 3d
    Story 3.2: OpenMemory supplementary          :crit, story32, after story31, 2d

    section Phase 3 (After Phase 2)
    Story 3.3: CodeGraphContext supplementary    :crit, story33, after story32, 3d
    End-to-end validation                        :crit, e2e, after story33, 2d
```

**Legend**: Blue (Phase 0) = Prerequisite RTK setup | Green (Active) = Phase 1 parallel | Red (Critical) = Phase 2 & 3 sequential | **Total**: 41 points

---

## Phase 0: RTK Installation and Hook Configuration (Prerequisite) (2 points)

**Parallel**: ✅ | **Team**: 1 DevOps Specialist

**Description**: Install RTK (Rust Token Killer) binary in workspace container image and configure agent hooks (Claude Code PreToolUse, Gemini CLI BeforeTool, Codex/Copilot CLI) to compress shell command outputs at Layer 0 (before Headroom Layer 1 and MCP tools Layer 2).

### 0A: RTK Installation and Hook Configuration (Story 0.1) (2 points)

**Acceptance Criteria**:
- RTK binary installed in workspace container image via Dockerfile `curl` from GitHub releases (https://github.com/rtk-ai/rtk)
- RTK available in PATH: `rtk --version` succeeds in built image
- Claude Code PreToolUse hook configured in `.claude/settings.json` — bash commands rewritten as `rtk <command>`
- Gemini CLI BeforeTool hook configured with RTK binary path
- Codex CLI and Copilot CLI hook files configured for RTK
- Test: `rtk git status` returns compressed output (2,000→200 tokens); `rtk cargo test` reduces output by >90% (4,823→11 tokens)
- RTK telemetry optional: logs to `~/.local/share/rtk/` if enabled
- Verify RTK works for git, cargo, docker, kubectl, ls, find, grep, pytest, jest, AWS CLI, helm in container

**Tasks**:
- [x] Add RTK binary download to Dockerfile via curl from GitHub releases (1) — moved to `mise.toml` `[tasks.rtk]` task; installs to `~/.local/bin/rtk` as `user`; `mise run rtk` called in Dockerfile build chain
- [x] Add Claude Code PreToolUse hook config to workspace `.claude/settings.json` (0.5)
- [x] Add Gemini CLI BeforeTool hook configuration (0.5)
- [x] Add Codex CLI and Copilot CLI hook configs to respective config files (0.5)
- [ ] Validate RTK works for all supported commands in container (0.5) — pending image build

**Outputs**: Updated `docker/Dockerfile` with RTK installation, updated workspace `.claude/settings.json` with PreToolUse hook, updated Gemini/Codex/Copilot CLI hook configurations

**Dependencies**: None (Phase 0 prerequisite)

---

## Phase 1: Foundation (Parallel) (8 points)

**Parallel**: ✅ | **Team**: 1 DevOps Specialist

### 1A: Workspace Container Healthcheck (Story 1.2.1) (3 points)

**Acceptance Criteria**:
- `code serve-web` watchdog loop removed from `docker/entrypoint.sh`
- `EXPOSE ${VSCODE_PORT}` removed from `docker/Dockerfile`
- Docker `HEALTHCHECK` added to Dockerfile: `CMD bash -c '</dev/tcp/localhost/2222'` with interval 10s, retries 5, start_period 15s
- Workspace container no longer exposes VSCODE_PORT on host
- Healthcheck passes reliably before dependent services start

**Tasks**:
- [x] Remove serve-web watchdog from entrypoint.sh (1)
- [x] Add TCP/2222 healthcheck to Dockerfile (1)
- [x] Remove EXPOSE VSCODE_PORT from Dockerfile (1)

**Outputs**: Updated `docker/entrypoint.sh`, updated `docker/Dockerfile`

**Dependencies**: None

---

### 1B: Headroom AI Proxy Triple-Stack (Story 3.1) (5 points)

**Description**: Headroom proxy with automatic memory injection, code-graph file watcher, Qdrant vector storage, and Neo4j knowledge graph. Triple-stack enables compression, semantic memory, and code intelligence by default in all agent sessions.

**Acceptance Criteria**:
- `headroom` service added to docker-compose.yml — always-on (no profile), `restart: unless-stopped`
- `headroom` command: `headroom proxy --memory --code-graph`
- `qdrant` service added — `qdrant/qdrant:v1.17.1`, volume `<ws>-headroom-qdrant`, healthcheck `/readyz` (shared with OpenMemory MCP Phase 2)
- `neo4j` service added — `image: neo4j:5.24`, volumes for data + logs, BOLT port 7687, healthcheck on /browser
- `headroom` depends_on qdrant AND neo4j (condition: service_healthy)
- `workspace-repos` volume mounted into headroom container at `/workspace` (code-graph file watcher needs it)
- `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY` passed to headroom container
- `QDRANT_URL=http://qdrant:6333`, `NEO4J_URI=bolt://neo4j:7687` passed to headroom
- Workspace env always includes: `ANTHROPIC_BASE_URL=http://headroom:8787`, `OPENAI_BASE_URL=http://headroom:8787`, `GEMINI_API_BASE=http://headroom:8787`
- `x-headroom-user-id` header configured in workspace agent settings (enables per-user memory scoping)
- Proxy pipeline automatically injects memories before forwarding requests
- Headroom healthcheck: `wget -qO- http://localhost:8787/health` interval 10s, retries 5, start_period 30s
- Verify via /stats endpoint: memory injections happening automatically (no agent action required)
- code-graph file watcher logs show codebase indexed on startup
- Named volumes declared: `<ws>-headroom-qdrant`, `<ws>-headroom-neo4j-data`, `<ws>-headroom-neo4j-logs`

**Tasks**:
- [x] Add qdrant service with persistent volume and healthcheck (1)
- [x] Add neo4j service with persistent volumes and healthcheck (1)
- [x] Add headroom service with --memory --code-graph flags (1)
- [x] Mount workspace-repos volume into headroom container (1)
- [x] Wire ANTHROPIC_BASE_URL, OPENAI_BASE_URL, GEMINI_API_BASE into workspace env (1)
- [x] Configure x-headroom-user-id header in workspace agent settings (1)
- [x] Add workspace depends_on headroom: service_healthy (1)
- [x] Declare qdrant, neo4j, and headroom named volumes (1)

**Outputs**: Updated `docker/docker-compose.yml` with headroom (triple-stack), qdrant, neo4j services and volumes; updated workspace agent settings with x-headroom-user-id header

**Dependencies**: None (Phase 1 parallel execution)

---


---

### 1B: Fix Missing VS Code Extensions (Story 4.1) (2 points)

**Acceptance Criteria**:
- Verify correct marketplace ID for `google.gemini-code-assist` (may differ from current)
- Verify correct marketplace ID for `openai.chatgpt` (may differ from current)
- Extension IDs updated in `docker/mise.toml` vscode-extensions task
- Both extensions confirmed installed in built image via `code --extensions-dir /tmp/test-extensions --list-extensions`

**Tasks**:
- [x] Verify and update Gemini Code Assist extension ID (1) — `google.gemini-code-assist` confirmed correct
- [x] Verify and update OpenAI ChatGPT extension ID (1) — `openai.chatgpt` confirmed correct

**Outputs**: Updated `docker/mise.toml` with correct extension IDs

**Dependencies**: Completed before Story 2.1 acceptance validation

---

## Phase 2: Service Development (Sequential after Phase 1) (13 points)

**Parallel**: ❌ | **Team**: 1 DevOps Specialist

### 2A: VS Code Server Container (Story 1.1.1) (8 points)

**Reference**: Depends on Story 1.2.1 completion

**Acceptance Criteria**:
- `vscode-server` service added to docker-compose.yml with `profiles: ["vscode"]`
- Uses same image as workspace with `command` override for `code serve-web`
- Mounts `workspace-home` and `workspace-repos` volumes (same as workspace)
- `depends_on: workspace: condition: service_healthy`
- Healthcheck: `wget -qO- http://localhost:8080/` interval 15s, retries 5, start_period 30s
- `restart: unless-stopped`
- `VSCODE_PORT` exposed on host via vscode-server service ONLY (not workspace)
- Logs show successful serve-web startup and listening on :8080

**Tasks**:
- [x] Add vscode-server service definition to docker-compose.yml (2)
- [x] Configure volume mounts for workspace-home and workspace-repos (1)
- [x] Add healthcheck for serve-web endpoint (1)
- [x] Move VSCODE_PORT exposure from workspace to vscode-server (2)
- [ ] Test startup sequence: workspace healthy → vscode-server healthy (2) — pending image build

**Outputs**: Updated `docker/docker-compose.yml` with vscode-server service and profile

**Dependencies**: Story 1.2.1 (workspace healthcheck)

---

### 2B: Dev Containers Support (Story 2.1) (10 points)

**Acceptance Criteria**:
- `devcontainer.json` created and COPY'd into image at `/home/user/.devcontainer/devcontainer.json`
- `remoteUser: "user"`
- `customizations.vscode.extensions` mirrors full extension list from `docker/mise.toml` (includes fixed Gemini and ChatGPT extensions)
- `customizations.vscode.settings` references zzaia-workspace profile settings
- VS Code Dev Containers attach workflow tested: `Remote-Containers: Reopen in Container`
- Extensions install automatically on attach
- Settings apply from devcontainer configuration

**Tasks**:
- [x] Create devcontainer.json with remoteUser and extensions list (2)
- [x] Extract full extension list from mise.toml (1)
- [x] Configure VS Code settings customization block (1)
- [x] COPY devcontainer.json into Dockerfile at build time (1)
- [ ] Test Dev Containers attachment workflow (3) — pending image build
- [ ] Validate extension auto-installation on attach (2) — pending image build

**Outputs**: New `docker/devcontainer.json`, updated `docker/Dockerfile`

**Dependencies**: Story 1.2.1 (healthcheck), Story 4.1 (correct extension IDs)

---

### 2B: OpenMemory MCP — Supplementary Structured Memory (Story 3.2) (2 points)

**Description**: Supplements Headroom's automatic memory injection (Phase 1) with structured, filtered queries for agents that need explicit memory control.

**Acceptance Criteria**:
- `openmemory` service added to docker-compose.yml — `image: skpassegna/openmemory-mcp:latest`
- Depends on Phase 1B (Headroom triple-stack) completion
- Uses existing postgres and qdrant services already deployed by Phase 1
- Environment: `DATABASE_URL=postgresql://user:password@postgres:5432/openmemory`, `QDRANT_URL=http://qdrant:6333`
- MCP tools auto-discoverable: `search_memory`, `add_memories`, `list_memories`, `delete_all_memories`
- Workspace container MCP config includes openmemory endpoint
- Memory persists in Postgres across container restarts
- openmemory depends_on postgres and qdrant (condition: service_healthy)
- OpenMemory structured queries return filtered results (by topic, agent, date)

**Tasks**:
- [ ] Add openmemory compose service with correct image and env vars (1)
- [ ] Register MCP endpoint in workspace claude_desktop_config.json (1)

**Outputs**: Updated `docker/docker-compose.yml` with openmemory service, updated workspace MCP config

**Dependencies**: Story 3.1 (Headroom triple-stack Phase 1B complete)

---

## Phase 3: Code Graph Context (Sequential after Phase 2) (3 points)

**Sequential**: ✅ | **Team**: 1 DevOps Specialist

### 3A: CodeGraphContext MCP — Supplementary Code Graph Queries (Story 3.3) (3 points)

**Description**: Supplements Headroom's background --code-graph file watcher (Phase 1) with structured MCP query tools for agents that need explicit code graph navigation.

**Acceptance Criteria**:
- Depends on Phase 2 (OpenMemory) completion
- `code-graph` service added to docker-compose.yml — `image: mekayelanik/codegraphcontext-mcp:stable`
- HTTP mode on port 8045 (not stdio)
- Mounts `workspace-repos` volume at `/workspace`
- MCP tools auto-discoverable: `find_callers`, `find_callees`, `class_hierarchy`, `call_chain`
- Workspace container MCP config includes code-graph endpoint
- code-graph depends_on headroom (condition: service_healthy)
- CodeGraphContext HTTP endpoint responds on port 8045

**Tasks**:
- [ ] Add code-graph service definition to docker-compose.yml with mekayelanik image (1)
- [ ] Configure workspace-repos volume mount and HTTP port 8045 (1)
- [ ] Register MCP endpoint in workspace claude_desktop_config.json (1)

**Outputs**: Updated `docker/docker-compose.yml` with code-graph service, updated workspace MCP config

**Dependencies**: Story 3.2 (OpenMemory Phase 2 complete)

---

## Phase 4: Integration Validation (4 points)

**Sequential**: ✅ | **Team**: 1 QA/DevOps Specialist

**Tasks**:
- [ ] Build image with all changes and verify layer caching (1)
- [ ] Spin up `docker-compose up -d` (default profile): workspace + 8 MCP sidecars + headroom triple-stack (1)
- [ ] Verify headroom triple-stack (headroom, qdrant, neo4j) start in correct dependency order (1)
- [ ] Validate ANTHROPIC_BASE_URL, OPENAI_BASE_URL, GEMINI_API_BASE all resolve to headroom (1)
- [ ] Send a test agent request and confirm headroom /stats shows memory injections happening (1)
- [ ] Confirm headroom code-graph file watcher logs show codebase indexed on startup (1)
- [ ] Spin up with `--profile vscode`: add vscode-server, validate startup order (1)
- [ ] Verify OpenMemory MCP structured queries return filtered results (by topic, agent, date) (1)
- [ ] Verify CodeGraphContext HTTP endpoint responds on port 8045 (1)
- [ ] Attach VS Code Dev Containers: extensions install, zzaia-workspace profile active (2)
- [ ] SSH access via workspace container: verify independent of vscode-server health (1)

**Outputs**: Test report validating phased triple-stack, all profiles, healthchecks, memory injection, code-graph indexing, and Dev Containers workflow

---

## Technology Stack

**Command Output Compression**: RTK (Rust Token Killer) v1.0+ (https://github.com/rtk-ai/rtk) — Layer 0 shell I/O intercept via agent hooks; 81% average token reduction; Apache-2.0 license

**Container Orchestration**: Docker, Docker Compose, Compose profiles

**Development Environments**: VS Code browser (serve-web), VS Code SSH attach, VS Code Dev Containers

**AI Proxy**: Headroom (ghcr.io/chopratejas/headroom:latest) with context compression

**Vector DB**: Qdrant v1.17.1 (Phase 1: used by Headroom; Phase 2: shared with OpenMemory session memory)

**Knowledge Graph**: Neo4j 5.24 (Phase 1: used by Headroom for knowledge graph memory)

**Session Memory**: OpenMemory MCP (Phase 2: skpassegna/openmemory-mcp:latest) with Postgres + Qdrant backing

**Workspace Search**: CodeGraphContext MCP (Phase 3: mekayelanik/codegraphcontext-mcp:stable) HTTP endpoint on port 8045

**Tool Management**: mise for VS Code extensions and tool versioning

**Health Monitoring**: TCP/HTTP healthchecks, depends_on service_healthy condition

---

## Effort Summary

**Phase 0 (Prerequisite)**: 2 points (story 0.1 RTK installation and hooks)

**Phase 1 (Parallel)**: 8 points (stories 1.2.1, 3.1, 4.1 execute in parallel; depends on Phase 0 complete)

**Phase 2 (Sequential)**: 10 points (story 1.1.1 + 2.1 + 3.2 after Phase 1 complete)

**Phase 3 (Sequential)**: 3 points (story 3.3 after Phase 2 complete)

**Phase 4 (Integration)**: 4 points

**Total**: 27 points (2 Phase 0 + 25 from simplified phases 1-4)

**Phasing Strategy**: 
- Phase 0 installs RTK Layer 0 output compression (prerequisite for all agents)
- Phase 1 deploys complete Headroom triple-stack (proxy + memory + code-graph) in parallel
- Phase 2 adds supplementary OpenMemory for explicit memory control (optional)
- Phase 3 adds supplementary CodeGraphContext for explicit code-graph queries (optional)
- Efficiency: RTK compression applies to all agent commands immediately after Phase 0; all 3 capabilities available after Phase 1 validation; Phases 2-3 enhance with optional structured tools

---

## Team Structure

### Recommended (Phased Execution)
- 1 DevOps Specialist (Phase 1 parallel work: stories 1.2.1, 3.1, 4.1)
- 1 DevOps Specialist (Phase 2-3 sequential work: stories 1.1.1, 2.1, 3.2, 3.3)
- 1 QA/Integration Specialist (Phase 4 validation)

### Minimum (Sequential)
- 1 DevOps Specialist (executes all phases sequentially)

---

## Success Criteria

**Technical (Phase 0 RTK)**
- ✅ RTK binary installed in workspace container image via Dockerfile (curl from GitHub releases)
- ✅ RTK available in PATH: `rtk --version` succeeds in built image
- ✅ Claude Code PreToolUse hook configured in workspace `.claude/settings.json`
- ✅ Gemini CLI BeforeTool hook configured with RTK binary path
- ✅ Codex CLI and Copilot CLI hook configs updated for RTK
- ✅ `rtk git status` verified to reduce output (2,000→200 tokens)
- ✅ `rtk cargo test` verified to reduce output by >90% (4,823→11 tokens)
- ✅ RTK works for 100+ supported commands: git, cargo, docker, kubectl, ls, find, grep, pytest, jest, AWS CLI, helm

**Technical (Phase 1 Triple-Stack)**
- ✅ Workspace container exposes only SSH (2222) and has TCP/2222 healthcheck
- ✅ Headroom triple-stack (proxy + memory + code-graph) always-on with qdrant + neo4j
- ✅ Headroom started with `command: headroom proxy --memory --code-graph`
- ✅ workspace-repos volume mounted into Headroom container (code-graph file watcher needs it)
- ✅ ANTHROPIC_BASE_URL, OPENAI_BASE_URL, GEMINI_API_BASE all point to http://headroom:8787
- ✅ x-headroom-user-id header configured in workspace agent settings for memory scoping
- ✅ Neo4j required (Headroom uses it for knowledge graph memory + code-graph)
- ✅ Qdrant required (Headroom uses it for semantic cache + memory embeddings)
- ✅ Headroom /stats shows memory injections happening automatically (no agent action required)
- ✅ Headroom code-graph file watcher logs show codebase indexed on startup
- ✅ Headroom healthcheck passes: wget -qO- http://localhost:8787/health
- ✅ Qdrant and Neo4j data persists in named volumes across container restarts
- ✅ Google Gemini Code Assist and OpenAI ChatGPT extensions install without build-time failures

**Technical (Phase 2 OpenMemory Supplementary)**
- ✅ OpenMemory MCP service running (depends on Phase 1B complete)
- ✅ OpenMemory connects to same Qdrant already deployed by Headroom
- ✅ OpenMemory structured queries return filtered results (by topic, agent, date)
- ✅ MCP tools (search_memory, add_memories, list_memories, delete_all_memories) discoverable by all agents

**Technical (Phase 3 CodeGraphContext Supplementary)**
- ✅ CodeGraphContext service running (depends on Phase 2 complete)
- ✅ CodeGraphContext HTTP endpoint responds on port 8045
- ✅ MCP tools (find_callers, find_callees, class_hierarchy, call_chain) discoverable by all agents

**Operational**
- ✅ Default `docker-compose up -d` starts headroom triple-stack + qdrant + neo4j + openmemory + code-graph + workspace + 8 MCPs
- ✅ `docker-compose --profile vscode up -d` additionally starts vscode-server
- ✅ vscode-server container runs independently with serve-web, depends_on workspace healthy
- ✅ devcontainer.json embedded in image with correct extension list and zzaia-workspace profile
- ✅ Dev Containers attach workflow: `Remote-Containers: Reopen in Container` → extensions auto-install
- ✅ All healthchecks pass within 45s of startup
- ✅ Shell aliases in entrypoint set GEMINI_API_BASE=http://headroom:8787 for Gemini CLI compression

**Business**
- ✅ Decoupled VS Code browser failures (serve-web crash) do not affect SSH agent runtime
- ✅ Developers can choose: browser UI (vscode-server), SSH attach, or Dev Containers
- ✅ Headroom triple-stack applies compression + memory + code-graph to all agent sessions automatically
- ✅ OpenMemory (Phase 2) supplements with explicit structured memory queries
- ✅ CodeGraphContext (Phase 3) supplements with explicit code-graph queries
- ✅ All capabilities available to Claude Code, VS Code extensions, and Gemini CLI
- ✅ Extension installation no longer blocks image build

---

## Risk Mitigation

**Healthcheck timing failures** → Start Phase 4 validation with extended timeouts (60s), then optimize down to 45s based on observed startup curves

**Headroom service unavailable** → Headroom's passthrough guarantee ensures compression failures never drop requests; qdrant + neo4j persistence in named volumes survives restarts; if headroom crashes, Docker restarts it via restart: unless-stopped before workspace can accept agent requests (depends_on: service_healthy)

**x-headroom-user-id header not set** → Memories use default scope, may mix agent contexts; ensure header configured in workspace agent settings during Phase 1B

**workspace-repos volume not mounted in Headroom** → code-graph file watcher fails silently; ensure volume mounted at /workspace in Phase 1B

**OpenMemory database connectivity** → Ensure postgres service starts before openmemory; validate DATABASE_URL env var in test runs; add postgres depends_on condition if needed

**CodeGraphContext index stale** → File watcher should rebuild on file changes automatically; validate Tree-sitter scanning on workspace file save; add manual rebuild task if watch fails

**Extension marketplace IDs incorrect** → Validate by querying `code --list-extensions` in test container before final build; maintain fallback list if marketplace IDs change

**Dev Containers extension dependency conflicts** → Test devcontainer.json attachment in clean environment; validate extension load order

**Volume mount permission issues** → Ensure workspace-home and workspace-repos mounted as user (uid 1000) in workspace, vscode-server, headroom, and code-graph; test file ownership

---

## Next Steps

1. ~~**Phase 0** (RTK installation and hooks)~~ — ✅ **COMPLETE**

2. ~~**Phase 1** (Workspace healthcheck + Headroom triple-stack + VS Code extensions)~~ — ✅ **COMPLETE**

3. ~~**Phase 2A** (vscode-server container)~~ — ✅ **COMPLETE**

4. ~~**Phase 2B** (devcontainer.json)~~ — ✅ **COMPLETE**

5. **Additional improvements delivered** (beyond original plan):
   - RTK installation moved from Dockerfile root `RUN` to `mise.toml` `[tasks.rtk]` (cleaner, runs as `user`)
   - Aspire Dashboard polling loop removed from `entrypoint.sh`; replaced with `depends_on: aspire-dashboard: condition: service_healthy` in Compose
   - Headroom MCP server added to all agent configs (Gemini, Codex, Copilot) — Claude already had it
   - ADR 015 (GPU pass-through for workspace ML workflows and Headroom acceleration) added to architecture documentation

6. **Pending — Phase 3 (CodeGraphContext)**:
   - Add `code-graph` service to docker-compose.yml (`mekayelanik/codegraphcontext-mcp:stable`, HTTP port 8045)
   - Mount `workspace-repos` volume at `/workspace`
   - Register MCP endpoint in all agent configs

7. **Pending — Phase 4 (Integration Validation)**:
   - Build image and verify layer caching (`docker build`)
   - Spin up default profile: workspace + 8 MCP sidecars + headroom triple-stack
   - Verify headroom triple-stack startup order (qdrant → neo4j → headroom → workspace)
   - Validate ANTHROPIC_BASE_URL, OPENAI_BASE_URL, GEMINI_API_BASE resolve to headroom
   - Verify RTK binary in PATH: `rtk --version` in container
   - Verify RTK compression: `rtk git status` (2,000→200 tokens), `rtk cargo test` (>90% reduction)
   - Spin up `--profile vscode`: validate vscode-server startup order
   - Attach VS Code Dev Containers: extensions install, zzaia-workspace profile active
   - SSH access independent of vscode-server health
   - Verify CodeGraphContext HTTP endpoint on port 8045

8. **Create PR** on `feature/improve-agentic-system` branch.

---

**Estimated Total Duration**: ~16 calendar days (Phase 0 + Phase 1 + Phase 2 + Phase 3 + Phase 4)
