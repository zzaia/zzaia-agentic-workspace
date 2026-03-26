---
name: request
description: Execute HTTP calls via Postman runner
argument-hint: "--spec <payload> [--description <text>]"
user-invocable: true
agent: zzaia-workspace-manager
metadata:
  parameters:
    - name: spec
      description: Resource specification payload (method, URL, headers, body)
      required: true
    - name: description
      description: Broader description of what to do within this action
      required: false
---

## PURPOSE

Execute an HTTP call via Postman runner. Sends requests with full support for methods, URLs, headers, and body payloads.

## EXECUTION

1. **Parse** the request specification from `--spec`
2. **Execute** the HTTP call using Postman MCP
3. **Return** the response with status, headers, and body

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-workspace-manager` — Execute HTTP request via Postman runner

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant W as zzaia-workspace-manager

    U->>C: /capability:postman:request --spec <payload>
    C->>W: Execute HTTP request
    W-->>C: Response (status, headers, body)
    C-->>U: HTTP response result
```

## ACCEPTANCE CRITERIA

- HTTP request executes via Postman MCP
- Response includes status code, headers, and body
- Supports all HTTP methods (GET, POST, PUT, DELETE, PATCH, etc.)
- Handles request headers and body payload

## EXAMPLES

```
/capability:postman:request --spec '{"method":"GET","url":"https://api.example.com/data","headers":{"Authorization":"Bearer token"}}'
```

```
/capability:postman:request --spec '{"method":"POST","url":"https://api.example.com/data","headers":{"Content-Type":"application/json"},"body":{"name":"test"}}' --description "Create new user in test environment"
```

## OUTPUT

- HTTP response status code
- Response headers
- Response body
