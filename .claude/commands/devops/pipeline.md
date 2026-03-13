---
name: pipeline
description: Manage Azure DevOps pipelines — run existing or new pipelines, or diagnose build logs
argument-hint: "--action <run|debug> --portal <azure> --project <name> [--pipeline <id|name>] [--branch <branch>] [--file <path>] [--file-name <yaml>] [--run <id>] [--limit <count>]"
agents:
  - name: zzaia-devops-specialist
    description: Execute Azure DevOps MCP pipeline queries, trigger runs, and collect build logs
parameters:
  - name: action
    description: "Action to perform: run, debug"
    required: true
  - name: portal
    description: DevOps platform identifier (currently supports azure)
    required: true
  - name: project
    description: Azure DevOps project name (inferred from --file if not provided)
    required: false
  - name: pipeline
    description: Existing pipeline ID or name (run — triggers it; debug — inspects it)
    required: false
  - name: branch
    description: Target branch (inferred from --file if not provided)
    required: false
  - name: file
    description: Local workspace file path to infer project, branch, and YAML file name from git worktree metadata
    required: false
  - name: file-name
    description: Pipeline YAML file name for creating a new pipeline definition
    required: false
  - name: run
    description: "debug only — specific run/build ID to inspect (defaults to latest)"
    required: false
  - name: limit
    description: "debug only — number of log entries per stage (default 10)"
    required: false
---

## PURPOSE

Single interface for Azure DevOps pipeline management. Routes to execution or diagnostics based on `--action`.

## ACTIONS

| Action  | Description                                                     |
|---------|-----------------------------------------------------------------|
| `run`   | Trigger an existing or new pipeline; return run ID and URL      |
| `debug` | Collect build logs and metrics; generate structured issue report |

## EXECUTION

### action=run

1. **Resolve Context** — If `--file` provided, read git worktree metadata to infer `--project`, `--branch`, `--file-name`
2. **Select Pipeline** — Use `--pipeline` to get existing definition, or `--file-name` to create a new one
3. **Trigger Run** — Execute pipeline on target branch; capture run ID and metadata
4. **Report** — Return run ID, URL, branch, commit SHA; suggest `--action debug` for log inspection

### action=debug

1. **Discover Pipeline** — Resolve pipeline by ID or name; resolve run ID (defaults to latest)
2. **Collect Logs & Status** — Fetch build status, logs per stage, failed steps, artifacts, and linked commits
3. **Report** — Group issues by stage ❌ ⚠️; include log excerpts, artifact manifest, and commit list

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-devops-specialist` — Execute all Azure DevOps MCP pipeline operations

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant A as DevOps Agent
    participant ADO as Azure DevOps

    U->>C: /devops:pipeline --action <run|debug> [options]
    C->>C: Validate and resolve parameters
    alt action=run
        C->>A: Dispatch with resolved parameters
        A->>ADO: Get or create pipeline definition
        A->>ADO: Run pipeline on branch
        ADO-->>A: Run ID and metadata
        A-->>C: Compile run result
    else action=debug
        C->>A: Dispatch pipeline inspection
        A->>ADO: list_runs, get_run, get_build_status
        A->>ADO: get_build_log, list_artifacts, get_build_changes
        ADO-->>A: Logs, status, artifacts, commits
        A-->>C: Severity-grouped diagnostic report
    end
    C-->>U: Return output
```

## ACCEPTANCE CRITERIA

- `run`: resolves missing parameters from `--file`; returns run ID, URL, branch, and commit SHA
- `debug`: read-only; report includes summary table, failed steps with log excerpts, artifacts, and linked commits

## EXAMPLES

```
/devops:pipeline --action run --portal azure --project MyProject --pipeline build-pipeline --branch main
/devops:pipeline --action run --portal azure --file workspace/myrepo.worktrees/feature/my-feature/azure-pipelines.yml
/devops:pipeline --action debug --portal azure --project MyProject --pipeline build-pipeline
/devops:pipeline --action debug --portal azure --project MyProject --pipeline 42 --run 1850 --limit 20
```

## OUTPUT

- `run`: run ID, URL, target branch, commit SHA, follow-up suggestion
- `debug`: summary table (pipeline, run ID, status, duration), stage analysis, failed steps, warnings, artifacts, commits
