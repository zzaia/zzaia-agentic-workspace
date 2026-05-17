---
name: capability:aspire
description: Query and debug Aspire AppHost telemetry — retrieve logs, traces, and resource metadata
argument-hint: "--action <query|debug> [--application <name>] [--description <text>]"
---

# aspire Skill

Unified entry point for Aspire operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter      | Required | Description                                  |
|----------------|----------|----------------------------------------------|
| `--action`     | Yes      | Operation to perform: `query`, `debug`       |
| `--application`| No       | Filter to a single application name          |

## Action Routing

| Action  | Command                                       | Description                                        |
|---------|-----------------------------------------------|----------------------------------------------------|
| `query` | [@capability:aspire:query](./query/SKILL.md)  | Retrieve raw telemetry from Aspire AppHost         |
| `debug` | [@capability:aspire:debug](./debug/SKILL.md)  | Analyze telemetry and surface issues and warnings  |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
