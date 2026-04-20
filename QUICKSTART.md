# ZZAIA Agentic Workspace — Quick Start

> Get the workspace running in under 5 minutes.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **Docker Desktop** | Runs the workspace container and MCP sidecars | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) |

---

## Step 1 — Gather Your Values

You will need the following values before starting:

| Variable | Required | Description | Where to Get |
|----------|----------|-------------|--------------|
| `WORKSPACE_NAME` | ✅ | Unique name for this workspace instance (used as Docker Compose project name) | Choose any slug, e.g. `my-org` |
| `SSH_PUBLIC_KEY` | ✅ | Your SSH public key (e.g. `ssh-ed25519 AAAA...`) | `cat ~/.ssh/id_ed25519.pub` — generate with `ssh-keygen -t ed25519` |
| `VSCODE_PORT` | ✅ | Host port for VS Code browser access | Default: `8080` |
| `SSH_PORT` | ✅ | Host port for SSH access | Default: `2222` |
| `TAVILY_API_KEY` | Optional | Tavily API key | [tavily.com](https://tavily.com) |
| `ADO_MCP_AUTH_TOKEN` | Optional | Azure DevOps Personal Access Token | [Azure DevOps → User Settings → Personal Access Tokens](https://dev.azure.com) |
| `AZURE_DEVOPS_ORGANIZATION` | Optional | Azure DevOps organization name (e.g. `my-org`) | Azure DevOps URL: `dev.azure.com/<org>` |
| `POSTMAN_API_KEY` | Optional | Postman API key | [postman.com → Account Settings → API Keys](https://postman.com) |
| `NEW_RELIC_API_KEY` | Optional | New Relic User API key | [New Relic → API Keys](https://one.newrelic.com/admin-portal/api-keys) |

> MCP integrations are optional — leave any key empty and that sidecar exits cleanly without restarting.

---

## Step 2 — Start the Workspace

Fill in your values and run the command for your platform. No files are written to disk.

### Ubuntu / macOS / WSL

```bash
WORKSPACE_NAME="my-org"
SSH_PUBLIC_KEY=""
TAVILY_API_KEY=""
ADO_MCP_AUTH_TOKEN=""
AZURE_DEVOPS_ORGANIZATION=""
POSTMAN_API_KEY=""
NEW_RELIC_API_KEY=""
VSCODE_PORT="8080"
SSH_PORT="2222"

docker compose \
    -f "./docker/docker-compose.yml" \
    -p "$WORKSPACE_NAME" \
    --env-file <(
        printf 'WORKSPACE_NAME=%s\n'            "$WORKSPACE_NAME"
        printf 'SSH_PUBLIC_KEY=%s\n'            "$SSH_PUBLIC_KEY"
        printf 'TAVILY_API_KEY=%s\n'            "$TAVILY_API_KEY"
        printf 'ADO_MCP_AUTH_TOKEN=%s\n'        "$ADO_MCP_AUTH_TOKEN"
        printf 'AZURE_DEVOPS_ORGANIZATION=%s\n' "$AZURE_DEVOPS_ORGANIZATION"
        printf 'POSTMAN_API_KEY=%s\n'           "$POSTMAN_API_KEY"
        printf 'NEW_RELIC_API_KEY=%s\n'         "$NEW_RELIC_API_KEY"
        printf 'VSCODE_PORT=%s\n'               "$VSCODE_PORT"
        printf 'SSH_PORT=%s\n'                  "$SSH_PORT"
    ) \
    up -d
```

### Windows

```powershell
$WORKSPACE_NAME            = "my-org"
$SSH_PUBLIC_KEY            = ""
$TAVILY_API_KEY            = ""
$ADO_MCP_AUTH_TOKEN        = ""
$AZURE_DEVOPS_ORGANIZATION = ""
$POSTMAN_API_KEY           = ""
$NEW_RELIC_API_KEY         = ""
$VSCODE_PORT               = "8080"
$SSH_PORT                  = "2222"

$env:WORKSPACE_NAME            = $WORKSPACE_NAME
$env:SSH_PUBLIC_KEY            = $SSH_PUBLIC_KEY
$env:TAVILY_API_KEY            = $TAVILY_API_KEY
$env:ADO_MCP_AUTH_TOKEN        = $ADO_MCP_AUTH_TOKEN
$env:AZURE_DEVOPS_ORGANIZATION = $AZURE_DEVOPS_ORGANIZATION
$env:POSTMAN_API_KEY           = $POSTMAN_API_KEY
$env:NEW_RELIC_API_KEY         = $NEW_RELIC_API_KEY
$env:VSCODE_PORT               = $VSCODE_PORT
$env:SSH_PORT                  = $SSH_PORT

docker compose `
    -f ".\docker\docker-compose.yml" `
    -p $WORKSPACE_NAME `
    up -d

'WORKSPACE_NAME','SSH_PUBLIC_KEY','TAVILY_API_KEY','ADO_MCP_AUTH_TOKEN','AZURE_DEVOPS_ORGANIZATION',
'POSTMAN_API_KEY','NEW_RELIC_API_KEY','VSCODE_PORT','SSH_PORT' | ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }
```

After the first run, **start or stop the workspace from Docker Desktop** — no command needed again.

---

## Step 3 — Access the Workspace

| Access | URL / Command |
|--------|--------------|
| **VS Code** (browser) | `http://localhost:<VSCODE_PORT>` (default `8080`) |
| **SSH** | `ssh -p <SSH_PORT> zzaia@localhost` (default `2222`) |

The Claude Code extension is pre-installed. All MCP tools (Tavily, Azure DevOps, Postman, New Relic) connect automatically via isolated sidecar containers.

---

## Step 4 — Verify Setup

Inside Claude Code, run:

```
/mcp
```

All configured tools should show as connected. Then verify commands are available:

- Type `/behavior` — should list behavior commands
- Type `/workflow` — should list workflow commands
- Type `/capability` — should list capability commands

---

## Step 5 — Start Working

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
| Container not starting | Run `docker logs <WORKSPACE_NAME>-workspace-1` or `docker logs <WORKSPACE_NAME>-mcp-azure-devops-1` |
| Port already in use | Stop any existing stack via Docker Desktop before re-running |
| SSH key rejected | Verify `SSH_PUBLIC_KEY` starts with `ssh-ed25519`, `ssh-rsa`, or `ecdsa-` |

---

## Running Multiple Workspaces Simultaneously

Each workspace gets its own isolated Docker Compose stack identified by `WORKSPACE_NAME`. Use different ports per stack so they can run at the same time:

```bash
# Workspace 1 — default ports
WORKSPACE_NAME="org-one"  VSCODE_PORT=8080  SSH_PORT=2222  # ... other vars
docker compose -f "./docker/docker-compose.yml" -p "$WORKSPACE_NAME" \
    --env-file <(...) up -d

# Workspace 2 — different ports
WORKSPACE_NAME="org-two"  VSCODE_PORT=8081  SSH_PORT=2223  # ... other vars
docker compose -f "./docker/docker-compose.yml" -p "$WORKSPACE_NAME" \
    --env-file <(...) up -d
```

Each stack is fully isolated: separate containers (`org-one-workspace-1`, `org-two-workspace-1`), separate MCP sidecars, and separate internal networks.

**Recommended port assignments:**

| Workspace | `VSCODE_PORT` | `SSH_PORT` |
|-----------|--------------|------------|
| org-one   | `8080`       | `2222`     |
| org-two   | `8081`       | `2223`     |
| org-three | `8082`       | `2224`     |
| org-four  | `8083`       | `2225`     |

---

## Secret Rotation

To rotate a secret, re-run the Step 2 command with the updated value. Docker will recreate only the containers whose environment changed.

To recreate a single service without restarting the whole stack, set the updated variable and run:

```bash
# Ubuntu / macOS — rotate a single MCP service
NEW_VALUE="new-key-here"

docker compose \
    -f "./docker/docker-compose.yml" \
    -p "$WORKSPACE_NAME" \
    --env-file <(
        printf 'TAVILY_API_KEY=%s\n' "$NEW_VALUE"
        # include the other vars unchanged...
    ) \
    up -d --force-recreate mcp-tavily
```

```powershell
# Windows — rotate a single MCP service
$env:TAVILY_API_KEY = "new-key-here"
# set other vars as needed...

docker compose `
    -f ".\docker\docker-compose.yml" `
    -p $env:WORKSPACE_NAME `
    up -d --force-recreate mcp-tavily
```

> The SSH public key is persisted in the Docker volume `<WORKSPACE_NAME>-secrets`. To rotate it, remove the volume and re-run the full Step 2 command:
> ```bash
> docker volume rm <WORKSPACE_NAME>-secrets
> ```

---

## Available Commands Reference

| Command | Purpose | Definition |
|---------|---------|------------|
| `/behavior:workspace:repo` | Clone repo or create branch worktree | [↗](.claude/commands/behavior/workspace/repo.md) |
| `/behavior:devops:work-item` | Read or manage work items | [↗](.claude/commands/behavior/devops/work-item.md) |
| `/behavior:devops:pull-request` | Manage pull requests | [↗](.claude/commands/behavior/devops/pull-request.md) |
| `/behavior:devops:pipeline` | Run or debug CI/CD pipelines | [↗](.claude/commands/behavior/devops/pipeline.md) |
| `/behavior:devops:new-relic` | New Relic log diagnostics | [↗](.claude/commands/behavior/devops/new-relic.md) |
| `/behavior:development:develop` | Apply targeted changes to a branch | [↗](.claude/commands/behavior/development/develop.md) |
| `/behavior:development:build` | Multi-framework builds | [↗](.claude/commands/behavior/development/build.md) |
| `/behavior:development:test` | Comprehensive testing | [↗](.claude/commands/behavior/development/test.md) |
| `/behavior:development:review` | Code quality review | [↗](.claude/commands/behavior/development/review.md) |
| `/behavior:development:git` | Git commit and push | [↗](.claude/commands/behavior/development/git.md) |
| `/workflow:remote:implement` | Full implementation from work item to PR | [↗](.claude/commands/workflow/remote/implement.md) |
| `/workflow:remote:architect` | Generate BDD, Epic, and work items from a spec | [↗](.claude/commands/workflow/remote/architect.md) |
| `/workflow:remote:homologate` | Run E2E BDD against a live URL | [↗](.claude/commands/workflow/remote/homologate.md) |
| `/workflow:remote:fix-pipeline` | Iterative pipeline repair loop | [↗](.claude/commands/workflow/remote/fix-pipeline.md) |
| `/orchestrator:implement` | Implement multiple work items in parallel | [↗](.claude/commands/orchestrator/implement/SKILL.md) |

Full reference: [README.md](README.md)
