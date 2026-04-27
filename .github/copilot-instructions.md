# GitHub Copilot Custom Instructions

## Workspace Context

Multi-agent orchestration system for multi-language development workflows across repositories, using git worktrees and architectural principles.

## Available MCP Tools

Seven MCP servers are provisioned for workspace development:

- **tavily** — Web search, content extraction, and crawling
- **azure-devops** — Repository, pipeline, work item, and wiki management
- **postman** — API testing, collection, and environment management
- **new-relic** — Monitoring, diagnostics, and observability
- **github** — GitHub repository and issue operations
- **playwright** — Browser automation, screenshots, and DOM inspection
- **aspire** — AppHost resource inspection, container management, and telemetry

## Development Conventions

- Reference appropriate rule files in `.claude/commands/behavior/development/rules/` based on project language/framework
- Follow established architectural patterns per language
- Implement comprehensive testing per language conventions
- Use conventional commits for version control
- Maintain cross-repository feature development coordination

## Workspace Structure

```
workspace/
├── {repo}.worktrees/
│   ├── master/              # Reference branch
│   ├── feature/{name}/      # Feature branches
│   └── repository-metadata.json
└── host/                    # Aspire AppHost template
```

## Key Principles

- Language-appropriate architecture across all projects
- Comprehensive testing per language conventions
- Automated documentation updates
- Conventional commits and version control
- Multi-repository coordination via git worktrees
