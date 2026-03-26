---
name: create
description: Create new Postman resources (collections, requests, environments, mocks)
argument-hint: "--target <collection|request|environment|mock> --spec <payload> [--description <text>]"
user-invocable: true
agent: zzaia-workspace-manager
metadata:
  parameters:
    - name: target
      description: Resource type to create (collection, request, environment, mock)
      required: true
    - name: spec
      description: Resource specification payload (name, description, variables, etc.)
      required: true
    - name: description
      description: Broader description of what to do within this action
      required: false
---

## PURPOSE

Create a new Postman resource (collection, request, environment, or mock). Supports full specification of resource properties.

## EXECUTION

1. **Identify** the resource type from `--target`
2. **Parse** the resource specification from `--spec`
3. **Create** the resource using Postman MCP
4. **Return** the created resource ID and metadata

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-workspace-manager` — Create resource via Postman MCP

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant W as zzaia-workspace-manager

    U->>C: /capability:postman:create --target <type> --spec <payload>
    C->>W: Create resource
    W-->>C: Resource ID and metadata
    C-->>U: Created resource details
```

## ACCEPTANCE CRITERIA

- Resource is created in Postman workspace
- Resource ID is returned
- All specified properties are applied
- Resource is accessible for subsequent operations

## EXAMPLES

```
/capability:postman:create --target collection --spec '{"name":"API Tests","description":"Test collection"}'
```

```
/capability:postman:create --target environment --spec '{"name":"staging","variables":{"api_url":"https://staging.example.com","api_key":"test_key"}}' --description "Create staging environment with base URL and API key"
```

```
/capability:postman:create --target request --spec '{"name":"Get Users","method":"GET","url":"{{api_url}}/users","headers":{"Authorization":"Bearer {{api_key}}"}}' --description "Create request for retrieving user list"
```

## OUTPUT

- Created resource ID
- Resource name and type
- Resource metadata and properties
