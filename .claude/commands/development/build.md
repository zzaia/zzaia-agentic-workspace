---
name: /build
description: Multi-framework build with error reporting across repositories
parameters:
  - name: repoName
    description: Repository name in workspace
    required: true
  - name: branch
    description: Branch name (must exist as worktree)
    required: true
  - name: project
    description: Project name (must exist in a branch version)
    required: true
---

## PURPOSE

Build applications across multiple frameworks with comprehensive error reporting and no git operations.

## EXECUTION

1. **Validation**

   - Validate workspace repository and branch
   - Verify worktree existence
   - Check project structure

2. **Framework Detection**

   - Automatically detect project framework
   - Identify build configuration files
   - Determine appropriate build commands

3. **Build Execution**
   - NEVER try to fix code to enable building
   - Prefer building solutions
   - Execute framework-specific build
   - Capture build output and errors
   - Generate detailed error reports

## EXECUTION APPROACH

Direct build execution with comprehensive validation and error reporting.

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as /build Command
    participant W as Workspace
    participant P as Project

    U->>C: /build <repo> <branch> <project>
    C->>W: Validate repository and branch
    W-->>C: Repository context
    C->>C: Detect framework
    C->>P: Execute build command
    P-->>C: Build results
    C-->>U: Build status report
```

## EXAMPLES

```bash
# Build specific repository and branch
/build backend-hub master api

# Build feature branch
/build my-project feature/new-api
```

## OUTPUT

- Be concise
- Build success/failure status
- In case of error focus on listing errors and warnings messages
- Framework detection results
- Detailed error messages with file paths
- Build duration and component counts
- Warning and error classifications
