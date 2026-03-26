---
name: list-branches
description: List branches in a repository, optionally filtered by prefix
argument-hint: "--portal <azure|github> --project <name> --repo <name> [--branch <prefix>]"
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
      description: Optional branch name prefix filter
      required: false
---

## PURPOSE

Retrieve and display all branches in a repository, with optional filtering by branch name prefix.

## EXECUTION

1. **Validate inputs**: Confirm portal, project, and repo parameters are provided

2. **Fetch branches**: Call appropriate portal API or CLI tool
   - Azure DevOps: Use `mcp__azure-devops__repo_*` tools to list branches
   - GitHub: Use `gh` CLI to list repository branches

3. **Filter branches**: If `--branch` prefix provided, filter branch list

4. **Parse response**: Extract branch names and metadata

5. **Return result**: Display filtered branch list

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-devops-specialist` — Query portal APIs and filter branches

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant A as zzaia-devops-specialist

    U->>C: /capability:repo:list-branches --portal <portal> --project <project> --repo <repo> [--branch <prefix>]
    C->>A: Query branches in repository
    A-->>C: List of branches (filtered if prefix provided)
    C-->>U: Formatted branch list
```

## ACCEPTANCE CRITERIA

- All branches retrieved from repository
- Prefix filter works correctly when provided
- Branch names clearly displayed
- Default branch marked if identifiable
- Graceful handling of empty branch lists

## EXAMPLES

```
/capability:repo:list-branches --portal azure --project MyOrg --repo MyRepo
/capability:repo:list-branches --portal github --project my-org --repo my-repo --branch feature/
/capability:repo:list-branches --portal azure --project MyOrg --repo MyRepo --branch hotfix/
```

## OUTPUT

List of branches with metadata:
- Branch name
- Last commit hash (abbreviated)
- Last commit message (if available)
- Last updated timestamp (if available)
- Mark indicating default branch
