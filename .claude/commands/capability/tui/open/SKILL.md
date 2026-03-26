---
name: open
description: Start TUI server in a new tmux split pane with Unix socket at /tmp/zzaia-tui.sock
argument-hint: "--session <name> --direction <horizontal|vertical> [--description <text>]"
user-invocable: true
metadata:
  scripts:
    - name: server
      script: ./scripts/server.py
  parameters:
    - name: session
      description: tmux session name to split in (default uses current session)
      required: false
    - name: direction
      description: split direction - horizontal or vertical (default horizontal)
      required: false
    - name: description
      description: broader context for the operation
      required: false
---

## PURPOSE

Start a Textual TUI server in a new tmux split pane. The TUI listens on a Unix socket at `/tmp/zzaia-tui.sock` for structured events and renders them as formatted log entries with color coding.

## EXECUTION

1. **Create tmux split**: Use `capability:tmux:split-window` to create a new pane in the specified direction
2. **Launch server**: Execute `server.py` in the new pane, which binds the Unix socket and starts the Textual app
3. **Verify socket**: Confirm the socket file exists at `/tmp/zzaia-tui.sock` and is ready for connections

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant TM as tmux
    participant S as server.py

    U->>C: /capability:tui:open --session <name> --direction <dir>
    C->>TM: split-window in specified direction
    C->>S: execute server.py in new pane
    S->>S: bind Unix socket at /tmp/zzaia-tui.sock
    S->>S: start Textual TUI event loop
    S-->>C: socket ready
    C-->>U: TUI server started
```

## ACCEPTANCE CRITERIA

- Socket file created at `/tmp/zzaia-tui.sock`
- PID file written to `/tmp/zzaia-tui.pid` on startup
- Textual TUI renders in new tmux pane
- TUI remains responsive to incoming events
- `server.py` continues running until shutdown signal received

## EXAMPLES

```
/capability:tui:open --session main --direction horizontal
/capability:tui:open --direction vertical
/capability:tui:open
```

## OUTPUT

- TUI window displayed in new tmux split pane
- Socket ready for write/read operations
- Process ID file available for shutdown reference
