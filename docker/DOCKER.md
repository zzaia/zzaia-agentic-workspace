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

## Storage — Bind Mounts vs Named Volumes

### Why this matters

The workspace container uses a `/secrets` mount to persist the SSH public key across container restarts. Two approaches exist: bind mounts (host directory) and Docker named volumes.

### Bind mount (old approach — `~/.config/zzaia:/secrets`)

A bind mount maps a **host directory** directly into the container.

```
Host filesystem                  Container
~/.config/zzaia/   ──────────▶  /secrets/
    .env (root:root 600)             .env  ← inaccessible!
```

**Problem on Docker Desktop for Linux:** Docker Desktop runs containers inside a lightweight Linux VM (linuxkit). When a host directory is mounted into this VM and then into the container, file ownership passes through two layers. Host files owned by root (UID 0) appear as an unmapped/inaccessible UID inside the container — even to the container's own root user. This is compounded by `cap_drop: ALL` removing `CAP_DAC_OVERRIDE`, which would normally let root bypass permission checks.

Docker Desktop auto-creates bind mount directories as root when they don't exist, which is how `~/.config/zzaia` ended up root-owned in the first place. The result: the entrypoint cannot read or write the directory, causing a permanent crash loop.

### Named volume (current approach — `${WORKSPACE_NAME}-secrets:/secrets`)

A named Docker volume is managed entirely **inside Docker's storage layer** within the VM — it never passes through the host filesystem.

```
Docker volume store (inside VM)    Container
zzaia-tech-secrets/   ──────────▶  /secrets/
    (Docker-managed)                   .env  ← zzaia owns it ✓
```

**Advantages:**
- No host filesystem ownership issue — Docker creates volumes with proper Linux semantics inside the VM
- The entrypoint's `chown -R zzaia:zzaia /secrets` works correctly on first start
- Volume persists across container deletions — `docker rm` does not delete volumes
- Volume name is `<WORKSPACE_NAME>-secrets`, giving each workspace its own isolated secret store
- No `sudo` required on the host, ever
- Cleaner security boundary — secrets are not browsable from the host filesystem

**Volume lifecycle:**

```bash
# List volumes for a workspace
docker volume ls --filter name=my-org

# Inspect contents
docker run --rm -v my-org-secrets:/s alpine ls -la /s

# Remove (when decommissioning a workspace)
docker volume rm my-org-secrets
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
| Secrets storage | Named Docker volume (`<WORKSPACE_NAME>-secrets`), not host path |
| Host network | Bridge only, workspace ports bound to `127.0.0.1` |
| MCP ports | Internal only — not exposed to host |
| Capabilities | Drop ALL + minimum required (CHOWN, FOWNER, SETGID, SETUID, AUDIT_WRITE) |
| Root login | Disabled |

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
