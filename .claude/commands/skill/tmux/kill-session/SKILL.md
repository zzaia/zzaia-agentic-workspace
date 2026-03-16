---
name: kill-session
description: Kill tmux sessions by name or kill all sessions
argument-hint: "[--name <session-name>] [--description <context>]"
user-invocable: true
agent: zzaia-workspace-manager
metadata:
  parameters:
    - name: name
      description: Session name to kill. If omitted, kills all sessions after confirmation
      required: false
    - name: description
      description: Broader context for the operation
      required: false
---

## PURPOSE

Terminate one or more tmux sessions. If a session name is provided, kills that specific session. If no name is provided, terminates all active sessions after requesting confirmation.

## EXECUTION

1. **Validate**: If session name provided, confirm it exists
2. **Confirm**: For kill-all operations, request explicit user confirmation
3. **Kill**: Execute appropriate kill command
   - Single session: `tmux kill-session -t <name>`
   - All sessions: `tmux kill-server`
4. **Verify**: Confirm the session(s) were killed successfully
5. **Report**: Display confirmation with killed session details

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-workspace-manager` — Manages tmux session lifecycle and cleanup operations

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant WM as zzaia-workspace-manager

    U->>C: /skill:tmux:kill-session --name dev
    C->>WM: Kill session 'dev'
    WM->>WM: Run tmux kill-session
    WM-->>C: Session terminated
    C-->>U: Session 'dev' killed
```

## ACCEPTANCE CRITERIA

- Session name is validated if provided
- Kill-all operations require explicit confirmation
- kill-session command executes without error
- Targeted session is properly terminated
- All panes and windows in killed session are closed
- Confirmation shows session name(s) killed

## EXAMPLES

```
/skill:tmux:kill-session --name dev
/skill:tmux:kill-session --name build
/skill:tmux:kill-session --description "cleaning up test sessions"
/skill:tmux:kill-session
```

## OUTPUT

- Confirmation of session termination
- Session name(s) killed
- Number of windows and panes closed
- Warning if kill-all was performed
