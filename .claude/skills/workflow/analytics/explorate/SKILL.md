---
name: workflow:analytics:explorate
description: Comprehensive research workflow for domain, problem, and dataset exploration with optional auto-selection
---

## PURPOSE

Explore viable data science and software engineering problem domains, refine the selected domain into technical problems, and discover suitable datasets — with auto-selection fallback when interactive selection is unavailable.

## ARGUMENTS

- `domain` — Domain context to focus exploration on (optional)
- `description` — Additional context for domain/problem/dataset exploration (optional)
- `selectedDomain` — Pre-selected domain name from a prior run's `allDomains` list; if omitted, the top-ranked domain is used automatically (optional)
- `selectedProblem` — Pre-selected problem title from a prior run's `allProblems` list; if omitted, the top-ranked problem is used automatically (optional)
- `selectedDataset` — Pre-selected dataset name from a prior run's `allDatasets` list; if omitted, the top-ranked dataset is used automatically (optional)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/analytics/explorate.js", args: { domain, description, selectedDomain, selectedProblem, selectedDataset } })`.
3. Relay the workflow's returned result to the user, including the full ranked lists (`allDomains`, `allProblems`, `allDatasets`) so they can re-invoke with an explicit `selected*` override if the auto-picked choice wasn't right.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:analytics:explorate`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.

**NOTE**: This workflow runs non-interactively — since there is no live chat or external channel to poll for a human's domain/problem/dataset pick (unlike other workflows in this repo which can poll a PR or work-item discussion), each stage auto-selects the top-ranked result unless an explicit `selected*` argument overrides it.
