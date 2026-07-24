# ZZAIA Agentic Workspace — Quick Start

> Deploy the workspace onto Kubernetes.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **`ansible-playbook`** | Provision k3s cluster, Kong, ESO, Fleet, and local OCI registry | `apt install ansible-core` or `pipx install --include-deps ansible-core` |
| **Bitwarden Secrets Manager token (optional)** | Bootstrap workspace secrets at deploy time; ESO keeps them in sync thereafter | [Bitwarden Secrets Manager account](https://bitwarden.com/products/secrets-manager/) — generate an organization token |

---

## Step 1 — Provision the Cluster

The Ansible playbook self-provisions everything. Run:

```bash
bash deploy/local.sh up
```

This will:
1. Check for `ansible-playbook` prerequisite
2. Prompt for optional Bitwarden Secrets Manager token (BWS_ACCESS_TOKEN)
3. Run the Ansible playbook (`deploy/ansible/site.yml`) which:
   - Installs docker, kubectl, helm, k3s
   - Starts a single-node k3s cluster
   - Provisions a local OCI registry (127.0.0.1:5000)
   - Installs Kong (ingress, DB-less, single HTTPS listener on port 8443)
   - Installs External Secrets Operator (ESO)
   - Installs Bitwarden SDK server (for secret injection)
   - Deploys Fleet in standalone mode (no Rancher)
   - Generates self-signed TLS wildcard certificate
   - Configures local DNS wildcard (dnsmasq)

At the end, the script prints the cluster URL and next steps.

**Optional parameters:**
- `NO_BWS=true` — skip Bitwarden (secrets must be configured manually later via ESO)
- `CLUSTER_NAME=custom-name` — use a custom cluster name (default: `zzaia-local`)

> See [`deploy/ansible/site.yml`](deploy/ansible/site.yml) for the full playbook and role details.

---

## Step 2 — Configure Secrets (ESO + Bitwarden)

External Secrets Operator continuously syncs secrets from Bitwarden Secrets Manager into Kubernetes Secrets. Supply the `BWS_ACCESS_TOKEN` at deploy time (Step 1); ESO handles all rotation and reconciliation thereafter.

**Workspace secrets are defined in Bitwarden Secrets Manager as:**

See [`deploy/k8s/BWS_SECRETS.md`](deploy/k8s/BWS_SECRETS.md) for the complete table of secret names, expected keys, and Bitwarden credential setup instructions.

**At minimum, configure in Bitwarden:**
- **ml-server** — Claude Code / cloud-provider credentials (one of: `ANTHROPIC_API_KEY`, `AWS_*` for Bedrock, `CLAUDE_CODE_USE_VERTEX`, `CLAUDE_CODE_USE_FOUNDRY`)
- (Optional) **workspace-admin** — `ADMIN_PASSWORD` for sudo access inside the workspace

Everything else is optional and only required by the MCP tools you actually enable.

**ESO behavior:**
- ESO reads the `bitwarden-access-token` Secret created by `deploy/local.sh` in the `external-secrets` namespace
- ESO creates/updates k8s Secrets in the `zzaia-agentic-workspace` namespace based on Bitwarden secrets
- Refresh interval: default 1h; set via `externalSecrets.refreshInterval` in values.yaml
- No manual secret management — only update Bitwarden, ESO handles the rest

> If you skipped Bitwarden at deploy time (`NO_BWS=true`), you can manually create k8s Secrets or update `deploy/k8s/Chart/values.yaml` to point to a different ESO backend (Vault, AWS Secrets Manager, etc.).

---

## Step 3 — Deploy Workloads via Fleet

Fleet automatically reconciles this repo into the cluster. Workloads are defined in `deploy/k8s/Chart` and deployed continuously via GitOps.

**Fleet is already configured by `deploy/local.sh`:**
- GitRepo points to this public repository: `https://github.com/zzaia/zzaia-agentic-workspace`
- Namespace: `zzaia-agentic-workspace`
- Target: `deploy/k8s/Chart` (Helm chart)
- Auto-reconcile on push

**Manual deployment (if needed):**

```bash
# Re-deploy the chart (normally unnecessary — Fleet does this automatically)
helm upgrade --install zzaia-workspace deploy/k8s/Chart \
  --namespace zzaia-agentic-workspace --create-namespace \
  -f deploy/k8s/Chart/values.yaml
```

**Customizations via Helm:**

See [`deploy/k8s/README.md`](deploy/k8s/README.md) for:
- Building and pushing custom images to the local registry (127.0.0.1:5000)
- Per-image rebuild and registry override
- Production values overlay
- GPU enablement
- ESO backend switching (from Bitwarden to Vault, AWS Secrets Manager, etc.)

---

## Step 4 — Access the Workspace

All HTTP front-ends are served through Kong ingress, routed by subdomain under `*.workspace.zzaia.com`. Local DNS resolution is automatic (dnsmasq installed by Ansible) — no `/etc/hosts` editing needed.

> Kong listens on **`:8443`** (not 443). Every URL below includes this port.

| Access | URL / Command |
|--------|--------------|
| **ml-server** (main external ingress) | `https://headroom.workspace.zzaia.com:8443` — LLM proxy for Claude Code and other agents |
| **SSH** | `kubectl -n zzaia-agentic-workspace port-forward svc/workspace-server 2222:2222`, then `ssh -p 2222 user@localhost` |
| **Dev Containers** | VS Code → Remote Explorer → Attach to Running Container |
| **Aspire Dashboard** | Only available locally during dev; run via `workspace/host/` AppHost |
| **Bifrost Code Mode UI** | `https://bifrost.workspace.zzaia.com:8443` — Starlark sandbox dashboard |

Claude Code, Gemini, Copilot, and Codex extensions are pre-installed. All MCP tools connect automatically via bifrost Code Mode, each scoped to only its required credential group.

---

## Step 5 — Verify Setup

Inside Claude Code, run:

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
| MCP shows disconnected | MCP sidecar pods wait for ESO to sync secrets. Check: `kubectl -n zzaia-agentic-workspace get pods` — sidecars should be `Running` once ExternalSecret syncs. |
| Workspace slow to start | ml-server initializes on first boot; allow up to 5 min. Check logs: `kubectl -n zzaia-agentic-workspace logs deploy/ml-server` |
| Agent API calls failing | Check ml-server logs: `kubectl -n zzaia-agentic-workspace logs deploy/ml-server` — verify Claude Code credentials are configured in Bitwarden |
| Pod not starting | `kubectl -n zzaia-agentic-workspace describe pod <name>` then `kubectl -n zzaia-agentic-workspace logs <name>` |
| ExternalSecret not syncing | `kubectl -n zzaia-agentic-workspace get externalsecrets` — check `STATUS` and `ERROR` columns. Verify BWS token is valid. |
| SSH key rejected | Verify `SSH_PUBLIC_KEY` in Bitwarden starts with `ssh-ed25519`, `ssh-rsa`, or `ecdsa-` |
| `*.workspace.zzaia.com` doesn't resolve | Verify dnsmasq is running: `getent hosts headroom.workspace.zzaia.com` should resolve to 127.0.0.1. If not, re-run dnsmasq setup from Ansible output. |
| Bitwarden integration not working | Verify `BWS_ACCESS_TOKEN` is valid. Check ESO status: `kubectl -n external-secrets logs deploy/external-secrets -f` |

---

## Secret Rotation

Update the value directly in Bitwarden Secrets Manager. The External Secrets Operator re-syncs on `externalSecrets.refreshInterval` (default `1h`) — no redeploy needed. To pick up a rotated value immediately:

```bash
kubectl -n zzaia-agentic-workspace annotate externalsecrets zzaia-workspace-secrets \
  force-sync=$(date +%s) --overwrite
```

Then restart the pods that use that secret:

```bash
kubectl -n zzaia-agentic-workspace rollout restart deployment/<name>
```

> **PVC lifecycle** (Kubernetes native):
>
> | PVC | Contains | Delete to… |
> |-----|----------|-----------|
> | `zzaia-workspace-home` | Home directory (user config, workspace repos, SSH keys) | Reset all user state |
> | `zzaia-workspace-tools` | Runtime tools (Node.js, .NET, Python, CLIs) | Force tool re-install on next ml-server start |
> | `zzaia-workspace-sshkeys` | SSH host keys | Rotate host identity |
>
> Example:
> ```bash
> kubectl -n zzaia-agentic-workspace delete pvc zzaia-workspace-home
> ```

---

## Available Commands Reference

| Command | Purpose | Definition |
|---------|---------|------------|
| `/behavior:workspace:repo` | Clone repo or create branch worktree | [↗](agents/claude/.claude/commands/behavior/workspace/repo.md) |
| `/behavior:devops:work-item` | Read or manage work items | [↗](agents/claude/.claude/commands/behavior/devops/work-item.md) |
| `/behavior:devops:pull-request` | Manage pull requests | [↗](agents/claude/.claude/commands/behavior/devops/pull-request.md) |
| `/behavior:devops:pipeline` | Run or debug CI/CD pipelines | [↗](agents/claude/.claude/commands/behavior/devops/pipeline.md) |
| `/behavior:development:develop` | Apply targeted changes to a branch | [↗](agents/claude/.claude/commands/behavior/development/develop.md) |
| `/behavior:development:build` | Multi-framework builds | [↗](agents/claude/.claude/commands/behavior/development/build.md) |
| `/behavior:development:test` | Comprehensive testing | [↗](agents/claude/.claude/commands/behavior/development/test.md) |
| `/behavior:development:review` | Code quality review | [↗](agents/claude/.claude/commands/behavior/development/review.md) |
| `/behavior:development:git` | Git commit and push | [↗](agents/claude/.claude/commands/behavior/development/git.md) |
| `/workflow:remote:implement` | Full implementation from work item to PR | [↗](agents/claude/.claude/commands/workflow/remote/implement.md) |
| `/workflow:remote:architect` | Generate BDD, Epic, and work items from a spec | [↗](agents/claude/.claude/commands/workflow/remote/architect.md) |
| `/workflow:remote:homologate` | Run E2E BDD against a live URL | [↗](agents/claude/.claude/commands/workflow/remote/homologate.md) |
| `/workflow:remote:fix-pipeline` | Iterative pipeline repair loop | [↗](agents/claude/.claude/commands/workflow/remote/fix-pipeline.md) |
| `/orchestrator:implement` | Implement multiple work items in parallel | [↗](agents/claude/.claude/commands/orchestrator/implement/SKILL.md) |

Full reference: [README.md](README.md)
