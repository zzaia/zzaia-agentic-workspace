---
name: /workflow:implement
description: Orchestrate complete implementation workflow for work items from creation to pull request
argument-hint: "--work-item <id> --repo <name> --target-branch <branch> --working-branch <feature/name> --description <text>"
parameters:
  - name: work-item
    description: Work item ID to implement (e.g., 1605)
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
  - name: zzaia-repository-manager
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

   - Call `/devops:work-item` with workitem parameter
   - Obtain title, description, and acceptance criteria
   - Pass retrieved context to implementation phase
   - **MANDATORY**  Must use the work item descriptions and it must not be empty 

2. **Create Feature Branch**: Setup feature branch from target branch

   - Call `/workspace:new` with repository_name, target_branch, new_branch_name parameters
   - Prepare worktree for development
   - Verify branch is ready for code changes
   - Verify that the target branch is updated

3. **Think & Architect**: Analyze requirements and design the solution

   - Call `/management:architect` with branch, work directory, and description parameters
   - Clarify all requirements with the user before going to next phase
   - Use the tool **AskUserQuestion** to inquiry the user for clarifying questions
   - Produce a concise architecture design covering only what is relevant to the feature
   - **MANDATORY** All open questions must be resolved before proceeding to documentation

4. **Write Documentation**: Produce the SDD documentation from the architecture design

   - Call `/document:write` with the architecture output from phase 3 as input
   - Generate one concise Specification Driven Design (SDD) document for the feature
   - **MANDATORY** Documentation must be written to file before user approval phase

5. **Wait User Approval**: Wait for the user to review and make changes to the SDD documentation

   - User should make changes to SDD before next phase
   - Use the tool **AskUserQuestion** to inquiry the user answers

6. **Implement Feature**: Execute development based on SDD documentation

   - Call `/development:develop` in branch_name with approved SDD documentation
   - Implement functionality with comprehensive testing
   - Ensure code follows language-specific standards

7. **Review Changes**: Review all developed changes

   - Call `/development:review` for all developed changes
   - Use the tool **AskUserQuestion** to inquiry the user answers about what to fix or improve
   - Call `/development:develop` to fix or improve the code

8. **Commit and Push**: Stage, commit, and push all changes

   - Call `/development:git` with branch parameter
   - Create conventional commit message referencing work item
   - Push changes to remote origin

9. **Create Draft Pull Request**: Open pull request

   - Call `/devops:pull-request` with source_branch, target_branch, work-item parameters to create a draft pull request
   - Link PR to original work item

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-task-clarifier` — Analyze work item requirements and clarify acceptance criteria
- `zzaia-repository-manager` — Manage feature branch creation and worktree setup
- `zzaia-developer-specialist` — Implement feature based on approved SDD documentation
- `zzaia-tester-specialist` — Validate build quality and test coverage

## WORKFLOW DIAGRAM

```mermaid
sequenceDiagram
    participant U as User
    participant P as /workflow:implement
    participant WI as /devops:work-item
    participant WN as /workspace:new
    participant MA as /management:architect
    participant DW as /document:write
    participant DD as /development:develop
    participant DR as /development:review
    participant DG as /development:git
    participant PR as /devops:pull-request

    U->>P: /workflow:implement <params>

    P->>WI: Retrieve work item
    WI-->>P: Work item details

    P->>WN: Create feature branch
    WN-->>P: Branch ready

    P->>MA: Think & architect
    MA-->>P: Architecture design

    P->>DW: Write SDD documentation
    DW-->>P: SDD file written

    P->>U: AskUserQuestion (review SDD)
    U-->>P: Approved / changes requested

    P->>DD: Implement from approved SDD
    DD-->>P: Implementation complete

    P->>DR: Review changes
    DR-->>P: Review report
    P->>U: AskUserQuestion (fix/improve?)
    U-->>P: Feedback
    P->>DD: Apply fixes
    DD-->>P: Fixes applied

    P->>DG: Commit and push
    DG-->>P: Changes pushed

    P->>PR: Create draft pull request
    PR-->>P: PR created

    P-->>U: Workflow complete — PR link & summary
```

## ACCEPTANCE CRITERIA

- Work item details successfully retrieved and passed to implementation phase
- Feature branch created from target branch with correct naming
- Implementation executes with full work item context and description
- All code changes committed with conventional format referencing work item
- Pull request created linking feature branch to target branch with work item reference
- workflow execution provides clear output at each phase with status and results

## EXAMPLES

```
/implement workitem=1605 target_branch=develop branch_name=feature/implement-providers-entities description="Implement provider entities following order-service pattern with repository pattern and comprehensive unit tests"

/implement workitem=1606 target_branch=develop branch_name=feature/add-provider-api description="Add provider API endpoints with CRUD operations, validation, and integration tests"

/implement workitem=1607 target_branch=main branch_name=feature/fix-authentication-bug description="Fix authentication token refresh issue and add regression tests"
```

## OUTPUT

- Phase status reports with completion indicators
- Work item details retrieved in phase 1
- Feature branch reference and ready status
- Implementation summary with test results
- Git commit hash and push confirmation
- Pull request URL and link to work item
