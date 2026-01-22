---
name: /implement
description: Orchestrate complete implementation workflow for work items from creation to pull request
parameters:
  - name: workitem
    description: Work item ID to implement (e.g., 1605)
    required: true
  - name: repository_name 
    description: Repository name to work on 
    required: true
  - name: target_branch
    description: Base branch to create feature branch from, usually remote (e.g., develop, main)
    required: true
  - name: branch_name
    description: Name of the feature branch to create (e.g., feature/implement-some-stuff)
    required: true
  - name: description
    description: Implementation description/details for the developer
    required: true
---

## PURPOSE

Execute a complete implementation workflow that orchestrates multiple development commands in sequence. This generic, reusable workflow enables developers to implement work items following consistent patterns from requirements retrieval through pull request creation.

## WORKFLOW PHASES 

1. **Retrieve Work Item**: Fetch work item details and requirements

   - Call `/management:work-items` with workitem parameter
   - Obtain title, description, and acceptance criteria
   - Pass retrieved context to implementation phase
   - **MANDATORY** work-item must have non-empty descriptions

2. **Create Feature Branch**: Setup feature branch from target branch

   - Call `/workspace:new` with repository_name, target_branch, new_branch_name parameters
   - Prepare worktree for development
   - Verify branch is ready for code changes

3. **Clarify Feature**: Ask user for important clarifying questions about the feature 

   - Call `/ask` with branch, work directory, and description parameters
   - Clarify all requirements with the user before going to next phase 
   - Use the tool **AskUserQuestion** to inquiry the user answers

4. **Implement Documentation**: Implement the SDD documentation in a concise manner 

   - Call `/development:architect` with branch, work directory, and description parameters
   - Clarify all requirements with the user before implementing documentations
   - Implement one small necessary Specification Driven Design (SDD) documentation to implement the feature  
   - **MANDATORY** This must be very concise and have only the relevant feature information

5. **Wait User Approval**: Wait for the user to review and make changes to the SDD documentation 
   - User should make some changes to SDD before next phase
   - Use the tool **AskUserQuestion** to inquiry the user answers

6. **Implement Feature**: Execute development based on SDD documentation

   - Call `/development:develop` in branch_name with approved SDD documentation 
   - Implement functionality with comprehensive testing
   - Ensure code follows language-specific standards

7. **Commit and Push**: Stage, commit, and push all changes

   - Call `/development:git` with branch parameter
   - Create conventional commit message referencing work item
   - Push changes to remote origin

8. **Create Pull Request**: Open pull request for review

   - Call `/management:pull-request` with source_branch, target_branch, workitem parameters
   - Link PR to original work item
   - Prepare for code review and merge

## WORKFLOW DIAGRAM

```mermaid
sequenceDiagram
    participant U as User
    participant P as /implement Workflow
    participant MgmtW as /management:work-items
    participant WkspM as /workspace:new
    participant DevA as /development:architect
    participant DevD as /development:develop
    participant DevG as /development:git
    participant MgmtP as /management:pull-request

    U->>P: /implement workitem=1605<br/>repository_name=fiat-service<br/>target_branch=develop<br/>branch_name=feature/...<br/>description="..."

    P->>MgmtW: Retrieve work item
    MgmtW-->>P: Work item details

    P->>WkspM: Create feature branch
    WkspM-->>P: Branch ready

    P->>DevA: Generate SDD documentation
    DevA-->>P: Architecture & spec docs

    P->>U: Review SDD documentation
    U-->>P: Approve/update specs

    P->>DevD: Implement from approved SDD
    DevD-->>P: Implementation complete

    P->>DevG: Commit and push
    DevG-->>P: Changes pushed

    P->>MgmtP: Create pull request
    MgmtP-->>P: PR created

    P-->>U: Workflow complete<br/>PR link & summary
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
