# ZZAIA Agentic Workspace — Quick Start

> Get the workspace running in under 5 minutes.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **Docker Desktop or CLI** | Runs the workspace container and MCP sidecars | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) |
| **Bitwarden CLI** (optional) | Secret manager integration for automated setup | [bitwarden.com/help/cli](https://bitwarden.com/help/cli) |

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
| `ADMIN_PASSWORD` | Optional | Sets the sudo password for the `zzaia` user | Any string; leave empty to disable sudo entirely |
| `ANTHROPIC_API_KEY` | Optional | Claude API key — see Step 1 | [console.anthropic.com](https://console.anthropic.com) |
| `CLAUDE_CODE_OAUTH_TOKEN` | Optional | Long-lived OAuth token for Pro/Max — see Step 1 Option A | `claude setup-token` on host |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` | Optional | AWS Bedrock auth — see Step 1 | AWS IAM credentials |
| `ANTHROPIC_BEDROCK_BASE_URL` | Optional | Custom Bedrock endpoint | AWS console |
| `CLAUDE_CODE_USE_VERTEX` / `ANTHROPIC_VERTEX_PROJECT_ID` / `CLOUD_ML_REGION` | Optional | Google Vertex AI auth — see Step 1 | GCP console |
| `CLAUDE_CODE_USE_FOUNDRY` / `AZURE_FOUNDRY_BASE_URL` | Optional | Azure AI Foundry auth — see Step 1 | Azure portal |
| `OPENAI_API_KEY` | Optional | OpenAI API key for Codex CLI | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| `GEMINI_API_KEY` | Optional | Google Gemini API key for Gemini CLI | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | Optional | GitHub PAT for GitHub MCP + Copilot CLI | [GitHub → Settings → Personal Access Tokens](https://github.com/settings/tokens) |
| `ASPIRE_DASHBOARD_PORT` | Optional | Host port for Aspire telemetry dashboard | Default: `18888` |
| `TAVILY_API_KEY` | Optional | Tavily API key | [tavily.com](https://tavily.com) |
| `ADO_MCP_AUTH_TOKEN` | Optional | Azure DevOps Personal Access Token | [Azure DevOps → User Settings → Personal Access Tokens](https://dev.azure.com) |
| `AZURE_DEVOPS_ORGANIZATION` | Optional | Azure DevOps organization name (e.g. `my-org`) | Azure DevOps URL: `dev.azure.com/<org>` |
| `POSTMAN_API_KEY` | Optional | Postman API key | [postman.com → Account Settings → API Keys](https://postman.com) |
| `NEW_RELIC_API_KEY` | Optional | New Relic User API key | [New Relic → API Keys](https://one.newrelic.com/admin-portal/api-keys) |

> MCP integrations are optional — leave any key empty and that sidecar exits cleanly without restarting.

---

## Step 3 — Start the Workspace

### Option A — Automated (Bitwarden)

Pre-configure the following vault items in Bitwarden, then run the installation script:

| Vault Item Name | Environment Variable | Required | Purpose |
|---|---|---|---|
| `workspace-name` | WORKSPACE_NAME | ✅ | Docker Compose project name |
| `ssh-public-key` | SSH_PUBLIC_KEY | ✅ | Your SSH public key for container access |
| `admin-password` | ADMIN_PASSWORD | | Sudo password for `zzaia` user |
| `vscode-port` | VSCODE_PORT | | Host port for VS Code (default: 8080) |
| `ssh-port` | SSH_PORT | | Host port for SSH (default: 2222) |
| `aspire-dashboard-port` | ASPIRE_DASHBOARD_PORT | | Host port for Aspire dashboard (default: 18888) |
| `anthropic-api-key` | ANTHROPIC_API_KEY | | Claude API key |
| `claude-code-oauth-token` | CLAUDE_CODE_OAUTH_TOKEN | | Pro/Max OAuth token |
| `openai-api-key` | OPENAI_API_KEY | | OpenAI API key |
| `gemini-api-key` | GEMINI_API_KEY | | Google Gemini API key |
| `github-pat` | GITHUB_PERSONAL_ACCESS_TOKEN | | GitHub Personal Access Token |
| `tavily` | TAVILY_API_KEY | | Tavily API key |
| `azure-devops-pat` | ADO_MCP_AUTH_TOKEN | | Azure DevOps Personal Access Token |
| `azure-devops-org` | AZURE_DEVOPS_ORGANIZATION | | Azure DevOps organization name |
| `postman` | POSTMAN_API_KEY | | Postman API key |
| `new-relic` | NEW_RELIC_API_KEY | | New Relic API key |
| `docker-registry` | DOCKER_REGISTRY | | Container registry hostname (e.g. `ghcr.io`) |
| `docker-username` | DOCKER_USERNAME | | Registry login username |
| `docker-password` | DOCKER_PASSWORD | | Registry login password or token |

**Ubuntu / WSL:**
```bash
./install/ubuntu.sh
```

**macOS:**
```bash
./install/mac.sh
```

**Windows:**
```powershell
.\install\windows.ps1
```

The scripts fetch all secrets from Bitwarden and launch `docker compose`. Missing optional vault items are skipped without blocking startup.

---

### Option B — Manual

Fill in your values and run the command for your platform. No files are written to disk.

#### Ubuntu / macOS / WSL

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
export OPENAI_API_KEY=""
export GEMINI_API_KEY=""
export GITHUB_PERSONAL_ACCESS_TOKEN=""
export ASPIRE_DASHBOARD_PORT="18888"
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
      OPENAI_API_KEY GEMINI_API_KEY GITHUB_PERSONAL_ACCESS_TOKEN ASPIRE_DASHBOARD_PORT \
      TAVILY_API_KEY ADO_MCP_AUTH_TOKEN AZURE_DEVOPS_ORGANIZATION \
      POSTMAN_API_KEY NEW_RELIC_API_KEY VSCODE_PORT SSH_PORT
```

#### Windows

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
$OPENAI_API_KEY                    = ""
$GEMINI_API_KEY                    = ""
$GITHUB_PERSONAL_ACCESS_TOKEN      = ""
$ASPIRE_DASHBOARD_PORT             = "18888"
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
$env:OPENAI_API_KEY                    = $OPENAI_API_KEY
$env:GEMINI_API_KEY                    = $GEMINI_API_KEY
$env:GITHUB_PERSONAL_ACCESS_TOKEN      = $GITHUB_PERSONAL_ACCESS_TOKEN
$env:ASPIRE_DASHBOARD_PORT             = $ASPIRE_DASHBOARD_PORT
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
'OPENAI_API_KEY','GEMINI_API_KEY','GITHUB_PERSONAL_ACCESS_TOKEN','ASPIRE_DASHBOARD_PORT',
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
| **Aspire Dashboard** | `http://localhost:<ASPIRE_DASHBOARD_PORT>` (default `18888`) |

Claude Code, Gemini, Copilot, and Codex extensions are pre-installed. All MCP tools connect automatically via isolated sidecar containers. The Aspire dashboard starts empty and receives telemetry when an AppHost is running.

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
| Terminal `claude` shows onboarding wizard | Home volume was created before the fix — delete `<WORKSPACE_NAME>-home` volume and restart, or run `claude setup-token` inside the container |
| Extension auth error: `invalid header value` | `CLAUDE_CODE_OAUTH_TOKEN` contains a newline from terminal line-wrap — remove all line breaks from the token and recreate the container |

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
