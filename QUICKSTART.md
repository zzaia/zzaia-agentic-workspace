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

### Windows (PowerShell)

Download and run the installer script:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/zzaia/zzaia-agentic-workspace/main/Install-windows.ps1" -OutFile "Install-windows.ps1"
.\Install-windows.ps1
```

> If PowerShell blocks the script, run first: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

Installs: `Git`, `Node.js LTS`, `Claude Code CLI`, `Bitwarden CLI`, `VS Code`, `Docker Desktop`

### Ubuntu / WSL

Download and run the installer script:

```bash
curl -fsSL https://raw.githubusercontent.com/zzaia/zzaia-agentic-workspace/main/Install-ubuntu.sh -o Install-ubuntu.sh
bash Install-ubuntu.sh
```

Installs: `Git`, `Node.js LTS`, `Claude Code CLI`, `Bitwarden CLI`, `VS Code`, `Docker`, `.NET SDK`

After installation, restart your terminal.

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

## Step 3 — Run the Init Script

Download and run the init script for your platform. It unlocks your Bitwarden vault, injects secrets as environment variables, and launches Claude Code in auto mode.

### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/zzaia/zzaia-agentic-workspace/main/Init-windows.ps1" -OutFile "Init-windows.ps1"
.\Init-windows.ps1
```

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
