---
name: workspace:debug-apphost
description: Read-only command that collects logs, traces, and metrics from Aspire AppHost via MCP tools and generates a structured issue report
argument-hint: "[--application <name>]"
agents:
  - name: general-purpose
    description: Reads Aspire MCP tools to collect logs, structured logs, traces, and metrics; produces consolidated issue report
parameters:
  - name: application
    description: Optional application name to focus report on a single application. If omitted, report covers all applications.
    required: false
---

## PURPOSE

Diagnose issues in the Aspire AppHost by reading all available telemetry data via MCP tools. Generate a structured markdown report showing errors, warnings, failed traces, and unhealthy resources grouped by application with severity indicators.

This is a read-only command—no writes, no state changes.

## EXECUTION

1. **Discover Resources**: Call `mcp__aspire__list_resources` to enumerate all running resources; if `--application` is set, filter to that application only

2. **Collect Telemetry**: For each resource, gather:
   - Console logs via `mcp__aspire__list_console_logs`
   - Structured logs via `mcp__aspire__list_structured_logs` (filter Warning/Error severity)
   - Distributed traces via `mcp__aspire__list_traces`
   - Trace logs via `mcp__aspire__list_trace_structured_logs` for traces with errors

3. **Analyze & Report**: Categorize findings by severity:
   - Errors (❌)
   - Warnings (⚠️)
   - Failed traces
   - Unhealthy resources

4. **Output**: Generate consolidated markdown report with summary table at top, grouped by application

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant MCP as Aspire MCP
    participant R as Report Generator

    U->>C: /workspace:debug-apphost [--application name]
    C->>C: Parse parameters
    C->>MCP: mcp__aspire__list_resources
    MCP-->>C: All running resources
    C->>C: Filter by --application if set
    loop For each resource
        C->>MCP: mcp__aspire__list_console_logs
        MCP-->>C: Console output
        C->>MCP: mcp__aspire__list_structured_logs
        MCP-->>C: Structured logs (all severities)
        C->>MCP: mcp__aspire__list_traces
        MCP-->>C: Trace summaries
        C->>MCP: mcp__aspire__list_trace_structured_logs
        MCP-->>C: Logs within traces
    end
    C->>R: Compile all data
    R->>R: Categorize by severity
    R->>R: Group by application
    R-->>C: Markdown report
    C-->>U: Display report
```

## ACCEPTANCE CRITERIA

- Command is read-only—no writes to files or state changes
- Uses `mcp__aspire__` tools directly; does not simulate
- Supports optional `--application` parameter to filter results
- Report includes summary table with error/warning counts per application
- Severity indicators used: ❌ (Error), ⚠️ (Warning)
- Grouped output organized by application name
- Handles empty results gracefully (e.g., no errors, no warnings)
- Includes timestamp and resource health status where available

## EXAMPLES

```
/workspace:debug-apphost
/workspace:debug-apphost --application api-service
/workspace:debug-apphost --application web-ui
```

## OUTPUT

- Consolidated markdown report
- Summary table: Application | Errors | Warnings | Failed Traces | Status
- Sections per application with categorized findings
- Direct output to stdout (no file write)
