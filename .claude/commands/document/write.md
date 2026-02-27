---
name: document:write
description: Write markdown documentation using specialized agent templates for architecture, services, data models, and event catalogs. Output to local files and remote Wiki page.
argument-hint: "[document-type] [title] [--output <path>] [--wiki] [--repo <name>]"
agents:
  - name: template-architecture-overview
    description: Architecture overview with ADRs and C4 diagrams
  - name: template-service-architecture
    description: Individual service architecture documentation
  - name: template-service-data-model
    description: Entity, value objects, and data modeling documentation
  - name: template-event-notification
    description: Event catalog, topics, and pub/sub configuration
parameters:
  - name: document-type
    description: Type of document to write (template-architecture-overview, template-service-architecture, template-service-data-model, template-event-notification)
    required: false
  - name: title
    description: Document title or subject
    required: false
  - name: output
    description: Output file path for local markdown file
    required: false
  - name: wiki
    description: Push documentation to a remote Wiki page
    required: false
  - name: repo
    description: Target repository name for wiki integration
    required: false
---

## PURPOSE

Write markdown documentation with specialized agent templates ensuring consistency in formatting, structure, and compliance with ZZAIA conventions. Route to appropriate agent based on document type and support writing to both local files and remote Wiki page.

## EXECUTION

1. **Clarify Document Type**: Identify or ask which documentation type to write
   - template-architecture-overview: Architecture overview with ADRs and C4 diagrams
   - template-service-architecture: Individual service architecture
   - template-service-data-model: Service data models and entities
   - template-event-notification: Event notifications and pub/sub catalog

2. **Route to Specialized Agent**: Dispatch to appropriate agent based on document type
   - Agent handles template structure, formatting, and conventions
   - Agent generates comprehensive documentation content
   - Ensure output follows ZZAIA conciseness standards

3. **Write Output**: Generate markdown file at specified location
   - Write local .md file if output path provided
   - Push to remote Wiki pages if --wiki flag set
   - Maintain consistent formatting across all outputs

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `template-architecture-overview` — Architecture overview with ADRs and C4 diagrams
- `template-service-architecture` — Individual service architecture documentation
- `template-service-data-model` — Entity, value objects, and data modeling documentation
- `template-event-notification` — Event catalog, topics, and pub/sub configuration

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant A as Agent
    participant F as File System
    participant W as Azure Wiki

    U->>C: /document:write [type] [title]
    C->>C: Validate document type
    C->>A: Route to specialized agent
    A->>A: Generate documentation
    A->>C: Return markdown content
    C->>F: Write local .md file
    C->>W: Optionally push to Wiki
    C-->>U: Document ready
```

## ACCEPTANCE CRITERIA

- Document type correctly identified or prompted from user
- Specialized agent template applied to output
- Local markdown file written to specified path
- Remote Wiki page integration available via --wiki flag
- Documentation follows ZZAIA conventions
- Consistent formatting across all document types

## EXAMPLES

```
/document:write template-architecture-overview "System Architecture"
/document:write template-service-architecture "User Service" --output docs/user-service.md
/document:write template-service-data-model "Order Entity" --output docs/order-models.md --wiki
/document:write template-event-notification "Payment Events" --repo payments --wiki
```

## OUTPUT

- Local markdown file at specified path
- Optional remote Wiki page with formatted content
