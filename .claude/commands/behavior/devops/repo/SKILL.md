---
name: repo
description: Manage repositories in external DevOps portals — read metadata, list branches, create branches, and list repos across Azure DevOps and GitHub
argument-hint: "--action <read|list-repos|list-branches|create-branch> [options]"
---

# behavior:devops:repo

Unified entry point for repository operations in external DevOps portals. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter  | Required | Description                                                                  |
|------------|----------|------------------------------------------------------------------------------|
| `--action` | Yes      | Operation to perform: `read`, `list-repos`, `list-branches`, `create-branch` |

## Action Routing

| Action           | Command                                                       | Description                               |
|------------------|---------------------------------------------------------------|-------------------------------------------|
| `read`           | [@behavior:devops:repo:read](./read/SKILL.md)                 | Read repository metadata                  |
| `list-repos`     | [@behavior:devops:repo:list-repos](./list-repos/SKILL.md)     | List all repositories in a project        |
| `list-branches`  | [@behavior:devops:repo:list-branches](./list-branches/SKILL.md) | List branches, optionally filtered      |
| `create-branch`  | [@behavior:devops:repo:create-branch](./create-branch/SKILL.md) | Create a new branch from source         |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
