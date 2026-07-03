---
name: workflow:remote:architect
description: Orchestrate architectural documentation via pull request with BDD, SDD, plan, and work-item creation using Specification Driven Design
---

## PURPOSE

Document complex architectural requirements through a SDD workflow, generating behavior specifications, architectural overview, implementation plan, and parallelizable work-item hierarchy.

## ARGUMENTS

- `project` — Project identifier (required)
- `selectedWorkItem` — Work item identifier (required)
- `selectedRepo` — Repository identifier (required)
- `selectedBranch` — Source branch (required)
- `targetBranch` — Target branch for PR (required)
- `description` — Task description or context (required)
- `workspace` — Workspace paths (optional, array)
- `doc` — Documentation paths (optional, array)
- `url` — URL paths (optional, array)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/remote/architect.js", args: { project, selectedWorkItem, selectedRepo, selectedBranch, targetBranch, description, workspace, doc, url } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:remote:architect`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.
