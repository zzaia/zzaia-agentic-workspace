# ZZAIA Agentic Workspace — Quick Start

> Get the workspace running in under 5 minutes.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **Docker Desktop or CLI** | Runs the workspace container and MCP sidecars | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) |

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

**Option A — Long-lived token via env var (recommended):**

On your **host machine**, run:

```bash
claude setup-token
```

Copy the printed token and set it as `CLAUDE_CODE_OAUTH_TOKEN` in Step 2. The token is valid for ~1 year and is passed directly to the container — no login step required inside the container.

**Option B — Interactive login (inside the container):**

Start the container first (Step 3), then open a terminal inside VS Code and run:

```bash
claude setup-token
```

The URL is printed to the terminal (no browser opens automatically). Open the URL in a browser tab on your host, complete authentication, then copy the code displayed back into the terminal when prompted. Claude Code stores the session in `~/.claude/.credentials.json` inside the home volume — persists across container restarts.

> Use Option B when you prefer to authenticate interactively after the container is already running, or when you do not want to pass credentials via environment variables.

---

## Step 2 — Gather Your Values

You will need the following values before starting:

| Variable | Required | Description | Where to Get |
|----------|----------|-------------|--------------|
| `WORKSPACE_NAME` | ✅ | Unique name for this workspace instance (used as Docker Compose project name) | Choose any slug, e.g. `my-org` |
| `SSH_PUBLIC_KEY` | ✅ | Your SSH public key (e.g. `ssh-ed25519 AAAA...`) | `cat ~/.ssh/id_ed25519.pub` — generate with `ssh-keygen -t ed25519` |
| `VSCODE_PORT` | ✅ | Host port for VS Code browser access | Default: `8080` |
| `SSH_PORT` | ✅ | Host port for SSH access | Default: `2222` |
| `ADMIN_PASSWORD` | Optional | Sets the sudo password for the `zzaia` user | Any string; leave empty to disable sudo entirely |
| `ANTHROPIC_API_KEY` | Optional | Claude API key — see Step 1 | [console.anthropic.com](https://console.anthropic.com) |
| `CLAUDE_CODE_OAUTH_TOKEN` | Optional | Long-lived OAuth token for Pro/Max — see Step 1 Option A | `claude setup-token` on host |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` | Optional | AWS Bedrock auth — see Step 1 | AWS IAM credentials |
| `ANTHROPIC_BEDROCK_BASE_URL` | Optional | Custom Bedrock endpoint | AWS console |
| `CLAUDE_CODE_USE_VERTEX` / `ANTHROPIC_VERTEX_PROJECT_ID` / `CLOUD_ML_REGION` | Optional | Google Vertex AI auth — see Step 1 | GCP console |
| `CLAUDE_CODE_USE_FOUNDRY` / `AZURE_FOUNDRY_BASE_URL` | Optional | Azure AI Foundry auth — see Step 1 | Azure portal |
| `TAVILY_API_KEY` | Optional | Tavily API key | [tavily.com](https://tavily.com) |
| `ADO_MCP_AUTH_TOKEN` | Optional | Azure DevOps Personal Access Token | [Azure DevOps → User Settings → Personal Access Tokens](https://dev.azure.com) |
| `AZURE_DEVOPS_ORGANIZATION` | Optional | Azure DevOps organization name (e.g. `my-org`) | Azure DevOps URL: `dev.azure.com/<org>` |
| `POSTMAN_API_KEY` | Optional | Postman API key | [postman.com → Account Settings → API Keys](https://postman.com) |
| `NEW_RELIC_API_KEY` | Optional | New Relic User API key | [New Relic → API Keys](https://one.newrelic.com/admin-portal/api-keys) |

> MCP integrations are optional — leave any key empty and that sidecar exits cleanly without restarting.

---

## Step 3 — Start the Workspace

Fill in your values and run the command for your platform. No files are written to disk.

### Ubuntu / macOS / WSL

```bash
export WORKSPACE_NAME="my-org"
export SSH_PUBLIC_KEY=""
export ADMIN_PASSWORD=""
export ANTHROPIC_API_KEY=""
export CLAUDE_CODE_OAUTH_TOKEN=""
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_REGION=""
export ANTHROPIC_BEDROCK_BASE_URL=""
export CLAUDE_CODE_USE_VERTEX=""
export ANTHROPIC_VERTEX_PROJECT_ID=""
export CLOUD_ML_REGION=""
export CLAUDE_CODE_USE_FOUNDRY=""
export AZURE_FOUNDRY_BASE_URL=""
export TAVILY_API_KEY=""
export ADO_MCP_AUTH_TOKEN=""
export AZURE_DEVOPS_ORGANIZATION=""
export POSTMAN_API_KEY=""
export NEW_RELIC_API_KEY=""
export VSCODE_PORT="8080"
export SSH_PORT="2222"

docker compose \
    -f "./docker/docker-compose.yml" \
    -p "$WORKSPACE_NAME" \
    up -d

unset WORKSPACE_NAME SSH_PUBLIC_KEY ADMIN_PASSWORD \
      ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN \
      AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION ANTHROPIC_BEDROCK_BASE_URL \
      CLAUDE_CODE_USE_VERTEX ANTHROPIC_VERTEX_PROJECT_ID CLOUD_ML_REGION \
      CLAUDE_CODE_USE_FOUNDRY AZURE_FOUNDRY_BASE_URL \
      TAVILY_API_KEY ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION \
      POSTMAN_API_KEY NEW_RELIC_API_KEY VSCODE_PORT SSH_PORT
```

### Windows

```powershell
$WORKSPACE_NAME                    = "my-org"
$SSH_PUBLIC_KEY                    = ""
$ADMIN_PASSWORD                    = ""
$ANTHROPIC_API_KEY                 = ""
$CLAUDE_CODE_OAUTH_TOKEN           = ""
$AWS_ACCESS_KEY_ID                 = ""
$AWS_SECRET_ACCESS_KEY             = ""
$AWS_REGION                        = ""
$ANTHROPIC_BEDROCK_BASE_URL        = ""
$CLAUDE_CODE_USE_VERTEX            = ""
$ANTHROPIC_VERTEX_PROJECT_ID       = ""
$CLOUD_ML_REGION                   = ""
$CLAUDE_CODE_USE_FOUNDRY           = ""
$AZURE_FOUNDRY_BASE_URL            = ""
$TAVILY_API_KEY                    = ""
$ADO_MCP_AUTH_TOKEN                = ""
$AZURE_DEVOPS_ORGANIZATION         = ""
$POSTMAN_API_KEY                   = ""
$NEW_RELIC_API_KEY                 = ""
$VSCODE_PORT                       = "8080"
$SSH_PORT                          = "2222"

$env:WORKSPACE_NAME                    = $WORKSPACE_NAME
$env:SSH_PUBLIC_KEY                    = $SSH_PUBLIC_KEY
$env:ADMIN_PASSWORD                    = $ADMIN_PASSWORD
$env:ANTHROPIC_API_KEY                 = $ANTHROPIC_API_KEY
$env:CLAUDE_CODE_OAUTH_TOKEN           = $CLAUDE_CODE_OAUTH_TOKEN
$env:AWS_ACCESS_KEY_ID                 = $AWS_ACCESS_KEY_ID
$env:AWS_SECRET_ACCESS_KEY             = $AWS_SECRET_ACCESS_KEY
$env:AWS_REGION                        = $AWS_REGION
$env:ANTHROPIC_BEDROCK_BASE_URL        = $ANTHROPIC_BEDROCK_BASE_URL
$env:CLAUDE_CODE_USE_VERTEX            = $CLAUDE_CODE_USE_VERTEX
$env:ANTHROPIC_VERTEX_PROJECT_ID       = $ANTHROPIC_VERTEX_PROJECT_ID
$env:CLOUD_ML_REGION                   = $CLOUD_ML_REGION
$env:CLAUDE_CODE_USE_FOUNDRY           = $CLAUDE_CODE_USE_FOUNDRY
$env:AZURE_FOUNDRY_BASE_URL            = $AZURE_FOUNDRY_BASE_URL
$env:TAVILY_API_KEY                    = $TAVILY_API_KEY
$env:ADO_MCP_AUTH_TOKEN                = $ADO_MCP_AUTH_TOKEN
$env:AZURE_DEVOPS_ORGANIZATION         = $AZURE_DEVOPS_ORGANIZATION
$env:POSTMAN_API_KEY                   = $POSTMAN_API_KEY
$env:NEW_RELIC_API_KEY                 = $NEW_RELIC_API_KEY
$env:VSCODE_PORT                       = $VSCODE_PORT
$env:SSH_PORT                          = $SSH_PORT

docker compose `
    -f ".\docker\docker-compose.yml" `
    -p $WORKSPACE_NAME `
    up -d

'WORKSPACE_NAME','SSH_PUBLIC_KEY','ADMIN_PASSWORD',
'ANTHROPIC_API_KEY','CLAUDE_CODE_OAUTH_TOKEN',
'AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AWS_REGION','ANTHROPIC_BEDROCK_BASE_URL',
'CLAUDE_CODE_USE_VERTEX','ANTHROPIC_VERTEX_PROJECT_ID','CLOUD_ML_REGION',
'CLAUDE_CODE_USE_FOUNDRY','AZURE_FOUNDRY_BASE_URL',
'TAVILY_API_KEY','ADO_MCP_AUTH_TOKEN','AZURE_DEVOPS_ORGANIZATION',
'POSTMAN_API_KEY','NEW_RELIC_API_KEY','VSCODE_PORT','SSH_PORT' | ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }
```

After the first run, **start or stop the workspace from Docker Desktop** — no command needed again.

---

## Step 4 — Access the Workspace

| Access | URL / Command |
|--------|--------------|
| **VS Code** (browser) | `http://localhost:<VSCODE_PORT>` (default `8080`) |
| **SSH** | `ssh -p <SSH_PORT> zzaia@localhost` (default `2222`) |

The Claude Code extension is pre-installed. All MCP tools (Tavily, Azure DevOps, Postman, New Relic) connect automatically via isolated sidecar containers.

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
| Container not starting | Run `docker logs <WORKSPACE_NAME>-workspace-1` or `docker logs <WORKSPACE_NAME>-mcp-azure-devops-1` |
| Port already in use | Stop any existing stack via Docker Desktop before re-running |
| SSH key rejected | Verify `SSH_PUBLIC_KEY` starts with `ssh-ed25519`, `ssh-rsa`, or `ecdsa-` |

---

## Running Multiple Workspaces Simultaneously

Each workspace gets its own isolated Docker Compose stack identified by `WORKSPACE_NAME`. Use different ports per stack so they can run at the same time:

```bash
# Workspace 1 — default ports
export WORKSPACE_NAME="org-one"  VSCODE_PORT=8080  SSH_PORT=2222  # ... other vars
docker compose -f "./docker/docker-compose.yml" -p "$WORKSPACE_NAME" up -d

# Workspace 2 — different ports
export WORKSPACE_NAME="org-two"  VSCODE_PORT=8081  SSH_PORT=2223  # ... other vars
docker compose -f "./docker/docker-compose.yml" -p "$WORKSPACE_NAME" up -d
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

export TAVILY_API_KEY="$NEW_VALUE"
docker compose \
    -f "./docker/docker-compose.yml" \
    -p "$WORKSPACE_NAME" \
    up -d --force-recreate mcp-tavily
unset TAVILY_API_KEY
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

> Three volumes exist per workspace, each with an independent lifecycle:
>
> | Volume | Contains | Delete to… |
> |--------|----------|-----------|
> | `<WORKSPACE_NAME>-secrets` | SSH public key | Rotate SSH key |
> | `<WORKSPACE_NAME>-home` | Tools, configs, auth tokens | Reset system / pick up image updates |
> | `<WORKSPACE_NAME>-workspace` | Cloned repos | Wipe all repositories |
>
> ```bash
> # Rotate SSH key only
> docker volume rm <WORKSPACE_NAME>-secrets
>
> # Reset system (keeps secrets and repos)
> docker volume rm <WORKSPACE_NAME>-home
>
> # Full decommission
> docker volume rm <WORKSPACE_NAME>-secrets <WORKSPACE_NAME>-home <WORKSPACE_NAME>-workspace
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
