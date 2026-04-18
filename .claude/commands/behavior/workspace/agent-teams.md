---
name: behavior:workspace:agent-teams
description: Orchestrate teams of specialized agents to collectively execute a task in consensus or parallel mode, each displayed in a dedicated tmux pane
argument-hint: "--mode <consensus|parallel> --context <task-context> [--tasks <task-list>] [--agents <agent-list>] [--description <description>] [--max-agents <n>] [--session <tmux-session>]"
agents:
  - name: zzaia-tech-leader
    description: Lead task execution through a given workflow using sub-agents; coordinates and reports results back to the team session
parameters:
  - name: mode
    description: Collaboration mode - consensus for multiple perspectives on single task, parallel for distributing sub-tasks
    required: true
  - name: context
    description: Shared task context, problem description, or goal that all agents receive
    required: true
  - name: tasks
    description: Comma-separated list of discrete sub-tasks for parallel mode
    required: false
  - name: agents
    description: Comma-separated list of agent names to form the team; auto-selects if omitted
    required: false
  - name: description
    description: Broader description of what the team should accomplish
    required: false
  - name: max-agents
    description: Maximum number of agents running simultaneously; excess tasks are queued and dispatched as slots free up
    required: false
    type: integer
  - name: session
    description: Tmux session name to attach agent panes to (defaults to current session)
    required: false
---

## PURPOSE

Orchestrate teams of specialized agents to execute tasks collaboratively. Each agent runs in a dedicated tmux side pane, allowing the user to observe all agent conversations simultaneously.

## EXAMPLES

```
/behavior:workspace:agent-teams --mode consensus --context "Design a REST API for managing user accounts" --description "Get architectural perspectives on API design"

/behavior:workspace:agent-teams --mode parallel --context "Refactor legacy authentication module" --tasks "Update login handler, Migrate session storage, Add MFA support" --max-agents 3

/behavior:workspace:agent-teams --mode consensus --context "Evaluate framework choice for real-time messaging"
```

## EXECUTION

1. **Resolve Session**: Use `--session` if provided; otherwise detect via `tmux display-message -p '#S'`
2. **Determine Agents**: Use `--agents` list, or auto-select based on tasks/context
3. **Open Side Panes**: For each agent, run `tmux split-window -h -t <session>` and capture the pane index
4. **Equalize Layout**: Run `tmux select-layout -t <session> even-horizontal`
5. **Dispatch Agents**: In each pane, send the agent's claude CLI command:
   `tmux send-keys -t <session>:.<pane> 'claude --dangerously-skip-permissions -p "<prompt>"' Enter`

## DELEGATION

- `zzaia-tech-leader` — Lead task execution through a given workflow using sub-agents; coordinates and reports results back to the team session

## ACCEPTANCE CRITERIA

- One tmux horizontal side pane opened per agent
- Layout equalized with `tmux select-layout even-horizontal`
- Each agent runs as a live `claude` CLI process inside its pane via `tmux send-keys`
- Parallel mode correctly maps sub-tasks to agents with shared context; panes are reused as slots free up
- Missing `--tasks` in parallel mode fails with clear error message
- Results include clear agent attribution for traceability
- `zzaia-tech-leader` is always the dispatched agent; `--agents` overrides for advanced use only

## OUTPUT

- **Tmux layout**: One labeled right-side horizontal pane per active agent, visible before dispatch begins
- **Consensus mode**: Unified synthesis document with merged insights and clear distinction of perspectives
- **Parallel mode**: Structured output organized by task with individual agent results and combined summary
- **Agent attribution**: Each result includes clear identification of responsible agent and pane index
- **Error handling**: Explicit failure message if required parameters are missing or tmux session cannot be resolved
