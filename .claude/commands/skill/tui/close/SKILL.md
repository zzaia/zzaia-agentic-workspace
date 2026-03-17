---
name: close
description: Gracefully shutdown the running TUI server and remove Unix socket
argument-hint: "[--description <text>]"
user-invocable: true
agent: zzaia-workspace-manager
metadata:
  scripts:
    - name: client
      script: ./scripts/client.py
  parameters:
    - name: description
      description: broader context for the operation
      required: false
---

## PURPOSE

Gracefully shutdown the running TUI server by sending a shutdown signal via the Unix socket, then clean up socket and PID files.

## EXECUTION

1. **Send shutdown signal**: Use `client.py` to send `{"type": "shutdown"}` message to the socket
2. **Wait for exit**: Give the server process time to exit cleanly
3. **Clean up files**: Remove `/tmp/zzaia-tui.sock` and `/tmp/zzaia-tui.pid`

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-workspace-manager` — Handle process termination and file cleanup

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant CLI as client.py
    participant S as server.py

    U->>C: /skill:tui:close
    C->>CLI: send shutdown message to socket
    CLI->>S: {"type": "shutdown"}
    S->>S: cleanup resources and exit
    S-->>CLI: connection closed
    C->>C: remove /tmp/zzaia-tui.sock
    C->>C: remove /tmp/zzaia-tui.pid
    C-->>U: TUI server shut down
```

## ACCEPTANCE CRITERIA

- Shutdown message sent successfully to socket
- Server process exits within timeout
- Socket file removed from filesystem
- PID file removed from filesystem
- No stray processes remain

## EXAMPLES

```
/skill:tui:close
/skill:tui:close --description "End debug session"
```

## OUTPUT

- Confirmation that TUI server has been shut down
- Socket and PID files cleaned up
- All resources released
