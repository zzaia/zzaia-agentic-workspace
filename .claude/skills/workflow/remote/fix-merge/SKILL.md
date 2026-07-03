---
name: workflow:remote:fix-merge
description: Retrieve PR info, ensure the local worktree exists, merge from target branch, resolve conflicts, fix issues, and push to remote
---

## PURPOSE

Fix a pull request with merge conflicts: read the PR, merge target into source, resolve conflicts automatically, identify and fix post-merge issues, and push to remote.

## ARGUMENTS

- `repo` — Repository identifier (required)
- `pr` — Pull request identifier (required)
- `portal` — DevOps portal: `azure` or `github` (required)
- `project` — Project identifier (required)
- `description` — Task description or context (optional)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/remote/fix-merge.js", args: { repo, pr, portal, project, description } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:remote:fix-merge`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.
