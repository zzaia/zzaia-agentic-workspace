# ZZAIA Agentic Workspace — Quick Start

> Get the workspace running in under 15 minutes.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **Docker Desktop** | Runs the workspace container and MCP sidecars | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) |
| **Bitwarden CLI** | Fetches secrets once at install time | See below |

#### Bitwarden CLI

```bash
# Ubuntu / WSL
sudo snap install bw && sudo snap install jq

# macOS
brew install bitwarden-cli jq

# Windows (PowerShell 7)
winget install --id Bitwarden.BitwardenCLI
```

---

## Step 1 — Create Bitwarden Items

Create the following items in your **Bitwarden vault** using the **Login** type. Store each value as the item **Password** field.

| Bitwarden Item Name | Password Value | Service |
|---------------------|----------------|---------|
| `ssh-public-key` | Your SSH public key (e.g. `ssh-ed25519 AAAA...`) | Local SSH key |
| `tavily` | Tavily API key | [tavily.com](https://tavily.com) |
| `azure-devops-pat` | Azure DevOps Personal Access Token | [Azure DevOps](https://dev.azure.com) |
| `azure-devops-org` | Azure DevOps organization name (e.g. `my-org`) | Azure DevOps |
| `postman` | Postman API key | [postman.com](https://postman.com) |
| `new-relic` | New Relic API key | [newrelic.com](https://newrelic.com) |

> Items you don't have credentials for can be skipped — the workspace will warn and continue without them.

> Generate an SSH key if needed: `ssh-keygen -t ed25519 -f ~/.ssh/zzaia_key -N ""`

---

## Step 2 — Install & Start (once per environment)

Run the install script for your platform. It fetches all secrets from Bitwarden, starts the Docker Compose stack named after your Azure DevOps organization, then discards all secrets — **no .env file is left on disk**.

### Ubuntu / WSL

```bash
chmod +x install-compose.sh
./install-compose.sh
```

### macOS

```bash
chmod +x install-compose-mac.sh
./install-compose-mac.sh
```

### Windows (PowerShell 7)

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\install-compose.ps1
```

After the first run, **start or stop the workspace from Docker Desktop** — no script needed again. To recreate containers (e.g. after a secret rotation), re-run the install script.

---

## Step 3 — Access the Workspace

| Access | URL / Command |
|--------|--------------|
| **VS Code** (browser) | `http://localhost:8080` |
| **SSH** | `ssh -p 2222 zzaia@localhost` |

The Claude Code extension is pre-installed in VS Code. All MCP tools (Tavily, Azure DevOps, Postman, New Relic) connect automatically via isolated sidecar containers.

---

## Step 4 — Add the Plugin Marketplace

Inside Claude Code, run:

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
| `bw: command not found` | Install Bitwarden CLI — see Prerequisites |
| `jq: command not found` | `sudo apt-get install jq` or `brew install jq` |
| PowerShell script blocked | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Bitwarden item not found | Verify item name matches exactly (e.g. `tavily`) and type is Login |
| Container not starting | Check `docker logs <org>-zzaia-workspace-1` |

---

## Secret Rotation

To rotate a single MCP secret:

1. Update the item in Bitwarden
2. Re-run the install script — it recreates only the affected container:

```bash
# Or target a single service after updating docker/.env manually
docker compose -f docker/docker-compose.yml -p <org> up -d --force-recreate mcp-tavily
```

---

## Alternative: Local CLI Mode

If you prefer running Claude Code directly on your machine (without Docker), use the Init scripts. Secrets are loaded from Bitwarden into the terminal session only — never written to disk.

### Ubuntu / WSL

```bash
chmod +x Init-ubuntu.sh
./Init-ubuntu.sh --session-name <name> [--full-automatic] [--tmux]
```

### Windows (PowerShell 7)

```powershell
.\Init-windows.ps1 -SessionName <name> [-FullAutomatic]
```

| Flag | Description |
|------|-------------|
| `--session-name` / `-SessionName` | **Required.** Named session for resume across restarts |
| `--full-automatic` / `-FullAutomatic` | Skip permission prompts |
| `--tmux` | Ubuntu/WSL only. Wrap in a tmux session |

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
