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

## Step 1 — Platform Prerequisites

### Windows (PowerShell)

1. Open **PowerShell as Administrator** and run:
   ```powershell
   winget install --id OpenJS.NodeJS.LTS --accept-source-agreements
   npm install -g @anthropic-ai/claude-code
   ```

2. Verify Claude Code is working:
   ```powershell
   claude --version
   ```

### Ubuntu / WSL

1. Open a terminal and run:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
   sudo apt-get install -y nodejs
   npm install -g @anthropic-ai/claude-code
   ```

2. Verify:
   ```bash
   claude --version
   ```

---

## Step 2 — Create Bitwarden Items

Create the following items in your **Bitwarden vault** using the **Login** type. Store each secret as the item's **Password** field.

| Bitwarden Item Name | Password Value | Service |
|---------------------|----------------|---------|
| `zzaia-tavily` | Tavily API key | [tavily.com](https://tavily.com) |
| `zzaia-azure-devops-pat` | Azure DevOps Personal Access Token | [Azure DevOps](https://dev.azure.com) |
| `zzaia-azure-devops-org` | Azure DevOps organization name (e.g. `my-org`) | Azure DevOps |
| `zzaia-postman` | Postman API key | [postman.com](https://postman.com) |
| `zzaia-new-relic` | New Relic API key | [newrelic.com](https://newrelic.com) |

> Items you don't have credentials for can be skipped — the workspace will warn and continue without them.

---

## Step 3 — Run the Init Script

Download and run the init script for your platform. It installs the Bitwarden CLI if missing, unlocks your vault, injects secrets as environment variables, and launches Claude Code in auto mode.

### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/zzaia/zzaia-agentic-workspace/main/Init-windows.ps1" -OutFile "Init-windows.ps1"
.\Init-windows.ps1
```

> If PowerShell blocks the script, run: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

### Ubuntu / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/zzaia/zzaia-agentic-workspace/main/Init-ubuntu.sh -o Init-ubuntu.sh
bash Init-ubuntu.sh
```

When prompted, enter your Bitwarden master password to unlock the vault. Secrets are loaded into the terminal session only — never written to disk.

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

> If `azure-devops` MCP shows an error, see the note below.

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

## Note: Azure DevOps MCP without 1Password

The default `.mcp.json` wraps the Azure DevOps MCP with the `op run` command from 1Password CLI.
If you are using Bitwarden instead, update the `azure-devops` entry in `.mcp.json`:

**Before:**
```json
"command": "op",
"args": ["run", "--", "sh", "-c", "npx @azure-devops/mcp@next \"$AZURE_DEVOPS_ORGANIZATION\" -a envvar"]
```

**After:**
```json
"command": "sh",
"args": ["-c", "npx @azure-devops/mcp@next \"$AZURE_DEVOPS_ORGANIZATION\" -a envvar"]
```

Then restart Claude Code.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| MCP shows disconnected | Verify the env var was loaded: `echo $TAVILY_API_KEY` in the same terminal |
| Commands start with `//` | Run `/reload-plugins` inside Claude Code |
| `bw: command not found` | Re-run the init script or install manually: `sudo snap install bw` |
| PowerShell script blocked | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Bitwarden item not found | Verify item name matches exactly (e.g. `zzaia-tavily`) and item type is Login |

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
