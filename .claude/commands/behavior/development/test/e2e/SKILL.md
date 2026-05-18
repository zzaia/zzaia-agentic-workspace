---
name: behavior:development:test:e2e
description: Execute a single BDD step via direct API call and query a data source for consistency and issue validation
argument-hint: "--step <bdd-step> --environment <url> --application <app> --debug-sources <new-relic|sqs|postgresql|aspire|docker> [--source <queue|table|container>] [--description <text>]"
user-invocable: true
metadata:
  parameters:
    - name: step
      description: BDD step text to execute (single step from Test Case Steps)
      required: true
    - name: environment
      description: Live URL to execute the API call against
      required: true
    - name: application
      description: Application name used for new-relic and aspire collection filtering
      required: true
    - name: debug-sources
      description: "Data source to debug for consistency and issue validation: new-relic, sqs, postgresql, aspire, docker"
      required: true
    - name: source
      description: "Collection-specific source — queue name (sqs), table name (postgresql optional), container name (docker optional)"
      required: false
    - name: description
      description: Additional context or instructions for the operation
      required: false
---

## PURPOSE

Execute a single BDD step as a direct API call against a live URL, resolve or create the Postman request, query the specified `--debug-sources` data source for consistency and issues, and return a concise step report.

## EXECUTION

1. **Resolve Postman Request**

   - Call `/capability:postman:read --target request` to find existing request matching the step URL/method
   - If not found: Call `/capability:postman:create --target request --spec "<method + url + headers + body>"`

2. **Authentication** *(if required)*

   - Call `/behavior:workspace:ask-user-question --question "Authentication required. Please provide credentials, then confirm to continue"`

3. **Execute Step**

   - Execute the API call via the resolved Postman request
   - Capture: response status, body, response time

4. **Debug Sources** — route by `--debug-sources`:

   | Debug Source  | Capability call                                                                              |
   |---------------|----------------------------------------------------------------------------------------------|
   | `new-relic`   | `/capability:new-relic:debug --application-name <application>`                               |
   | `aspire`      | `/capability:aspire:debug --application <application>`                                       |
   | `sqs`         | `/capability:sqs:debug --queue-name <source>`                                                |
   | `postgresql`  | `/capability:postgresql:debug [--connection-name <application>] [--table <source>]`          |
   | `docker`      | `/capability:docker:debug [--container <source>]`                                            |

   - Receive structured diagnostic findings from the selected source
   - Cross-reference findings with the executed step: surface errors, anomalies, warnings, or inconsistencies triggered by the API call

5. **Report Step Result**

   - Return: step name, result (pass/fail), response time, diagnostic findings (errors, anomalies, warnings, inconsistencies)

## WORKFLOW

```mermaid
sequenceDiagram
    participant C as behavior:development:test:e2e
    participant PM as /capability:postman
    participant SRC as /capability:<collection>

    C->>PM: read --target request
    PM-->>C: Existing or new request
    C->>C: Execute API call via Postman request
    C->>SRC: debug --application/queue/table per collection
    SRC-->>C: Structured diagnostic findings (issues, warnings, anomalies)
    C->>C: Validate consistency and detect issues
    C-->>C: Step report (pass/fail, timing, findings)
```

## ACCEPTANCE CRITERIA

- Postman request resolved or created before execution
- API call executed and response captured
- Collection debugged regardless of pass/fail
- Issues, anomalies, warnings, and inconsistencies surfaced in step report
- Concise step report returned with result, timing, and findings

## EXAMPLES

```
/behavior:development:test:e2e --step "POST /orders with valid payload returns 201" --environment https://staging.myapp.com --application order-service --debug-sources new-relic
```

```
/behavior:development:test:e2e --step "POST /orders places message on queue" --environment https://staging.myapp.com --application order-service --debug-sources sqs --source orders-queue
```

```
/behavior:development:test:e2e --step "POST /orders persists record" --environment https://staging.myapp.com --application order-service --debug-sources postgresql --source "SELECT * FROM orders ORDER BY created_at DESC LIMIT 1"
```

```
/behavior:development:test:e2e --step "POST /orders returns 201" --environment https://staging.myapp.com --application order-service --debug-sources aspire
```

```
/behavior:development:test:e2e --step "POST /orders triggers container processing" --environment https://staging.myapp.com --application order-service --debug-sources docker --source order-worker
```

## OUTPUT

- Step name and result (pass/fail)
- HTTP response status and response time
- Collection findings: errors, anomalies, data inconsistencies, unexpected states
