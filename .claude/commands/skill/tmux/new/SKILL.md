---
name: new
description: Create a new named tmux session with optional directory and window name
argument-hint: "--name <session-name> [--dir <path>] [--window <name>] [--description <context>]"
user-invocable: true
metadata:
  parameters:
    - name: name
      description: Session name to create
      required: true
    - name: dir
      description: Starting directory for the session
      required: false
    - name: window
      description: Initial window name within the session
      required: false
    - name: description
      description: Broader context for the operation
      required: false
---

## PURPOSE

Create a new tmux session with a specified name, optional starting directory, and optional initial window name. The session can then be used for persistent terminal operations.

## EXECUTION

1. **Validate**: Check that the session name is provided and does not already exist
2. **Create**: Initialize a new tmux session with `tmux new-session -d -s <name> -x 120 -y 40`
3. **Configure**: If `--dir` is provided, set the session's working directory
4. **Name Window**: If `--window` is provided, rename the initial window
5. **Verify**: Confirm the session was created successfully

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command

    U->>C: /skill:tmux:new --name dev --dir /repo
    C->>C: Run tmux new-session -d -s dev
    C-->>U: Session 'dev' ready
```

## ACCEPTANCE CRITERIA

- Session name is provided and validated
- Session does not already exist
- Session is created with detached mode
- Starting directory is set if provided
- Window is renamed if provided
- Confirmation message shows session details

## EXAMPLES

```
/skill:tmux:new --name dev
/skill:tmux:new --name build --dir /workspace/project
/skill:tmux:new --name api --window server --dir /app
/skill:tmux:new --name monitor --description "monitoring session for health checks"
```

## OUTPUT

- Confirmation of session creation
- Session name, number of windows, and creation timestamp
- Working directory if specified
