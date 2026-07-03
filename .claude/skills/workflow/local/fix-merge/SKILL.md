---
name: workflow:local:fix-merge
description: Local-only workflow for resolving merge conflicts — merge, resolve, fix post-merge issues, and commit locally without pushing to remote
---

## PURPOSE

Ensure the local worktree/branch exists, merge from a target branch, resolve conflicts, fix any issues that arise, and commit changes locally without any remote interaction.

## ARGUMENTS

- `repo` — Repository identifier (required)
- `workingBranch` — Feature branch to work on (required)
- `targetBranch` — Target branch to merge from (required)
- `description` — Task description or context (required)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/local/fix-merge.js", args: { repo, workingBranch, targetBranch, description } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:local:fix-merge`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.
