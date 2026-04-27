# GEMINI.md

This file provides guidance to Gemini Code Assist when working with code in this repository.

## Repository Overview

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

## Development Workflow

1. **Task Clarification** - Analyze requirements, create specifications
2. **Implementation** - Language-specific architecture with comprehensive testing
3. **Quality Gates** - Build validation, test execution, code review
4. **Documentation** - Automated documentation updates
5. **Version Control** - Conventional commits across repositories

## Development Standards

Language-specific coding standards are defined in `.claude/commands/behavior/development/rules/` directory:

- Reference appropriate rule files based on project language/framework
- Follow established architectural patterns per language
- Maintain comprehensive documentation standards
- Implement testing strategies per language conventions

## Workspace Structure

Multi-repository workspace with git worktrees:

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
- Cross-repository feature development coordination
- Comprehensive testing per language conventions
- Automated documentation updates
- Conventional commits and version control
