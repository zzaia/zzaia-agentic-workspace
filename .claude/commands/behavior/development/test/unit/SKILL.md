---
name: unit
description: Unit test execution within a project using framework detection
argument-hint: "--repo <name> --branch <name> --project <name> [--action implement|run] [--framework auto]"
user-invocable: true
agent: zzaia-tester-specialist
metadata:
  parameters:
    - name: repo
      description: Repository name in workspace
      required: true
    - name: branch
      description: Branch name as worktree
      required: true
    - name: project
      description: Project name to test within the repository
      required: true
    - name: action
      description: "Execution mode: implement — write test cases; run — execute existing tests"
      required: false
      default: run
    - name: framework
      description: Optional test framework override (auto-detected by default)
      required: false
---

## PURPOSE

Auto-detect the testing framework and run unit tests for a specific project within a repository.

## EXECUTION

1. **Project Validation**

   - Verify repository and branch exist in workspace
   - Validate project structure and locate test files
   - Check for test configurations

2. **Framework Detection**

   - Automatically detect unit testing framework
   - Determine build requirements

3. **Implement Test Cases** *(skip if `--action run`)*

   - Use `zzaia-developer-specialist` to write unit test cases
   - Can run multiple agents in parallel per project

4. **Test Execution**

   - Execute build process if required
   - Run unit tests only
   - Execute with coverage analysis
   - Skip if no unit tests found
   - Use `zzaia-tester-specialist` for execution

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-tester-specialist` — Framework detection and unit test execution
- `zzaia-developer-specialist` — Test implementation when `--action implement`

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as behavior:development:test:unit
    participant TS as zzaia-tester-specialist
    participant DS as zzaia-developer-specialist

    U->>C: --repo <repo> --branch <branch> --project <project>
    C->>TS: Detect framework and validate project
    opt action is implement
        C->>DS: Implement unit test cases
        DS-->>C: Test implementation summary
    end
    C->>TS: Execute unit tests with coverage
    TS-->>C: Test results and coverage
    C-->>U: Unit test report
```

## ACCEPTANCE CRITERIA

- Framework auto-detected from project structure
- Build executed before test run when required
- Only unit tests executed
- Coverage report generated

## EXAMPLES

```
/behavior:development:test --type unit --repo backend-hub --branch master --project api
/behavior:development:test --type unit --repo compliance-hub --branch feature/new-module --project core --action implement
```

## OUTPUT

- Build success/failure status
- List of executed unit tests with pass/fail
- Coverage percentage
- Framework detection result
- Errors and warnings on failure
