# Bitwarden Secrets Manager Configuration

This cluster uses **Bitwarden Secrets Manager (BWS)** as its secrets backend via External Secrets Operator (ESO). This document specifies the required BWS secrets and the provisioning flow.

## Architecture

### Components

1. **Bitwarden Secrets Manager**  
   External secrets source (not deployed by this chart).

2. **bitwarden-sdk-server** (Helm chart)  
   Helper sidecar deployed in the `external-secrets` namespace by `deploy/ansible/roles/ring/tasks/main.yml`. Provides HTTP interface that ESO's Bitwarden provider calls to fetch secrets.
   - Service: `bitwarden-sdk-server.external-secrets.svc.cluster.local:5000`
   - Used by: ESO ClusterSecretStore (bitwardensecretsmanager provider)

3. **ESO ClusterSecretStore** (`zzaia-secrets-store`)  
   Created by `deploy/k8s/Chart/templates/clustersecretstore.yaml`.
   - Provider: `bitwardensecretsmanager`
   - References: `bitwarden-sdk-server` service + BWS access token secret

4. **External Secrets** (per-group)  
   One ExternalSecret per credential group (ai, integrations, mcp-github, ...), reconciled to k8s Secrets named `zzaia-workspace-secrets-<group>`.
   - Mapped in `deploy/k8s/Chart/values.yaml` under `externalSecrets.data`
   - Each references the ClusterSecretStore

### Secret Flow at Deploy Time

```
User runs: bash deploy/local.sh
  ↓
Prompts for: BWS_ACCESS_TOKEN (env override: --no-bws to skip)
  ↓
Creates Secret in external-secrets namespace: bitwarden-access-token
  - Key: credentials
  - Value: <BWS_ACCESS_TOKEN>
  ↓
Ansible installs bitwarden-sdk-server
  ↓
Chart creates ClusterSecretStore (references the bitwarden-access-token Secret)
  ↓
Chart creates ExternalSecrets (reference the ClusterSecretStore)
  ↓
ESO reconciles: fetches each secret from BWS via bitwarden-sdk-server
  ↓
Result: k8s Secrets in zzaia-agentic-workspace namespace (one per group)
```

## Required BWS Secrets

Create these secrets in Bitwarden Secrets Manager (one secret per entry, name must match exactly).

### Group: ai

| Secret Name | Value |
|-------------|-------|
| `anthropic-api-key` | Anthropic API key |
| `claude-code-oauth-token` | Claude Code OAuth token |
| `openai-api-key` | OpenAI API key |
| `gemini-api-key` | Google Gemini API key |
| `tavily-api-key` | Tavily search API key |
| `bifrost-virtual-key-claude-pro` | Bifrost virtual key for Claude Pro |
| `bifrost-virtual-key-agents-generic` | Bifrost virtual key for agents |

**Consumers:** workspace-server, bifrost-server, mcp-tavily, all IDE sidecars

### Group: integrations

| Secret Name | Value |
|-------------|-------|
| (reserved for future integrations) | — |

**Consumers:** (none currently)

### Group: mcp-github

| Secret Name | Value |
|-------------|-------|
| `github-personal-access-token` | GitHub PAT (repo, workflow, admin:repo_hook scopes) |

**Consumers:** mcp-github

### Group: mcp-azure-devops

| Secret Name | Value |
|-------------|-------|
| `ado-mcp-auth-token` | Azure DevOps PAT |
| `azure-devops-organization` | Azure DevOps organization name |

**Consumers:** mcp-azure-devops

### Group: mcp-azure-portal

| Secret Name | Value |
|-------------|-------|
| `azure-client-id` | Azure Entra app client ID |
| `azure-client-secret` | Azure Entra app client secret |
| `azure-tenant-id` | Azure tenant ID |
| `azure-subscription-id` | Azure subscription ID |

**Consumers:** mcp-azure-portal

### Group: mcp-postman

| Secret Name | Value |
|-------------|-------|
| `postman-api-key` | Postman API key |

**Consumers:** mcp-postman

### Group: mcp-aws

| Secret Name | Value |
|-------------|-------|
| `aws-access-key-id` | AWS IAM access key |
| `aws-secret-access-key` | AWS IAM secret access key |
| `aws-region` | AWS region (e.g., `us-east-1`) |

**Consumers:** mcp-aws-api

### Group: workspace

| Secret Name | Value |
|-------------|-------|
| `git-sidecar-agent-key` | SSH private key for git-sidecar agent (deploy key format) |
| `ssh-public-key` | SSH public key for workspace-server SSH access |

**Consumers:** workspace-server, git-sidecar

### Group: admin

| Secret Name | Value |
|-------------|-------|
| `admin-email` | Admin email address |
| `admin-password` | Admin password (used by workspace bootstrap) |

**Consumers:** workspace-server (bootstrap only)

## ClusterSecretStore Specification

The ClusterSecretStore uses the ESO `bitwardensecretsmanager` provider:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: zzaia-secrets-store
spec:
  provider:
    bitwardensecretsmanager:
      auth:
        secretRef:
          secretAccessKey:
            name: bitwarden-access-token
            namespace: external-secrets
            key: credentials
      organizationId: <BWS_ORGANIZATION_ID>  # Must be set in values-production.yaml
      bitwardenServerSDKURL: "http://bitwarden-sdk-server.external-secrets.svc.cluster.local:5000"
      # Optional:
      apiURL: ""  # Defaults to Bitwarden cloud
      identityURL: ""  # Defaults to Bitwarden cloud
      caBundle: ""  # For self-hosted Bitwarden with custom CA
```

## bitwarden-access-token Secret

Created at deploy time by `deploy/local.sh`:

```bash
kubectl create secret generic bitwarden-access-token \
  --from-literal=credentials=<BWS_ACCESS_TOKEN> \
  -n external-secrets \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Location:** `external-secrets` namespace  
**Name:** `bitwarden-access-token`  
**Key:** `credentials`  
**Value:** Service Account token from Bitwarden Secrets Manager (machine account)

To rotate:
```bash
export BWS_ACCESS_TOKEN=<new-token>
kubectl create secret generic bitwarden-access-token \
  --from-literal=credentials="${BWS_ACCESS_TOKEN}" \
  -n external-secrets \
  --dry-run=client -o yaml | kubectl apply -f -
```

ESO will pick up the new token on its next reconciliation (default: 1 hour).

## ExternalSecret Resources

One per group, named `zzaia-workspace-secrets-<group>`, in the `zzaia-agentic-workspace` namespace.

Example (ai group):

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: zzaia-workspace-secrets-ai
  namespace: zzaia-agentic-workspace
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: zzaia-secrets-store
    kind: ClusterSecretStore
  target:
    name: zzaia-workspace-secrets-ai
    creationPolicy: Owner
    deletionPolicy: Retain
  data:
    - secretKey: ANTHROPIC_API_KEY
      remoteRef:
        key: "anthropic-api-key"  # ← BWS secret name
    - secretKey: CLAUDE_CODE_OAUTH_TOKEN
      remoteRef:
        key: "claude-code-oauth-token"
    # ... more entries
```

Resulting k8s Secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: zzaia-workspace-secrets-ai
  namespace: zzaia-agentic-workspace
type: Opaque
data:
  ANTHROPIC_API_KEY: <base64-value>
  CLAUDE_CODE_OAUTH_TOKEN: <base64-value>
  # ... more keys
```

## Provisioning Checklist

1. **Before deploying:**
   - [ ] Create BWS organization and machine account
   - [ ] Note the machine account access token (use it with `--no-bws` to skip if not ready, or supply at deploy time)
   - [ ] Create all required secrets in BWS (see "Required BWS Secrets" table above)
   - [ ] Set `externalSecrets.bitwardensecretsmanager.organizationId` in `deploy/k8s/Chart/values-production.yaml`

2. **At deploy time:**
   - [ ] Run `bash deploy/local.sh`
   - [ ] When prompted, enter the BWS access token (or `--no-bws` to skip)
   - [ ] Verify ESO reconciliation:
     ```bash
     kubectl -n zzaia-agentic-workspace get externalsecret
     kubectl -n zzaia-agentic-workspace get secret -l app.kubernetes.io/instance=zzaia-workspace
     ```

3. **Troubleshooting:**
   - Check ClusterSecretStore:
     ```bash
     kubectl describe clustersecretstore zzaia-secrets-store
     ```
   - Check ExternalSecret status:
     ```bash
     kubectl -n zzaia-agentic-workspace describe externalsecret zzaia-workspace-secrets-ai
     ```
   - Check bitwarden-sdk-server logs:
     ```bash
     kubectl -n external-secrets logs deployment/bitwarden-sdk-server
     ```
   - Check ESO controller logs:
     ```bash
     kubectl -n external-secrets logs deployment/external-secrets
     ```

## Notes

- Secrets are refreshed hourly by default (`refreshInterval: 1h` in ExternalSecret spec).
- Each workload envFroms only the group(s) it needs (not all secrets at once) — see `zzaia-workspace.credentialsEnvFrom` helper in `_helpers.tpl`.
- Rotation: update the secret in BWS → ESO reconciles → workloads re-read the k8s Secret on next restart.
- The bitwarden-sdk-server is deployed with `ignore_errors: true` in Ansible; if it fails, Bitwarden Secrets Manager will still be configured in ESO, but secret fetch will fail until the SDK server is available.
