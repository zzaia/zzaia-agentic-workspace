---
name: workflow:remote:fix-pipeline
description: Iterative pipeline repair loop until successful completion
---

## PURPOSE

When debugging and fixing pipeline failures across multiple repositories with automated re-run cycles.

## ARGUMENTS

- `portal` — DevOps portal (required)
- `project` — Project identifier (required)
- `repo` — Repository identifier (required)
- `pipeline` — Pipeline identifier (required)
- `branch` — Branch name (required)
- `targetBranch` — Target branch (required)
- `deps` — Dependencies (required)
- `workItem` — Work item identifier (required)
- `run` — Run identifier (required)
- `maxIterations` — Maximum iterations (required)
- `description` — Task description or context (optional)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/remote/fix-pipeline.js", args: { portal, project, repo, pipeline, branch, targetBranch, deps, workItem, run, maxIterations, description } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:remote:fix-pipeline`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.
