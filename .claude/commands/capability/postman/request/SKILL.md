---
name: capability:postman:request
description: Execute HTTP calls via Newman CLI runner
argument-hint: "--spec <payload> [--description <text>]"
user-invocable: true
---

## PURPOSE

Execute an HTTP call via Newman CLI. Sends requests with full support for methods, URLs, headers, and body payloads.

## EXECUTION

1. **Parse** the request specification from `--spec`
2. **Build** a minimal Postman collection JSON in memory
3. **Run** `npx newman run <collection.json> --reporters cli,json` via Bash
4. **Return** the response with status, headers, and body

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command

    U->>C: /capability:postman:request --spec <payload>
    C->>C: Build collection JSON
    C->>C: newman run --reporters cli,json
    C-->>U: HTTP response result
```

## ACCEPTANCE CRITERIA

- HTTP request executes via Newman CLI
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
