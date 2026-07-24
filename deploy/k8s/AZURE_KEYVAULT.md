# Agentic Workspace secrets — Azure Key Vault (External Secrets Operator)

**Bitwarden Secrets Manager (BWS) is retired — Azure Key Vault is the sole source of truth for the agentic workspace.** The old flow (`BWS_ACCESS_TOKEN` into a `vault-server` container, secrets managed via a Vault UI) is gone. On the cluster, the workspace chart's `ExternalSecret` fetches these values from Key Vault through the shared `zzaia-secrets-store` `ClusterSecretStore` (Azure Key Vault provider, WorkloadIdentity auth) that the cluster already exposes. No secret ever lives in Git or in a chart value.

> **Prerequisite (cluster side, one-time):** the Key Vault, the WorkloadIdentity client, and the `zzaia-secrets-store` ClusterSecretStore are provisioned by the cluster repo (`zzaia-finance-data-engine`, see its `deploy/AZURE_SETUP.md`). This document covers only the **workspace-specific secret objects**; it adds nothing to the cluster repo.

## How the workspace reads Key Vault (JSON secrets, not flat)

The workspace `ExternalSecret` reads **JSON-valued** Key Vault secrets and extracts individual fields with `remoteRef.property`. Each Key Vault secret below holds one JSON object; the JSON keys are the exact environment-variable names the container `entrypoint.sh` scripts consume (underscores allowed — they are JSON keys, not Key Vault secret names). Key Vault secret **names** allow only letters, numbers, and dashes, which is why they are grouped (`ai`, `mcp-github`, …) rather than one-per-variable.

Nine JSON secrets cover all 23 workspace credentials:

| Key Vault secret name | JSON keys (properties) |
|---|---|
| `ai` | `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TAVILY_API_KEY`, `BIFROST_VIRTUAL_KEY_CLAUDE_PRO`, `BIFROST_VIRTUAL_KEY_AGENTS_GENERIC` |
| `integrations` | `NEW_RELIC_API_KEY` |
| `mcp-github` | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `mcp-azure-devops` | `ADO_MCP_AUTH_TOKEN`, `AZURE_DEVOPS_ORGANIZATION` |
| `mcp-azure-portal` | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `mcp-postman` | `POSTMAN_API_KEY` |
| `mcp-aws` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` |
| `workspace` | `GIT_SIDECAR_AGENT_KEY`, `SSH_PUBLIC_KEY` |
| `admin` | `email`, `password` |

`admin` is the **same secret** the infra chart already reads (`admin`/`email`, `admin`/`password`); if the cluster repo set it up for infra you do not create it again here. The other eight are workspace-only.

## Store them

Set each secret's value to a JSON document, using the `$KV_NAME` from the cluster repo's Key Vault setup:

```bash
KV_NAME="<your-keyvault-name>"

az keyvault secret set --vault-name "$KV_NAME" --name "ai" --value '{
  "ANTHROPIC_API_KEY": "sk-ant-...",
  "CLAUDE_CODE_OAUTH_TOKEN": "...",
  "OPENAI_API_KEY": "sk-...",
  "GEMINI_API_KEY": "AIza...",
  "TAVILY_API_KEY": "tvly-...",
  "BIFROST_VIRTUAL_KEY_CLAUDE_PRO": "sk-bf-claude-pro-001",
  "BIFROST_VIRTUAL_KEY_AGENTS_GENERIC": "sk-bf-agents-generic-001"
}'

az keyvault secret set --vault-name "$KV_NAME" --name "integrations" --value '{
  "NEW_RELIC_API_KEY": "NRAK-..."
}'

az keyvault secret set --vault-name "$KV_NAME" --name "mcp-github" --value '{
  "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..."
}'

az keyvault secret set --vault-name "$KV_NAME" --name "mcp-azure-devops" --value '{
  "ADO_MCP_AUTH_TOKEN": "...",
  "AZURE_DEVOPS_ORGANIZATION": "https://dev.azure.com/<org>"
}'

az keyvault secret set --vault-name "$KV_NAME" --name "mcp-azure-portal" --value '{
  "AZURE_CLIENT_ID": "...",
  "AZURE_CLIENT_SECRET": "...",
  "AZURE_TENANT_ID": "...",
  "AZURE_SUBSCRIPTION_ID": "..."
}'

az keyvault secret set --vault-name "$KV_NAME" --name "mcp-postman" --value '{
  "POSTMAN_API_KEY": "PMAK-..."
}'

az keyvault secret set --vault-name "$KV_NAME" --name "mcp-aws" --value '{
  "AWS_ACCESS_KEY_ID": "AKIA...",
  "AWS_SECRET_ACCESS_KEY": "...",
  "AWS_REGION": "us-east-1"
}'

az keyvault secret set --vault-name "$KV_NAME" --name "workspace" --value '{
  "GIT_SIDECAR_AGENT_KEY": "-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----",
  "SSH_PUBLIC_KEY": "ssh-ed25519 AAAA..."
}'

# Shared with the infra chart — skip if already created for infra:
az keyvault secret set --vault-name "$KV_NAME" --name "admin" --value '{
  "email": "you@zzaia.com",
  "password": "<a-strong-password>"
}'
```

Notes:
- `GIT_SIDECAR_AGENT_KEY` is a multi-line PEM private key — embed real newlines as `\n` inside the JSON string (as shown) so the value round-trips through Key Vault intact.
- The `BIFROST_VIRTUAL_KEY_*` values shown match the chart's Bifrost defaults; override only if you rotate them.
- The WorkloadIdentity client that reads these must hold **Key Vault Secrets User** on the vault — this is the identity referenced by `externalSecrets.azurekv.clientId`/`tenantId` in this chart's `values-production.yaml`.

---

## Local development (in-cluster Vault instead of Key Vault)

`values.yaml`'s default `externalSecrets.provider` is `azurekv`, but a local
cluster's `zzaia-secrets-store` may instead be backed by the cluster repo's
own in-cluster Vault (its default local provider). The `ExternalSecret`
objects this chart creates only reference the shared `ClusterSecretStore` by
name — they work identically against either backend. **This section adds
nothing to the cluster repo**: it only documents how to seed the SAME nine
credential groups into whichever Vault the cluster's `zzaia-secrets-store`
already points at, using that Vault's existing generic `zzaia-read` policy
(any key under the KV mount, not workspace-specific) and its existing
Kubernetes auth role — both already set up for any consumer, no changes
needed on the cluster side.

```bash
# Get the Vault root token (cluster repo's own bootstrap secret, "infra" ns)
ROOT_TOKEN=$(kubectl get secret vault-bootstrap-secret -n infra \
  -o jsonpath="{.data.root-token}" | base64 -d)

# Reach Vault from outside the cluster
kubectl port-forward -n infra svc/vault-data-engine 8200:8200 &
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="$ROOT_TOKEN"

vault kv put zzaia/ai \
  ANTHROPIC_API_KEY="sk-ant-..." \
  CLAUDE_CODE_OAUTH_TOKEN="..." \
  OPENAI_API_KEY="sk-..." \
  GEMINI_API_KEY="AIza..." \
  TAVILY_API_KEY="tvly-..." \
  BIFROST_VIRTUAL_KEY_CLAUDE_PRO="sk-bf-claude-pro-001" \
  BIFROST_VIRTUAL_KEY_AGENTS_GENERIC="sk-bf-agents-generic-001"

vault kv put zzaia/integrations NEW_RELIC_API_KEY="NRAK-..."
vault kv put zzaia/mcp-github GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."
vault kv put zzaia/mcp-azure-devops \
  ADO_MCP_AUTH_TOKEN="..." \
  AZURE_DEVOPS_ORGANIZATION="https://dev.azure.com/<org>"
vault kv put zzaia/mcp-azure-portal \
  AZURE_CLIENT_ID="..." \
  AZURE_CLIENT_SECRET="..." \
  AZURE_TENANT_ID="..." \
  AZURE_SUBSCRIPTION_ID="..."
vault kv put zzaia/mcp-postman POSTMAN_API_KEY="PMAK-..."
vault kv put zzaia/mcp-aws \
  AWS_ACCESS_KEY_ID="AKIA..." \
  AWS_SECRET_ACCESS_KEY="..." \
  AWS_REGION="us-east-1"
vault kv put zzaia/workspace \
  GIT_SIDECAR_AGENT_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----" \
  SSH_PUBLIC_KEY="ssh-ed25519 AAAA..."

# admin/email+password: shared with the infra chart, skip if already seeded
```

Property names are identical to the Azure Key Vault table above — the
`ExternalSecret.data[].property` field is provider-agnostic. Set
`externalSecrets.provider: vault` and `externalSecrets.vault.*` in a values
override if the cluster's `zzaia-secrets-store` uses the vault provider
rather than azurekv (check the cluster repo's own
`deploy/k8s/infra/Chart/values.yaml` `externalSecrets.provider` to confirm
which one is actually live).

---

## Two-tier provisioning contract: ephemeral vs. durable

Provisioning happens at two tiers, and only one survives a cluster rebuild. Know which tier you are writing to before you create anything.

**Tier 1 — Ephemeral (imperative, in-cluster).** Agents and operators can create objects imperatively inside the `zzaia-agentic-workspace` namespace via the chart's namespaced `Role` (`kubectl create/apply`, an agent granted namespace-scoped RBAC). These live only in the running cluster's etcd. They are **lost the moment the cluster is rebuilt** — Fleet reconciles **only** what is committed in Git. Treat Tier 1 as scratch space: fine for probing, debugging, and throwaway experiments; never a system of record.

**Tier 2 — Durable (declarative, Git-committed).** Anything that must outlive a rebuild — a workload, a Service, a PVC, an ExternalSecret, an Ingress host, an RBAC grant, a namespace default (LimitRange/ResourceQuota) — **MUST land as a commit** in this chart (`deploy/k8s/Chart/`), which the workspace `GitRepo` (`deploy/fleet/gitrepo.yaml`) watches. Fleet re-applies committed state on every reconcile and after every rebuild.

**The rule:** if losing it on the next rebuild would be a problem, it belongs in a commit, not in the cluster. Secrets follow the same contract one level down: the desired-state *reference* (the `ExternalSecret`) is committed to Git, while the secret *value* lives in Azure Key Vault and is re-fetched on every reconcile — so even secrets survive a rebuild without ever being committed in plaintext.
