# zzaia-agentic-workspace

Helm chart for the agentic development workspace, ported from
`docker/docker-compose.yml`. Namespace `zzaia-agentic-workspace`, release name
`zzaia-workspace`.

## What this chart does and does not deploy

| Deployed here |
|---|
| workspace-server, vscode / jupyter / containers-dev / tunnel sidecars |
| dind-server (privileged), portainer-server |
| bifrost-server, ml-server |
| database-qdrant, database-neo4j, git-sidecar |
| 11 MCP servers |
| **ClusterSecretStore** `zzaia-secrets-store` (Bitwarden Secrets Manager) |
| Kong ingress controller (part of bootstrap ring) |
| External Secrets Operator (pre-installed, part of bootstrap ring) |

Dropped relative to compose:

- **vault-server**, **nginx-proxy** — replaced by Bitwarden Secrets Manager + Kong
- **signoz-server, mcp-signoz, mcp-newrelic** — observability moved to AppHost
- **SigNoz/OTEL** — not deployed by this chart

## Layout

```
Chart.yaml              chart metadata
values.yaml             THE CONTRACT — every service, image, volume, probe
values-production.yaml  Production overlay (storage, quota)
fleet.yaml              Fleet GitOps targets (local / production)
templates/_helpers.tpl  naming, labels, images, FQDNs, probes, securityContext
templates/clustersecretstore.yaml   Bitwarden Secrets Manager ClusterSecretStore
templates/externalsecrets.yaml      Per-group ExternalSecrets for credential sync
templates/limitrange.yaml
templates/resourcequota.yaml
templates/NOTES.txt
```

## Install

```bash
helm upgrade --install zzaia-workspace ./Chart \
  -n zzaia-agentic-workspace --create-namespace \
  -f Chart/values.yaml
```

Production:

```bash
helm upgrade --install zzaia-workspace ./Chart \
  -n zzaia-agentic-workspace --create-namespace \
  -f Chart/values.yaml -f Chart/values-production.yaml \
  --set externalSecrets.bitwardensecretsmanager.organizationId=<org-uuid>
```

## Secrets

This chart **creates its own ClusterSecretStore** (`zzaia-secrets-store`) that
references Bitwarden Secrets Manager via the ESO `bitwardensecretsmanager` provider.

**Wiring:**
1. **ClusterSecretStore** (`templates/clustersecretstore.yaml`): points at
   `bitwarden-sdk-server.external-secrets.svc.cluster.local:5000` and the
   `bitwarden-access-token` Secret (created at deploy time).
2. **ExternalSecrets** (`templates/externalsecrets.yaml`): one per credential group
   (ai, mcp-github, mcp-aws, etc.). Each syncs from BWS to a per-group k8s Secret
   named `zzaia-workspace-secrets-<group>` with 1-hour refresh.
3. **Credential consumption**: each workload's `envFrom` references only the
   group(s) it needs, not all secrets.

**Required at deploy time:**
- Bitwarden Secrets Manager access token (supplied via `deploy/local.sh`, creates
  the `bitwarden-access-token` Secret in the `external-secrets` namespace)
- `externalSecrets.bitwardensecretsmanager.organizationId` (set via `--set` or
  `values-production.yaml`)

**Required in Bitwarden Secrets Manager:**
See [`../BWS_SECRETS.md`](../BWS_SECRETS.md) for the full list of required secrets
and their consumer groups.

## Ingress

Kong, hosts `<subdomain>.workspace.zzaia.com`, TLS secret `zzaia-workspace-tls`
in this namespace.

Only **ml-server** (subdomain `headroom`) is exposed by default. All other services
have `ingress.enabled: false`.

Local resolution uses a dnsmasq wildcard on the developer machine (installed by
the Ansible `dns` role during `deploy/local.sh host`):

```
address=/workspace.zzaia.com/127.0.0.1
```

SSH (workspace-server 2222, git-sidecar 2223) is TCP, which Kong cannot route.
Use `kubectl port-forward`, or set `workspaceServer.service.type=NodePort` with
`sshNodePort`.

## Shared volumes (workspaceHome / workspaceTools)

`volumes.workspaceHome` and `volumes.workspaceTools` are mounted by several
workloads at once. `local-path` (the local default) doesn't support RWX, so
**this chart pins every workload to a single node** via `nodeSelector`, matching
local k3s's implicit single-node behavior.

`/opt/tools` deliberately stays a PVC populated at runtime by the workspace-server
Ansible bootstrap. It is never baked into an image. Nothing that mounts it becomes
Ready until `/opt/tools/.bootstrap/tools.ready` exists — up to 30 minutes cold.

## Resources

`limits` are taken verbatim from each compose service's `deploy.resources.limits`.
Compose declared no `requests` (except portainer-server's 256M reservation), so
every `requests` value in `values.yaml` is a **chosen** default of roughly 25–50%
of the limit. Tune against real usage.

## Conventions for template authors

- Labels come from `zzaia-workspace.componentLabels`; selectors from
  `zzaia-workspace.componentSelectorLabels`. Never hand-write either.
- Images come from `zzaia-workspace.image` / `zzaia-workspace.imageByKey`. Both
  `fail` the render on a bare `latest` tag.
- Cross-namespace references use `zzaia-workspace.infraFqdn`.
- Cluster-scoped object names go through `zzaia-workspace.clusterScopedName`,
  which prefixes `.Release.Namespace`.
- Every workload needs requests **and** limits, a real readiness and liveness
  probe (never `|| exit 0`), and a `securityContext`.

## Known issues

- **Three container UIDs are unverified.** `mcp-graphiti`, `mcp-headroom` and
  `database-qdrant` create their runtime user with `useradd -r` and no explicit
  UID, so the chart assumes `999`. If the real UID differs, the pod fails with
  `CreateContainerConfigError` (because `runAsNonRoot: true` is set). Either
  confirm the UID against the built image or pin a numeric `USER` in each
  Dockerfile.

- **`mcp-codegraph` runs as root.** Its Dockerfile declares no `USER`. Reflected
  honestly as `runAsUser: 0`; fix the image, then set a non-root UID here.
