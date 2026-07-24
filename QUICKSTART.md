# ZZAIA Agentic Workspace — Quick Start

> Deploy the workspace onto Kubernetes.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **A running cluster** | Kong ingress, the External Secrets Operator, and the `zzaia-secrets-store` ClusterSecretStore already installed | Provisioned separately (e.g. by the `zzaia-finance-data-engine` control repo) — this chart only deploys *into* an existing cluster's shared infra, never its own copy |
| **Azure Key Vault access** | Source of truth for all workspace secrets — no Bitwarden, no in-cluster Vault seed | See [`deploy/k8s/AZURE_KEYVAULT.md`](deploy/k8s/AZURE_KEYVAULT.md) |
| **`helm`, `kubectl`, `docker`** | Build images and deploy the chart | Standard installs |

---

## Step 1 — Choose Authentication

Only **one** method is needed. Claude Code checks them in this priority order:

| Priority | Method | Best For |
|----------|--------|---------|
| 1 | **Cloud Provider** (Bedrock / Vertex / Foundry) | Enterprise / no token expiry |
| 2 | **API Key** | Pay-per-token / simplest setup |
| 3 | **Pro / Max (OAuth)** | Subscription accounts |

> If multiple methods are configured, the highest-priority one wins.

### Cloud Provider variables

| Provider | Variables to Set |
|----------|-----------------|
| **AWS Bedrock** | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` + `AWS_REGION` (+ optional `ANTHROPIC_BEDROCK_BASE_URL`) |
| **Google Vertex AI** | `CLAUDE_CODE_USE_VERTEX=1` + `ANTHROPIC_VERTEX_PROJECT_ID` + `CLOUD_ML_REGION` |
| **Azure AI Foundry** | `CLAUDE_CODE_USE_FOUNDRY=1` + `AZURE_FOUNDRY_BASE_URL` |

### API Key

Set `ANTHROPIC_API_KEY` — obtain from [console.anthropic.com](https://console.anthropic.com).

### Pro / Max (OAuth)

| | Extension | Terminal `claude` REPL |
|---|---|---|
| **Option A** (`CLAUDE_CODE_OAUTH_TOKEN` env var) | ✅ | ✅ after one-time `.claude.json` seed |
| **Option B** (`claude setup-token` inside container) | ✅ | ✅ fully self-contained |

**Option A — Long-lived env var token:**

On your **host machine**, run:

```bash
claude setup-token
```

Copy the printed token and store it as `CLAUDE_CODE_OAUTH_TOKEN` in the `ai` Key Vault secret (Step 2). Valid for ~1 year. The extension picks it up immediately.

> **Important:** The token must be a single unbroken line. Terminal output may wrap it across multiple lines — copy the full token and remove any line breaks. A token with an embedded newline causes an `invalid header value` error.

The onboarding wizard is automatically suppressed — the image ships a `.claude.json` with `hasCompletedOnboarding: true` that seeds the home volume on first start.

**Option B — Interactive session inside the container (simplest, fully self-contained):**

Start the workspace first (Step 3), open a terminal inside VS Code, and run:

```bash
claude setup-token
```

Claude Code prints a URL. **Do not expect a browser to open automatically** — the pod has no display. Instead:

1. Copy the URL from the terminal
2. Open it in a browser **on your host machine**
3. Complete authentication
4. Copy the authorization code shown in the browser back into the terminal when prompted

> **Important:** The OAuth callback URL is not reachable from inside the pod — you must manually copy the URL and open it on the host, then copy the code back.

Claude Code stores the full session (credentials + account info) in the `workspace-home` PVC — the onboarding wizard is permanently suppressed and the session persists across all pod restarts. No env var is needed.

---

## Step 2 — Seed Azure Key Vault

Every secret the workspace needs — AI keys, MCP tool credentials, the git-sidecar SSH key, the admin password — lives in Azure Key Vault as one of nine JSON-object secrets, projected into the cluster by the External Secrets Operator. No secret ever lives in Git or in a Helm value.

> See [`deploy/k8s/AZURE_KEYVAULT.md`](deploy/k8s/AZURE_KEYVAULT.md) for the full table of secret names, the JSON keys each one holds, and copy-paste `az keyvault secret set` commands.

At minimum you need the `ai` secret (your Claude Code / cloud-provider credentials from Step 1) and, if you want sudo inside the workspace, the `admin` secret (`ADMIN_PASSWORD`). Everything else is optional and only required by the MCP tools you actually enable.

> `ADMIN_PASSWORD` also becomes the SigNoz and Neo4j credentials where applicable. It has no strength requirement enforced by this chart, but a weak password is your own risk since it gates `sudo` inside the workspace.

---

## Step 3 — Deploy the Workspace

One-time cluster wiring (Fleet GitRepo + local DNS wildcard), then build images and install the chart:

```bash
# One-time: wire this repo into the cluster's Fleet + local DNS
./deploy/k8s/bootstrap.sh

# Build and push every zzaia-* image, pin tags in a Helm values overlay
bash deploy/k8s/build-images.sh

# Deploy
helm upgrade --install zzaia-workspace deploy/k8s/Chart \
  --namespace zzaia-agentic-workspace --create-namespace \
  -f deploy/k8s/Chart/values.yaml \
  -f deploy/k8s/Chart/values-images.yaml
```

For a production-shaped cluster, also layer `-f deploy/k8s/Chart/values-production.yaml` and set the Azure Key Vault identity:

```bash
helm upgrade --install zzaia-workspace deploy/k8s/Chart \
  --namespace zzaia-agentic-workspace --create-namespace \
  -f deploy/k8s/Chart/values.yaml \
  -f deploy/k8s/Chart/values-production.yaml \
  -f deploy/k8s/Chart/values-images.yaml \
  --set externalSecrets.azurekv.vaultUrl=https://<vault>.vault.azure.net \
  --set externalSecrets.azurekv.clientId=<uuid> \
  --set externalSecrets.azurekv.tenantId=<uuid>
```

**GPU:** set `--set gpu.enabled=true` — this both requests `nvidia.com/gpu` and turns on the NVIDIA Container Toolkit inside `dind-server`. Requires the cluster's `nvidia` RuntimeClass and device plugin (owned by the infra chart, not this one).

**Observability:** nothing to opt into — every pod ships logs/metrics/traces to the cluster's existing SigNoz via the shared OTel Collector by default. There is no separate observability stack to enable or disable per workspace.

**SDKs (Node, Java, Rust, …):** installed at runtime by the Ansible bootstrap inside `workspace-server`, controlled by the same `*_ENABLED` flags as before — now set via `workspaceServer.env` in `values.yaml` rather than a deploy-script flag.

See [`deploy/k8s/README.md`](deploy/k8s/README.md) for the full build/deploy reference, including per-image rebuild and registry override.

---

## Step 4 — Access the Workspace

All HTTP front-ends are served through the cluster's Kong ingress, routed by subdomain under `*.workspace.zzaia.com`. Local resolution is a dnsmasq wildcard installed by `deploy/k8s/bootstrap.sh` (or run `./deploy/k8s/setup-workspace-dns.sh` directly) — no `/etc/hosts` editing needed.

> Kong's proxy Service listens on **`:8443`**, not the default 443 (see the cluster repo's `deploy/ansible/roles/ring`) — every URL below needs that port. `.Values.ingress.httpsPort` controls it; the chart's own `helm install` output (NOTES.txt) always prints the correct port.

| Access | URL / Command |
|--------|--------------|
| **VS Code** (browser) | `https://vscode.workspace.zzaia.com:8443` |
| **SSH** | `kubectl -n zzaia-agentic-workspace port-forward svc/workspace-server 2222:2222`, then `ssh -p 2222 user@localhost` — SSH is TCP, not routed through Kong |
| **Dev Containers** | VS Code → Remote Explorer → Attach to Running Container → workspace |
| **Aspire Dashboard** | `https://aspire.workspace.zzaia.com:8443` |
| **Portainer** | `https://portainer.workspace.zzaia.com:8443` |
| **Bifrost UI** | `https://bifrost.workspace.zzaia.com:8443` — gateway dashboard: logs, provider config, MCP clients |
| **SigNoz UI** | The cluster's existing SigNoz instance (see the cluster repo's docs) — not deployed per-workspace |

Claude Code, Gemini, Copilot, and Codex extensions are pre-installed. All MCP tools connect automatically via isolated sidecar pods, each scoped to only the Key Vault credential group it needs. The Aspire dashboard starts empty and receives telemetry when an AppHost is running.

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
| MCP shows disconnected | MCP images are pre-installed (no runtime npx). Wait ~15s for the ExternalSecret to sync + supergateway init, then retry `/mcp`. A sidecar with no Key Vault entry for its own secret group CrashLoopBackOffs (by design, see the entrypoint's readiness contract) rather than idling silently |
| Workspace slow to start | `workspace-server` runs tool installation on first boot; other pods wait on its `tools.ready` sentinel — allow up to 30 min on a cold `workspace-tools` PVC |
| Agent API calls failing | `kubectl -n zzaia-agentic-workspace logs deploy/ml-server` — the LLM proxy may still be initializing |
| Pod not starting | `kubectl -n zzaia-agentic-workspace describe pod <name>` then `kubectl -n zzaia-agentic-workspace logs <name>` |
| ExternalSecret not syncing | `kubectl -n zzaia-agentic-workspace get externalsecret` — check `STATUS`; verify the Key Vault object name matches exactly (see AZURE_KEYVAULT.md) |
| SSH key rejected | Verify `SSH_PUBLIC_KEY` in the `workspace` Key Vault secret starts with `ssh-ed25519`, `ssh-rsa`, or `ecdsa-` |
| Terminal `claude` shows onboarding wizard | The `workspace-home` PVC predates the fix — delete and recreate it, or run `claude setup-token` inside the pod |
| Extension auth error: `invalid header value` | `CLAUDE_CODE_OAUTH_TOKEN` contains a newline from terminal line-wrap — remove all line breaks from the token, update the `ai` Key Vault secret, and restart the affected pod |
| `*.workspace.zzaia.com` doesn't resolve | Re-run `./deploy/k8s/setup-workspace-dns.sh` on the k3s host; verify with `getent hosts vscode.workspace.zzaia.com` |

---

## Secret Rotation

Update the value directly in Azure Key Vault (see [`AZURE_KEYVAULT.md`](deploy/k8s/AZURE_KEYVAULT.md) for the `az keyvault secret set` commands per group). The External Secrets Operator re-syncs on `externalSecrets.refreshInterval` (default `1h`) — no redeploy needed. To pick up a rotated value immediately:

```bash
kubectl -n zzaia-agentic-workspace annotate externalsecret zzaia-workspace-secrets-<group> \
  force-sync=$(date +%s) --overwrite
```

Then restart the pods that consume that group so the new env var takes effect:

```bash
kubectl -n zzaia-agentic-workspace rollout restart deployment/<name>
```

> PVC lifecycle (same concept as before, now Kubernetes-native):
>
> | PVC | Contains | Delete to… |
> |-----|----------|-----------|
> | `workspace-home` | Home directory (user config, credentials, workspace repos) | Reset all user state |
> | `workspace-tools` | Runtime tools (Node.js, .NET, Python, CLIs) | Force tool re-install on next `workspace-server` start |
> | `workspace-sshkeys` | Host key material | Rotate host identity |
> | `ml-tools` | ml-server's own toolchain | Force ml-server re-install |
>
> ```bash
> kubectl -n zzaia-agentic-workspace delete pvc zzaia-workspace-workspace-home
> kubectl -n zzaia-agentic-workspace delete pvc zzaia-workspace-workspace-tools
> ```

---

## Available Commands Reference

| Command | Purpose | Definition |
|---------|---------|------------|
| `/behavior:workspace:repo` | Clone repo or create branch worktree | [↗](agents/claude/.claude/commands/behavior/workspace/repo.md) |
| `/behavior:devops:work-item` | Read or manage work items | [↗](agents/claude/.claude/commands/behavior/devops/work-item.md) |
| `/behavior:devops:pull-request` | Manage pull requests | [↗](agents/claude/.claude/commands/behavior/devops/pull-request.md) |
| `/behavior:devops:pipeline` | Run or debug CI/CD pipelines | [↗](agents/claude/.claude/commands/behavior/devops/pipeline.md) |
| `/behavior:devops:new-relic` | New Relic log diagnostics | [↗](agents/claude/.claude/commands/behavior/devops/new-relic.md) |
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
