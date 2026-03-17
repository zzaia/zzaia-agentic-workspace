---
name: list
description: List all active tmux sessions with status, windows, and creation time
argument-hint: "[--description <context>]"
user-invocable: true
metadata:
  parameters:
    - name: description
      description: Broader context for the operation
      required: false
---

## PURPOSE

Retrieve and display all currently active tmux sessions with detailed information including session name, number of windows, status, and creation timestamp.

## EXECUTION

1. **Query**: Use `tmux list-sessions -F` to fetch all active sessions
2. **Format**: Parse session data to extract name, window count, and timestamp
3. **Display**: Present sessions in a tabular format with status indicators
4. **Filter**: Highlight attached vs. detached sessions

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant WM as zzaia-workspace-manager

    U->>C: /skill:tmux:list
    C->>WM: Fetch all active sessions
    WM->>WM: Run tmux list-sessions
    WM-->>C: Session list with metadata
    C-->>U: Formatted session table
```

## ACCEPTANCE CRITERIA

- All active sessions are listed
- Session names are displayed
- Window count per session is shown
- Session status (attached/detached) is indicated
- Creation timestamp is included where available
- Output is clearly formatted for readability

## EXAMPLES

```
/skill:tmux:list
/skill:tmux:list --description "check current active sessions"
```

## OUTPUT

- Table with columns: Session Name, Windows, Status, Created
- Summary count of total active sessions
- Indicators for which sessions have attached clients
