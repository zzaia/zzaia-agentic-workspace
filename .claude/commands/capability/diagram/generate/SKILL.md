---
name: diagram:generate
description: Generate PNG diagram from Mermaid or Graphviz source code using local offline renderers
argument-hint: "--code <diagram_code> --output <path.png> [--type mermaid|graphviz]"
user-invocable: true
agent: zzaia-document-specialist
metadata:
  scripts:
    - name: generate-diagram.py
      script: ./scripts/generate-diagram.py
  parameters:
    - name: code
      description: Diagram source code (Mermaid syntax or Graphviz DOT)
      required: true
    - name: output
      description: Output PNG file path
      required: true
    - name: type
      description: "Renderer: mermaid (default, uses mmdc) or graphviz (uses graphviz binary)"
      required: false
      default: mermaid
---

## PURPOSE

Render a diagram from Mermaid or Graphviz source code to a PNG file using local renderers — no internet access required.

## EXECUTION

1. **Detect Renderer**: Use `--type` or auto-detect from code syntax
   - Mermaid keywords (`graph`, `sequenceDiagram`, `C4Context`, `erDiagram`, etc.) → `mmdc`
   - Graphviz keywords (`digraph`, `graph {`) → `graphviz`

2. **Generate PNG**: Run `./scripts/generate-diagram.py`

3. **Return Path**: Confirm PNG written to `--output`

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter.

- `zzaia-document-specialist` — Executes diagram generation workflow

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant P as Python Script
    participant F as File System

    U->>C: /capability:diagram:generate --code <code> --output <path>
    C->>P: Execute generate-diagram.py
    P->>P: Auto-detect renderer
    P->>F: Write PNG to output path
    P-->>C: PNG path + size
    C-->>U: Diagram ready
```

## EXAMPLES

```
/capability:diagram:generate --code "graph TD\n A --> B --> C" --output ./diagrams/flow.png
/capability:diagram:generate --code "sequenceDiagram\n  A->>B: Hello" --output ./diagrams/seq.png
/capability:diagram:generate --type graphviz --code "digraph { A -> B -> C }" --output ./diagrams/arch.png
```

## OUTPUT

- PNG file at `--output` path
- Confirmation message with renderer used and file size
