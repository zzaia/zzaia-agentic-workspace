---
name: read
description: Read and list Postman workspace resources
argument-hint: "--target <collection|request|environment|mock> [--id <id>] [--description <text>]"
user-invocable: true
agent: zzaia-workspace-manager
metadata:
  parameters:
    - name: target
      description: Resource type to read (collection, request, environment, mock)
      required: true
    - name: id
      description: Resource ID or name (optional; if omitted, lists all resources of that type)
      required: false
    - name: description
      description: Broader description of what to do within this action
      required: false
---

## PURPOSE

Read and list Postman workspace resources by type. Retrieves a single resource by ID or lists all resources of the specified type.

## EXECUTION

1. **Identify** the resource type from `--target`
2. **Check** if `--id` is provided (single resource) or omitted (list all)
3. **Fetch** the resource(s) using Postman MCP
4. **Return** resource details or list of resources

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-workspace-manager` — Read resources via Postman MCP

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant W as zzaia-workspace-manager

    U->>C: /skill:postman:read --target <type> [--id <id>]
    C->>W: Fetch resource(s)
    W-->>C: Resource details or list
    C-->>U: Resource data
```

## ACCEPTANCE CRITERIA

- Single resource read returns full resource details
- List operation returns all resources of the type
- Resource properties are complete and accurate
- Nested structures (folders, requests within collections) are included

## EXAMPLES

```
/skill:postman:read --target collection
```

```
/skill:postman:read --target collection --id "collection-abc123"
```

```
/skill:postman:read --target environment --description "Get all environments to see available API configurations"
```

```
/skill:postman:read --target request --id "Get Users"
```

## OUTPUT

- For single resource: Full resource object with all properties
- For list: Array of resources with ID, name, and type
