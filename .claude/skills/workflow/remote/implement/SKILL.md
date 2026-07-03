---
name: workflow:remote:implement
description: Orchestrate single-repo implementation from work item through pull request publication using the JS dynamic-workflow runtime
---

## PURPOSE

Implement a work item end-to-end: retrieve requirements, create branch, write documentation, implement with tests, review, fix issues, and publish PR.

## ARGUMENTS

- `workItem` — The work item identifier (required)
- `portal` — DevOps portal: `azure` or `github` (required)
- `project` — Project identifier (required)
- `repo` — Repository identifier (required)
- `targetBranch` — Target branch for the PR (required)
- `workingBranch` — Feature branch to create and work on (required)
- `description` — Task description or context (optional)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/remote/implement.js", args: { workItem, portal, project, repo, targetBranch, workingBranch, description } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:remote:implement`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.
