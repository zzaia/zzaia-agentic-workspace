---
name: tui
description: Render a Textual TUI application in a tmux split pane with bidirectional Unix socket communication
argument-hint: "--action <open|close|write|read> [options]"
---

# TUI Skill

Unified entry point for TUI operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter     | Required | Description                                    |
|---------------|----------|------------------------------------------------|
| `--action`    | Yes      | Operation to perform: `open`, `close`, `write`, `read` |
| `--description` | No     | Broader context for the operation              |

## Action Routing

| Action  | Command                        | Description                                  |
|---------|--------------------------------|----------------------------------------------|
| `open`  | [@skill:tui:open](./open/SKILL.md)   | Start TUI server in a new tmux split pane    |
| `close` | [@skill:tui:close](./close/SKILL.md) | Gracefully shutdown the running TUI          |
| `write` | [@skill:tui:write](./write/SKILL.md) | Send a structured event to the TUI           |
| `read`  | [@skill:tui:read](./read/SKILL.md)   | Read the last N log lines from the TUI       |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
