---
name: create-branch
description: Create a new branch from a source branch
argument-hint: "--portal <azure|github> --project <name> --repo <name> --branch <name> [--source-branch <name>]"
user-invocable: true
agent: zzaia-devops-specialist
metadata:
  parameters:
    - name: portal
      description: Portal type (azure or github)
      required: true
    - name: project
      description: Project or organization name
      required: true
    - name: repo
      description: Repository name
      required: true
    - name: branch
      description: New branch name to create
      required: true
    - name: source-branch
      description: Source branch to create from (defaults to repository default branch)
      required: false
---

## PURPOSE

Create a new branch in a repository, optionally from a specified source branch. If no source branch is provided, creates from the repository's default branch.

## EXECUTION

1. **Validate inputs**: Confirm portal, project, repo, and branch parameters are provided

2. **Resolve source**: Determine source branch
   - If `--source-branch` provided, use it
   - Otherwise, query repository default branch

3. **Create branch**: Call appropriate portal API or CLI tool
   - Azure DevOps: Use `mcp__azure-devops__repo_*` tools to create branch
   - GitHub: Use `gh` CLI to create branch

4. **Verify creation**: Confirm branch was created successfully

5. **Return result**: Display confirmation with branch details

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-devops-specialist` — Create branch via portal APIs and verify creation

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant A as zzaia-devops-specialist

    U->>C: /capability:repo:create-branch --portal <portal> --project <project> --repo <repo> --branch <branch> [--source-branch <source>]
    C->>A: Resolve source branch and create new branch
    A-->>C: Branch creation confirmation
    C-->>U: Success message with branch details
```

## ACCEPTANCE CRITERIA

- Source branch is correctly resolved (default or specified)
- New branch created successfully in remote repository
- Branch name follows repository naming conventions
- Error handling for branch already exists
- Error handling for invalid source branch
- Confirmation includes new branch name and source

## EXAMPLES

```
/capability:repo:create-branch --portal azure --project MyOrg --repo MyRepo --branch feature/new-feature
/capability:repo:create-branch --portal github --project my-org --repo my-repo --branch feature/new-feature --source-branch develop
/capability:repo:create-branch --portal azure --project MyOrg --repo MyRepo --branch bugfix/issue-123 --source-branch release/v1.0
```

## OUTPUT

Confirmation message including:
- New branch name created
- Source branch used
- Commit hash at branch point
- Remote URL for branch
- Success or error status
