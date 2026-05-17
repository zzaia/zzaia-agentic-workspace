---
name: capability:new-relic
description: Query and debug New Relic observability data — retrieve logs, errors, warnings, anomalies, and metrics
argument-hint: "--action <query|debug> --application-name <name> [options]"
---

# new-relic Skill

Unified entry point for New Relic operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter            | Required | Description                                        |
|----------------------|----------|----------------------------------------------------|
| `--action`           | Yes      | Operation to perform: `query`, `debug`             |
| `--application-name` | Yes      | Application name to query in New Relic             |

## Action Routing

| Action  | Command                                         | Description                                          |
|---------|-------------------------------------------------|------------------------------------------------------|
| `query` | [@capability:new-relic:query](./query/SKILL.md) | Retrieve raw telemetry data from New Relic           |
| `debug` | [@capability:new-relic:debug](./debug/SKILL.md) | Analyze telemetry and surface issues and warnings    |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
