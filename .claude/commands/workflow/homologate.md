---
name: /homologate
description: Orchestrate complete homologation workflow for one or more applications, from work item retrieval through bug reporting
argument-hint: "work-item=<id> repos=<name[,name]> target-branches=<branch[,branch]> working-branches=<branch[,branch]> description=<text>"
agents:
  - name: zzaia-task-clarifier
    description: Analyze work item requirements and validate acceptance criteria
  - name: zzaia-repository-manager
    description: Manage homologation branch creation across multiple repositories
  - name: zzaia-tester-specialist
    description: Implement tests, execute test suites, and generate testing reports
  - name: zzaia-developer-specialist
    description: Review test implementations and fix issues discovered during homologation
parameters:
  - name: work-item
    description: Work item ID from Azure DevOps
    required: true
  - name: repos
    description: Repository names (comma-separated for multiple repos)
    required: true
  - name: target-branches
    description: Base branches per repo (comma-separated, must match repos count)
    required: true
  - name: working-branches
    description: Feature/homologation branch names per repo (comma-separated, must match repos count)
    required: true
  - name: description
    description: Homologation scope and description
    required: true
---

## PURPOSE

Orchestrate complete homologation (QA/acceptance testing) workflow for one or more applications simultaneously. Validates work item requirements, creates homologation branches, develops comprehensive test cases, executes tests against integrated environment, and reports bugs found.

## EXECUTION

1. **Retrieve Work Item**: Call `/devops:work-item` to fetch work item details

   - Extract title, description, acceptance criteria
   - Validate work item description is not empty
   - Confirm work item is in proper state for homologation

2. **Create Homologation Branches**: Call `/workspace:new` for each repo/branch pair

   - Create homologation branches in ALL specified repositories
   - Support concurrent branch creation across multiple repos
   - Confirm branch creation in each repository

3. **Generate Test Plan**: Call `/management:architect` focused on test cases only

   - Document all test scenarios derived from acceptance criteria
   - Define expected behaviors and validation criteria
   - Clarify testing scope with user via **AskUserQuestion**
   - Create concise Test Plan document covering test scope only

4. **User Approval**: Wait for Test Plan approval via **AskUserQuestion**

   - Request user confirmation of test coverage completeness
   - Address any clarifications needed before proceeding

5. **Implement Tests**: Call `/development:test` in each working branch

   - Implement test cases covering all acceptance criteria
   - Execute tests to verify they detect both passing and failing scenarios
   - Ensure test coverage across all specified repositories

6. **Commit Initial Tests**: Call `/development:git` for all repos/branches

   - Commit test implementations with meaningful messages referencing work item
   - Push to working branches in all repositories

7. **Review and Fix**: Call `/development:review` and `/development:develop` as needed

   - Review test implementations for quality and completeness
   - Request fixes via **AskUserQuestion** if improvements needed
   - Re-run tests after fixes

8. **Commit and Push Fixes**: Call `/development:git` for all repos/branches

   - Commit fix implementations with meaningful messages referencing work item
   - Push to working branches in all repositories

9. **AppHost Setup and Test Execution**:

   - Call `/workspace:setup-apphost` with all involved working branches
   - Configure integrated environment with all applications
   - Call `/development:test` to run implemented tests against AppHost
   - Generate testing report with pass/fail results, coverage metrics, and issues found
   - Request user approval via **AskUserQuestion** before proceeding to bug creation

10. **Create Bug Work Items**: For each issue found in test execution

    - Call `/devops:work-item` (create mode) for each bug
    - Include: title, detailed description, steps to reproduce, expected vs actual behavior, affected repo/application, severity
    - Link bugs to original work item
    - Provide summary of all created bug work items

11. **Create Pull Requests**: Open pull requests for all repositories

    - Call `/devops:pull-request` for each repo with source_branch, target_branch, and work-item parameters
    - Link each PR to the original work item
    - Provide all PR URLs in final summary

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-task-clarifier` — Analyze work item requirements and validate acceptance criteria
- `zzaia-repository-manager` — Manage homologation branch creation across multiple repositories
- `zzaia-tester-specialist` — Implement tests, execute test suites, and generate testing reports
- `zzaia-developer-specialist` — Review test implementations and fix issues discovered during homologation

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as /homologate
    participant WI as /devops:work-item
    participant WS as /workspace:new
    participant AR as /management:architect
    participant DT as /development:test
    participant DR as /development:review
    participant DD as /development:develop
    participant DG as /development:git
    participant SA as /workspace:setup-apphost
    participant BW as /devops:work-item
    participant PR as /devops:pull-request

    U->>C: /homologate (work-item, repos, branches, description)
    C->>C: Validate parameters

    C->>WI: Retrieve work item details
    WI-->>C: Title, description, acceptance criteria

    C->>WS: Create homologation branches (all repos)
    WS-->>C: Branch creation confirmation per repo

    C->>AR: Generate Test Plan (test cases focus)
    AR-->>C: Test Plan document

    C->>U: AskUserQuestion (approve Test Plan)
    U-->>C: Approval or clarifications

    C->>DT: Implement tests (per branch)
    DT-->>C: Test implementation summary

    C->>DG: Commit initial tests (all repos)
    DG-->>C: Commit confirmation

    C->>DR: Review test implementations
    DR-->>C: Review feedback

    opt Fixes needed
        C->>U: AskUserQuestion (address fixes)
        U-->>C: Approval for fixes
        C->>DD: Implement fixes
        DD-->>C: Fix summary
    end

    C->>DG: Commit and push fixes (all repos)
    DG-->>C: Commit confirmation

    C->>SA: Setup AppHost (all working branches)
    SA-->>C: AppHost environment ready

    C->>DT: Execute tests (AppHost environment)
    DT-->>C: Testing report (pass/fail, coverage, issues)

    C->>U: AskUserQuestion (approve bug creation)
    U-->>C: Approval or modifications

    loop For each issue found
        C->>BW: Create bug work item
        BW-->>C: Bug ID and link
    end

    loop For each repo
        C->>PR: Create pull request
        PR-->>C: PR URL and work item link
    end

    C-->>U: Complete report with bug IDs and PR URLs
```

## ACCEPTANCE CRITERIA

- Work item details retrieved and passed through all phases
- Homologation branches successfully created in all specified repositories
- Test Plan documentation generated with clear test scenarios and acceptance criteria
- User explicitly approves Test Plan before implementation proceeds
- Tests implemented covering all acceptance criteria from work item
- AppHost environment configured with all working branches
- Tests executed against integrated AppHost environment with measurable results
- Testing report generated with clear pass/fail status and metrics
- Bug work items created for all found issues with complete details and linking
- Pull requests created for all repositories linking to the original work item
- All phase statuses reported with clear completion indicators

## EXAMPLES

```
/homologate work-item=2001 repos=auth-service target-branches=develop working-branches=homolog/sprint-10 description="Homologate authentication flow for sprint 10"

/homologate work-item=2002 repos=auth-service,payment-service target-branches=develop,develop working-branches=homolog/sprint-10,homolog/sprint-10 description="Homologate integrated checkout flow across auth and payment services"
```

## OUTPUT

- Phase completion status with indicators
- Work item details summary (title, description, acceptance criteria)
- Branch creation confirmation per repository
- Test Plan document reference and summary
- Test implementation report per repository
- AppHost setup confirmation with all configured branches
- Testing report with metrics: total tests, pass count, fail count, coverage percentage
- List of discovered issues per application
- Created bug work item IDs with direct links
- Pull request URLs per repository with work item references
- Final summary report
