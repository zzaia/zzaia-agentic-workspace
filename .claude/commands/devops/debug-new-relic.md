---
name: /devops:debug-new-relic
description: Query New Relic for application logs, errors, warnings, and anomalies to generate a diagnostic report
argument-hint: "--application-name <name>"
agents:
  - name: zzaia-devops-specialist
    description: Query New Relic MCP tools and compile diagnostic findings
parameters:
  - name: application-name
    description: Application name to query in New Relic
    required: true
---

## PURPOSE

Query New Relic MCP for logs, issues, warnings, and anomalies from a specified application, then generate a structured diagnostic report with error patterns, timeline summary, and actionable insights.

## EXECUTION

1. **Connect and Query**: Establish connection to New Relic MCP and retrieve logs filtered by application-name from the last 24 hours

   - Query error logs and stack traces
   - Retrieve warning events and anomalies
   - Extract transaction performance metrics

2. **Analyze Findings**: Process results to identify patterns and correlations

   - Group errors by error type and frequency
   - Identify warning trends and timestamps
   - Map error occurrences to timeline

3. **Generate Report**: Compile structured diagnostic output in conversation prompt

   - Issues section with error details and count
   - Warnings section with severity levels
   - Error patterns with common causes
   - Timeline summary of key events

## DELEGATION

**MANDATORY**: Always invoke the agent defined in this command's frontmatter for its designated responsibilities. Never skip, replace, or simulate its behavior directly.

- `zzaia-devops-specialist` — Query New Relic MCP tools, analyze diagnostic data, and compile structured report

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant D as zzaia-devops-specialist
    participant NR as New Relic MCP

    U->>C: /devops/debug-new-relic --application-name <app>
    C->>C: Validate application-name parameter
    C->>D: Dispatch query task with application filter
    D->>NR: Query logs and events filtered by app
    NR-->>D: Return logs, errors, warnings, metrics
    D->>D: Analyze patterns and correlations
    D->>D: Structure findings by category
    D->>C: Compile diagnostic report
    C-->>U: Return structured markdown report
```

## ACCEPTANCE CRITERIA

- Successfully connects to New Relic MCP with provided application name
- Retrieves and processes logs from the last 24 hours
- Report includes distinct sections for Issues, Warnings, Error Patterns, and Timeline
- Error patterns are deduplicated and grouped by root cause
- Timestamps are included for all critical events

## EXAMPLES

```
/devops/debug-new-relic --application-name payment-service
/devops/debug-new-relic --application-name api-gateway
```

## OUTPUT

- Structured markdown report with sections:
  - **Issues**: Error count, types, and stack traces
  - **Warnings**: Warning events with timestamps and severity
  - **Error Patterns**: Grouped by cause with frequency
  - **Timeline**: Chronological summary of key events
