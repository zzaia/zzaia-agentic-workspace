# ZZAIA Container — Docker

Ubuntu container with all workspace tools provisioned via `mise.toml`. Accessible via SSH and browser-based VS Code.

---

## Prerequisites

- Docker
- An SSH key pair — generate one if needed:
  ```bash
  ssh-keygen -t ed25519 -f zzaia_key -N ""
  ```

---

## Run

```bash
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
docker compose -f docker/docker-compose.yml up -d
```

To rebuild after changes:

```bash
docker compose -f docker/docker-compose.yml build --no-cache
```

---

## VS Code (code-server)

`code-server` starts automatically at container startup. Open in browser:

```
http://localhost:8080
```

The Claude Code extension is pre-installed. Logs:

```bash
docker exec zzaia-workspace cat /tmp/code-server.log
```

> For persistent settings, mount a volume at `/home/zzaia/.config/code-server`.

---

## SSH

```bash
ssh -p 2222 zzaia@localhost
```

---

## Browser authentication (OAuth flows)

The container is headless — tools that open a browser will instead print the URL to the terminal. Copy-paste it into your local browser.

---

## What's installed

| Category | Tools |
|----------|-------|
| Runtimes | Node.js LTS, Python 3.12, .NET 8 |
| CLI tools | Claude Code CLI, Dapr, k6, D2, Mermaid |
| Editor | code-server + Claude Code extension — browser on port 8080 |
| Data science | Miniforge3, conda envs (`venv-analytics`, `venv-development`) |
| Python packages | pypdf, python-docx, textual, jinja2, graphviz, diagrams |
| .NET tools | Aspire workload, Aspirate |
| System | tmux, PlantUML, tectonic, git, build-essential |

---

## Container logs

```bash
docker logs zzaia-workspace          # sshd logs
docker exec zzaia-workspace cat /tmp/code-server.log  # code-server logs
```

---

## Security

| Control | Value |
|---------|-------|
| Host filesystem | No mounts |
| Host network | Bridge only, ports bound to 127.0.0.1 |
| Capabilities | Drop ALL + sshd minimum |
| Root login | Disabled |
| Auth | SSH key only |

Minimum capabilities: `AUDIT_WRITE`, `CHOWN`, `FOWNER`, `SETGID`, `SETUID`.

---

## Files

```
docker/
├── Dockerfile        — Image definition
├── entrypoint.sh     — code-server + sshd startup, SSH key injection
├── sshd_config       — Port 2222, key-auth only
└── docker-compose.yml — Local deployment
```
