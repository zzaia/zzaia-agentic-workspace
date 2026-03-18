---
name: /workflow:remote:implement
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
  - name: auto-continue
    description: Skip interactive review confirmation and proceed automatically (use when invoked from orchestrators)
    required: false
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

   - Call `/behavior:devops:work-item --action read --id <work-item> --project <project>`
   - Obtain title, description, type (Bug or other), and acceptance criteria
   - **MANDATORY** Work item description must not be empty and must contain SDD documentation with all ADRs (skip for Bug type)
   - Change work item state to **Active** via `/behavior:devops:work-item --id <work-item> --project <project> --action update --state Active`

2. **Create Feature Branch**: Setup feature branch from target branch

   - Call `/behavior:workspace:repo --action new --repo <repo> --branch <working-branch> --target-branch <target-branch>`
   - Verify branch is ready for code changes and target branch is up to date

3. **Write Documentation Locally**: Produce the SDD documentation from the work item architecture design

   - **SKIP this phase if work item type is Bug**
   - Derive `<feature-name>` by converting `<work-item-title>` to lowercase kebab-case (e.g., `implement-provider-entities`)
   - Call `/skill:document:write --template service-architecture --title "<work-item-title>" --output ./docs/<feature-name>.md`
   - Organize following folder and name conventions that already exist

4. **Implement Feature**: Execute development based on SDD documentation or description

   - Call `/behavior:development:develop --task "<description + SDD content>" --repo <repo> --branch <working-branch>` — add `--auto-continue` when `--auto-continue` is set on this workflow
   - Implement functionality with comprehensive testing
   - Ensure code follows language-specific standards

5. **Commit and Push**: Stage, commit, and push implementation changes

   - Call `/behavior:development:git --action commit-push --repository <repo> --branch <working-branch> --message "feat: <description> [#<work-item>]"`

6. **Create Draft Pull Request**: Open draft pull request

   - Call `/behavior:devops:pull-request --action create --portal <portal> --project <project> --repo <repo> --source-branch <working-branch> --target-branch <target-branch> --work-item <work-item> --draft true`
   - Link PR to original work item

7. **Review Changes**: Review all developed changes and post findings to PR

   - Call `/behavior:development:review --target repo --path ./workspace/<repo>.worktrees/<working-branch>`
   - Generate numbered issue list from review output
   - Call `/skill:document:write --template pull-request-review --title "Review: <work-item-title>" --pr <pr-id> --target-field comment` to post the review with numbered issues to the PR
   - If `--auto-continue` is set, skip the question and proceed automatically to fix all issues
   - Otherwise call `/behavior:workspace:ask-user-question --question "Review posted to PR. How would you like to proceed?" --options "Fix all issues; Continue without fixing; <Any user input>"`

8. **Implement Accepted Reviews**: Apply review feedback based on user selection

   - Call `/behavior:devops:pull-request --action read --portal <portal> --project <project> --repo <repo> --pr <pr-id>` to retrieve the PR review comment posted in Phase 7 and extract the numbered issue list from it
   - Call `/behavior:development:develop --task "Fix all review issues: <numbered-issue-list>" --repo <repo> --branch <working-branch>`

9. **Commit and Push**: Stage, commit, and push all changes

   - If merge conflicts are detected, call `/workflow:fix-merge --repo <repo> --working-branch <working-branch> --target-branch <target-branch>` before committing
   - Call `/behavior:development:git --action commit-push --repository <repo> --branch <working-branch> --message "fix: apply review feedback [#<work-item>]"`
   - Change work item state to **Resolved** via `/behavior:devops:work-item --id <work-item> --project <project> --action update --state Resolved`

10. **Publish Pull Request**: Mark pull request as ready for review

    - Call `/behavior:devops:pull-request --action update --portal <portal> --project <project> --repo <repo> --pr <pr-id> --draft false`
    - Confirm PR is published and share PR link with user

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
    participant P as /workflow:remote:implement
    participant WI as /behavior:devops:work-item
    participant WN as /behavior:workspace:repo --action new
    participant DW as /skill:document:write
    participant DD as /behavior:development:develop
    participant DR as /behavior:development:review
    participant DG as /behavior:development:git
    participant PR as /behavior:devops:pull-request

    U->>P: /workflow:remote:implement <params>

    P->>WI: Retrieve work item
    WI-->>P: Work item details (title, type, SDD)
    P->>WI: Update state to Active
    WI-->>P: State updated

    P->>WN: Create feature branch
    WN-->>P: Branch ready

    alt work item type is NOT Bug
        P->>DW: Write SDD documentation locally
        DW-->>P: SDD file written
    end

    P->>DD: Implement from SDD
    DD-->>P: Implementation complete

    P->>DG: Commit and push implementation
    DG-->>P: Changes pushed

    P->>PR: Create draft pull request
    PR-->>P: PR created

    P->>DR: Review changes
    DR-->>P: Numbered issue list
    P->>DW: Write pull-request-review to PR comment
    DW-->>P: Review posted
    P->>U: /behavior:workspace:ask-user-question (confirm to continue)
    U-->>P: Confirmed

    P->>PR: Read review issues from PR
    PR-->>P: Issue list

    P->>DD: Fix all review issues
    DD-->>P: Fixes applied

    P->>DG: Commit and push fixes
    DG-->>P: Changes pushed (fix-merge if conflicts)
    P->>WI: Update state to Resolved
    WI-->>P: State updated

    P->>PR: Publish PR (draft false)
    PR-->>P: PR published

    P-->>U: Workflow complete — PR link & summary
```

## ACCEPTANCE CRITERIA

- Work item details retrieved with non-empty SDD documentation and ADRs (except Bug type)
- Work item state changed to Active at start of workflow
- Feature branch created from target branch with correct naming
- SDD documentation written to `./docs/` folder following existing conventions (skipped for Bug type)
- Implementation executes with full work item context and SDD documentation
- Initial implementation committed and pushed before PR creation
- Draft pull request created linking feature branch to target branch with work item reference
- Review findings posted to PR as numbered issue list using `pull-request-review` template via `/skill:document:write`
- When `--auto-continue` is set, review confirmation is skipped and all issues are fixed automatically
- When interactive, user chooses between fixing all issues, continuing without fixes, or providing custom input
- All review issues implemented and committed with conventional format referencing work item
- Merge conflicts resolved via `/workflow:fix-merge` before final push
- Work item state changed to Resolved after final commit and push
- Pull request published (draft removed) after fixes are pushed
- Workflow execution provides clear output at each phase with status and results

## EXAMPLES

```
/workflow:remote:implement --work-item 1605 --portal azure --project my-project --repo order-service --target-branch develop --working-branch feature/implement-providers-entities --description "Implement provider entities following order-service pattern with repository pattern and comprehensive unit tests"

/workflow:remote:implement --work-item 1606 --portal azure --project my-project --repo order-service --target-branch develop --working-branch feature/add-provider-api --description "Add provider API endpoints with CRUD operations, validation, and integration tests"

/workflow:remote:implement --work-item 1607 --portal github --project my-org/my-project --repo order-service --target-branch main --working-branch feature/fix-authentication-bug --description "Fix authentication token refresh issue and add regression tests"
```

## OUTPUT

- Phase status reports with completion indicators
- Work item details retrieved in phase 1
- Feature branch reference and ready status
- Implementation summary with test results
- Git commit hash and push confirmation
- Pull request URL and link to work item
