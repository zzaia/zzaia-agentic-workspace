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

Run the init script for your platform and password manager. Secrets live only in the terminal session — never written to disk.

### Ubuntu / WSL — Bitwarden

```bash
chmod +x Init-ubuntu.sh
./Init-ubuntu.sh --session-name <name> [--full-automatic] [--tmux]
```

### Ubuntu / WSL — 1Password

```bash
chmod +x Init-ubuntu-op.sh
./Init-ubuntu-op.sh --vault-name <vault> --session-name <name> [--full-automatic] [--tmux]
```

### Windows — Bitwarden (PowerShell)

> **Requires PowerShell 7.** The built-in Windows PowerShell (v5) is no longer actively developed.
> Install PowerShell 7 first:
>
> ```powershell
> winget install Microsoft.PowerShell
> ```
>
> Then open PowerShell 7:
>
> ```powershell
> pwsh
> ```
>
> Optionally verify the version:
>
> ```powershell
> $PSVersionTable.PSVersion
> ```

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\Init-windows.ps1 -SessionName <name> [-FullAutomatic]
```

| Flag | Script | Description |
|------|--------|-------------|
| `--session-name` / `-SessionName` | all | **Required.** Named session for resume across restarts |
| `--vault-name` | `Init-ubuntu-op.sh` | **Required.** 1Password vault name |
| `--full-automatic` / `-FullAutomatic` | all | Skip permission prompts (`--dangerously-skip-permissions`) |
| `--tmux` / `-Tmux` | Ubuntu/WSL only | Optional. Wrap Claude in a tmux session (attach if exists, create if not) |

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
