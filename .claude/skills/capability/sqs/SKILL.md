---
name: capability:sqs
description: Retrieve and debug AWS SQS queues — raw messages and issue analysis
argument-hint: "--action <query|debug> --queue-name <name> [--max-messages <number>] [--description <text>]"
---

# sqs Skill

Unified entry point for SQS operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter      | Required | Description                                  |
|----------------|----------|----------------------------------------------|
| `--action`     | Yes      | Operation to perform: `query`, `debug`       |
| `--queue-name` | Yes      | SQS queue name or URL                        |

## Action Routing

| Action  | Command                                   | Description                                        |
|---------|-------------------------------------------|----------------------------------------------------|
| `query` | [@capability:sqs:query](./query/SKILL.md) | Retrieve raw messages from an SQS queue            |
| `debug` | [@capability:sqs:debug](./debug/SKILL.md) | Analyze queue state and surface issues and warnings|

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
