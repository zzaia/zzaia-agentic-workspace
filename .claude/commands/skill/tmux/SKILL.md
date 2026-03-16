---
name: tmux
description: Manage tmux sessions, windows, and panes for persistent terminal sessions
argument-hint: "--action <new|list|attach|split-window|send-keys|kill-session> [options]"
---

# tmux Skill

Unified entry point for tmux operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter      | Required | Description                                              |
|----------------|----------|----------------------------------------------------------|
| `--action`     | Yes      | Operation to perform: `new`, `list`, `attach`, `split-window`, `send-keys`, `kill-session` |
| `--description` | No       | Broader context for the operation                        |

## Action Routing

| Action         | Command                                            | Description                                              |
|----------------|----------------------------------------------------|----------------------------------------------------------|
| `new`          | [@skill:tmux:new](./new/SKILL.md)                 | Create a new named tmux session                          |
| `list`         | [@skill:tmux:list](./list/SKILL.md)               | List all active tmux sessions with status               |
| `attach`       | [@skill:tmux:attach](./attach/SKILL.md)           | Attach to an existing tmux session                      |
| `split-window` | [@skill:tmux:split-window](./split-window/SKILL.md) | Split a tmux window horizontally or vertically         |
| `send-keys`    | [@skill:tmux:send-keys](./send-keys/SKILL.md)     | Send keystrokes or commands to a target pane           |
| `kill-session` | [@skill:tmux:kill-session](./kill-session/SKILL.md) | Kill tmux sessions by name                             |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
