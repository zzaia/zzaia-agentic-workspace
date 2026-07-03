---
name: workflow:remote:homologate
description: Orchestrate homologation testing with live-URL BDD execution, diagnostics, and bug reporting via Azure DevOps work items
---

## PURPOSE

QA validation of a work item against a live URL using an existing Test Case with BDD scenarios, collecting diagnostics and creating bugs for approved failures.

## ARGUMENTS

- `workItem` — The work item identifier (required)
- `project` — Project identifier (required)
- `url` — URL to test against (required)
- `application` — Application name (required)
- `type` — Application type (required)
- `testCase` — Test case identifier or name (required)
- `description` — Task description or context (optional)
- `doc` — Documentation path (optional)
- `debugSources` — Debug sources paths (optional)
- `sourceMetadata` — Source metadata (optional)
- `refUrl` — Reference URL (optional)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/remote/homologate.js", args: { workItem, project, url, application, type, testCase, description, doc, debugSources, sourceMetadata, refUrl } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:remote:homologate`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.
