# ZZAIA Agentic Workspace — Quick Start

> Get the workspace running in under 5 minutes.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **Docker Desktop or CLI** | Runs the workspace container and MCP sidecars | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) |
| **Bitwarden Secrets Manager** *(optional)* | Automated secret bootstrap — vault-server runs the bws CLI internally at startup; no host installation required | [bitwarden.com/products/secrets-manager](https://bitwarden.com/products/secrets-manager/) |
| **Enhanced Container Isolation (ECI)** *(optional)* | Enables unprivileged Docker-in-Docker sandboxing — Docker Desktop > Settings > General > "Use Enhanced Container Isolation" | [docs.docker.com/desktop/hardened-desktop/enhanced-container-isolation](https://docs.docker.com/desktop/hardened-desktop/enhanced-container-isolation/) |

---

## Step 1 — Choose Authentication

Only **one** method is needed. Claude Code checks them in this priority order:

| Priority | Method | Best For |
|----------|--------|---------|
| 1 | **Cloud Provider** (Bedrock / Vertex / Foundry) | Enterprise / no token expiry |
| 2 | **API Key** | Pay-per-token / simplest setup |
| 3 | **Pro / Max (OAuth)** | Subscription accounts |

> If multiple methods are configured, the highest-priority one wins.

### Cloud Provider variables

| Provider | Variables to Set |
|----------|-----------------|
| **AWS Bedrock** | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` + `AWS_REGION` (+ optional `ANTHROPIC_BEDROCK_BASE_URL`) |
| **Google Vertex AI** | `CLAUDE_CODE_USE_VERTEX=1` + `ANTHROPIC_VERTEX_PROJECT_ID` + `CLOUD_ML_REGION` |
| **Azure AI Foundry** | `CLAUDE_CODE_USE_FOUNDRY=1` + `AZURE_FOUNDRY_BASE_URL` |

### API Key

Set `ANTHROPIC_API_KEY` — obtain from [console.anthropic.com](https://console.anthropic.com).

### Pro / Max (OAuth)

| | Extension | Terminal `claude` REPL |
|---|---|---|
| **Option A** (`CLAUDE_CODE_OAUTH_TOKEN` env var) | ✅ | ✅ after one-time `.claude.json` seed |
| **Option B** (`claude setup-token` inside container) | ✅ | ✅ fully self-contained |

**Option A — Long-lived env var token:**

On your **host machine**, run:

```bash
claude setup-token
```

Copy the printed token and set it as `CLAUDE_CODE_OAUTH_TOKEN` in Step 2. Valid for ~1 year. The extension picks it up immediately.

> **Important:** The token must be a single unbroken line. Terminal output may wrap it across multiple lines — copy the full token and remove any line breaks. A token with an embedded newline causes an `invalid header value` error.

The onboarding wizard is automatically suppressed — the image ships a `.claude.json` with `hasCompletedOnboarding: true` that seeds the home volume on first start.

**Option B — Interactive session inside the container (simplest, fully self-contained):**

Start the container first (Step 3), open a terminal inside VS Code, and run:

```bash
claude setup-token
```

Claude Code prints a URL. **Do not expect a browser to open automatically** — the container has no display. Instead:

1. Copy the URL from the terminal
2. Open it in a browser **on your host machine**
3. Complete authentication
4. Copy the authorization code shown in the browser back into the terminal when prompted

> **Important:** The OAuth callback URL is not reachable from inside the container — you must manually copy the URL and open it on the host, then copy the code back.

Claude Code stores the full session (credentials + account info) in the home volume — the onboarding wizard is permanently suppressed and the session persists across all container restarts. No env var is needed.

---

## Step 2 — Gather Your Values

You will need the following values before starting:

| Variable | Required | Description | Where to Get |
|----------|----------|-------------|--------------|
| `WORKSPACE_NAME` | ✅ | Unique name for this workspace instance (used as Docker Compose project name) | Choose any slug, e.g. `my-org` |
| `SSH_PUBLIC_KEY` | ✅ | Your SSH public key (e.g. `ssh-ed25519 AAAA...`) | `cat ~/.ssh/id_ed25519.pub` — generate with `ssh-keygen -t ed25519` |
| `VSCODE_PORT` | ✅ | Host port for VS Code browser access | Default: `8080` |
| `SSH_PORT` | ✅ | Host port for SSH access | Default: `2222` |
| `ASPIRE_DASHBOARD_PORT` | ✅ | Host port for Aspire telemetry dashboard | Default: `18888` |
| `BWS_ACCESS_TOKEN` | Optional | Bitwarden Secrets Manager machine account token — if provided, vault-server bootstraps all secrets from Bitwarden automatically; if skipped, secrets are entered manually via Vault UI after first boot | From Bitwarden Secrets Manager; press Enter to skip |
| `ADMIN_PASSWORD` | Optional | Sets the sudo password for the `user` account; also used as the Neo4j password for Headroom | Any string; leave empty for no sudo and default Neo4j password (`headroom`) |

All API keys, PATs, and cloud credentials are stored in Vault (AES-256-GCM encrypted at rest). Configure or update them via Vault UI at `http://localhost:${VAULT_PORT}/ui` after first boot.

---

## Step 3 — Start the Workspace

Run the deploy script for your platform. The script prompts securely for `BWS_ACCESS_TOKEN` (press Enter to skip and configure secrets manually via Vault UI after startup).

**Ubuntu / WSL:**
```bash
./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..."
```

**macOS:**
```bash
./deploy/mac.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..."
```

**Windows:**
```powershell
.\deploy\windows.ps1 -WorkspaceName my-org -SshPublicKey "ssh-ed25519 AAAA..."
```

Optional flags: `--gpu`, `--profiles vscode,devcontainer`, `--vault-port 8200`, `--ssh-port 2222`, `--vscode-port 8080`, `--jupyter-port 8888`.

**With Bitwarden token** — vault-server bootstraps all secrets from Bitwarden at startup. Manage or rotate via Vault UI afterward.

**Without token** (press Enter) — vault-server starts with an empty KV store. The script prints the root token retrieval command and the KV paths to populate via Vault UI.

After the first run, **start or stop the workspace from Docker Desktop** — no command needed again.

---

## Step 4 — Access the Workspace

| Access | URL / Command |
|--------|--------------|
| **VS Code** (browser) | `http://localhost:<VSCODE_PORT>` (default `8080`) — requires `--profile vscode` at startup |
| **SSH** | `ssh -p <SSH_PORT> user@localhost` (default `2222`) |
| **Dev Containers** | VS Code → Remote Explorer → Attach to Running Container → workspace |
| **Aspire Dashboard** | `http://localhost:<ASPIRE_DASHBOARD_PORT>` (default `18888`) |
| **Vault UI** | `http://localhost:8200/ui` (localhost only) |

Claude Code, Gemini, Copilot, and Codex extensions are pre-installed. All MCP tools connect automatically via isolated sidecar containers. The Aspire dashboard starts empty and receives telemetry when an AppHost is running. Vault UI provides interactive secret management and audit logs.

---

## Step 5 — Verify Setup

Inside Claude Code, run:

```
/mcp
```

All configured tools should show as connected. Then verify commands are available:

- Type `/behavior` — should list behavior commands
- Type `/workflow` — should list workflow commands
- Type `/capability` — should list capability commands

---

## Step 6 — Start Working

### Clone your first repository

```
/behavior:workspace:repo --action new --repo your-repo-url
```

### Read a work item

```
/behavior:devops:work-item --action read --id 12345 --portal azure --project YourProject
```

### Implement a feature end-to-end

```
/workflow:remote:implement --work-item 1605 --portal azure --project my-project --repo game-service --target-branch develop --working-branch feature/implement-something --description "Additional context"
```

### Apply targeted changes

```
/behavior:development:develop --repo repo-name --branch branch-name --description "What needs to change" @path/to/file
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| MCP shows disconnected | Wait ~30s for sidecar containers to finish npx install, then retry `/mcp` |
| Workspace slow to start | workspace-server runs tool installation on first boot; headroom waits for qdrant/neo4j — allow up to 90s on first boot |
| Agent API calls failing | Run `docker logs <WORKSPACE_NAME>-headroom-1` — headroom may still be initializing |
| Container not starting | Run `docker logs <WORKSPACE_NAME>-workspace-server-1` or `docker logs <WORKSPACE_NAME>-mcp-azure-devops-1` |
| Port already in use | Stop any existing stack via Docker Desktop before re-running |
| SSH key rejected | Verify `SSH_PUBLIC_KEY` starts with `ssh-ed25519`, `ssh-rsa`, or `ecdsa-` |
| Terminal `claude` shows onboarding wizard | Home volume was created before the fix — delete `<WORKSPACE_NAME>-home` volume and restart, or run `claude setup-token` inside the container |
| Extension auth error: `invalid header value` | `CLAUDE_CODE_OAUTH_TOKEN` contains a newline from terminal line-wrap — remove all line breaks from the token and recreate the container |
| Vault UI shows 'sealed' | vault-server auto-unseals on startup using keys in vault-data volume. Check logs: `docker logs <WORKSPACE_NAME>-vault-server-1` |

---

## Running Multiple Workspaces Simultaneously

Each workspace gets its own isolated Docker Compose stack identified by `WORKSPACE_NAME`. Use different ports per stack so they can run at the same time:

```bash
# Workspace 1 — default ports
./deploy/ubuntu.sh --workspace-name org-one --ssh-public-key "ssh-ed25519 AAAA..." \
    --vscode-port 8080 --ssh-port 2222

# Workspace 2 — different ports
./deploy/ubuntu.sh --workspace-name org-two --ssh-public-key "ssh-ed25519 AAAA..." \
    --vscode-port 8081 --ssh-port 2223
```

Each stack is fully isolated: separate containers (`org-one-workspace-1`, `org-two-workspace-1`), separate MCP sidecars, separate Vault volumes, and separate internal networks.

**Recommended port assignments:**

| Workspace | `VSCODE_PORT` | `SSH_PORT` |
|-----------|--------------|------------|
| org-one   | `8080`       | `2222`     |
| org-two   | `8081`       | `2223`     |
| org-three | `8082`       | `2224`     |
| org-four  | `8083`       | `2225`     |

---

## Secret Rotation

To update secrets (API keys, PATs, cloud credentials), log in to the Vault UI at `http://localhost:${VAULT_PORT}/ui` using the root token stored in the `vault-data` volume:

```bash
# Retrieve root token from vault-data volume
docker run --rm -v <WORKSPACE_NAME>-vault-data:/vault/data alpine cat /vault/data/.init | grep root_token
```

Then navigate to the secret path in Vault UI and update the value. MCP sidecar containers re-fetch secrets at next restart.

> Multiple volumes exist per workspace, each with an independent lifecycle:
>
> | Volume | Contains | Delete to… |
> |--------|----------|-----------|
> | `<WORKSPACE_NAME>-secrets` | SSH public key, persisted env | Rotate SSH key |
> | `<WORKSPACE_NAME>-home` | Home directory (user config, credentials, workspace repos) | Reset all user state |
> | `<WORKSPACE_NAME>-tools` | Runtime tools (Node.js, .NET, Python, CLIs) | Force tool re-install on next workspace-server start |
> | `<WORKSPACE_NAME>-vault-data` | HashiCorp Vault KV v2 (file backend, AES-256-GCM encryption at rest); init/unseal keys at `/vault/data/.init` | Reset Vault secrets (caution: loses all stored values) |
>
> ```bash
> # Rotate SSH key only
> docker volume rm <WORKSPACE_NAME>-secrets
>
> # Reset home (user configs, credentials, repos)
> docker volume rm <WORKSPACE_NAME>-home
>
> # Force tool re-install (delete tools volume)
> docker volume rm <WORKSPACE_NAME>-tools
>
> # Full decommission
> docker volume rm <WORKSPACE_NAME>-secrets <WORKSPACE_NAME>-home <WORKSPACE_NAME>-tools <WORKSPACE_NAME>-vault-data
> ```

---

## Available Commands Reference

| Command | Purpose | Definition |
|---------|---------|------------|
| `/behavior:workspace:repo` | Clone repo or create branch worktree | [↗](agents/claude/.claude/commands/behavior/workspace/repo.md) |
| `/behavior:devops:work-item` | Read or manage work items | [↗](agents/claude/.claude/commands/behavior/devops/work-item.md) |
| `/behavior:devops:pull-request` | Manage pull requests | [↗](agents/claude/.claude/commands/behavior/devops/pull-request.md) |
| `/behavior:devops:pipeline` | Run or debug CI/CD pipelines | [↗](agents/claude/.claude/commands/behavior/devops/pipeline.md) |
| `/behavior:devops:new-relic` | New Relic log diagnostics | [↗](agents/claude/.claude/commands/behavior/devops/new-relic.md) |
| `/behavior:development:develop` | Apply targeted changes to a branch | [↗](agents/claude/.claude/commands/behavior/development/develop.md) |
| `/behavior:development:build` | Multi-framework builds | [↗](agents/claude/.claude/commands/behavior/development/build.md) |
| `/behavior:development:test` | Comprehensive testing | [↗](agents/claude/.claude/commands/behavior/development/test.md) |
| `/behavior:development:review` | Code quality review | [↗](agents/claude/.claude/commands/behavior/development/review.md) |
| `/behavior:development:git` | Git commit and push | [↗](agents/claude/.claude/commands/behavior/development/git.md) |
| `/workflow:remote:implement` | Full implementation from work item to PR | [↗](agents/claude/.claude/commands/workflow/remote/implement.md) |
| `/workflow:remote:architect` | Generate BDD, Epic, and work items from a spec | [↗](agents/claude/.claude/commands/workflow/remote/architect.md) |
| `/workflow:remote:homologate` | Run E2E BDD against a live URL | [↗](agents/claude/.claude/commands/workflow/remote/homologate.md) |
| `/workflow:remote:fix-pipeline` | Iterative pipeline repair loop | [↗](agents/claude/.claude/commands/workflow/remote/fix-pipeline.md) |
| `/orchestrator:implement` | Implement multiple work items in parallel | [↗](agents/claude/.claude/commands/orchestrator/implement/SKILL.md) |

Full reference: [README.md](README.md)
