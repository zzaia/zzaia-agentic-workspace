# zzaia-agentic-workspace

Helm chart for the agentic development workspace, ported from
`docker/docker-compose.yml`. Namespace `zzaia-agentic-workspace`, release name
`zzaia-workspace`.

## What this chart does and does not deploy

| Deployed here | Consumed from `.Values.sharedInfraNamespace` (`infra`) |
|---|---|
| workspace-server, vscode / jupyter / containers-dev / tunnel sidecars | Vault (`vault-data-engine`) |
| dind-server (privileged), portainer-server | SigNoz (`signoz-data-engine`) |
| bifrost-server, ml-server | OTEL collector (`otel-collector-data-engine`) |
| database-qdrant, database-neo4j, git-sidecar | ClusterSecretStore `zzaia-secrets-store` |
| 11 MCP servers | PriorityClass `zzaia-critical`, RuntimeClass `nvidia` |

Dropped relative to compose:

- **vault-server** — the cluster Vault is reused, so the `vault-data` volume is gone too.
- **nginx-proxy** — Kong Ingress replaces it; its `server_name` blocks became `.Values.<service>.ingress`.
- **Bitwarden / BWS** (`bws_token` secret) — removed entirely. Azure Key Vault via
  External Secrets Operator is the only source of truth.

## Layout

```
Chart.yaml              chart metadata
values.yaml             THE CONTRACT — every service, image, volume, probe
values-production.yaml  Vultr VKE overlay (registry, storage, quota)
fleet.yaml              Fleet GitOps targets (local / production)
templates/_helpers.tpl  naming, labels, images, FQDNs, probes, securityContext
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
  --set externalSecrets.azurekv.vaultUrl=https://<vault>.vault.azure.net \
  --set externalSecrets.azurekv.clientId=<uuid> \
  --set externalSecrets.azurekv.tenantId=<uuid>
```

## Secrets

`externalSecrets.provider` is `azurekv` with `authType: WorkloadIdentity`, matching
the shape in `deploy/k8s/infra/Chart/templates/external-secrets-store.yaml`. The
`ClusterSecretStore` is **owned by the infra chart** — this chart references it and
does not recreate it (`createClusterSecretStore: false`).

`externalSecrets.data[]` maps Azure Key Vault secrets to keys in the namespace
Secret `zzaia-workspace-secrets`, which is mounted at `/secrets` and injected via
`envFrom`. Every `remoteKey` / `property` pair was read out of the container
entrypoints under `docker/containers/*/entrypoint.sh`, so the property names are
the exact environment variable names those scripts consume.

The Key Vault secret objects to create (nine JSON secrets, 23 credentials) and the
two-tier ephemeral-vs-durable provisioning contract are documented in
[`../AZURE_KEYVAULT.md`](../AZURE_KEYVAULT.md). Fleet reconciliation of this chart
is driven by [`../../fleet/gitrepo.yaml`](../../fleet/gitrepo.yaml) — applied once
to the cluster at bootstrap; it lives in this repo so the cluster repo carries no
workspace-specific manifest.

## Ingress

Kong, hosts `<subdomain>.workspace.zzaia.com`, TLS secret `zzaia-workspace-tls`
in this namespace. `zzaia-wildcard-tls` is **not** usable here — it covers
`*.fintech.zzaia.com` and lives in the infra namespace.

Local resolution uses a dnsmasq wildcard on the developer machine, installed by
[`../setup-workspace-dns.sh`](../setup-workspace-dns.sh) (run once on the k3s
host; split-DNS, leaves the cluster's own DNS untouched):

```
address=/workspace.zzaia.com/127.0.0.1
```

Hosts enabled by default: `vscode`, `aspire`, `jupyter`, `bifrost`, `headroom`,
`portainer`. `qdrant` and `neo4j` exist but are off.

SSH (workspace-server 2222, git-sidecar 2223) is TCP, which a Kong HTTP Ingress
cannot route. Use `kubectl port-forward`, or set
`workspaceServer.service.type=NodePort` with `sshNodePort`.

## Shared volumes (workspaceHome / workspaceTools)

`volumes.workspaceHome` and `volumes.workspaceTools` are mounted by several
workloads at once. `local-path` (the local default) doesn't support RWX, and
**no RWX-capable StorageClass exists in the finance-data-engine cluster repo
today** — `values-production.yaml` therefore uses `ReadWriteOnce` for both and
sets `.Values.nodeSelector` to pin every workload in the release to one node,
matching local's implicit single-node behavior. Either:

1. install an RWX-capable StorageClass (Longhorn / NFS) and switch both
   volumes back to `ReadWriteMany`, dropping the `nodeSelector`, or
2. keep the current RWO + `nodeSelector` pinning (the shipped default).

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
- Cross-namespace references use `zzaia-workspace.infraFqdn`. Same-namespace
  references use bare service names.
- Cluster-scoped object names go through `zzaia-workspace.clusterScopedName`,
  which prefixes `.Release.Namespace` so nothing collides with the infra chart.
- Every workload needs requests **and** limits, a real readiness and liveness
  probe (never `|| exit 0`), and a `securityContext`.

## Known issues

- **Cluster OTLP ingestion is broken** and must be fixed in the
  `zzaia-finance-data-engine` repo before telemetry from this chart lands
  anywhere. Three independent faults in the infra chart:
  1. `otel-collector-data-engine` is a DaemonSet with **no Service**, so
     `otel-collector-data-engine.infra.svc.cluster.local` does not resolve.
  2. The collector pod declares **no `containerPort`** for 4317/4318.
  3. Its pipelines export to `logging`, not `otlp`, and the `otlp` exporter
     targets `signoz-data-engine:4317` — a port the SigNoz StatefulSet never
     exposes (it opens 8080, 8085, 4320, 8090).

  `observability.otlpEndpoint` is therefore correct-by-construction but dead
  until that Service and those pipelines exist.

- **Three container UIDs are unverified.** `mcp-graphiti`, `mcp-headroom` and
  `database-qdrant` create their runtime user with `useradd -r` and no explicit
  UID, so the chart assumes `999`. If the real UID differs, the pod fails with
  `CreateContainerConfigError` (because `runAsNonRoot: true` is set). Either
  confirm the UID against the built image or pin a numeric `USER` in each
  Dockerfile.

- **`mcp-codegraph` runs as root.** Its Dockerfile declares no `USER`. Reflected
  honestly as `runAsUser: 0`; fix the image, then set a non-root UID here.
