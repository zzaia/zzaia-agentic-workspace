# ZZAIA Container — Docker

Ubuntu 24.04 all-in-one container (`workspace-server`) with tools provisioned via modular shell scripts (`build-install.sh` + `runtime-install.sh`). Runs SSH daemon by default; optionally runs browser VS Code and Dev Containers on separate container services. MCP servers run as isolated sidecar containers — each receives only its own secret.

---

## Prerequisites

The workspace requires the following host software:

- **Docker Desktop** — Container runtime and compose orchestration ([docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop))
- **Enhanced Container Isolation (ECI)** *(optional)* — Enables unprivileged Docker-in-Docker sandboxing. Enable via Docker Desktop > Settings > General > "Use Enhanced Container Isolation".

**GPU acceleration (optional, NVIDIA only):**

> Only NVIDIA GPUs are supported. AMD and Apple Silicon are not supported. GPU passthrough requires native Docker Engine — Docker Desktop's VM isolation prevents CDI device injection.

- **NVIDIA drivers** — Must be installed on the host (`nvidia-smi` must work)
- **NVIDIA Container Toolkit** — `nvidia-container-toolkit` package; see [GPU Acceleration](#gpu-acceleration-nvidia-only) section
- **Native Docker Engine** — Not Docker Desktop; install via `apt-get install docker-ce` on Ubuntu

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
docker compose -f docker/docker-compose.yml -p <WORKSPACE_NAME> up -d --force-recreate workspace-server
```

---

## Access

| Method | Address |
|--------|---------|
| VS Code (browser) | `http://localhost:<VSCODE_PORT>` (default `8080`) |
| SSH | `ssh -p <SSH_PORT> zzaia@localhost` (default `2222`) |

The Claude Code extension is pre-installed. Code-server logs (if vscode profile enabled):

```bash
docker logs <WORKSPACE_NAME>-vscode-server-1
docker exec <WORKSPACE_NAME>-vscode-server-1 cat /tmp/code-server.log
```

---

## Storage — Named Volumes

The workspace uses multiple named Docker volumes per stack. Named volumes live entirely inside Docker's storage layer — no host filesystem ownership issues, no `sudo` required, no Docker Desktop VM permission pass-through problems.

### Volume layout

| Volume alias | Docker volume name | Mount path | Contents | Lifecycle |
|---|---|---|---|---|
| `workspace-secrets` | `<WORKSPACE_NAME>-secrets` | `/secrets` (all servers) | SSH public key, persisted env | Independent |
| `workspace-home` | `<WORKSPACE_NAME>-home` | `/home/user` (workspace-server, vscode-server, containers-dev-server) | Home directory with user configs, credentials, workspace repos | Shared across all servers |
| `workspace-tools` | `<WORKSPACE_NAME>-tools` | `/opt/tools` (workspace-server rw, vscode-server, containers-dev-server, and proxy-headroom :ro) | Runtime tools: Node.js, .NET, Python, CLIs, ML packages (when GPU_ENABLED=true) | Delete to force tool re-install |

### Home volume seeding

On the **first start with an empty home volume**, Docker copies the image's `/home/user` content into the volume. This means:

- Home configs, SSH configs, Claude auth tokens, and workspace seeds are copied once on first start
- `workspace-server` owns and manages the shared `workspace-home` volume — it starts first and runs initialization
- `vscode-server` and `containers-dev-server` depend on `workspace-server: condition: service_healthy` and mount the same shared home
- Home contents persist across restarts and container recreation

### Tools volume installation

Tools install to `/opt/tools` in the separate `workspace-tools` volume:

- `workspace-server` entrypoint runs `runtime-install.sh` which installs tools to `/opt/tools` (INSTALL_PREFIX=/opt/tools, HOME=/home/user)
- `workspace-tools` volume is read-write for `workspace-server`, read-only (`:ro`) for `vscode-server` and `containers-dev-server`
- Tools persist across restarts; delete the volume to force re-installation with new versions from `versions.env`

**After image updates:** To pick up new tool versions, delete both the home and tools volumes:

```bash
docker compose -f docker/docker-compose.yml -p <WORKSPACE_NAME> down
docker volume rm <WORKSPACE_NAME>-home <WORKSPACE_NAME>-tools
docker compose -f docker/docker-compose.yml -p <WORKSPACE_NAME> up -d
```

All server configs, credentials, and tools will be re-installed fresh on the next start.

### Volume lifecycle

```bash
# List volumes for a workspace
docker volume ls --filter name=my-org

# Inspect home volume
docker run --rm -v my-org-home:/h alpine ls -la /h

# Inspect tools volume
docker run --rm -v my-org-tools:/t alpine ls -la /t

# Reset home (user configs, credentials, workspace repos)
docker volume rm my-org-home

# Reset tools (forces tool re-install on next workspace-server start)
docker volume rm my-org-tools

# Full decommission
docker volume rm my-org-secrets my-org-home my-org-tools
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
| Runtimes | Node.js 24, Python 3.12, .NET 10, Go, Rust, Java |
| CLI tools | Claude Code CLI, Dapr, k6, D2, Mermaid, Azure CLI |
| Editor | code-server + Claude Code extension — browser on port 8080 (vscode profile) |
| Data science | Miniforge3, conda envs |
| Python packages | pypdf, python-docx, textual, jinja2, graphviz, diagrams, azure-cli |
| ML packages *(GPU_ENABLED=true)* | PyTorch, headroom-ai[ml], Jupyter, ipykernel, NumPy, Pandas, scikit-learn, Matplotlib |
| .NET tools | Aspire workload, Aspirate |
| System | tmux, PlantUML, tectonic, git, build-essential |

---

## GPU Acceleration (NVIDIA only)

**Only NVIDIA GPUs are supported.** AMD GPUs and Apple Silicon are not supported.

**Docker Desktop is not supported for GPU passthrough.** Docker Desktop runs containers inside a VM, which blocks CDI device injection. Use native Docker Engine (`apt-get install docker-ce`).

### Host requirements

1. NVIDIA drivers installed (`nvidia-smi` must succeed)
2. NVIDIA Container Toolkit:

```bash
# Install toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit

# Generate CDI spec
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

# Configure Docker runtime
[ -s /etc/docker/daemon.json ] || echo '{}' | sudo tee /etc/docker/daemon.json
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Enabling GPU in the workspace

Set `GPU_ENABLED=true` in your Bitwarden vault (item: `gpu-enabled`) or pass it directly:

```bash
GPU_ENABLED=true docker compose -f docker/docker-compose.yml -p "$WORKSPACE_NAME" up -d
```

With `GPU_ENABLED=true`:
- `workspace-server` installs ML packages (PyTorch, headroom-ai[ml], Jupyter) into the `venv-analytics` conda env on first start
- `proxy-headroom` activates that env and runs headroom with Kompress model (SLM context compression)
- ML packages persist in the `workspace-tools` volume — deleted the volume forces re-install

---

## Security

| Control | Value |
|---------|-------|
| Docker sandbox | DinD via `runc` runtime; enable Docker Desktop ECI for unprivileged isolation (optional) |
| Workspace secrets | SSH key only — no API keys in workspace container |
| MCP secrets | Isolated per sidecar container, internal network only |
| Secret handling | Injected in-memory at startup — no cleartext on host disk |
| Secrets storage | Named Docker volume (`<WORKSPACE_NAME>-secrets`), not host path |
| Host network | Bridge only, workspace ports bound to `127.0.0.1` |
| MCP ports | Internal only — not exposed to host |
| Capabilities | Drop ALL + minimum required (CHOWN, FOWNER, SETGID, SETUID, AUDIT_WRITE) |
| Root login | Disabled |
| Sudo access | Disabled by default; set `ADMIN_PASSWORD` to enable password-based sudo |

---

## Files

```
docker/
├── Dockerfile          — Image definition (Ubuntu 24.04)
├── entrypoint.sh       — workspace-server entrypoint: setup-user → runtime-install → setup-credentials → sshd
├── sshd_config         — Port 2222, key-auth only
├── docker-compose.yml  — workspace-server + vscode-server + containers-dev-server + MCP sidecars
└── DOCKER.md           — This file
```
