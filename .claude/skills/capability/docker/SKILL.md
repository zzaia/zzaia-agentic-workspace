---
name: capability:docker
description: Retrieve and debug Docker environment — raw state and issue analysis
argument-hint: "--action <query|debug> [--target <containers|images|volumes|networks>] [--description <text>]"
---

# docker Skill

Unified entry point for Docker operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter     | Required | Description                                      |
|---------------|----------|--------------------------------------------------|
| `--action`    | Yes      | Operation to perform: `query`, `debug`           |

## Action Routing

| Action  | Command                                       | Description                                               |
|---------|-----------------------------------------------|-----------------------------------------------------------|
| `query` | [@capability:docker:query](./query/SKILL.md)  | Retrieve raw Docker state via CLI                         |
| `debug` | [@capability:docker:debug](./debug/SKILL.md)  | Analyze Docker environment and surface issues             |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
