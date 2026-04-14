# ZZAIA Container — Docker & Kubernetes

SSH-accessible Ubuntu container with all workspace tools provisioned via `mise.toml`.

---

## Prerequisites

- Docker or a Kubernetes cluster
- An SSH key pair — generate one if needed:
  ```bash
  ssh-keygen -t ed25519 -f zzaia_key -N ""
  ```

---

## Local — Docker Compose

```bash
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
docker compose -f docker/docker-compose.yml up -d
ssh -p 2222 zzaia@localhost
```

To rebuild after changes to `mise.toml`:

```bash
docker compose -f docker/docker-compose.yml build --no-cache
```

---

## Cluster — Kubernetes

### 1. Create namespace and secret

```bash
cp docker/k8s/secret-template.yaml docker/k8s/secret.yaml
# Edit secret.yaml — paste your public key into authorized_keys
kubectl apply -f docker/k8s/namespace.yaml
kubectl apply -f docker/k8s/secret.yaml
```

> `secret.yaml` is in `.gitignore` — never commit it.

### 2. Deploy

```bash
kubectl apply -f docker/k8s/deployment.yaml
kubectl apply -f docker/k8s/service.yaml
```

### 3. Connect

**Port-forward (recommended for internal access):**

```bash
kubectl port-forward svc/zzaia-workspace 2222:2222 -n zzaia
ssh -i zzaia_key -p 2222 zzaia@localhost
```

**External access (change Service type to LoadBalancer):**

```bash
kubectl patch svc zzaia-workspace -n zzaia -p '{"spec":{"type":"LoadBalancer"}}'
kubectl get svc zzaia-workspace -n zzaia  # copy EXTERNAL-IP
ssh -i zzaia_key -p 2222 zzaia@<EXTERNAL-IP>
```

---

## What's installed

All tools from `mise.toml` are provisioned at image build time:

| Category | Tools |
|----------|-------|
| Runtimes | Node.js LTS, Python 3.12, .NET 8 |
| CLI tools | Claude Code, Dapr, k6, D2 |
| Editor | VS Code (`code-server`) — browser-based on port 8080 |
| Data science | Miniforge3, conda envs (`venv-analytics`, `venv-development`) |
| Python packages | pypdf, python-docx, textual, jinja2, graphviz, diagrams |
| .NET tools | Aspire workload, Aspirate |
| System | tmux, PlantUML, git, build-essential |

---

## VS Code (code-server)

SSH into the container and start `code-server`:

```bash
ssh -p 2222 zzaia@localhost
code-server --bind-addr 0.0.0.0:8080 --auth none
```

Then open `http://localhost:8080` in your browser.

> For persistent settings, mount a volume at `/home/zzaia/.config/code-server`.

---

## Security

| Control | Docker | Kubernetes |
|---------|--------|------------|
| Host filesystem | No mounts | No hostPath volumes |
| Host network | Bridge only | `hostNetwork: false` |
| Host PID/IPC | Isolated | `hostPID/IPC: false` |
| K8s API | — | `automountServiceAccountToken: false` |
| Capabilities | Drop ALL + sshd minimum | Drop ALL + sshd minimum |
| Root login | Disabled | Disabled |
| Auth | SSH key only | SSH key only (Secret) |

Minimum capabilities retained for sshd: `AUDIT_WRITE`, `CHOWN`, `FOWNER`, `SETGID`, `SETUID`.

---

## Files

```
docker/
├── Dockerfile              — Image definition
├── entrypoint.sh           — SSH key injection + sshd startup
├── sshd_config             — Port 2222, key-auth only
├── docker-compose.yml      — Local deployment
└── k8s/
    ├── namespace.yaml       — zzaia namespace
    ├── deployment.yaml      — Pod with isolation controls
    ├── service.yaml         — ClusterIP on port 2222
    └── secret-template.yaml — Copy → secret.yaml, add your public key
```
