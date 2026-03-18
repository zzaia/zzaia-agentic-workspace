---
name: /behavior:workspace:agent-teams
description: Orchestrate teams of specialized agents to collectively execute a task in consensus or parallel mode
argument-hint: "--mode <consensus|parallel> --context <task-context> [--tasks <task-list>] [--agents <agent-list>] [--description <description>]"
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
---

## PURPOSE

Orchestrate teams of specialized agents to execute tasks collaboratively. Choose between consensus mode (multiple agents analyze a single problem independently, then synthesize results) or parallel mode (distribute decomposed sub-tasks across agents with shared context).

## EXECUTION

### consensus mode

1. **Parse Input**: Extract `--context` and `--agents` (or auto-select 2-3 agents suited to task)
2. **Dispatch**: Send all selected agents the same context simultaneously
3. **Collect**: Gather independent outputs from all agents
4. **Synthesize**: Identify agreements, resolve conflicts, merge complementary insights
5. **Return**: Unified consensus response with clear attribution

### parallel mode

1. **Validate**: Ensure `--tasks` is provided; fail gracefully if absent
2. **Parse Input**: Extract `--context` and `--tasks` list
3. **Assign**: Map agents to individual tasks (auto-select or use `--agents`)
4. **Dispatch**: Send all agents simultaneously, each with sub-task plus shared `--context`
5. **Collect**: Gather all task outputs with agent attribution
6. **Combine**: Merge into structured result with per-task grouping
7. **Return**: Combined output with clear task-to-agent mapping

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-tech-leader` — Lead task execution through a given workflow using sub-agents; coordinates and reports results back to the team session

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant CMD as Command
    participant TL as zzaia-tech-leader
    participant SUB as sub-agents

    U->>CMD: /behavior:workspace:agent-teams <params>
    CMD->>CMD: Parse and validate parameters

    alt mode == consensus
        par Dispatch tech-leaders with shared context
            CMD->>TL: context + workflow (instance A)
            CMD->>TL: context + workflow (instance B)
        end
        TL->>SUB: Delegate steps via workflow
        SUB-->>TL: Step results
        TL-->>CMD: Structured result (task, status, output)
        CMD->>CMD: Synthesize consensus from all outputs
    else mode == parallel
        CMD->>CMD: Verify --tasks present
        par Assign one task per tech-leader
            CMD->>TL: sub-task + context + workflow (A)
            CMD->>TL: sub-task + context + workflow (B)
        end
        TL->>SUB: Delegate steps via workflow
        SUB-->>TL: Step results
        TL-->>CMD: Structured result (task, status, output)
        CMD->>CMD: Merge into structured output
    end

    CMD-->>U: Return unified result with attribution
```

## ACCEPTANCE CRITERIA

- Consensus mode produces synthesized output reflecting all agent perspectives
- Parallel mode correctly maps sub-tasks to agents with shared context
- Missing `--tasks` in parallel mode fails with clear error message
- Results include clear agent attribution for traceability
- Auto-selection of agents occurs when `--agents` is omitted

## EXAMPLES

```
/behavior:workspace:agent-teams --mode consensus --context "Design a REST API for managing user accounts" --description "Get architectural perspectives on API design"

/behavior:workspace:agent-teams --mode parallel --context "Refactor legacy authentication module" --tasks "Update login handler, Migrate session storage, Add MFA support" --agents "zzaia-developer-specialist,zzaia-code-reviewer"

/behavior:workspace:agent-teams --mode consensus --context "Evaluate framework choice for real-time messaging"
```

## OUTPUT

- **Consensus mode**: Unified synthesis document with merged insights and clear distinction of perspectives
- **Parallel mode**: Structured output organized by task with individual agent results and combined summary
- **Agent attribution**: Each result includes clear identification of responsible agent
- **Error handling**: Explicit failure message if required parameters are missing
