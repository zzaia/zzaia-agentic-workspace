# ZZAIA Agentic Workspace

Multi-language agentic development environment — architecture, implementation, and delivery from a single Claude Code session.

---

## 1. Authenticate

Open the Claude Code terminal or the Claude Code extension and run:

```
/login
```

After login, verify your MCP tools are available:

```
/mcp
```

---

## 2. Add a Repository

Clone any repository into the workspace worktree structure:

```
/behavior:workspace:repo --action new --repo https://github.com/org/repo.git
```

Once cloned, create a working branch:

```
/behavior:workspace:repo --action new --repo my-repo --branch feature/my-feature
```

→ Definition: [behavior/workspace/repo.md](.claude/commands/behavior/workspace/repo.md)

---

## 3. Architect a System

Generate architectural documentation — BDD scenarios, solution design, implementation plan, and Azure DevOps work items — all from a description or existing work item:

```
/workflow:remote:architect --project MyProject --description "event-driven order processing service"
```

With an existing work item:

```
/workflow:remote:architect --project MyProject --selected-work-item 1042 --selected-repo my-repo
```

→ Definition: [workflow/remote/architect.md](.claude/commands/workflow/remote/architect.md)

---

## 4. Implement a Feature

Implement a work item end-to-end — from worktree creation to pull request:

```
/workflow:remote:implement --work-item 1605 --portal azure --project MyProject --repo my-repo --target-branch develop --working-branch feature/my-feature --description "implement order service with event sourcing"
```

→ Definition: [workflow/remote/implement.md](.claude/commands/workflow/remote/implement.md)

---

## 5. Other Useful Commands

| Command | Purpose | Definition |
|---------|---------|------------|
| `/behavior:ask <question>` | Ask anything about the codebase or architecture | [ask.md](.claude/commands/behavior/ask.md) |
| `/behavior:devops:work-item` | Read and manage Azure DevOps work items | [work-item.md](.claude/commands/behavior/devops/work-item.md) |
| `/workflow:remote:fix-pipeline` | Diagnose and repair failing pipelines | [fix-pipeline.md](.claude/commands/workflow/remote/fix-pipeline.md) |
| `/workflow:remote:homologate` | Run homologation tests before release | [homologate.md](.claude/commands/workflow/remote/homologate.md) |
| `/behavior:workspace:apphost --action setup` | Configure Aspire AppHost with workspace services | [apphost.md](.claude/commands/behavior/workspace/apphost.md) |

---

## Documentation

- [README.md](https://github.com/zzaia/zzaia-agentic-workspace.git) — repository overview
