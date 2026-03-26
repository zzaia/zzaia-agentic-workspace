---
name: latex
description: LaTeX document operations — compile templates to PDF
argument-hint: "--action <write> [options]"
---

# latex Skill

Unified entry point for LaTeX document operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter  | Required | Description                        |
|------------|----------|------------------------------------|
| `--action` | Yes      | Operation to perform: `write`      |

## Action Routing

| Action  | Command                                | Description                             |
|---------|----------------------------------------|-----------------------------------------|
| `write` | [@skill:latex:write](./write/SKILL.md) | Generate PDF from Jinja2 LaTeX template |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
