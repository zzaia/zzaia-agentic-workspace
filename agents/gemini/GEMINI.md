# GEMINI.md

This file provides guidance to Gemini Code Assist when working with code in this repository.

## Repository Overview

Multi-agent orchestration system for multi-language development workflows across repositories, using git worktrees and architectural principles.

## Available MCP Tools

Three MCP connections are configured:

- **bifrost** — MCP gateway aggregating all work tools via Code Mode (tavily, azure-devops, postman, new-relic, github, playwright)
- **headroom** — Memory context injection (direct, not through bifrost)
- **aspire** — AppHost resource inspection, container management, and telemetry (local CLI)

## MCP via Bifrost Code Mode

When tools available are `listToolFiles`, `readToolFile`, `getToolDocs`, `executeToolCode` — bifrost Code Mode is active:
- `listToolFiles()` → discover available tool servers
- `readToolFile(name)` → load compact Python function signatures
- `getToolDocs(name, fn)` → get detailed docs for a specific function
- `executeToolCode(code)` → run Python orchestration code in sandbox

Rules: use `result["key"]` syntax (not dot notation), no async/await, assign final output to `result` variable. `headroom` tools are available directly (not through Code Mode).

## Development Workflow

1. **Task Clarification** - Analyze requirements, create specifications
2. **Implementation** - Language-specific architecture with comprehensive testing
3. **Quality Gates** - Build validation, test execution, code review
4. **Documentation** - Automated documentation updates
5. **Version Control** - Conventional commits across repositories

## Commands

Gemini must read and follow command definitions from `~/.claude/plugins/marketplaces/zzaia/.claude/commands` before execution. All agents share the same command patterns:

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
