---
name: /run-pipeline
description: Run new or existing Azure DevOps pipelines with automatic workspace context inference
argument-hint: "--portal <azure> [--project <name>] [--pipeline <id-or-name>] [--file-name <yaml>] [--branch <branch>] [--file <path>]"
agents:
  - name: zzaia-devops-specialist
    description: Execute Azure DevOps MCP queries and pipeline operations
parameters:
  - name: portal
    description: DevOps platform identifier (currently supports azure)
    required: true
  - name: project
    description: Azure DevOps project name (inferred from --file if not provided)
    required: false
  - name: pipeline
    description: Existing pipeline ID or name to run (creates new pipeline if omitted)
    required: false
  - name: file-name
    description: Pipeline YAML file name (inferred from --file if not provided)
    required: false
  - name: branch
    description: Target branch for pipeline execution (inferred from --file if not provided)
    required: false
  - name: file
    description: Local workspace file path to infer project, branch, and YAML file name from git worktree metadata
    required: false
---

## PURPOSE

Execute Azure DevOps pipelines with flexible parameter resolution. Supports running existing pipelines by ID/name or creating and running new pipelines from YAML definitions. Automatically infers project, branch, and pipeline file details from local workspace context when --file is provided.

## EXECUTION

1. **Context Resolution**: Validate arguments and infer missing parameters from workspace metadata
   - If --file provided, read git worktree context (repository-metadata.json, git remote, current branch)
   - Populate missing --project, --branch, and --file-name values
   - Validate required parameters (--portal, --project, --branch)

2. **Pipeline Selection**: Determine pipeline action based on provided arguments
   - If --pipeline provided, retrieve existing pipeline definition
   - If only --file-name provided, list available pipelines or prepare to create new definition
   - Validate pipeline or YAML file exists in project

3. **Pipeline Execution**: Trigger pipeline run with resolved parameters
   - Create new pipeline definition if --file-name provided without --pipeline
   - Run selected or newly created pipeline on target branch
   - Capture run ID and metadata for status tracking

4. **Status Reporting**: Return execution results and follow-up instructions
   - Confirm pipeline triggered with run ID
   - Provide run URL for monitoring
   - Report target branch and commit SHA
   - Suggest /devops:debug-pipeline for log inspection

## DELEGATION

**MANDATORY**: Invoke `zzaia-devops-specialist` for all Azure DevOps MCP operations. Never skip or simulate agent behavior directly.

- `zzaia-devops-specialist` — Execute Azure DevOps pipeline queries, create pipeline definitions, and trigger pipeline runs using designated MCP tools

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant A as DevOps Agent
    participant ADO as Azure DevOps

    U->>C: /devops:run-pipeline <args>
    C->>C: Validate portal and resolve parameters
    alt File context provided
        C->>C: Read worktree metadata and git context
        C->>C: Infer project, branch, file-name
    end
    C->>A: Dispatch with resolved parameters
    alt Pipeline ID provided
        A->>ADO: Get pipeline definition
        ADO-->>A: Pipeline details
    else File name provided
        A->>ADO: List or create pipeline from YAML
        ADO-->>A: Pipeline ID
    end
    A->>ADO: Run pipeline on branch
    ADO-->>A: Run ID and metadata
    A->>ADO: Get run status
    ADO-->>A: Run status details
    A->>C: Compile results
    C-->>U: Return run ID, URL, and follow-up instructions
```

## ACCEPTANCE CRITERIA

- Resolves all missing parameters from --file context when provided
- Runs existing pipeline by ID or name without errors
- Creates and runs new pipeline from YAML file when --file-name provided
- Returns run ID, run URL, and target branch/commit information
- Provides actionable follow-up command for log inspection

## EXAMPLES

```
/devops:run-pipeline --portal azure --project MyProject --pipeline build-pipeline --branch main

/devops:run-pipeline --portal azure --file /home/user/workspace/myrepo.worktrees/feature/my-feature/azure-pipelines.yml

/devops:run-pipeline --portal azure --project MyProject --file-name azure-pipelines.yml --branch feature/new-feature
```

## OUTPUT

- Pipeline run confirmation with run ID
- Run URL for real-time monitoring
- Target branch and commit SHA executed
- Recommendation to use `/devops:debug-pipeline --run-id <id>` for detailed logs
