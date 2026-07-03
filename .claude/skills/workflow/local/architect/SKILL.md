---
name: workflow:local:architect
description: Orchestrate local architectural documentation with BDD, SDD, plan, and per-item specifications — no PR, no work items, local-only review
---

## PURPOSE

Generate architectural documentation locally from workspace and document context, with generated specifications reviewed directly on the local branch after completion.

## ARGUMENTS

- `repo` — Repository identifier (required)
- `branch` — Branch name (required)
- `targetBranch` — Target branch (required)
- `description` — Task description or context (required)
- `workspace` — Workspace paths (optional, array)
- `doc` — Documentation paths (optional, array)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/local/architect.js", args: { repo, branch, targetBranch, description, workspace, doc } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:local:architect`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.
