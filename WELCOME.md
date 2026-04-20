# Welcome to ZZAIA Agentic Workspace

Claude Code agentic development environment — tools, MCP servers, and workspace repos pre-configured.

---

## Authenticate Claude Code

Open a terminal and run:

```bash
claude auth login
```

Follow the URL printed in the terminal. Auth tokens persist in the home volume across restarts.

**Alternatively**, set `ANTHROPIC_API_KEY` (or AWS Bedrock vars) in your env-file before `docker compose up`.

---

## Quick Commands

| Command | Purpose |
|---------|---------|
| `/develop [task]` | Full task clarification + development |
| `/behavior:ask` | Ask a question with research |
| `/behavior:workspace:repo` | Clone or manage workspace repos |
| `/workflow:remote:implement` | Full implementation workflow from work item to PR |
| `/behavior:devops:work-item` | Read or manage work items |

---

## MCP Tools

| Tool | Key Required |
|------|-------------|
| Web Search (Tavily) | `TAVILY_API_KEY` |
| Azure DevOps | `ADO_MCP_AUTH_TOKEN` + `AZURE_DEVOPS_ORGANIZATION` |
| Postman | `POSTMAN_API_KEY` |
| New Relic | `NEW_RELIC_API_KEY` |

MCP sidecars without a key exit cleanly — provide keys at next `docker compose up --force-recreate`.

---

## Documentation

- [QUICKSTART.md](../QUICKSTART.md) — step-by-step setup
- [ARCHITECTURE.md](../ARCHITECTURE.md) — system design and ADRs
- [CLAUDE.md](../CLAUDE.md) — command hierarchy and development standards
