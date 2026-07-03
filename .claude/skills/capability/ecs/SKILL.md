---
name: capability:ecs
description: Retrieve and debug AWS ECS clusters — raw resource data and deployment analysis
argument-hint: "--action <query|debug> --cluster <name> [--resource <type>] [--description <text>]"
---

# ecs Skill

Unified entry point for ECS operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter    | Required | Description                                  |
|--------------|----------|----------------------------------------------|
| `--action`   | Yes      | Operation to perform: `query`, `debug`       |
| `--cluster`  | Yes      | ECS cluster name or ARN                      |

## Action Routing

| Action  | Command                                  | Description                                        |
|---------|------------------------------------------|----------------------------------------------------|
| `query` | [@capability:ecs:query](./query/SKILL.md) | Retrieve raw ECS cluster data and resources        |
| `debug` | [@capability:ecs:debug](./debug/SKILL.md) | Analyze cluster state and surface issues and warnings|

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
