---
name: capability:new-relic:query
description: Query raw telemetry data from New Relic — retrieve logs, errors, warnings, anomalies, and transaction metrics
argument-hint: "--application-name <name> [--time-range <hours>] [--description <text>]"
user-invocable: true
agent: zzaia-devops-specialist
metadata:
  parameters:
    - name: application-name
      description: Application name to query in New Relic
      required: true
    - name: time-range
      description: Time range in hours to query (default 24)
      required: false
      default: "24"
    - name: description
      description: Additional context or instructions for the query
      required: false
---

## PURPOSE

Query New Relic MCP for raw telemetry data — retrieve error logs, stack traces, warning events, anomalies, and transaction performance metrics. Returns structured unprocessed data for analysis in higher layers.

## EXECUTION

1. **Query New Relic** — Retrieve logs filtered by `--application-name` from the last `--time-range` hours (default 24h)
   - Error logs and stack traces
   - Warning events
   - Anomalies
   - Transaction performance metrics

2. **Return Raw Data** — Compile structured telemetry data without analysis or formatting

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-devops-specialist` — Query New Relic MCP tools and retrieve raw telemetry data

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant A as DevOps Agent
    participant NR as New Relic MCP

    U->>C: /capability:new-relic:query --application-name <app> [--time-range <hours>]
    C->>A: Dispatch with application filter and time range
    A->>NR: Query logs, errors, warnings, metrics
    NR-->>A: Raw telemetry data
    A-->>C: Structured data (errors, warnings, anomalies, metrics)
    C-->>U: Raw telemetry response
```

## ACCEPTANCE CRITERIA

- Connects to New Relic MCP with provided application name
- Retrieves logs, errors, warnings, anomalies, and metrics from specified time range
- Returns raw structured data without analysis
- Timestamps preserved for all events
- Data organized by category (errors, warnings, anomalies, metrics)

## EXAMPLES

```
/capability:new-relic:query --application-name payment-service
```

```
/capability:new-relic:query --application-name api-gateway --time-range 48
```

```
/capability:new-relic:query --application-name worker-service --time-range 12 --description "Check for recent memory anomalies"
```

## OUTPUT

- **Errors**: Error logs, stack traces, error types
- **Warnings**: Warning events with timestamps and severity
- **Anomalies**: Detected anomalies and deviations
- **Metrics**: Transaction performance data (latency, throughput, error rates)
- **Timestamps**: Event timestamps for correlation and analysis
