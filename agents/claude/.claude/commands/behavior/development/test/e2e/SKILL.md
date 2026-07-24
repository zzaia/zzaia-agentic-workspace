---
name: behavior:development:test:e2e
description: Execute a single BDD step via direct API call against a live URL
argument-hint: "--step <bdd-step> --environment <url> [--description <text>]"
user-invocable: true
agent: zzaia-tester-specialist
metadata:
  parameters:
    - name: step
      description: BDD step text to execute (single step from Test Case Steps)
      required: true
    - name: environment
      description: Live URL to execute the API call against
      required: true
    - name: description
      description: Additional context or instructions for the operation
      required: false
---

## PURPOSE

Execute a single BDD step as a direct API call against a live URL, resolve or create the Postman request, and return a concise step report with response status and timing.

## EXAMPLES

```
/behavior:development:test --type e2e --step "POST /orders with valid payload returns 201" --environment https://staging.myapp.com --application MyApp
```

## EXECUTION

1. **Resolve Postman Request**

   - Call `/capability:postman:read --target request` to find existing request matching the step URL/method
   - If not found: Call `/capability:postman:create --target request --spec "<method + url + headers + body>"`

2. **Authentication** *(if required)*

   - Call `/behavior:workspace:ask-user-question --question "Authentication required. Please provide credentials, then confirm to continue"`

3. **Execute Step**

   - Execute the API call via the resolved Postman request
   - Capture: response status, body, response time

4. **Report Step Result**

   - Return: step name, result (pass/fail), response time

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-tester-specialist` — Execute API step and collect diagnostics
- `zzaia-workspace-manager` — Resolve and create Postman requests

## WORKFLOW

```mermaid
sequenceDiagram
    participant C as behavior:development:test:e2e
    participant PM as /capability:postman
    participant TS as zzaia-tester-specialist

    C->>PM: --action read --target request
    PM-->>C: Existing or new request
    C->>TS: Execute API call via Postman request
    TS-->>C: Response (status, body, timing)
    C-->>C: Step report (pass/fail, timing)
```

## ACCEPTANCE CRITERIA

- Postman request resolved or created before execution
- API call executed and response captured
- Concise step report returned with result and timing

## OUTPUT

- Step name and result (pass/fail)
- HTTP response status and response time
