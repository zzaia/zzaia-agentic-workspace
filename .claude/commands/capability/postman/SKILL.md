---
name: postman
description: Manage Postman workspace resources via MCP — collections, requests, environments, mocks, and HTTP execution
argument-hint: "--action <request|create|read|update|delete> --description <text> [options]"
---

# postman Skill

Unified entry point for Postman operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter       | Required | Description                                                           |
|-----------------|----------|-----------------------------------------------------------------------|
| `--action`      | Yes      | Operation to perform: `request`, `create`, `read`, `update`, `delete` |
| `--description` | No       | Broader description of what to do within the action                   |

## Action Routing

| Action    | Command                                    | Description                          |
|-----------|-------------------------------------------|--------------------------------------|
| `request` | [@capability:postman:request](./request/SKILL.md) | Execute HTTP calls via Postman runner |
| `create`  | [@capability:postman:create](./create/SKILL.md) | Create new resources (collections, requests, environments, mocks) |
| `read`    | [@capability:postman:read](./read/SKILL.md)     | Read and list existing resources |
| `update`  | [@capability:postman:update](./update/SKILL.md) | Update existing resources |
| `delete`  | [@capability:postman:delete](./delete/SKILL.md) | Delete resources by ID or name |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
