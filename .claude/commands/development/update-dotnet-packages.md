---
name: /update-dotnet-packages
description: Update NuGet packages with comprehensive validation and safety checks
parameters:
  - name: repoName
    description: Repository name in workspace
    required: true
  - name: branch
    description: Branch name for package updates
    required: true
  - name: target
    description: Update target (all, project, outdated, major)
    required: false
---

## PURPOSE

Update NuGet packages across .NET projects with comprehensive validation, safety checks, and rollback capabilities.

## EXECUTION

1. **Workspace Validation**
   - Verify repository and branch existence
   - Validate .NET project structure
   - Check package configuration files

2. **Package Analysis**
   - Identify update candidates
   - Analyze dependency conflicts
   - Assess security vulnerabilities

3. **Update Execution & Validation**
   - Apply package updates safely
   - Execute build and test validation
   - Prepare rollback information

## EXECUTION APPROACH

Direct NuGet package management with comprehensive validation and safety checks.

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as /update-dotnet-packages Command
    participant W as Workspace
    participant N as NuGet
    participant P as Project

    U->>C: /update-dotnet-packages <repo> <branch> [target]
    C->>W: Validate workspace context
    W-->>C: Repository confirmation
    C->>N: Analyze packages
    C->>N: Identify update candidates
    C->>N: Execute package updates
    N->>P: Apply updates
    C->>P: Run build and tests
    P-->>C: Validation results
    C-->>U: Package update summary
```

## PARAMETERS

- `repoName`: Repository name in workspace
- `branch`: Branch name for package updates
- `target`: Update target (optional)
  - `all`: Update all packages (default)
  - `project <name>`: Update specific project
  - `outdated`: Update only outdated packages
  - `major`: Allow major version updates

## EXAMPLES

```bash
# Update all packages
/update-dotnet-packages compliance-hub master

# Update specific project
/update-dotnet-packages my-project develop project MyProject

# Update only outdated packages
/update-dotnet-packages api-service main outdated
```

## OUTPUT

- Package update summary with version changes
- Security vulnerability assessment
- Build and test validation results
- Dependency conflict analysis
- Rollback preparation status