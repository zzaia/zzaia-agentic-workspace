---
name: /workflow:orchestrate:implement
description: Orchestrate parallel implementation of multiple work items across repositories
argument-hint: "--work-items <id-list> --portal <azure|github> --project <name> --repo <name> --target-branch <branch> [--description <text>] [--sequential]"
parameters:
  - name: work-items
    description: Comma-separated list of work-item IDs to implement
    required: true
  - name: portal
    description: DevOps portal - azure or github
    required: true
  - name: project
    description: Project name in the DevOps portal
    required: true
  - name: repo
    description: Repository name (shared across all work items)
    required: true
  - name: target-branch
    description: Base branch for all feature branches
    required: true
  - name: description
    description: Shared context description for all agents
    required: false
  - name: sequential
    description: Execute work items sequentially instead of parallel
    required: false
agents:
  - name: zzaia-developer-specialist
    description: Execute /workflow:remote:implement for each assigned work item in parallel
---

## PURPOSE

Build one `/workflow:remote:implement` invocation per work-item ID and hand the full task list to `/behavior:workspace:agent-teams`. The orchestrator owns only parameter composition and result consolidation — all work-item retrieval, branching, and PR logic live inside `remote:implement`.

## EXECUTION

1. **Compose task list**

   - Split `--work-items` into individual IDs
   - For each ID build the full invocation string:
     ```
     /workflow:remote:implement --work-item <id> --portal <portal> --project <project> --repo <repo> --target-branch <target-branch> --working-branch feature/wi-<id> --description <description>
     ```
   - Collect all strings as the `--tasks` value

2. **Dispatch to agent-teams**

   - Call `/behavior:workspace:agent-teams` with:
     - `--mode parallel` (or `sequential` when `--sequential` flag is provided)
     - `--context` = portal + project + repo + target-branch + description
     - `--tasks` = comma-separated invocation strings from step 1
     - `--description` = "Implement work items [ids] in parallel"

3. **Consolidate results**

   - Collect PR URL and status from each agent
   - Present delivery table: work-item → branch → PR URL → status
   - Report per-item failures without halting other tracks

## DELEGATION

**MANDATORY**: Invoke the agents defined in frontmatter for their designated responsibilities.

- `zzaia-devops-specialist` — Manage PR operations and DevOps interactions within each parallel track
- `zzaia-developer-specialist` — Execute `/workflow:remote:implement` for each assigned work item

## WORKFLOW DIAGRAM

```mermaid
sequenceDiagram
    participant U as User
    participant W as /workflow:orchestrate:implement
    participant AT as /behavior:workspace:agent-teams
    participant A1 as Agent 1 (WI-1)
    participant A2 as Agent 2 (WI-2)
    participant AN as Agent N (WI-N)

    U->>W: --work-items <ids> --portal <p> --project <pr> --repo <r> --target-branch <tb>
    W->>W: Build /workflow:remote:implement invocation per ID
    W->>AT: --mode parallel --tasks [impl-1, impl-2, ..., impl-N]
    par Parallel Execution
        AT->>A1: /workflow:remote:implement --work-item 1 --working-branch feature/wi-1
        AT->>A2: /workflow:remote:implement --work-item 2 --working-branch feature/wi-2
        AT->>AN: /workflow:remote:implement --work-item N --working-branch feature/wi-N
    and
        A1-->>AT: PR URL, status
        A2-->>AT: PR URL, status
        AN-->>AT: PR URL, status
    end
    AT-->>W: All agent results
    W-->>U: Delivery summary table
```

## ACCEPTANCE CRITERIA

- Task list built without any work-item pre-retrieval — all parameters come from user input
- Each task string is a complete, self-contained `/workflow:remote:implement` invocation
- `--working-branch` derived as `feature/wi-<id>` per item
- `--sequential` flag switches agent-teams mode from parallel to sequential
- Consolidated delivery table covers all items with PR URLs and status
- Per-item failures reported without halting other tracks

## EXAMPLES

```
/workflow:orchestrate:implement --work-items 1605,1606,1607 --portal azure --project my-project --repo order-service --target-branch develop --description "Implement provider module features"

/workflow:orchestrate:implement --work-items 1610,1611 --portal github --project my-org/my-project --repo api-gateway --target-branch main --sequential
```

## OUTPUT

- Retrieval summary: count of work items loaded with titles and derived branches
- Parallel execution status report: agent assignments and task dispatch confirmation
- Consolidated delivery table:

| Work Item | Branch | PR URL | Status |
|-----------|--------|--------|--------|
| 1605 | feature/provider-auth | https://... | completed |
| 1606 | feature/provider-config | https://... | completed |
| 1607 | feature/provider-sync | https://... | failed |

- Failure report (if any) with work-item ID and error context
