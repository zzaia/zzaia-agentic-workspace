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
./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..."
# Prompts for BWS_ACCESS_TOKEN (optional — press Enter to configure secrets via Vault UI after startup)

# With observability enabled:
./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..." --observability --signoz-port 3301
# SigNoz UI admin account and API token are auto-provisioned at deploy time
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
| `workspace-secrets` | `<WORKSPACE_NAME>-secrets` | `/secrets` (all servers) | SSH public key | Independent |
| `workspace-home` | `<WORKSPACE_NAME>-home` | `/home/user` (workspace-server, vscode-sidecar, containers-dev-sidecar, jupyter-sidecar, tunnel-sidecar) | Home directory with user configs, credentials, workspace repos | Shared across all servers |
| `workspace-tools` | `<WORKSPACE_NAME>-tools` | `/opt/tools` (workspace-server rw, vscode-sidecar, containers-dev-sidecar, tunnel-sidecar :ro, jupyter-sidecar rw) | Runtime tools: Node.js, .NET, Python, CLIs, miniforge3, venv-development, venv-analytics (when GPU_ENABLED=true) | Delete to force tool re-install |
| `ml-tools` | `<WORKSPACE_NAME>-ml-tools` | `/opt/ml-tools` (ml-server rw) | ML-server miniforge3, venv-system with headroom-ai, fastapi, uvicorn | Delete to force ml-server re-install |
| `vault-data` | `<WORKSPACE_NAME>-vault-data` | `/vault/data` (vault-server) | HashiCorp Vault KV v2 (file backend, AES-256-GCM encryption at rest); unseal keys at `/vault/data/.init` | Persists across restarts |

### Home volume seeding

On the **first start with an empty home volume**, Docker copies the image's `/home/user` content into the volume. This means:

- Home configs, SSH configs, Claude auth tokens, and workspace seeds are copied once on first start
- `workspace-server` owns and manages the shared `workspace-home` volume — it starts first and runs initialization
- `vscode-sidecar`, `containers-dev-sidecar`, `jupyter-sidecar`, and `tunnel-sidecar` depend on `workspace-server: condition: service_healthy` and mount the same shared home
- Home contents persist across restarts and container recreation

### Tools volume installation

Tools install to `/opt/tools` in the separate `workspace-tools` volume:

- `workspace-server` entrypoint runs `runtime-install.sh` which installs tools to `/opt/tools` (INSTALL_PREFIX=/opt/tools, HOME=/home/user)
- `workspace-tools` volume is read-write for `workspace-server`, read-only (`:ro`) for `vscode-server` and `containers-dev-server`
- Tools persist across restarts; delete the volume to force re-installation with new versions from `versions.env`

### ML-server volume installation

ML-server runtime installs to `/opt/ml-tools` in the separate `ml-tools` volume:

- `ml-server` entrypoint bootstraps miniforge3 and venv-system conda env with headroom-ai, fastapi, uvicorn
- `ml-tools` volume is read-write for `ml-server` only — owned by headroom user (uid=1001), no shared conda envs
- Workspace home (`workspace-home`) is mounted read-only for headroom code-graph/memory access
- `ml-server` does NOT mount `workspace-tools` — independent sealed environment

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

# Reset ml-tools (forces ml-server miniforge re-download and package re-install)
docker volume rm my-org-ml-tools

# Full decommission
docker volume rm my-org-secrets my-org-home my-org-tools my-org-ml-tools
```

---

## Secrets and Vault

**vault-server** is the central secret store:

| Service | Port | Role |
|---------|------|------|
| `vault-server` | 8200 | Production Vault (file backend, AES-256-GCM encryption at rest) — bootstrapped from Bitwarden at startup; Vault UI at `localhost:8200/ui` |
| `git-sidecar` | 2223 (SSH) | SSH git proxy — workspace agents clone/push private repos via this relay; credentials never leave the container |

**Secret distribution pattern**:
- At deploy time: deploy script passes `BWS_ACCESS_TOKEN` to vault-server container only
- vault-server fetches secrets from Bitwarden using bws CLI at startup and stores them in Vault KV v2 (encrypted at rest)
- vault-server generates an ed25519 SSH keypair and stores it at `secret/workspace` (`GIT_SIDECAR_AGENT_KEY` + `GIT_SIDECAR_AGENT_PUBKEY`)
- vault-server enables AppRole auth and binds `git-sidecar-policy` (read `secret/workspace`, `secret/mcp/github`, `secret/mcp/azure-devops`)
- All other containers fetch only their needed secrets from Vault at runtime via `VAULT_ADDR=http://vault-server:8200`
- After bootstrap, manage secrets via Vault UI at `http://localhost:${VAULT_PORT}/ui`

**git-sidecar — SSH Git Proxy**:

The `git-sidecar` service is an SSH relay that lets workspace agents (`git clone`, `git push`) access private GitHub and Azure DevOps repositories without the agent ever seeing a PAT.

| Item | Details |
|------|---------|
| Port | `2223` (SSH, internal Docker network only) |
| Auth | SSH key generated by vault-server, stored at `secret/workspace.GIT_SIDECAR_AGENT_PUBKEY`; installed as the sole `authorized_keys` entry |
| ForceCommand | Every SSH session is restricted to `git-proxy-cmd` — no shell, no port forwarding |
| Token file | `GITHUB_PERSONAL_ACCESS_TOKEN` + `ADO_MCP_AUTH_TOKEN` written to `/home/git/.git-proxy/tokens` (chmod 600) at startup; never exposed as env vars |

**URL routing** via `git-proxy-cmd`:

| Path prefix | Upstream |
|-------------|---------|
| `github/<owner>/<repo>` | `https://x-access-token:<PAT>@github.com/<owner>/<repo>.git` |
| `ado/<org>/<project>/<repo>` | `https://anything:<TOKEN>@dev.azure.com/<org>/<project>/_git/<repo>` |

Usage from inside `workspace-server`:
```bash
# Clone a private GitHub repo
git clone ssh://git@git-sidecar:2223/github/my-org/my-repo

# Clone a private Azure DevOps repo
git clone ssh://git@git-sidecar:2223/ado/my-org/my-project/my-repo
```

If `GIT_SIDECAR_AGENT_PUBKEY`, `GITHUB_PERSONAL_ACCESS_TOKEN`, or `ADO_MCP_AUTH_TOKEN` are missing from Vault, git-sidecar enters idle mode (exits cleanly on SIGTERM) and does not start the SSH daemon.

---

## Observability — SigNoz Stack

When deployed with `--observability`, the workspace includes a full observability stack: SigNoz (logs, metrics, traces UI), Fluent Bit (log collection), OTel Collector (metric and trace aggregation), and cAdvisor (container metrics).

### SigNoz Auto-Provisioning

At deploy time, if `--observability` is enabled:

1. **Health check:** `signoz-server` entrypoint waits for SigNoz to be healthy (`/api/v1/health`)
2. **Admin account:** Registers `admin@<WORKSPACE_NAME>.local` with the password from `SIGNOZ_ADMIN_PASSWORD` (generated once, preserved across re-deployments in `.env`)
3. **Service account:** Creates a `mcp-signoz` service account with viewer role (assigned via SpiceDB tuple in SQLite)
4. **API key:** Generates an API key and writes it to the `signoz-mcp-creds` shared volume at `/signoz-data/mcp-api-key`
5. **mcp-signoz reads key:** The `mcp-signoz` container reads the key from the volume and exports it as `SIGNOZ_TOKEN` for the `signoz-mcp-server` process

Re-running is idempotent — provisioning is skipped if `/signoz-data/mcp-api-key` already exists.

### Fluent Bit Log Isolation

Fluent Bit reads all Docker container logs from `/var/lib/docker/containers/*/` but filters by workspace using docker metadata enrichment and a grep filter:

1. **docker_metadata filter:** Enriches each log record with `container_name` from the Docker socket
2. **grep filter:** Keeps only logs where `container_name` matches `/${WORKSPACE_NAME}-*` (Docker Compose prefixes container names with the project name)
3. **DB persistence:** Fluent Bit state is stored in `/var/lib/fluent-bit/state/` on a named Docker volume, so logs are never re-read on restart

This ensures each workspace's Fluent Bit instance only forwards logs from its own containers to SigNoz, even if multiple compose stacks run on the same Docker host.

### Port Configuration

Use the `--signoz-port` and `--mcp-signoz-port` deploy flags to customize observability ports:

```bash
./deploy/ubuntu.sh --workspace-name my-org --ssh-public-key "ssh-ed25519 AAAA..." \
  --observability --signoz-port 3400 --mcp-signoz-port 3410
# SigNoz UI:  http://localhost:3400
# SigNoz MCP: http://localhost:3410/mcp
```

| Flag | Default | Description |
|------|---------|-------------|
| `--signoz-port` | `3301` | SigNoz web UI |
| `--mcp-signoz-port` | `3009` | SigNoz MCP HTTP endpoint (streamableHttp, `POST /mcp`) |

The MCP endpoint accepts standard JSON-RPC 2.0 over HTTP with `Accept: application/json, text/event-stream`. External agents can call it directly without entering the Docker network.

---

**MCP Services and Proxy**

**Proxy server** runs as the central bridge for LLM API calls:

| Service | Port | Role |
|---------|------|------|
| ml-server | 8787 | Central LLM API proxy (headroom) — all containers point to `http://ml-server:8787` |

Each MCP server runs as an isolated sidecar container on the internal `mcp` Docker network. Ports are not exposed to the host. If a secret is not provided, the sidecar exits cleanly (code 0) and does not restart.

| Service | Port | Secret (fetched from Vault) |
|---------|------|--------|
| mcp-tavily | 3001 | `TAVILY_API_KEY` |
| mcp-azure-devops | 3002 | `ADO_MCP_AUTH_TOKEN`, `AZURE_DEVOPS_ORGANIZATION` |
| mcp-postman | 3003 | `POSTMAN_API_KEY` |
| mcp-newrelic | 3004 | `NEW_RELIC_API_KEY` |
| mcp-signoz | 3009 | API key auto-provisioned by `signoz-server` entrypoint; shared via Docker volume. **Host port exposed** — configurable via `--mcp-signoz-port` (default: `3009`). |

`playwright` and `aspire` run as local stdio servers inside the workspace container (no secrets required).

---

## What's installed

| Category | Tools |
|----------|-------|
| Runtimes | Node.js 24, Python 3.12, .NET 10, Go, Rust, Java |
| CLI tools | Claude Code CLI, Dapr, k6, D2, Mermaid, Azure CLI |
| Editor | code-server + Claude Code extension — browser on port 8080 (vscode profile) |
| Data science | Miniforge3 (in workspace-tools), venv-development, venv-analytics |
| Python packages | pypdf, python-docx, textual, jinja2, graphviz, diagrams, azure-cli |
| Development | venv-development: FastAPI, Uvicorn, Pydantic, HTTPx, SQLAlchemy, Alembic, python-jose, passlib, python-multipart, aiofiles, typer, loguru, pytest |
| ML packages *(GPU_ENABLED=true)* | venv-analytics: PyTorch, headroom-ai[ml], scikit-learn |
| Proxy server | headroom-ai, fastapi, uvicorn, httpx (in ml-server's venv-system) |
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

Use the docker-compose GPU override file to enable GPU support. GPU is completely optional — the primary compose file has zero CUDA footprint on CPU-only deployments.

**Two-file compose pattern:**

```bash
# CPU-only (no GPU packages, no CUDA footprint)
docker compose -f docker/docker-compose.yml -p "$WORKSPACE_NAME" up -d

# With GPU support (opt-in via override file)
docker compose -f docker/docker-compose.yml -f docker/docker-compose.gpu.yml -p "$WORKSPACE_NAME" up -d
```

### What GPU mode does

#### Shared Conda CUDA (workspace-server group)

Instead of each container needing its own CUDA base image, CUDA libraries are installed once in the shared `workspace-tools` volume:

- `workspace-server` installs `cuda-runtime` and `cuda-nvcc` via conda into `/opt/tools/miniforge3/` when `GPU_ENABLED=true`
- All sidecars (vscode-sidecar, containers-dev-sidecar, jupyter-sidecar, tunnel-sidecar) mount `/opt/tools` and inherit the CUDA installation via existing PATH/LD_LIBRARY_PATH
- NVIDIA Container Toolkit injects `libcuda.so.1` (driver stub) per-container when GPU devices are bound in compose
- All containers with GPU_ENABLED=true reserve all available NVIDIA GPUs

#### Custom DinD Image with NVIDIA Container Toolkit

The workspace uses a custom Docker-in-Docker image (`containers/dind/`) that extends the official `docker:28.1.1-dind` with conditional NVIDIA Container Toolkit support:

**How it works:**

1. **Image:** Custom Dockerfile in `containers/dind/Dockerfile` extends `docker:28.1.1-dind` (Alpine)
2. **Entrypoint:** Custom `entrypoint.sh` checks `GPU_ENABLED` environment variable at container startup
3. **GPU mode:** When `GPU_ENABLED=true`:
   - Entrypoint downloads and installs NVIDIA Container Toolkit binaries for Alpine (x86_64/arm64)
   - Docker daemon starts with toolkit ready
   - Inner containers can use `docker run --gpus all` to access GPUs
4. **CPU mode:** When `GPU_ENABLED=false`:
   - No toolkit installed, zero NVIDIA overhead
   - Standard Docker daemon

**Compose integration:**

- **Base:** `docker-compose.yml` builds and uses `zzaia-dind-nvidia:latest` image
- **GPU override:** `docker-compose.gpu.yml` sets `GPU_ENABLED=true` and reserves GPU devices for dind service
- **Build:** `docker compose build` automatically builds the custom image if not present

**GPU DinD support in workspace-server:**

When `GPU_ENABLED=true`, workspace-server entrypoint also:

1. Installs NVIDIA Container Toolkit inside workspace-server (redundant but ensures availability)
2. Generates CDI spec: `nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml`
3. Configures inner Docker daemon with nvidia runtime: `nvidia-ctk runtime configure --runtime=docker`
4. This runs in entrypoint BEFORE sshd starts

Users can then start inner containers with `docker run --privileged` or `--gpus all` to access GPU.

#### ML packages

- `ml-server` uses `ARG GPU_ENABLED=true` to select `nvidia/cuda:12.1.1-runtime-ubuntu24.04` base image (isolated from shared tools)
- `ml-server` installs PyTorch from CUDA 12.1 index (`https://download.pytorch.org/whl/cu121`) into its own `ml-tools` volume
- ML packages persist in their respective volumes (`ml-tools` for ml-server, `workspace-tools` for all workspace containers)

**Important:** ECI (Enhanced Container Isolation) must be disabled for DinD GPU support to work. Docker Desktop VM isolation prevents CDI device injection into inner containers.

---

## Security

| Control | Value |
|---------|-------|
| Docker sandbox | DinD via `runc` runtime; enable Docker Desktop ECI for unprivileged isolation (optional) |
| Workspace secrets | SSH key only — no API keys in workspace container |
| MCP secrets | Isolated per sidecar container, internal network only |
| Secret handling | vault-server fetches secrets from Bitwarden at startup — never written to host disk or .env files |
| Secrets storage | Named Docker volume (`<WORKSPACE_NAME>-vault-data`), not host path; Vault auto-unseals using keys sealed in encrypted volume |
| Host network | Bridge only, workspace ports bound to `127.0.0.1` |
| MCP ports | Internal only — not exposed to host, **except `mcp-signoz`** (host port `MCP_SIGNOZ_PORT`, bound to `127.0.0.1`) |
| Capabilities | Drop ALL + minimum required (CHOWN, FOWNER, SETGID, SETUID, AUDIT_WRITE) |
| Root login | Disabled |
| Sudo access | Passwordless by default; set `ADMIN_PASSWORD` to require password for sudo (restricts installs) |
| vault-server PAT exposure | vault-server is the only container that receives BWS_ACCESS_TOKEN; unset after bootstrap; no other container sees it |

---

## Files

```
docker/
├── Dockerfile               — Image definition (Ubuntu 24.04)
├── entrypoint.sh           — workspace-server entrypoint: setup-user → runtime-install → setup-credentials → sshd
├── sshd_config             — Port 2222, key-auth only
├── docker-compose.yml      — workspace-server + vscode-server + containers-dev-server + dind + MCP sidecars
├── docker-compose.gpu.yml  — GPU override for all services + dind
├── DOCKER.md               — This file
└── containers/
    ├── workspace-server/   — Workspace container definition
    ├── vscode-sidecar/     — VS Code editor sidecar
    ├── ml-server/          — ML inference server (headroom-ai, FastAPI)
    ├── jupyter-sidecar/    — Jupyter notebook server
    ├── containers-dev-sidecar/  — Dev containers CLI host
    ├── tunnel-sidecar/         — VS Code tunnel relay (Microsoft relay, no ports needed)
    ├── dind/               — Custom Docker-in-Docker with NVIDIA Container Toolkit support
    │   ├── Dockerfile      — DinD image extending docker:28.1.1-dind with toolkit installation
    │   ├── entrypoint.sh   — Custom entrypoint: conditionally installs NVIDIA toolkit if GPU_ENABLED=true
    │   ├── test-build.sh   — Build verification script
    │   └── README.md       — DinD image documentation
    ├── mcp-**/             — MCP server sidecar containers (tavily, github, postman, etc.)
    └── database-**/        — Database containers (neo4j, qdrant)
```
