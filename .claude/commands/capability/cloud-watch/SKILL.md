---
name: capability:cloud-watch
description: Query and debug AWS observability data — retrieve CloudWatch logs, metrics, and X-Ray traces
argument-hint: "--action <query|debug> --service-name <name> [options]"
---

# cloud-watch Skill

Unified entry point for AWS CloudWatch operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter      | Required | Description                                     |
|----------------|----------|-------------------------------------------------|
| `--action`     | Yes      | Operation to perform: `query`, `debug`          |
| `--service-name` | Yes    | AWS service name or log group to query          |

## Action Routing

| Action  | Command                                          | Description                                        |
|---------|--------------------------------------------------|----------------------------------------------------|
| `query` | [@capability:cloud-watch:query](./query/SKILL.md) | Retrieve raw telemetry data from CloudWatch and X-Ray |
| `debug` | [@capability:cloud-watch:debug](./debug/SKILL.md) | Analyze telemetry and surface issues and anomalies |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
