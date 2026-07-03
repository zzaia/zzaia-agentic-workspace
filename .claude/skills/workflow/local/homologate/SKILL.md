---
name: workflow:local:homologate
description: Execute BDD-style homologation tests against a URL locally and generate a test result report
---

## PURPOSE

Developer validation of BDD scenarios against a live or local URL, collecting diagnostics and generating a local report file.

## ARGUMENTS

- `url` — URL to test against (required)
- `application` — Application name (required)
- `type` — Application type (required)
- `steps` — BDD test steps (required)
- `description` — Task description or context (required)
- `doc` — Documentation path (optional)
- `debugSources` — Debug sources paths (optional)
- `sourceMetadata` — Source metadata (optional)

## EXECUTION

This skill is a thin wrapper — it does not implement any logic itself. When invoked:

1. Parse the arguments above from the user's request (ask for any required ones that are missing).
2. Call the Workflow tool: `Workflow({ scriptPath: ".claude/workflows/local/homologate.js", args: { url, application, type, steps, description, doc, debugSources, sourceMetadata } })`.
3. Relay the workflow's returned result to the user.

**MANDATORY**: Always invoke via the `Workflow` tool with the exact `scriptPath` above — do not reimplement the workflow's logic manually, and this skill's name matches the script's own `meta.name` (`workflow:local:homologate`) — still always invoke via `scriptPath`, not `name:`, since scriptPath is unambiguous even when names align.
