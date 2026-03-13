---
name: /workflow:implement
description: Orchestrate complete implementation workflow for work items from creation to pull request
argument-hint: "--work-item <id> --portal <azure|github> --project <name> --repo <name> --target-branch <branch> --working-branch <feature/name> --description <text>"
parameters:
  - name: work-item
    description: Work item ID to implement (e.g., 1605)
    required: true
  - name: portal
    description: DevOps portal to use (azure or github)
    required: true
  - name: project
    description: Project name in the DevOps portal (e.g., my-project)
    required: true
  - name: repo
    description: Repository name to work on
    required: true
  - name: target-branch
    description: Base branch to create feature branch from, usually remote (e.g., develop, main), it is the target branch during the pull request creation
    required: true
  - name: working-branch
    description: Name of the feature branch to create (e.g., feature/implement-some-stuff) and work on
    required: true
  - name: description
    description: Implementation description/details for the developer
    required: true
agents:
  - name: zzaia-task-clarifier
    description: Analyze work item requirements and clarify acceptance criteria
  - name: zzaia-workspace-manager
    description: Manage feature branch creation and worktree setup
  - name: zzaia-developer-specialist
    description: Implement feature based on approved SDD documentation
  - name: zzaia-tester-specialist
    description: Validate build quality and test coverage
---

## PURPOSE

Execute a complete implementation workflow that orchestrates multiple development commands in sequence. This generic, reusable workflow enables developers to implement work items following consistent patterns from requirements retrieval through pull request creation.

## WORKFLOW PHASES

1. **Retrieve Work Item**: Fetch work item details and requirements

   - Call `/devops:work-item --work-item <work-item> --portal <portal> --project <project>`
   - Obtain title, description, type (Bug or other), and acceptance criteria
   - Pass retrieved context to implementation phase
   - **MANDATORY** Work item description must not be empty
   - Change work item state to **Active** via `/devops:work-item --work-item <work-item> --portal <portal> --project <project> --action update --state Active`

2. **Create Feature Branch**: Setup feature branch from target branch

   - Call `/workspace:repo --action new --repo <repo> --target-branch <target-branch> --branch <working-branch>`
   - Verify branch is ready for code changes and target branch is up to date

3. **Think & Architect**: Analyze requirements and design the solution

   - **SKIP this phase if work item type is Bug**
   - Call `/management:architect --description "<description>" --context "<work-item-details>"`
   - Clarify all requirements with the user before proceeding
   - Call `/workspace:ask-user-question --question "<clarifying question about requirements>"`
   - Produce a concise architecture design covering only what is relevant to the feature
   - **MANDATORY** All open questions must be resolved before proceeding to documentation

4. **Write Documentation**: Produce the SDD documentation from the architecture design

   - **SKIP this phase if work item type is Bug**
   - Call `/document:write --context "<architecture-output>" --output local`
   - Generate one concise Specification Driven Design (SDD) document for the feature
   - **MANDATORY** Documentation must be written to file before user approval phase

5. **Wait User Approval**: Wait for the user to review and make changes to the SDD documentation

   - **SKIP this phase if work item type is Bug**
   - Call `/workspace:ask-user-question --question "Please review the SDD documentation and confirm to proceed or describe changes needed"`

6. **Implement Feature**: Execute development based on approved SDD documentation or description

   - Call `/development:develop --repo <repo> --branch <working-branch> --task "<description>"`
   - Implement functionality with comprehensive testing
   - Ensure code follows language-specific standards

7. **Review Changes**: Review all developed changes

   - Call `/development:review --repo <repo> --branch <working-branch>`
   - Call `/workspace:ask-user-question --question "What would you like to fix or improve?" --options "Continue as-is; Describe fixes needed"`
   - Call `/development:develop --repo <repo> --branch <working-branch> --task "Fix review issues"`

8. **Commit and Push**: Stage, commit, and push all changes

   - Call `/development:git --repo <repo> --branch <working-branch> --action commit-push --message "feat: <description> [#<work-item>]"`
   - Push changes to remote origin
   - Change work item state to **Resolved** via `/devops:work-item --work-item <work-item> --portal <portal> --project <project> --action update --state Resolved`

9. **Create Draft Pull Request**: Open pull request

   - Call `/devops:pull-request --portal <portal> --project <project> --repo <repo> --source-branch <working-branch> --target-branch <target-branch> --work-item <work-item> --draft`
   - Link PR to original work item

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-task-clarifier` — Analyze work item requirements and clarify acceptance criteria
- `zzaia-workspace-manager` — Manage feature branch creation and worktree setup
- `zzaia-developer-specialist` — Implement feature based on approved SDD documentation
- `zzaia-tester-specialist` — Validate build quality and test coverage

## WORKFLOW DIAGRAM

```mermaid
sequenceDiagram
    participant U as User
    participant P as /workflow:implement
    participant WI as /devops:work-item
    participant WN as /workspace:repo --action new
    participant MA as /management:architect
    participant DW as /document:write
    participant DD as /development:develop
    participant DR as /development:review
    participant DG as /development:git
    participant PR as /devops:pull-request

    U->>P: /workflow:implement <params>

    P->>WI: Retrieve work item
    WI-->>P: Work item details (title, type)
    P->>WI: Update state to Active
    WI-->>P: State updated

    P->>WN: Create feature branch
    WN-->>P: Branch ready

    alt work item type is NOT Bug
        P->>MA: Think & architect
        MA-->>P: Architecture design

        P->>DW: Write SDD documentation
        DW-->>P: SDD file written

        P->>U: /workspace:ask-user-question (review SDD)
        U-->>P: Approved / changes requested
    end

    P->>DD: Implement from approved SDD
    DD-->>P: Implementation complete

    P->>DR: Review changes
    DR-->>P: Review report
    P->>U: /workspace:ask-user-question (fix/improve?)
    U-->>P: Feedback
    P->>DD: Apply fixes
    DD-->>P: Fixes applied

    P->>DG: Commit and push
    DG-->>P: Changes pushed
    P->>WI: Update state to Resolved
    WI-->>P: State updated

    P->>PR: Create draft pull request
    PR-->>P: PR created

    P-->>U: Workflow complete — PR link & summary
```

## ACCEPTANCE CRITERIA

- Work item details successfully retrieved and passed to implementation phase
- Work item state changed to Active at start of workflow
- Feature branch created from target branch with correct naming
- Think & Architect, Write Documentation, and Wait User Approval phases skipped for Bug type work items
- Implementation executes with full work item context and description
- All code changes committed with conventional format referencing work item
- Work item state changed to Resolved after final commit and push
- Pull request created linking feature branch to target branch with work item reference
- Workflow execution provides clear output at each phase with status and results

## EXAMPLES

```
/workflow:implement --work-item 1605 --portal azure --project my-project --repo order-service --target-branch develop --working-branch feature/implement-providers-entities --description "Implement provider entities following order-service pattern with repository pattern and comprehensive unit tests"

/workflow:implement --work-item 1606 --portal azure --project my-project --repo order-service --target-branch develop --working-branch feature/add-provider-api --description "Add provider API endpoints with CRUD operations, validation, and integration tests"

/workflow:implement --work-item 1607 --portal github --project my-org/my-project --repo order-service --target-branch main --working-branch feature/fix-authentication-bug --description "Fix authentication token refresh issue and add regression tests"
```

## OUTPUT

- Phase status reports with completion indicators
- Work item details retrieved in phase 1
- Feature branch reference and ready status
- Implementation summary with test results
- Git commit hash and push confirmation
- Pull request URL and link to work item
