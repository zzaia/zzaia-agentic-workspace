# ZZAIA Agentic Workspace — Kubernetes deployment

This directory holds the Helm chart (`Chart/`) and the image build pipeline
(`build-images.sh`) that deploy the agentic workspace to a single-node k3s
cluster provisioned via Ansible. The container **images are unchanged** — every
`zzaia-*` image is still built from `docker/containers/*/Dockerfile` with the
exact build context Compose used.

## Architecture Overview

The deployment is **self-contained and self-provisioning**:

1. **Host provisioning** (Ansible `site.yml`): k3s cluster, local OCI registry,
   Kong ingress, External Secrets Operator, bitwarden-sdk-server, Fleet (standalone),
   and dnsmasq wildcard DNS.
2. **Secrets**: Bitwarden Secrets Manager via ESO (ClusterSecretStore + ExternalSecrets).
   Access token supplied at deploy time, never stored in git.
3. **Workloads**: Fleet pull-mode reconciliation from this public repo (see
   `deploy/fleet/gitrepo.yaml`). Only ml-server exposed via Kong ingress.

## Prerequisites

Run `bash deploy/local.sh` on a Linux host with:
- sudo access (for systemd, networking, Docker)
- 16+ GB RAM, 50+ GB disk
- Internet access (k3s, Helm repos, container images, Bitwarden)

The script will prompt for the **Bitwarden Secrets Manager access token**
(or skip with `--no-bws` if not ready yet).

## Deployment

### One-command setup

```bash
# Provisions k3s cluster, deploys all infrastructure, builds images, and reconciles workloads
bash deploy/local.sh
```

This runs the full flow: Ansible provisioning → TLS setup → image build/push → Fleet deployment.

### Step-by-step (if needed)

```bash
# Just host provisioning (k3s + ring infrastructure)
bash deploy/local.sh host

# Just app deployment (images + workloads)
bash deploy/local.sh app

# Pause all workloads without destroying infrastructure
bash deploy/local.sh pause

# Resume workloads
bash deploy/local.sh resume

# Delete app namespaces (keep cluster + bootstrap ring)
bash deploy/local.sh reset

# Completely remove the cluster
bash deploy/local.sh teardown
```

## Build and push images

`build-images.sh` builds every surviving `zzaia-*` image, tags each with an
**immutable** tag (the git short SHA) plus a **moving alias** (`latest` by
default), pushes both to the registry, and writes a Helm values overlay
(`Chart/values-images.yaml`) that pins `images.<name>.tag` to the immutable tag.

```bash
# Build + push all 22 images, write Chart/values-images.yaml
bash deploy/k8s/build-images.sh
# or, from the docker/ directory:
make k8s-images
```

Useful flags (`--help` for the full list):

| Flag | Purpose | Default |
|------|---------|---------|
| `-r, --registry HOST[:PORT]` | Target registry | `localhost:5000` |
| `-t, --tag TAG` | Immutable tag | git short SHA (`.dirty` if the tree is dirty) |
| `-a, --alias ALIAS` | Moving alias also pushed | `latest` |
| `-o, --overlay FILE` | Overlay path to write | `Chart/values-images.yaml` |
| `--set-string` | Also print a `--set-string` snippet | off |
| `--no-push` | Build only; skip push and overlay | off |
| `-l, --list` | List the image keys and exit | — |

```bash
# Rebuild only two services at an explicit tag
bash deploy/k8s/build-images.sh --tag 1.4.0 mlServer mcpGithub

# Production registry + a named alias
REGISTRY=sjc.vultrcr.com/zzaia bash deploy/k8s/build-images.sh --alias prod
```

## Secrets provisioning

See [`BWS_SECRETS.md`](./BWS_SECRETS.md) for:
- Required Bitwarden Secrets Manager secrets and their consumer groups
- How the BWS access token is supplied and managed
- ClusterSecretStore and ExternalSecret wiring
- Rotation procedures

## Chart deployment (manual Helm, without GitOps)

If you prefer not to use Fleet:

```bash
helm upgrade --install zzaia-workspace deploy/k8s/Chart \
  --namespace zzaia-agentic-workspace --create-namespace \
  -f deploy/k8s/Chart/values.yaml \
  -f deploy/k8s/Chart/values-production.yaml \
  -f deploy/k8s/Chart/values-images.yaml
```

## Images

22 images map one-to-one to the chart's `images.<key>` entries. Run
`bash deploy/k8s/build-images.sh --list` for the current list. Build contexts
match Compose: all use the repository root except `dind` (its own directory).
`vault-server`, `nginx-proxy`, `signoz-server`, `mcp-signoz`, and `mcp-newrelic`
are intentionally absent (observability moved to AppHost, secrets via Bitwarden,
Kong replaces nginx).
