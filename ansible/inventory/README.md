# Ansible Inventory

Place static inventory files in this directory.

## Inventory File Examples

### VM Groups

Define host groups in your inventory files:

- **`[workspace]`** — Workspace VMs with workspace-server + sidecars
- **`[ml]`** — ML server VMs (headroom proxy)
- **`[databases]`** — Database VMs (PostgreSQL, Redis, RabbitMQ, Qdrant, Neo4j)
- **`[mcp]`** — MCP services VMs (can overlap with workspace)

### Inventory File Format

Create `vm.ini` or similar:

```ini
[workspace]
workspace-01 ansible_host=10.0.1.10 ansible_user=ubuntu ansible_become=yes

[ml]
ml-01 ansible_host=10.0.1.20 ansible_user=ubuntu ansible_become=yes

[databases]
db-01 ansible_host=10.0.1.30 ansible_user=ubuntu ansible_become=yes

[mcp]
mcp-01 ansible_host=10.0.1.40 ansible_user=ubuntu ansible_become=yes
```

### Playbook Tags

Run plays with specific tags to deploy optional services:

```bash
# Install only VS Code and Jupyter on workspace
ansible-playbook site.yml --tags vscode,jupyter

# Install only MCP services
ansible-playbook site.yml --tags mcp

# Install GPU support
ansible-playbook site.yml --tags gpu

# Install specific MCP service
ansible-playbook site.yml --tags mcp-tavily
```

### Available Tags

- `vscode` — VS Code Server
- `jupyter` — Jupyter Lab
- `tunnel` — VS Code Tunnel
- `devcontainer` — Dev Containers support
- `gpu` — GPU support (CUDA, torch)
- `credentials` — GitHub/credentials setup
- `mcp` — All MCP services
- `mcp-tavily`, `mcp-github`, `mcp-azure-devops`, `mcp-postman`, `mcp-newrelic`, `mcp-playwright`, `mcp-headroom` — Individual MCP services
- `databases` — All database roles
- `qdrant` — Qdrant vector database
- `neo4j` — Neo4j graph database
