# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Multi-agent orchestration system for multi-language development workflows across repositories, using git worktrees and architectural principles.

## Core Commands

### Development Commands

- `/develop [task]` - Full task clarification and development workflow
- `/build <repo> <branch>` - Multi-framework build with error reporting
- `/test <repo> <branch>` - Comprehensive testing with coverage analysis
- `/migrations <repo> <branch> <action> [name]` - EF Core migrations management

### Agent Architecture

Specialized agents in `.claude/agents/`:

- **zzaia-task-clarifier** - Requirements analysis
- **zzaia-developer-specialist** - Multi-language implementation
- **zzaia-workspace-manager** - Workspace operations: repository cloning, worktree management, browser diagnostics, AppHost telemetry
- **zzaia-tester-specialist** - Build validation and quality assurance
- **zzaia-code-reviewer** - Code quality and static analysis
- **zzaia-devops-specialist** - Azure DevOps and GitHub DevOps operations
- **zzaia-meta-agent** - Agent generation utilities
- **zzaia-meta-behavior** - Behavior generation utilities
- **zzaia-meta-workflow** - Workflow command generation utilities

## Workspace Structure

Multi-repository workspace with git worktrees:

```
workspace/
├── {repo}.worktrees/
│   ├── master/              # Reference branch
│   ├── feature/{name}/      # Feature branches
│   └── repository-metadata.json
├── tasks/                   # Task specifications
host/                        # Aspire AppHost template
```

## AppHost Template

`host/` contains a .NET Aspire AppHost used to run workspace applications with shared infrastructure (PostgreSQL, Redis, RabbitMQ) for integrated validation and testing. Add workspace project references and configure `ApplicationInjection.cs` extensions per development session.

## Development Workflow

1. **Task Clarification** - Analyze requirements, create specifications
2. **Implementation** - Language-specific architecture with comprehensive testing
3. **Quality Gates** - Build validation, test execution, code review
4. **Documentation** - Automated documentation updates
5. **Version Control** - Conventional commits across repositories

## Development Standards

Language-specific coding standards are defined in `.claude/rules/` directory:

- Reference appropriate rule files based on project language/framework
- Follow established architectural patterns per language
- Maintain comprehensive documentation standards
- Implement testing strategies per language conventions

## Command Hierarchy

Commands are organized in a four-layer hierarchy, each layer calling into the next:

```
workflow → behavior → skill → template
```

| Layer | Prefix | Purpose |
|-------|--------|---------|
| **Workflow** | `/workflow:*` | Orchestrates end-to-end tasks by sequencing multiple behaviors |
| **Behavior** | `/behavior:*` | Executes a single domain operation, optionally invoking skills |
| **Skill** | `/skill:*` | Reusable capability with its own instructions, template, examples, and scripts |
| **Template** | `templates/` | Static markdown templates that skills populate with real content |

This hierarchy enables complex automation through composition without coupling layers.

## Key Principles

- Command hierarchy: workflow → behavior → skill → template
- Agent orchestration system with specialized responsibilities
- Language-appropriate architecture across all projects
- Cross-repository feature development coordination

## MANDATORY DEFINITIONS

Those definitions must be ALWAYS be applied and never be removed or altered from this document by the /init command;

- Avoid using names from workspace projects as .claude or CLAUDE.md definition examples, also this memory must not be removed, ever;
- Concise when building claude code related definitions ex. CLAUDE.md, agents, output-styles and others, also this memory must not be removed, ever.
- Avoid adding commands or peace of codes in .claude and CLAUDE.md definitions;
- ALWAYS be Concise on all outputs, responses and implementations;
- ALWAYS be check for the selected files or lines on IDE when receiving prompt;
- ALWAYS read and follow agent definitions specified in command frontmatter before executing — never skip or replace agents defined there;
