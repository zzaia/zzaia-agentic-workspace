---
name: /document:write
description: Write markdown documentation by selecting a template from .claude/templates/ and delivering to a target output (local file, wiki, pull-request, work-item).
argument-hint: "[template] [title] [--output <path>] [--wiki] [--pr <id>] [--work-item <id>]"
agents:
  - name: zzaia-document-specialist
    description: Generate documentation from conversation context following the selected template and deliver to the specified output
parameters:
  - name: template
    description: Template to use (architecture-overview, service-architecture, service-data-model, event-notification)
    required: true
  - name: title
    description: Document title or subject
    required: false
  - name: output
    description: Local output file path for the markdown file
    required: false
  - name: wiki
    description: Push documentation to Azure DevOps Wiki page
    required: false
  - name: pr
    description: Pull request ID to post documentation as description or comment
    required: false
  - name: work-item
    description: Work item ID to post documentation as description or comment
    required: false
---

## PURPOSE

Select a documentation template from `.claude/templates/`, generate content from conversation context following the template structure, and deliver to the requested output target.

## EXECUTION

1. **Select Template**: Identify or ask which template to use
   - `architecture-overview` → `.claude/templates/architecture-overview.md`
   - `service-architecture` → `.claude/templates/service-architecture.md`
   - `service-data-model` → `.claude/templates/service-data-model.md`
   - `event-notification` → `.claude/templates/event-notification.md`

2. **Select Output Target**: Identify from flags or ask
   - `--output <path>` — write local markdown file
   - `--wiki` — push to Azure DevOps Wiki page
   - `--pr <id>` — post as pull request description or comment
   - `--work-item <id>` — post as work item description or comment

3. **Invoke Agent**: Call `zzaia-document-specialist` with template path and output target

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter. Never skip or simulate their behavior.

- `zzaia-document-specialist` — reads template, generates content from conversation context, delivers to output

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant A as zzaia-document-specialist

    U->>C: /document:write [template] [title] [--output/--wiki/--pr/--work-item]
    C->>C: Resolve template path from .claude/templates/
    C->>C: Identify output target
    C->>A: template path + output target + context
    A->>A: Read template, generate content from context
    A->>A: Deliver to output target
    A-->>C: Done
    C-->>U: Document ready
```

## EXAMPLES

```
/document:write architecture-overview "System Architecture" --output docs/architecture.md
/document:write service-architecture "Payment Service" --wiki
/document:write service-data-model "Order Entity" --output docs/data-model.md --wiki
/document:write event-notification "Payment Events" --pr 42
/document:write service-architecture "User Service" --work-item 1234
```

## OUTPUT

- Local markdown file, Wiki page, PR description/comment, or work item description/comment
