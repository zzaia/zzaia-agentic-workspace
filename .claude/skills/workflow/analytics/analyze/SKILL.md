---
name: workflow:analytics:analyze
description: Comprehensive dataset download, visualization, and exploration workflow — creates and extends Jupyter notebooks with dataset analysis
---

## PURPOSE

Perform end-to-end dataset analysis: download dataset, create interactive visualizations, and conduct in-depth exploratory analysis with feature assessment.

## ARGUMENTS

- `dataset` — Dataset URL or text description of the desired dataset (required)
- `description` — Additional project/context description, also used to derive the notebook's project-name slug (optional)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/analytics/analyze.js", args: { dataset, description } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:analytics:analyze`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.

**NOTE**: The underlying script substitutes `zzaia-developer-specialist` for the original `zzaia-notebook-development` agent, which no longer exists in this repo.
