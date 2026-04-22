# ZZAIA Agentic Workspace

Multi-language development environment with Claude Code, MCP tools, and integrated workspace repositories.

## Getting Started

### Step 1: Access the Workspace

Open the code-server URL in your browser (default: `http://localhost:8080`) to access VS Code.

### Step 2: Authenticate Claude Code

Option A: Use environment variables (recommended for automation)
```bash
export ANTHROPIC_API_KEY="your-api-key"
# or AWS Bedrock
export ANTHROPIC_BEDROCK_BASE_URL="your-bedrock-url"
export AWS_ACCESS_KEY_ID="your-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="your-region"
```

Option B: Use interactive login
```bash
claude auth login
```

When prompted, open the OAuth URL in your browser. If the callback fails:
- Manual token: paste the token printed in the terminal
- Port forward: expose port 10000 or use code-server proxy at `localhost:8080/proxy/10000/`

### Step 3: Clone Repositories

Clone workspace repositories with the repository management command:
```bash
/behavior:workspace:repo --action new --repo https://github.com/org/repo.git
```

### Step 4: Start Developing

Common development tasks:

```bash
# Full task clarification and implementation
/develop implement user authentication

# Ask questions about the codebase
/behavior:ask how does the authentication work?

# Manage Azure DevOps work items
/behavior:devops:work-item --action list --project MyProject

# Complete implementation workflow from work item to PR
/workflow:remote:implement

# Set up Aspire AppHost with services
/behavior:workspace:apphost --action setup --applications "my-service"

# Build and test
/build my-repo main
/test my-repo main
```

## MCP Tools

External tools require API keys. Provide them via environment variables or add to `docker/docker-compose.yml` before starting.

| Tool | Environment Variable | Purpose |
|------|----------------------|---------|
| Tavily Search | `TAVILY_API_KEY` | Web research and crawling |
| Azure DevOps | `ADO_MCP_AUTH_TOKEN`, `AZURE_DEVOPS_ORGANIZATION` | Work items, repositories, pipelines |
| Postman | `POSTMAN_API_KEY` | API testing and documentation |
| New Relic | `NEW_RELIC_API_KEY` | Application monitoring and diagnostics |

Services without keys exit cleanly and disable their tools. Provide keys at next restart:
```bash
docker compose up --force-recreate
```

## Documentation

- [QUICKSTART.md](QUICKSTART.md) — step-by-step setup and configuration
- [ARCHITECTURE.md](ARCHITECTURE.md) — system design, ADRs, and patterns
- [CLAUDE.md](CLAUDE.md) — command hierarchy, agent structure, and development standards
- [CLAUDE.md - Development Workflow](CLAUDE.md#development-workflow) — task execution pipeline
