---
name: /workflow:fix-merge
description: Merge from target branch, resolve conflicts, fix issues, and push changes
argument-hint: "--repo <name> --working-branch <branch> --target-branch <branch> --description <context>"
parameters:
  - name: repo
    description: Repository name to work on
    required: true
  - name: working-branch
    description: The branch being worked on where the merge is applied into
    required: true
  - name: target-branch
    description: The branch to merge from (e.g., develop, main)
    required: true
  - name: description
    description: Additional context about the merge or expected conflicts
    required: false
agents:
  - name: zzaia-developer-specialist
    description: Resolve merge conflicts and fix post-merge issues
  - name: zzaia-workspace-manager
    description: Manage git operations across worktrees
---

## PURPOSE

Merge from a target branch into the working branch, automatically resolving merge conflicts, identifying issues that arose from the merge, fixing them systematically, and pushing the result to remote.

## WORKFLOW PHASES

1. **Merge from Target Branch**: Pull target branch then perform merge operation and resolve all merge conflicts

   - Call `/development:git` with `--repo <repo>` `--branch <target-branch>` `--action pull` to ensure target branch is up to date
   - Call `/development:git` with `--repo <repo>` `--working-branch <working-branch>` `--target-branch <target-branch>` `--action merge`
   - Resolve merge conflicts with context from `--description`
   - **MANDATORY** Verify no unresolved conflicts remain

2. **Review Merge Result**: Identify issues that arose from the merge

   - Call `/development:review` with `--repo <repo>` `--branch <working-branch>` `--context "verification of merged related files"`
   - Focus only on issues merge files with conflict
   - Document all issues found
   - Call `/workspace:ask-user-question --question "Review findings confirmed. Approve proceeding to fixes?" --options "Proceed with fixes; Describe additional context"`

3. **Fix Issues**: Address all issues identified in the review

   - Call `/development:develop` with `--repo <repo>` `--branch <working-branch>` `--task "Fix post-merge issues"`
   - Fix all identified issues systematically
   - Re-run `/development:review` to verify fixes

4. **Push Changes**: Commit and push all changes to remote

   - Call `/development:git` with `--repo <repo>` `--branch <working-branch>` `--action push`
   - Push all commits to remote
   - **MANDATORY** Verify remote branch is updated

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-developer-specialist` — Resolve merge conflicts, fix post-merge issues, verify compatibility
- `zzaia-workspace-manager` — Execute git merge, review, and push operations across worktrees

## WORKFLOW DIAGRAM

```mermaid
sequenceDiagram
    participant U as User
    participant W as /workflow:fix-merge
    participant C1 as /development:git
    participant C2 as /development:review
    participant C3 as /development:develop
    participant C4 as /development:git

    U->>W: /workflow:fix-merge --repo <repo> --working-branch <working-branch> --target-branch <target-branch>
    W->>C1: Pull target-branch (ensure up to date)
    C1-->>W: Target branch updated
    W->>C1: Merge target-branch into working-branch
    C1-->>W: Merge complete, conflicts resolved
    W->>C2: Review post-merge state
    C2-->>W: Issues identified
    W->>U: /workspace:ask-user-question (confirm review & proceed)
    U-->>W: Approval
    W->>C3: Fix all identified issues
    C3-->>W: Issues fixed, verified
    W->>C4: Commit and push to remote
    C4-->>W: Remote updated
    W-->>U: Workflow complete
```

## ACCEPTANCE CRITERIA

- Merge from target branch completes without unresolved conflicts
- All post-merge issues identified and fixed
- All changes committed with conventional commit messages
- Remote branch reflects all local changes
- Working branch is clean and ready for continued development

## EXAMPLES

```
/workflow:fix-merge --repo myrepo --working-branch feature/new-api --target-branch develop
/workflow:fix-merge --repo myrepo --working-branch feature/new-api --target-branch develop --description "Expect conflicts in schema definitions"
```

## OUTPUT

- Merge completion status with conflict resolution details
- Post-merge review report with issues identified
- Fix verification report confirming all issues resolved
- Push confirmation with remote branch state
