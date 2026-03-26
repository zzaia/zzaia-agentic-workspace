---
name: diagram
description: Diagram generation — render Mermaid or Graphviz source code to PNG files locally
argument-hint: "--action <generate> [options]"
---

# diagram Skill

Unified entry point for diagram generation. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter  | Required | Description                     |
|------------|----------|---------------------------------|
| `--action` | Yes      | Operation to perform: `generate` |

## Action Routing

| Action     | Command                                   | Description                                       |
|------------|-------------------------------------------|---------------------------------------------------|
| `generate` | [@capability:diagram:generate](./generate/SKILL.md) | Render Mermaid or Graphviz code to PNG locally |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
