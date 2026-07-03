---
name: workflow:local:implement
description: Local-only workflow for iterative development — branch creation, documentation, implementation, review, and local commit without DevOps portal interaction
---

## PURPOSE

Implement a feature locally: create branch, write documentation, implement with tests, review, fix issues, and commit locally without touching DevOps portals or creating pull requests.

## ARGUMENTS

- `repo` — Repository identifier (required)
- `workingBranch` — Feature branch to create and work on (required)
- `targetBranch` — Target branch (required)
- `description` — Task description or context (required)
- `skipDocumentation` — Skip documentation step (optional)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/local/implement.js", args: { repo, workingBranch, targetBranch, description, skipDocumentation } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:local:implement`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.
