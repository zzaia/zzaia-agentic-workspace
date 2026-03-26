---
name: diagram
description: Diagram generation — render Mermaid, Graphviz, D2, or PlantUML source code to PNG files locally
argument-hint: "--action <generate> [options]"
---

# diagram Skill

Unified entry point for diagram generation. Routes to the appropriate sub-command based on `--action`.

## Supported Renderers

| Renderer | Layout Quality | C4 Support | When to Use |
|---|---|---|---|
| `mermaid` | ★★★☆☆ | experimental | Quick inline diagrams, sequence flows, already-markdown content |
| `graphviz` | ★★★★☆ | none | Dependency graphs, `splines=ortho` edge routing, DOT control |
| `d2` | ★★★★★ | ★★★★☆ | **Default for service/container architecture diagrams** |
| `plantuml` | ★★★☆☆ | ★★★★★ | **Formal C4 notation with Person/System/Container icons** |
| `diagrams` | ★★★☆☆ | ★★★★☆ | **AWS, Azure, GCP, Kubernetes infrastructure with cloud icons** |

## Parameters

| Parameter  | Required | Description                     |
|------------|----------|---------------------------------|
| `--action` | Yes      | Operation to perform: `generate` |

## Action Routing

| Action     | Command                                   | Description                                       |
|------------|-------------------------------------------|---------------------------------------------------|
| `generate` | [@capability:diagram:generate](./generate/SKILL.md) | Render diagram code to PNG locally |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
