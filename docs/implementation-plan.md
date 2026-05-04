---
project: zzaia-agentic-workspace
branch: feature/improve-agentic-system
document-type: implementation-plan
created: 2026-05-02
updated: 2026-05-02
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
    title Implementation Timeline - Parallel vs Sequential
    dateFormat 2026-05-02

    section Phase 1 (Parallel)
    Story 1.2.1: Workspace healthcheck           :active, story121, 2026-05-02, 3d
    Story 3.1: Headroom proxy setup              :active, story31, 2026-05-02, 3d
    Story 3.2: OpenMemory MCP service            :active, story32, 2026-05-02, 2d
    Story 4.1: Fix VS Code extensions            :active, story41, 2026-05-02, 2d

    section Phase 2 (Sequential - after Wave 1)
    Story 1.1.1: vscode-server container         :crit, story111, after story121, 2d
    Story 2.1: devcontainer.json                 :crit, story21, after story41, 3d
    Story 3.3: CodeGraphContext service          :crit, story33, after story121, 3d

    section Phase 3 (Integration)
    End-to-end validation                        :crit, e2e, after story21, 2d
```

**Legend**: Green (Active) = Parallel execution | Red (Critical) = Sequential execution | **Total**: 39 points

---

## Phase 1: Foundation (Wave 1 - Parallel) (10 points)

**Parallel**: ✅ | **Team**: 1 DevOps Specialist

### 1A: Workspace Container Healthcheck (Story 1.2.1) (3 points)

**Acceptance Criteria**:
- `code serve-web` watchdog loop removed from `docker/entrypoint.sh`
- `EXPOSE ${VSCODE_PORT}` removed from `docker/Dockerfile`
- Docker `HEALTHCHECK` added to Dockerfile: `CMD bash -c '</dev/tcp/localhost/2222'` with interval 10s, retries 5, start_period 15s
- Workspace container no longer exposes VSCODE_PORT on host
- Healthcheck passes reliably before dependent services start

**Tasks**:
- [ ] Remove serve-web watchdog from entrypoint.sh (1)
- [ ] Add TCP/2222 healthcheck to Dockerfile (1)
- [ ] Remove EXPOSE VSCODE_PORT from Dockerfile (1)

**Outputs**: Updated `docker/entrypoint.sh`, updated `docker/Dockerfile`

**Dependencies**: None

---

### 1B: Headroom AI Proxy Container (Story 3.1) (3 points)

**Acceptance Criteria**:
- `headroom` service added to docker-compose.yml — always-on (no profile), `restart: unless-stopped`
- `qdrant` service added — `qdrant/qdrant:v1.17.1`, volume `<ws>-headroom-qdrant`, healthcheck `/readyz` (shared by OpenMemory MCP)
- `headroom` depends_on qdrant (condition: service_healthy)
- `workspace` depends_on headroom (condition: service_healthy)
- `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY` passed to headroom container
- `QDRANT_URL=http://qdrant:6333` passed to headroom
- Workspace env always includes: `ANTHROPIC_BASE_URL=http://headroom:8787`, `OPENAI_BASE_URL=http://headroom:8787`, `GEMINI_API_BASE=http://headroom:8787`
- Headroom healthcheck: `wget -qO- http://localhost:8787/health` interval 10s, retries 5, start_period 30s
- Named volume declared: `<ws>-headroom-qdrant`

**Tasks**:
- [ ] Add qdrant service with persistent volume and healthcheck (1)
- [ ] Add headroom service depending on qdrant healthy (1)
- [ ] Wire ANTHROPIC_BASE_URL, OPENAI_BASE_URL, GEMINI_API_BASE into workspace env (1)
- [ ] Add workspace depends_on headroom: service_healthy (1)
- [ ] Declare headroom-qdrant named volume (1)

**Outputs**: Updated `docker/docker-compose.yml` with headroom (always-on) and qdrant services and volumes

**Dependencies**: None

---

### 1B2: OpenMemory MCP for Session Memory (Story 3.2) (2 points)

**Acceptance Criteria**:
- `openmemory` service added to docker-compose.yml — `image: skpassegna/openmemory-mcp:latest`
- Uses existing postgres and qdrant services from compose
- Environment: `DATABASE_URL=postgresql://user:password@postgres:5432/openmemory`, `QDRANT_URL=http://qdrant:6333`
- MCP tools auto-discoverable: `search_memory`, `add_memories`, `list_memories`, `delete_all_memories`
- Workspace container MCP config includes openmemory endpoint
- Memory persists in Postgres across container restarts
- openmemory depends_on postgres and qdrant (condition: service_healthy)

**Tasks**:
- [ ] Add openmemory compose service with correct image and env vars (1)
- [ ] Register MCP endpoint in workspace claude_desktop_config.json (1)

**Outputs**: Updated `docker/docker-compose.yml` with openmemory service, updated workspace MCP config

**Dependencies**: None

---

### 1C: Fix Missing VS Code Extensions (Story 4.1) (2 points)

**Acceptance Criteria**:
- Verify correct marketplace ID for `google.gemini-code-assist` (may differ from current)
- Verify correct marketplace ID for `openai.chatgpt` (may differ from current)
- Extension IDs updated in `docker/mise.toml` vscode-extensions task
- Both extensions confirmed installed in built image via `code --extensions-dir /tmp/test-extensions --list-extensions`

**Tasks**:
- [ ] Verify and update Gemini Code Assist extension ID (1)
- [ ] Verify and update OpenAI ChatGPT extension ID (1)

**Outputs**: Updated `docker/mise.toml` with correct extension IDs

**Dependencies**: Completed before Story 2.1 acceptance validation

---

## Phase 2: Service Development (Wave 2 - Sequential after Wave 1) (21 points)

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
- [ ] Add vscode-server service definition to docker-compose.yml (2)
- [ ] Configure volume mounts for workspace-home and workspace-repos (1)
- [ ] Add healthcheck for serve-web endpoint (1)
- [ ] Move VSCODE_PORT exposure from workspace to vscode-server (2)
- [ ] Test startup sequence: workspace healthy → vscode-server healthy (2)

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
- [ ] Create devcontainer.json with remoteUser and extensions list (2)
- [ ] Extract full extension list from mise.toml (1)
- [ ] Configure VS Code settings customization block (1)
- [ ] COPY devcontainer.json into Dockerfile at build time (1)
- [ ] Test Dev Containers attachment workflow (3)
- [ ] Validate extension auto-installation on attach (2)

**Outputs**: New `docker/devcontainer.json`, updated `docker/Dockerfile`

**Dependencies**: Story 1.2.1 (healthcheck), Story 4.1 (correct extension IDs)

---

### 2C: CodeGraphContext for Workspace Semantic Search (Story 3.3) (3 points)

**Reference**: Depends on Story 1.2.1 completion; workspace-repos volume must be confirmed

**Acceptance Criteria**:
- `code-graph` service added to docker-compose.yml — `image: kuzudb/code-graph:latest`
- Mounts `workspace-repos` volume at `/workspace`
- Runs `cgc watch /workspace` (file watcher) + `cgc mcp start` (MCP server on port 3000)
- MCP tools auto-discoverable: `find_callers`, `find_callees`, `class_hierarchy`, `call_chain`
- Index rebuilds automatically on file changes (Tree-sitter scanning)
- Persistent index stored in named volume `<ws>-code-graph-db` at `/db`
- Workspace container MCP config includes code-graph endpoint
- code-graph depends_on workspace (condition: service_healthy)

**Tasks**:
- [ ] Add code-graph service definition to docker-compose.yml (1)
- [ ] Configure workspace-repos volume mount and persistent db volume (1)
- [ ] Register MCP endpoint in workspace claude_desktop_config.json (1)
- [ ] Test index build on startup (file presence detection) (1)

**Outputs**: Updated `docker/docker-compose.yml` with code-graph service and volume, updated workspace MCP config

**Dependencies**: Story 1.2.1 (workspace healthcheck)

---

## Phase 3: Integration Validation (4 points)

**Sequential**: ✅ | **Team**: 1 QA/DevOps Specialist

**Tasks**:
- [ ] Build image with all changes and verify layer caching (1)
- [ ] Spin up `docker-compose up -d` (default profile): workspace + 8 MCP sidecars (1)
- [ ] Spin up with `--profile vscode`: add vscode-server, validate startup order (1)
- [ ] Verify headroom, qdrant, neo4j start in correct dependency order (1)
- [ ] Validate ANTHROPIC_BASE_URL, OPENAI_BASE_URL, GEMINI_API_BASE all resolve to headroom (1)
- [ ] Spin up with `--profile vscode`: workspace + vscode-server + headroom + qdrant + neo4j all healthy (1)
- [ ] Send a test agent request and confirm headroom /stats shows intercepted request (1)
- [ ] Attach VS Code Dev Containers: extensions install, zzaia-workspace profile active (2)
- [ ] SSH access via workspace container: verify independent of vscode-server health (1)

**Outputs**: Test report validating all profiles, healthchecks, and Dev Containers workflow

---

## Technology Stack

**Container Orchestration**: Docker, Docker Compose, Compose profiles

**Development Environments**: VS Code browser (serve-web), VS Code SSH attach, VS Code Dev Containers

**AI Proxy**: Headroom (ghcr.io/chopratejas/headroom:latest) with context compression

**Vector DB**: Qdrant v1.17.1 (shared by Headroom compression and OpenMemory session memory)

**Session Memory**: OpenMemory MCP (skpassegna/openmemory-mcp:latest) with Postgres + Qdrant backing

**Workspace Search**: CodeGraphContext (kuzudb/code-graph:latest) with Tree-sitter + KûzuDB for semantic code search

**Tool Management**: mise for VS Code extensions and tool versioning

**Health Monitoring**: TCP/HTTP healthchecks, depends_on service_healthy condition

---

## Effort Summary

**Parallel Execution (Phase 1 Wave 1)**: 10 points (all 4 stories in parallel)

**Sequential Execution (Phase 2 Wave 2)**: 21 points (after Wave 1 complete)

**Integration (Phase 3)**: 4 points

**Total**: 39 points

**Efficiency Gain**: 12 points (24% reduction vs sequential)
- Wave 1 stories (1.2.1, 3.1, 3.2, 4.1) execute in parallel → saves ~7 days
- Wave 2 stories (1.1.1, 2.1, 3.3) can start after Wave 1 → saves ~5 days

---

## Team Structure

### Recommended (Parallel Execution)
- 1 DevOps Specialist (handles Phases 1A, 1B, 1C in parallel)
- 1 QA/Integration Specialist (Phase 3)

### Minimum (Sequential)
- 1 DevOps Specialist (executes all phases sequentially)

---

## Success Criteria

**Technical**
- ✅ Workspace container exposes only SSH (2222) and has TCP/2222 healthcheck
- ✅ vscode-server container runs independently with serve-web, depends_on workspace healthy
- ✅ devcontainer.json embedded in image with correct extension list and zzaia-workspace profile
- ✅ Headroom AI proxy always-on with qdrant; ANTHROPIC_BASE_URL, OPENAI_BASE_URL, GEMINI_API_BASE always set
- ✅ Qdrant persists data in named volume across container restarts
- ✅ OpenMemory MCP service running and MCP tools (search_memory, add_memories, list_memories, delete_all_memories) discoverable by all agents
- ✅ CodeGraphContext service running with workspace-repos indexed and MCP tools (find_callers, find_callees, class_hierarchy, call_chain) discoverable
- ✅ All 8 MCP sidecars start with default profile
- ✅ Google Gemini Code Assist and OpenAI ChatGPT extensions install without build-time failures

**Operational**
- ✅ Default `docker-compose up -d` starts headroom + qdrant + openmemory + code-graph + workspace + 8 MCPs
- ✅ `docker-compose --profile vscode up -d` additionally starts vscode-server
- ✅ Dev Containers attach workflow: `Remote-Containers: Reopen in Container` → extensions auto-install
- ✅ All healthchecks pass within 45s of startup
- ✅ Shell aliases in entrypoint set GEMINI_API_BASE=http://headroom:8787 for Gemini CLI compression

**Business**
- ✅ Decoupled VS Code browser failures (serve-web crash) do not affect SSH agent runtime
- ✅ Developers can choose: browser UI (vscode-server), SSH attach, or Dev Containers
- ✅ Headroom AI proxy applies compression, OpenMemory MCP provides session memory, CodeGraphContext provides workspace semantic search to all agent sessions by default
- ✅ All three optimization capabilities available to Claude Code, VS Code extensions, and Gemini CLI
- ✅ Extension installation no longer blocks image build

---

## Risk Mitigation

**Healthcheck timing failures** → Start Phase 3 validation with extended timeouts (60s), then optimize down to 45s based on observed startup curves

**Headroom service unavailable** → Headroom's passthrough guarantee ensures compression failures never drop requests; qdrant persistence in named volume survives restarts; if headroom crashes, Docker restarts it via restart: unless-stopped before workspace can accept agent requests (depends_on: service_healthy)

**OpenMemory database connectivity** → Ensure postgres service starts before openmemory; validate DATABASE_URL env var in test runs; add postgres depends_on condition if needed

**CodeGraphContext index stale** → File watcher should rebuild on file changes automatically; validate Tree-sitter scanning on workspace file save; add manual rebuild task if watch fails

**Extension marketplace IDs incorrect** → Validate by querying `code --list-extensions` in test container before final build; maintain fallback list if marketplace IDs change

**Dev Containers extension dependency conflicts** → Test devcontainer.json attachment in clean environment; validate extension load order

**Volume mount permission issues** → Ensure workspace-home and workspace-repos mounted as user (uid 1000) in workspace, vscode-server, and code-graph; test file ownership

---

## Next Steps

1. **Start Phase 1 (Wave 1) in parallel**:
   - Assign Story 1.2.1 (healthcheck) to DevOps lead
   - Assign Story 3.1 (headroom) to same lead (parallel work)
   - Assign Story 3.2 (openmemory) to same lead (parallel work)
   - Assign Story 4.1 (extensions) to same lead (parallel work)
   - Target completion: 3 days

2. **After Wave 1 complete, start Phase 2 (Wave 2)**:
   - Assign Story 1.1.1 (vscode-server) — blocking dependency on Story 1.2.1
   - Assign Story 2.1 (devcontainer.json) — blocking dependency on Story 4.1
   - Assign Story 3.3 (code-graph) — blocking dependency on Story 1.2.1
   - Target completion: 5 days

3. **Execute Phase 3 (Integration)**:
   - Full build and profile validation
   - Dev Containers attachment end-to-end test
   - Verify OpenMemory MCP tools and CodeGraphContext tools discoverable
   - Test Gemini CLI compression via GEMINI_API_BASE alias
   - Target completion: 2 days

4. **Create feature branch PR** with all changes, request review on:
   - Healthcheck TCP endpoint reliability
   - Volume mount isolation between workspace, vscode-server, and code-graph
   - Extension list completeness vs mise.toml source
   - devcontainer.json profile settings alignment
   - Qdrant shared between Headroom and OpenMemory
   - CodeGraphContext index persistence and rebuild logic

---

**Estimated Total Duration**: ~11 calendar days (parallel Wave 1 + sequential Wave 2 + Phase 3)
