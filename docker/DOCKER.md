# ZZAIA Container — Docker

Ubuntu container with all workspace tools provisioned via `mise.toml`. Accessible via SSH and browser-based VS Code. MCP servers run as isolated sidecar containers — each receives only its own secret.

---

## Prerequisites

- Docker
- An SSH key pair — generate one if needed:
  ```bash
  ssh-keygen -t ed25519 -f zzaia_key -N ""
  ```

---

## Secrets

Create `docker/.env` with your secrets (auto-loaded by docker compose, gitignored):

```bash
SSH_PUBLIC_KEY=<your public key>
TAVILY_API_KEY=...
ADO_MCP_AUTH_TOKEN=...
AZURE_DEVOPS_ORGANIZATION=...
POSTMAN_API_KEY=...
NEW_RELIC_API_KEY=...
```

Only `SSH_PUBLIC_KEY` is available inside the workspace container. Each MCP service receives only its own variable.

---

## Run

```bash
docker compose -f docker/docker-compose.yml up -d
```

**Rebuild after changes:**

```bash
docker compose -f docker/docker-compose.yml build --no-cache
```

**Reset SSH key:**

```bash
rm ~/.config/zzaia/.env
# Update SSH_PUBLIC_KEY in docker/.env, then restart
docker compose -f docker/docker-compose.yml restart zzaia
```

---

## VS Code (code-server)

`code-server` starts automatically at container startup. Open in browser:

```
http://localhost:8080
```

The Claude Code extension is pre-installed. Logs:

```bash
docker exec zzaia-workspace cat /tmp/code-server.log
```

---

## SSH

```bash
ssh -p 2222 zzaia@localhost
```

---

## Browser authentication (OAuth flows)

The container is headless — tools that open a browser will instead print the URL to the terminal. Copy-paste it into your local browser.

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
docker logs zzaia-workspace          # sshd logs
docker exec zzaia-workspace cat /tmp/code-server.log  # code-server logs
docker logs mcp-tavily               # MCP sidecar logs
```

---

## Security

| Control | Value |
|---------|-------|
| Workspace secrets | SSH key only — no API keys in workspace container |
| MCP secrets | Isolated per sidecar container, internal network only |
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
├── entrypoint.sh       — SSH key init + code-server + sshd startup
├── sshd_config         — Port 2222, key-auth only
├── docker-compose.yml  — Workspace + MCP sidecar services
└── .env                — Local secrets (gitignored, create manually)
```
