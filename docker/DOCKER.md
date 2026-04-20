# ZZAIA Container — Docker

Ubuntu container with all workspace tools provisioned via `mise.toml`. Accessible via SSH and browser-based VS Code. MCP servers run as isolated sidecar containers — each receives only its own secret.

---

## Start (once per environment)

See [QUICKSTART.md](../QUICKSTART.md) for full step-by-step instructions. Short version:

```bash
WORKSPACE_NAME="my-org"  SSH_PUBLIC_KEY="ssh-ed25519 AAAA..."  VSCODE_PORT=8080  SSH_PORT=2222
# ... set other optional API keys
docker compose -f docker/docker-compose.yml -p "$WORKSPACE_NAME" --env-file <(...) up -d
```

After the first run, start and stop the workspace from **Docker Desktop** or:

```bash
docker compose -f docker/docker-compose.yml -p <WORKSPACE_NAME> start
docker compose -f docker/docker-compose.yml -p <WORKSPACE_NAME> stop
```

**Rebuild image after changes:**

```bash
docker compose -f docker/docker-compose.yml build
# Then force-recreate:
docker compose -f docker/docker-compose.yml -p <WORKSPACE_NAME> up -d --force-recreate workspace
```

---

## Access

| Method | Address |
|--------|---------|
| VS Code (browser) | `http://localhost:<VSCODE_PORT>` (default `8080`) |
| SSH | `ssh -p <SSH_PORT> zzaia@localhost` (default `2222`) |

The Claude Code extension is pre-installed. Code-server logs:

```bash
docker logs <WORKSPACE_NAME>-workspace-1
docker exec <WORKSPACE_NAME>-workspace-1 cat /tmp/code-server.log
```

---

## Storage — Named Volumes

The workspace uses two named Docker volumes per stack. Named volumes live entirely inside Docker's storage layer — no host filesystem ownership issues, no `sudo` required, no Docker Desktop VM permission pass-through problems.

### Volume layout

| Volume alias | Docker volume name | Mount path | Contents | Lifecycle |
|---|---|---|---|---|
| `workspace-secrets` | `<WORKSPACE_NAME>-secrets` | `/secrets` | SSH public key (persisted once at first start) | Independent — survives home deletion |
| `workspace-home` | `<WORKSPACE_NAME>-home` | `/home/zzaia` | System files, tools, configs, auth tokens, Claude settings | Reset to pick up image updates |
| `workspace-repos` | `<WORKSPACE_NAME>-workspace` | `/home/zzaia/workspace` | Cloned repositories and worktrees | **Independent** — survives home volume deletion |

`workspace-repos` overlays inside `workspace-home` at `/home/zzaia/workspace`. Docker supports named-volume overlay correctly.

### Home volume seeding

On the **first container start with an empty home volume**, Docker copies the image's `/home/zzaia` content into the volume. This means:

- All tools installed in the image (mise, miniforge3, VS Code extensions, conda envs, claude-code CLI) are available immediately on first start.
- Tool installations and configs persist across restarts and container recreation.
- Claude auth tokens (`~/.config/claude/`) persist — `claude auth login` needs to be run only once.

**After image updates:** the volume is NOT automatically updated from the new image. To pick up new tool versions, delete the home volume and recreate:

```bash
docker compose -f docker/docker-compose.yml -p <WORKSPACE_NAME> down
docker volume rm <WORKSPACE_NAME>-home
docker compose -f docker/docker-compose.yml -p <WORKSPACE_NAME> up -d
```

The repos volume is unaffected — your cloned repositories survive.

### Volume lifecycle

```bash
# List volumes for a workspace
docker volume ls --filter name=my-org

# Inspect home volume
docker run --rm -v my-org-home:/h alpine ls -la /h

# Inspect repos volume
docker run --rm -v my-org-workspace:/w alpine ls -la /w

# Reset system only (keeps secrets and repos)
docker volume rm my-org-home

# Full decommission (removes everything)
docker volume rm my-org-secrets my-org-home my-org-workspace
```

---

## MCP Services

Each MCP server runs as an isolated sidecar container on the internal `mcp` Docker network. Ports are not exposed to the host. If a secret is not provided, the sidecar exits cleanly (code 0) and does not restart.

| Service | Port | Secret |
|---------|------|--------|
| mcp-tavily | 3001 | `TAVILY_API_KEY` |
| mcp-azure-devops | 3002 | `ADO_MCP_AUTH_TOKEN`, `AZURE_DEVOPS_ORGANIZATION` |
| mcp-postman | 3003 | `POSTMAN_API_KEY` |
| mcp-newrelic | 3004 | `NEW_RELIC_API_KEY` |

`playwright` and `aspire` run as local stdio servers inside the workspace container (no secrets required).

---

## What's installed

| Category | Tools |
|----------|-------|
| Runtimes | Node.js 22, Python 3.12, .NET 8, Go, Rust, Java |
| CLI tools | Claude Code CLI, Dapr, k6, D2, Mermaid |
| Editor | code-server + Claude Code extension — browser on port 8080 |
| Data science | Miniforge3, conda envs |
| Python packages | pypdf, python-docx, textual, jinja2, graphviz, diagrams |
| .NET tools | Aspire workload, Aspirate |
| System | tmux, PlantUML, tectonic, git, build-essential |

---

## Security

| Control | Value |
|---------|-------|
| Workspace secrets | SSH key only — no API keys in workspace container |
| MCP secrets | Isolated per sidecar container, internal network only |
| Secret handling | Injected in-memory at startup — no cleartext on host disk |
| Host filesystem | No host directory mounts except docker socket |
| Secrets storage | Named Docker volume (`<WORKSPACE_NAME>-home`), not host path |
| Host network | Bridge only, workspace ports bound to `127.0.0.1` |
| MCP ports | Internal only — not exposed to host |
| Capabilities | Drop ALL + minimum required (CHOWN, FOWNER, SETGID, SETUID, AUDIT_WRITE) |
| Root login | Disabled |
| Sudo access | Disabled by default; set `ADMIN_PASSWORD` to enable password-based sudo |

---

## Files

```
docker/
├── Dockerfile          — Image definition
├── entrypoint.sh       — SSH key init + code-server + sshd startup
├── sshd_config         — Port 2222, key-auth only
├── docker-compose.yml  — Workspace + MCP sidecar services
└── DOCKER.md           — This file
```
