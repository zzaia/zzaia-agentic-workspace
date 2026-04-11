# ZZAIA Agentic Workspace — Quick Start

> Get the workspace running in Claude Code in under 15 minutes.

---

## Who is this for?

| Profile | Platform |
|---------|----------|
| Windows user | PowerShell (native) |
| Windows user with WSL | Ubuntu terminal inside WSL |
| Linux / macOS user | Ubuntu/bash terminal |

---

## Step 1 — Install Prerequisites

Install **Claude Code** and **Bitwarden CLI** — these are the only hard requirements.

#### Claude Code CLI

Requires Node.js LTS — [nodejs.org](https://nodejs.org)

```bash
npm install -g @anthropic-ai/claude-code
```

#### Bitwarden CLI

```bash
# Ubuntu / WSL
sudo snap install bw

# Windows (PowerShell)
winget install --id Bitwarden.BitwardenCLI
```

---

## Step 2 — Create Bitwarden Items

Create the following items in your **Bitwarden vault** using the **Login** type. Store each secret as the item's **Password** field.

| Bitwarden Item Name | Password Value | Service |
|---------------------|----------------|---------|
| `tavily` | Tavily API key | [tavily.com](https://tavily.com) |
| `azure-devops-pat` | Azure DevOps Personal Access Token | [Azure DevOps](https://dev.azure.com) |
| `azure-devops-org` | Azure DevOps organization name (e.g. `my-org`) | Azure DevOps |
| `postman` | Postman API key | [postman.com](https://postman.com) |
| `new-relic` | New Relic API key | [newrelic.com](https://newrelic.com) |

> Items you don't have credentials for can be skipped — the workspace will warn and continue without them.

---

## Step 3 — Load Secrets and Launch Claude Code

Unlock your Bitwarden vault, export each secret as an environment variable, then launch Claude Code. Secrets live only in the terminal session — never written to disk.

### Option A — Copy-paste commands

#### Ubuntu / WSL

```bash
bw login
export BW_SESSION=$(bw unlock --raw)
export TAVILY_API_KEY=$(bw get password tavily --session "$BW_SESSION")
export ADO_MCP_AUTH_TOKEN=$(bw get password azure-devops-pat --session "$BW_SESSION")
export AZURE_DEVOPS_ORGANIZATION=$(bw get password azure-devops-org --session "$BW_SESSION")
export POSTMAN_API_KEY=$(bw get password postman --session "$BW_SESSION")
export NEW_RELIC_API_KEY=$(bw get password new-relic --session "$BW_SESSION")
bw lock --session "$BW_SESSION"; unset BW_SESSION
claude --enable-auto-mode
```

#### Windows (PowerShell)

```powershell
bw login
$s = bw unlock --raw
$env:TAVILY_API_KEY = bw get password tavily --session $s
$env:ADO_MCP_AUTH_TOKEN = bw get password azure-devops-pat --session $s
$env:AZURE_DEVOPS_ORGANIZATION = bw get password azure-devops-org --session $s
$env:POSTMAN_API_KEY = bw get password postman --session $s
$env:NEW_RELIC_API_KEY = bw get password new-relic --session $s
bw lock --session $s; Remove-Variable s
claude --enable-auto-mode
```

> Skip any `bw get` line for services you don't use — Claude will start without that MCP.

### Option B — Init script

```bash
# Ubuntu / WSL
bash Init-ubuntu.sh

# Windows (PowerShell)
.\Init-windows.ps1
```

---

## Step 4 — Add the Plugin Marketplace

Inside Claude Code, run the following commands to add the ZZAIA plugin:

```
/plugins
```

Navigate to **Marketplace → Add Marketplaces** and add:

```
https://github.com/zzaia/zzaia-agentic-workspace.git
```

Then install the workspace plugin:

```
/plugin install zzaia-workspace@zzaia
/reload-plugins
```

---

## Step 5 — Verify Setup

Check that MCP tools and commands loaded correctly:

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

This creates the worktree structure under `./workspace/your-repo-name.worktrees/`.

### Read a work item

```
/behavior:devops:work-item --action read --id 12345 --portal azure --project YourProject
```

### Implement a feature end-to-end

```
/workflow:remote:implement --work-item 1605 --portal azure --project my-project --repo game-service --target-branch develop --working-branch feature/implement-something --description "Additional context"
```

Claude will implement the feature, create a Pull Request, and wait for your review.

### Review and address PR comments

After reviewing the PR in the portal, post your comments there and then respond to Claude's prompt — it will update the branch and PR automatically.

### Apply targeted changes

At any time you can apply targeted changes to any worktree repository inside the workspace.

```
/behavior:development:develop --repo repo-name --branch branch-name --description "What needs to change" @path/to/file
```

### Commit and push manually

It is advised for a manual check in git changes in case of a target implementation, but in the need for more automation the workspace can handle the git operations.

```
/behavior:development:git --action commit-push --repo repo-name --branch branch-name --message commit-message
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| MCP shows disconnected | Verify the env var was loaded: `echo $TAVILY_API_KEY` in the same terminal |
| Commands start with `//` | Run `/reload-plugins` inside Claude Code |
| `bw: command not found` | Re-run the init script or install manually: `sudo snap install bw` |
| PowerShell script blocked | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Bitwarden item not found | Verify item name matches exactly (e.g. `tavily`) and item type is Login |

---

## Available Commands Reference

| Command | Purpose |
|---------|---------|
| `/behavior:workspace:repo` | Clone repo or create branch worktree |
| `/behavior:devops:work-item` | Read or manage work items |
| `/behavior:devops:pull-request` | Manage pull requests |
| `/workflow:remote:implement` | Full implementation from work item to PR |
| `/workflow:remote:architect` | Generate BDD, Epic, and work items from a spec |
| `/workflow:remote:homologate` | Run E2E BDD against a live URL |
| `/behavior:development:develop` | Apply targeted changes to a branch |
| `/behavior:development:git` | Git commit and push |
| `/behavior:devops:pipeline` | Run or debug CI/CD pipelines |

Full command reference: [README.md](README.md)
