# ZZAIA Container — Docker

Ubuntu container with all workspace tools provisioned via `mise.toml`. Accessible via SSH and browser-based VS Code. MCP servers run as isolated sidecar containers — each receives only its own secret.

---

## Install & Start (once per environment)

Run the install script for your platform from the repository root. It fetches all secrets from Bitwarden, pipes them directly into docker compose, and leaves nothing on disk.

```bash
# Ubuntu / Linux / WSL
./install-compose.sh

# macOS
./install-compose-mac.sh

# Windows (PowerShell 7)
.\install-compose.ps1
```

After the first run, start and stop the workspace from **Docker Desktop** or:

```bash
docker compose -f docker/docker-compose.yml start
docker compose -f docker/docker-compose.yml stop
```

**Rebuild image after changes:**

```bash
docker compose -f docker/docker-compose.yml build --no-cache
# Then re-run the install script to recreate containers
```

**Rotate a secret (single service):**

```bash
# Re-run install script to recreate all containers with fresh secrets, or target one:
docker compose -f docker/docker-compose.yml up -d --force-recreate mcp-tavily
```

---

## Access

| Method | Address |
|--------|---------|
| VS Code (browser) | `http://localhost:8080` |
| SSH | `ssh -p 2222 zzaia@localhost` |

The Claude Code extension is pre-installed. Code-server logs:

```bash
docker exec zzaia-workspace cat /tmp/code-server.log
```

---

## Browser authentication (OAuth flows)

The container is headless — tools that open a browser print the URL to the terminal instead. Copy-paste it into your local browser.

---

## What's installed

| Category | Tools |
|----------|-------|
| Runtimes | Node.js LTS, Python 3.12, .NET 8 |
| CLI tools | Claude Code CLI, Dapr, k6, D2, Mermaid |
| Editor | code-server + Claude Code extension — browser on port 8080 |
| Data science | Miniforge3, conda envs (`venv-analytics`, `venv-development`) |
| Python packages | pypdf, python-docx, textual, jinja2, graphviz, diagrams |
| .NET tools | Aspire workload, Aspirate |
| System | tmux, PlantUML, tectonic, git, build-essential |

---

## MCP Services

Each MCP server runs as an isolated sidecar container on the internal `mcp` Docker network. Ports are not exposed to the host.

| Service | Port | Secret |
|---------|------|--------|
| mcp-tavily | 3001 | `TAVILY_API_KEY` |
| mcp-azure-devops | 3002 | `ADO_MCP_AUTH_TOKEN`, `AZURE_DEVOPS_ORGANIZATION` |
| mcp-postman | 3003 | `POSTMAN_API_KEY` |
| mcp-newrelic | 3004 | `NEW_RELIC_API_KEY` |

`playwright` and `aspire` run as local stdio servers inside the workspace container (no secrets required).

---

## Container logs

```bash
docker logs zzaia-workspace                            # sshd logs
docker exec zzaia-workspace cat /tmp/code-server.log   # code-server logs
docker logs mcp-tavily                                 # MCP sidecar logs
```

---

## Security

| Control | Value |
|---------|-------|
| Workspace secrets | SSH key only — no API keys in workspace container |
| MCP secrets | Isolated per sidecar container, internal network only |
| Secret handling | Piped in-memory at install time — no .env file on disk |
| Host filesystem | No mounts except docker socket and secrets volume |
| Host network | Bridge only, workspace ports bound to 127.0.0.1 |
| MCP ports | Internal only — not exposed to host |
| Capabilities | Drop ALL + sshd minimum |
| Root login | Disabled |
| Auth | SSH key only |

---

## Files

```
docker/
├── Dockerfile          — Image definition
├── .mcp.json           — MCP HTTP sidecar config (overrides root .mcp.json in image)
├── entrypoint.sh       — SSH key init + code-server + sshd startup
├── sshd_config         — Port 2222, key-auth only
└── docker-compose.yml  — Workspace + MCP sidecar services
```
