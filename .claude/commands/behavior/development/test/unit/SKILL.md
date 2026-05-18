---
name: behavior:development:test:unit
description: Unit test execution within a project using framework detection, with optional system debug after test run
argument-hint: "--repo <name> --branch <name> --project <name> [--action implement|run] [--debug-sources <new-relic|sqs|postgresql|aspire|docker>] [--application <app>] [--source <queue|table|container>] [--framework auto] [--description <text>]"
user-invocable: true
metadata:
  agents:
    - name: zzaia-developer-specialist
      description: Write unit test cases when --action implement is set
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
    - name: debug-sources
      description: "Data source to debug after test run: new-relic, sqs, postgresql, aspire, docker"
      required: false
    - name: application
      description: Application name for new-relic and aspire collection filtering
      required: false
    - name: source
      description: "Collection-specific source — queue name (sqs), table name (postgresql optional), container name (docker optional)"
      required: false
    - name: framework
      description: Optional test framework override (auto-detected by default)
      required: false
    - name: description
      description: Additional context or instructions for the operation
      required: false
---

## PURPOSE

Auto-detect the testing framework, run unit tests for a specific project, and optionally debug the system via a data source collection to surface issues and inconsistencies exposed by the test run.

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
   - Run unit tests only with coverage analysis
   - Skip if no unit tests found

5. **Debug Sources** *(skip if `--debug-sources` not provided)*

   Route by `--debug-sources` after test run completes:

   | Debug Source  | Capability call                                                                              |
   |---------------|----------------------------------------------------------------------------------------------|
   | `new-relic`   | `/capability:new-relic:debug --application-name <application>`                               |
   | `aspire`      | `/capability:aspire:debug --application <application>`                                       |
   | `sqs`         | `/capability:sqs:debug --queue-name <source>`                                                |
   | `postgresql`  | `/capability:postgresql:debug [--connection-name <application>] [--table <source>]`          |
   | `docker`      | `/capability:docker:debug [--container <source>]`                                            |

   - Cross-reference diagnostic findings with test results — surface system issues, warnings, and inconsistencies revealed by the test run


## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as behavior:development:test:unit
    participant DS as zzaia-developer-specialist
    participant SRC as /capability:<collection>

    U->>C: --repo <repo> --branch <branch> --project <project>
    C->>C: Detect framework and validate project
    opt action is implement
        C->>DS: Implement unit test cases
        DS-->>C: Test implementation summary
    end
    C->>C: Execute build and unit tests with coverage
    opt collection is provided
        C->>SRC: debug --application/queue/table per collection
        SRC-->>C: Structured diagnostic findings
        C->>C: Cross-reference findings with test failures
    end
    C-->>U: Unit test report with optional diagnostic findings
```

## ACCEPTANCE CRITERIA

- Framework auto-detected from project structure
- Build executed before test run when required
- Only unit tests executed with coverage report
- When `--debug-sources` provided: debug executed after test run regardless of pass/fail
- Diagnostic findings cross-referenced with test results

## EXAMPLES

```
/behavior:development:test:unit --repo backend-hub --branch master --project api
/behavior:development:test:unit --repo compliance-hub --branch feature/new-module --project core --action implement
/behavior:development:test:unit --repo order-service --branch master --project api --debug-sources postgresql --source orders
/behavior:development:test:unit --repo payment-service --branch master --project worker --debug-sources new-relic --application payment-service
/behavior:development:test:unit --repo order-service --branch master --project api --debug-sources docker --source order-service-api
```

## OUTPUT

- Build success/failure status
- List of executed unit tests with pass/fail
- Coverage percentage
- Framework detection result
- Errors and warnings on failure
- *(when `--debug-sources` set)* Diagnostic findings: issues, warnings, anomalies, and inconsistencies cross-referenced with test results
