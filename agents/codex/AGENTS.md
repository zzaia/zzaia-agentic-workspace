# AGENTS.md

This file provides guidance to Codex CLI when working with code in this repository.

## Repository Overview

Multi-agent orchestration system for multi-language development workflows across repositories, using git worktrees and architectural principles.

## MCP Tools

Four MCP connections are configured:

| MCP | Interaction | How to Interact | Use When | Example Tools |
|---|---|---|---|---|
| **bifrost** | Bifrost Code Mode | `listToolFiles()` → `getToolDocs(name, fn)` → `executeToolCode(code)` — Python/Starlark sandbox; `result["key"]` syntax (not dot notation); no async/await; assign final output to `result` | Aggregated work tools: web research, DevOps tickets/PRs, API testing, observability, cloud ops | tavily, azure_devops, postman, github, newrelic, playwright, aws_cloudwatch, aws_cloudwatch_xray, aws_ecs, aws_sns_sqs, aws_postgres (AWS tools require Vault credentials) |
| **headroom** | Direct (not through bifrost) | HTTP MCP tool call to `mcp-headroom` | Explicit compression control, or recovering an original prompt lost to automatic compression (1-hour retrieval window) | `headroom_compress`, `headroom_retrieve(hash)`, `headroom_stats` |
| **aspire** | Direct (not through bifrost) | stdio subprocess (local CLI) | Inspecting/managing the local Aspire AppHost — resources, containers, telemetry | resource listing, container start/stop, log/telemetry queries |
| **codegraph** | Direct (not through bifrost) | SSE connection to Neo4j-backed graph service | Cross-file relationship queries (callers, class hierarchies, call chains) that plain text search can't answer — use grep/file search for simple string lookups instead | `find_code`, `analyze_code_relationships`, `execute_cypher_query` (27 tools total) |

**Not yet wired**: OpenMemory MCP (persistent, semantic cross-session memory) is documented in ADR 012 but not configured in any agent yet.

Rules: use `result["key"]` syntax (not dot notation), no async/await, assign final output to `result` variable. `headroom` tools are available directly (not through Code Mode).

## Development Workflow

1. **Task Clarification** - Analyze requirements, create specifications
2. **Implementation** - Language-specific architecture with comprehensive testing
3. **Quality Gates** - Build validation, test execution, code review
4. **Documentation** - Automated documentation updates
5. **Version Control** - Conventional commits across repositories

## Commands

Codex must read and follow command definitions from `~/.claude/plugins/marketplaces/zzaia/.claude/commands/` before execution. All agents share the same command patterns:

- `/develop [task]` - Full task clarification and development workflow
- `/build <repo> <branch>` - Multi-framework build with error reporting
- `/test <repo> <branch>` - Comprehensive testing with coverage analysis
- `/migrations <repo> <branch> <action> [name]` - EF Core migrations management
- `/behavior:*` - Execute single domain operations
- `/workflow:*` - Orchestrate end-to-end tasks
- `/orchestrator:*` - Multi-item coordination

Read command file EXECUTION/WORKFLOW/DELEGATION instructions and apply them exactly as written.

## Development Standards

Language-specific coding standards are defined in `~/.claude/plugins/marketplaces/zzaia/.claude/commands/behavior/development/rules/` directory:

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
