# Docker Scripts — Bootstrap Architecture

Refactored entrypoint bootstrap into modular, testable scripts for improved readability and maintainability.

## Directory Structure

```
docker/
├── entrypoint.sh                 # Main orchestrator (Phase 1-3)
├── scripts/
│   ├── common.sh                 # Shared utilities, logging, env
│   ├── setup-user.sh             # User home, SSH, permissions
│   ├── setup-credentials.sh      # Authentication (Claude, GitHub, Azure)
│   └── README.md                 # This file
```

## Script Responsibilities

### `common.sh` — Shared Utilities
Provides reusable functions and environment:
- **Logging**: `log_info()`, `log_warn()`, `log_error()`, `log_success()`
- **Helpers**: `retry_with_backoff()`, `ensure_dir()`, `cleanup_secrets()`
- **Environment**: Common vars (`WORKSPACE_NAME`, `SECRETS_FILE`, `BOOTSTRAP_DIR`)
- **Exit trap**: Automatically cleans up sensitive env vars on exit

**Usage**: Source at top of each script: `source "$(dirname "${BASH_SOURCE[0]}")/common.sh"`

---

### `setup-user.sh` — User & System Setup
Runs as root. Initializes the workspace user environment:

1. **setup_user_home()** — Create/own `/home/user` for the non-root user
2. **seed_home()** — Extract image template to user home (one-time via marker file)
3. **setup_ssh_host_keys()** — Persist SSH host keys in `/secrets/` volume to avoid client fingerprint changes
4. **setup_docker_socket()** — Configure user for Docker socket access
5. **setup_sudo()** — Passwordless sudo for bootstrap tasks
6. **setup_apt_sandbox()** — Apt configuration for in-container runtime installs
7. **setup_ssh_auth()** — Load SSH public key from env or secrets file
**Exit on error**: Yes (`set -euo pipefail`)

---

### `runtime-install.sh` — Installation Orchestrator
Runs as user. Installs all development tools to `INSTALL_PREFIX` (default: `/home/user` — the shared workspace-home volume):

1. **python::install_miniforge()** — Miniforge (conda) if missing
2. **node::install()** — Node.js via nvm
3. **node::install_npm_globals()** — claude-code, mmdc, codex, gemini-cli
4. **dotnet::install()** — .NET SDK via dotnet-install.sh
5. **dotnet::install_tools()** — Aspire CLI + aspirate
6. **python::install_packages()** — pip packages (pypdf, python-docx, etc.)
7. **python::install_conda_envs()** — venv-analytics, venv-development
8. **cli::install_*()** — gh, k6, d2, dapr, rtk
9. **vscode::install_extensions()** — Extensions from `vscode-extensions.txt`
10. **configure_path()** — Write canonical PATH to `.bashrc` + `.profile`
11. **verify_tools()** — Gate check on required binaries

**Idempotent**: Via `BOOTSTRAP_MARKER` (`$INSTALL_PREFIX/.bootstrap/tools.ready`) using script SHA256 hash
**Upgrade**: `runtime-install.sh --upgrade` bypasses marker for explicit re-install
**Retries**: `retry_with_backoff()` from `common.sh`

---

### `setup-credentials.sh` — Authentication Setup
Runs as user. Configures all API credentials and git auth:

1. **apply_workspace_templating()** — Replace `{{WORKSPACE_NAME}}` in JSON/workspace files; rename `zzaia.code-workspace` to `${WORKSPACE_NAME}.code-workspace`
2. **setup_claude_credentials()** — Write Claude OAuth token to `~/.claude/.credentials.json` (if `CLAUDE_CODE_OAUTH_TOKEN` set)
3. **setup_github_credentials()** — Authenticate `gh` CLI, install gh-copilot, configure git credential helper (if `GITHUB_PERSONAL_ACCESS_TOKEN` set)
4. **setup_azure_devops_credentials()** — Configure git credential helper for Azure DevOps (if `ADO_MCP_AUTH_TOKEN` set)

**Skip gracefully**: Each setup function checks for env vars; missing vars logged as warnings, don't block

---

### `entrypoint.sh` — Main Orchestrator
Runs as root. Sequences all phases and starts SSH daemon:

```bash
Phase 1: setup-user.sh          # User & system setup
Phase 2: setup-credentials.sh   # Auth setup
Then:    /usr/sbin/sshd -D      # SSH daemon (blocking)
```

> Tools are installed by `workspace-server` into `/home/user` (the shared `workspace-home` volume) during container startup.

**Logging**: Each phase logs start/completion via `log_info()` and `log_success()`
**Error handling**: Any phase failure (`set -e`) stops execution

---

## Environment Variables

### Required
- `WORKSPACE_NAME` — Workspace identifier (default: `zzaia`)
- `SSH_PUBLIC_KEY` — SSH public key for authorized_keys (persisted in `/secrets/.env`)

### Optional (Credentials)
- `CLAUDE_CODE_OAUTH_TOKEN` — Claude OAuth access token
- `GITHUB_PERSONAL_ACCESS_TOKEN` — GitHub PAT (for gh CLI, git, gh-copilot)
- `ADO_MCP_AUTH_TOKEN` — Azure DevOps PAT for private repositories
- `ADMIN_PASSWORD` — User password for sudo/login (default: none; passwordless sudo always enabled)

### Optional (Tools)
- `GITHUB_PERSONAL_ACCESS_TOKEN` — Also used for higher API limits in tool installation

---

## Key Design Principles

1. **Modularity** — Each phase is a separate script with single responsibility
2. **Idempotency** — Marker files gate one-time operations; most operations are re-runnable
3. **Logging** — Color-coded, consistent logging across all phases
4. **Error Handling** — Early exit on error (`set -e`), with retry helpers for flaky operations
5. **Secret Management** — Credentials cleared from env on exit via `cleanup_secrets()` trap
6. **Volume Persistence** — SSH keys, .env, git credentials stored in `/secrets/` volume across restarts

---

## Testing Individual Phases

Each script can be tested independently:

```bash
# Test user setup
docker run --rm -it -v workspace-secrets:/secrets zzaia-agentic-workspace:latest \
  bash docker/scripts/setup-user.sh

# Test credentials
docker run --rm -it -u user -e GITHUB_PERSONAL_ACCESS_TOKEN=xxx zzaia-agentic-workspace:latest \
  bash docker/scripts/setup-credentials.sh
```

---

## Troubleshooting

### Issue: Bootstrap stuck on tool installation
**Check**: `docker logs <container> | grep -i "bootstrap\|warn"`
**Fix**: Individual tool installations may timeout; check network connectivity, GitHub API limits

### Issue: SSH key not loaded
**Check**: `/home/user/.ssh/authorized_keys` exists and has correct permissions (600)
**Fix**: Ensure `SSH_PUBLIC_KEY` env var is set or `/secrets/.env` persists across restarts

### Issue: Credentials not working
**Check**: `/home/user/.claude/.credentials.json`, `~/.git-credentials` are readable (user:user, 600 perms)
**Fix**: Re-run `setup-credentials.sh` or export env vars before container start

---

## Future Improvements

- [ ] Add script for vscode-server startup (separate from SSH bootstrap)
- [ ] Add script for AppHost integration
- [ ] Add health checks / readiness probes per phase
- [ ] Parallel tool installation where safe (currently sequential for stability)
- [ ] Cached layers for Docker build optimization
