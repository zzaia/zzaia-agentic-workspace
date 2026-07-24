# ZZAIA Container — Docker

> [!WARNING]
> **Docker Compose has been removed.** The container **images** documented below are still
> authoritative and are built unchanged for Kubernetes by
> [`../deploy/k8s/build-images.sh`](../deploy/k8s/build-images.sh) (`make k8s-images`);
> deploy via [`../deploy/k8s/README.md`](../deploy/k8s/README.md). Four services were dropped:
> `vault-server`, `nginx-proxy`, `signoz-server`/`mcp-signoz`, and `mcp-newrelic`.
> Secrets now come from Bitwarden Secrets Manager via the External Secrets Operator.

Ubuntu 24.04 all-in-one container (`workspace-server`) with system packages installed at build time (`build-install.sh`) and runtime tooling provisioned via Ansible (`entrypoint.sh` runs `ansible-playbook site.yml`). Runs SSH daemon by default; optionally runs browser VS Code and Dev Containers on separate container services. MCP servers run as isolated sidecar containers — each receives only its own secret.

---

## Prerequisites

The workspace requires the following host software when building and testing locally:

- **Docker Desktop** — Container runtime and image build  ([docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop))
- **Enhanced Container Isolation (ECI)** *(optional)* — Enables unprivileged Docker-in-Docker sandboxing. Enable via Docker Desktop > Settings > General > "Use Enhanced Container Isolation".

**GPU acceleration (optional, NVIDIA only):**

> Only NVIDIA GPUs are supported. AMD and Apple Silicon are not supported. GPU passthrough requires native Docker Engine — Docker Desktop's VM isolation prevents CDI device injection.

- **NVIDIA drivers** — Must be installed on the host (`nvidia-smi` must work)
- **NVIDIA Container Toolkit** — `nvidia-container-toolkit` package; see [GPU Acceleration](#gpu-acceleration-nvidia-only) section
- **Native Docker Engine** — Not Docker Desktop; install via `apt-get install docker-ce` on Ubuntu

> **For Kubernetes deployment**, see [`../deploy/k8s/README.md`](../deploy/k8s/README.md). Run `bash ../deploy/local.sh` to provision a complete k3s cluster and deploy workloads via Fleet. Local image building is optional — use `make k8s-images` to build images for development testing.

---

## SDK Deployment Flags

**.NET and Python are always installed.** All other SDKs are opt-in via deploy flags and installed by Ansible at first container start (persisted in the `workspace-tools` volume).

| Flag (Ubuntu/macOS) | Flag (Windows) | SDK | Install method | Auto-enables |
|---------------------|---------------|-----|---------------|--------------|
| `--node` | `-Node` | Node.js 24 via NVM | NVM | — |
| `--node-frontend` | `-NodeFrontend` | Angular CLI, Vite, TypeScript | npm global | `--node` |
| `--java` | `-Java` | Temurin JDK 21 | apt (Adoptium repo) | — |
| `--rust` | `-Rust` | Rust (stable) | rustup | — |
| `--lua` | `-Lua` | Lua 5.4 + luarocks | apt | — |
| `--cpp` | `-Cpp` | clang, cmake, build-essential | apt | — |
| `--clojure` | `-Clojure` | Clojure CLI | official installer | `--java` |
| `--go` | `-Go` | Go 1.24.4 | official binary | — |
| `--kotlin` | `-Kotlin` | Kotlin 2.1.21 | SDKMAN | `--java` |
| `--ruby` | `-Ruby` | Ruby 3.4.4 | rbenv | — |
| `--php` | `-Php` | PHP 8.2 + Composer | apt + script | — |
| `--swift` | `-Swift` | Swift 6.1.2 | swift.org binary | — |

**Dependency chains** (auto-resolved by deploy script):
- `--node-frontend` enables `--node`
- `--clojure` enables `--java` (Clojure requires JVM)
- `--kotlin` enables `--java` (Kotlin compiles to JVM bytecode)

**Install locations** (all under `INSTALL_PREFIX=/opt/tools`):

| SDK | Path |
|-----|------|
| Node.js | `/opt/tools/.nvm/` |
| Rust | `/opt/tools/.cargo/`, `/opt/tools/.rustup/` |
| Go | `/opt/tools/go/` (gopath: `/opt/tools/gopath/`) |
| Ruby | `/opt/tools/.rbenv/` |
| Kotlin | `/opt/tools/.sdkman/` |
| Swift | `/opt/tools/swift/` |
| Java, Lua, C++, PHP | System paths via apt |
| Clojure | `/usr/local/bin/` |

SDKs are installed once and persist across container restarts. Delete the `workspace-tools` volume to force reinstallation.

---

## Storage — Named Volumes

The workspace uses multiple named Docker volumes. Named volumes live entirely inside Docker's storage layer — no host filesystem ownership issues, no `sudo` required, no Docker Desktop VM permission pass-through problems.

### Volume layout

| Volume alias | Docker volume name | Mount path | Contents | Lifecycle |
|---|---|---|---|---|
| `workspace-secrets` | `<WORKSPACE_NAME>-secrets` | `/secrets` (all servers) | SSH public key | Independent |
| `workspace-home` | `<WORKSPACE_NAME>-home` | `/home/user` (workspace-server, vscode-sidecar, containers-dev-sidecar, jupyter-sidecar, tunnel-sidecar) | Home directory with user configs, credentials, workspace repos | Shared across all servers |
| `workspace-tools` | `<WORKSPACE_NAME>-tools` | `/opt/tools` (workspace-server rw, vscode-sidecar, containers-dev-sidecar, tunnel-sidecar :ro, jupyter-sidecar rw) | Runtime tools: Node.js, .NET, Python, CLIs, miniforge3, venv-development, venv-analytics (when GPU_ENABLED=true) | Delete to force tool re-install |
| `ml-tools` | `<WORKSPACE_NAME>-ml-tools` | `/opt/ml-tools` (ml-server rw) | ML-server miniforge3, venv-system with headroom-ai, fastapi, uvicorn | Delete to force ml-server re-install |

### Home volume seeding

On the **first start with an empty home volume**, Docker copies the image's `/home/user` content into the volume. This means:

- Home configs, SSH configs, Claude auth tokens, and workspace seeds are copied once on first start
- `workspace-server` owns and manages the shared `workspace-home` volume — it starts first and runs initialization
- `vscode-sidecar`, `containers-dev-sidecar`, `jupyter-sidecar`, and `tunnel-sidecar` depend on `workspace-server: condition: service_healthy` and mount the same shared home
- Home contents persist across restarts and container recreation

### Tools volume installation

Tools install to `/opt/tools` in the separate `workspace-tools` volume:

- `workspace-server` entrypoint runs `ansible-playbook site.yml` which installs tools to `/opt/tools` (INSTALL_PREFIX=/opt/tools, HOME=/home/user)
- `workspace-tools` volume is read-write for `workspace-server`, read-only (`:ro`) for `vscode-server` and `containers-dev-server`
- Tools persist across restarts; delete the volume to force re-installation with new versions from `versions.env`

### ML-server volume installation

ML-server runtime installs to `/opt/ml-tools` in the separate `ml-tools` volume:

- `ml-server` entrypoint bootstraps miniforge3 and venv-system conda env with headroom-ai, fastapi, uvicorn
- `ml-tools` volume is read-write for `ml-server` only — owned by headroom user (uid=1001), no shared conda envs
- Workspace home (`workspace-home`) is mounted read-only for headroom code-graph/memory access
- `ml-server` does NOT mount `workspace-tools` — independent sealed environment

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
```

---

## Secrets and Credentials

**Credentials are supplied at deploy time via Bitwarden Secrets Manager.** For Kubernetes deployment, the External Secrets Operator (ESO) syncs them continuously into k8s Secrets. See [`../deploy/k8s/BWS_SECRETS.md`](../deploy/k8s/BWS_SECRETS.md) for the full configuration.

**git-sidecar — SSH Git Proxy**:

The `git-sidecar` service is an SSH relay that lets workspace agents (`git clone`, `git push`) access private GitHub and Azure DevOps repositories without the agent ever seeing a PAT.

| Item | Details |
|------|---------|
| Port | `2223` (SSH, internal Docker network only) |
| Auth | SSH key provided via ESO Secret, stored at `/home/git/.ssh/authorized_keys` |
| ForceCommand | Every SSH session is restricted to `git-proxy-cmd` — no shell, no port forwarding |
| Token file | `GITHUB_PERSONAL_ACCESS_TOKEN` + `ADO_MCP_AUTH_TOKEN` written to `/home/git/.git-proxy/tokens` (chmod 600) at startup; never exposed as env vars |

**URL routing** via `git-proxy-cmd`:

| Path prefix | Upstream |
|-------------|---------|
| `github/<owner>/<repo>` | `https://x-access-token:<PAT>@github.com/<owner>/<repo>.git` |
| `ado/<org>/<project>/<repo>` | `https://anything:<TOKEN>@dev.azure.com/<org>/<project>/_git/<repo>` |

---

## MCP Services

**Proxy server** runs as the central bridge for LLM API calls:

| Service | Port | Role |
|---------|------|------|
| ml-server | 8787 | Central LLM API proxy (headroom) — all containers point to `http://ml-server:8787` |

Each MCP server runs as an isolated sidecar container. Credentials come from ESO ExternalSecrets. If a secret is not provided, the sidecar exits cleanly (code 0).

| Service | Port | Secret (from Bitwarden Secrets Manager) |
|---------|------|--------|
| mcp-tavily | 3001 | `TAVILY_API_KEY` |
| mcp-azure-devops | 3002 | `ADO_MCP_AUTH_TOKEN`, `AZURE_DEVOPS_ORGANIZATION` |
| mcp-postman | 3003 | `POSTMAN_API_KEY` |
| mcp-github | 3005 | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| mcp-aws-api | 3010 | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` |
| mcp-azure-portal | 3015 | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| mcp-playwright | 3006 | (no secrets required) |
| mcp-codegraph | — | (stdio server, no secrets) |
| mcp-graphiti | — | (stdio server, no secrets) |
| mcp-headroom | 3007 | (stdio server, no secrets) |

`playwright` and `headroom` run as local stdio servers inside the workspace container.

---

## What's installed

**Always installed (defaults):**

| Category | Tools |
|----------|-------|
| Runtimes | Python 3.12, .NET 10 |
| CLI tools | Claude Code CLI, Dapr, k6, D2, Mermaid, Azure CLI, GitHub CLI |
| Editor | code-server + Claude Code extension — browser on port 8080 (vscode profile) |
| Python packages | pypdf, python-docx, textual, jinja2, graphviz, diagrams, azure-cli |
| Development | venv-development: FastAPI, Uvicorn, Pydantic, HTTPx, SQLAlchemy, Alembic, python-jose, passlib, python-multipart, aiofiles, typer, loguru, pytest |
| ML packages *(GPU_ENABLED=true)* | venv-analytics: PyTorch, headroom-ai[ml], scikit-learn |
| Proxy server | headroom-ai, fastapi, uvicorn, httpx (in ml-server's venv-system) |
| .NET tools | Aspire workload, Aspirate |
| System | tmux, PlantUML, tectonic, git, build-essential |

**Opt-in SDKs** (via deploy flags — see [SDK Deployment Flags](#sdk-deployment-flags)):

| Flag | Adds |
|------|------|
| `--node` | Node.js 24, NVM, npm globals (Claude Code CLI, Mermaid CLI, Codex, Gemini CLI) |
| `--node-frontend` | + Angular CLI, Vite, TypeScript |
| `--java` | Temurin JDK 21 |
| `--rust` | Rust stable, cargo |
| `--lua` | Lua 5.4, luarocks |
| `--cpp` | clang, cmake, build-essential |
| `--clojure` | Clojure CLI (+ Java auto-enabled) |
| `--go` | Go 1.24.4 |
| `--kotlin` | Kotlin 2.1.21 via SDKMAN (+ Java auto-enabled) |
| `--ruby` | Ruby 3.4.4 via rbenv |
| `--php` | PHP 8.2 + Composer |
| `--swift` | Swift 6.1.2 |
