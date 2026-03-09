---
name: /devops:debug-pipeline
description: Read CI/CD pipeline logs and metrics, generate structured issue report
argument-hint: "--portal <platform> --project <name> --pipeline <id|name> [--run <id>] [--limit <count>]"
agents:
  - name: zzaia-devops-specialist
    description: Execute Azure DevOps MCP pipeline queries and collect build logs, status, and artifact information
parameters:
  - name: portal
    description: DevOps platform (currently supports azure)
    required: true
  - name: project
    description: Azure DevOps project name
    required: true
  - name: pipeline
    description: Pipeline ID or name to inspect
    required: true
  - name: run
    description: Specific run/build ID to inspect, defaults to latest run
    required: false
  - name: limit
    description: Number of log entries to retrieve per stage (default 10)
    required: false
---

## PURPOSE

Query Azure DevOps pipeline infrastructure to collect comprehensive logs, build status, and artifacts. Generate structured diagnostic report identifying failed stages, errors, warnings, and anomalies without modifying pipeline state.

## EXECUTION

1. **Discover Pipeline**: Resolve pipeline by ID or name, retrieve specified run or latest run

   - Query pipeline metadata
   - Resolve run ID if not provided
   - Validate pipeline exists and is accessible

2. **Collect Logs & Status**: Fetch build status, logs per stage, failed steps, and artifacts

   - Get build status and execution timeline
   - Extract logs by stage
   - Identify failed steps with timestamps
   - List artifacts and detect anomalies

3. **Analyze & Report**: Categorize issues by severity, generate structured diagnostic output

   - Group issues by stage (Failed, Warnings, Artifacts)
   - Include log excerpts from failed steps
   - Map commits that triggered the run
   - Format summary table with pipeline execution details

## DELEGATION

The `zzaia-devops-specialist` agent executes all Azure DevOps MCP queries:

- `mcp__azure-devops__pipelines_list_runs` — retrieve available runs for pipeline
- `mcp__azure-devops__pipelines_get_run` — fetch specific run details
- `mcp__azure-devops__pipelines_get_build_status` — retrieve build status
- `mcp__azure-devops__pipelines_get_build_log` — fetch stage logs
- `mcp__azure-devops__pipelines_get_build_log_by_id` — retrieve specific log entry
- `mcp__azure-devops__pipelines_list_artifacts` — enumerate build artifacts
- `mcp__azure-devops__pipelines_get_build_changes` — identify commits in run

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant WIM as zzaia-devops-specialist
    participant ADO as Azure DevOps

    U->>C: /devops:debug-pipeline --portal azure --project X --pipeline Y
    C->>C: Validate parameters
    C->>WIM: Dispatch pipeline discovery
    WIM->>ADO: Query pipeline metadata
    ADO-->>WIM: Pipeline details
    WIM->>ADO: List runs (or get specific run)
    ADO-->>WIM: Run information
    WIM->>C: Return run ID and metadata
    C->>WIM: Dispatch log collection
    WIM->>ADO: Get build status
    ADO-->>WIM: Status timeline
    WIM->>ADO: Get logs by stage
    ADO-->>WIM: Log entries (limited by --limit)
    WIM->>ADO: Get artifacts
    ADO-->>WIM: Artifact manifest
    WIM->>ADO: Get changes
    ADO-->>WIM: Commit list
    WIM->>C: Return collected data
    C->>C: Analyze and categorize issues
    C-->>U: Structured diagnostic report
```

## ACCEPTANCE CRITERIA

- Resolves pipeline by ID or name without ambiguity
- Defaults to latest run when --run not specified
- Report includes summary table with: pipeline name, run ID, status, duration, triggered by
- Issues grouped by stage with severity indicators (❌ Failed, ⚠️ Warning)
- Failed step details with log excerpts (first --limit entries per stage)
- Linked commits in run displayed with messages
- Read-only operation (no pipeline modifications, no triggers)
- Handles missing runs or pipelines gracefully with clear error messages
- Output formatted for terminal readability

## EXAMPLES

```
/devops:debug-pipeline --portal azure --project MyProject --pipeline build-pipeline

/devops:debug-pipeline --portal azure --project MyProject --pipeline 42 --run 1850

/devops:debug-pipeline --portal azure --project MyProject --pipeline deploy-prod --limit 20
```

## OUTPUT

- **Summary Table**: Pipeline metadata, run ID, status, duration, triggered by user/trigger
- **Stage Analysis**: Each stage with pass/fail status and step count
- **Failed Steps**: Stage name, step name, error log excerpt, timestamp
- **Warnings**: Non-fatal issues, deprecation notices, timeout warnings
- **Artifacts**: Artifact names, sizes, artifact metadata anomalies
- **Changes**: Commits that triggered run with message and author
- **Diagnostics**: Query execution time, data points collected, any missing data warnings
