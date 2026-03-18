---
name: implement
description: Orchestrate implementation of multiple work items by analyzing dependencies and dispatching parallel or sequential execution
argument-hint: "--work-items <id-list> --portal <azure|github> --project <name> --repo <name> --target-branch <branch> --description <text>"
user-invocable: true
metadata:
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
      description: Repository name shared across all work items
      required: true
    - name: target-branch
      description: Base branch for all feature branches
      required: true
    - name: description
      description: Shared implementation context passed to all remote:implement invocations
      required: true
---

## PURPOSE

Retrieve all work items, analyse their relationships to identify dependencies and parallelism opportunities, then orchestrate each implementation via `/workflow:remote:implement` — dispatching independent items in parallel and dependent items sequentially. The orchestrator decides execution strategy autonomously.

## EXECUTION

1. **Retrieve all work items**

   - For each ID in `--work-items`, call `/behavior:devops:work-item --action read --id <id> --project <project> --platform <portal>`
   - Collect per-item: title, type, parent, child links, and related work-item IDs
   - Build a dependency map: `{ id → [blocked-by ids] }`

2. **Analyse dependencies**

   - Inspect each work item's relationships (parent/child, predecessor/successor, related links)
   - Dependency classification rules:
     - **parent/child**: child depends on parent — parent must complete first
     - **predecessor/successor**: successor depends on predecessor
     - **related**: informational only — does NOT create an execution dependency
   - Classify items into execution groups:
     - **Parallel group**: items with no mutual dependency — can run simultaneously
     - **Sequential chain**: items where B depends on A — A must complete before B starts
   - Produce an ordered execution plan: list of groups where each group is a set of independent items

3. **Build invocation strings**

   - For each item derive `working-branch` as `feature/wi-<id>`
   - Escape `--description` content: wrap in quotes and replace any internal quotes with `\"` to prevent invocation parsing failures
   - Build the complete self-contained invocation:
     ```
     /workflow:remote:implement --work-item <id> --portal <portal> --project <project> --repo <repo> --target-branch <target-branch> --working-branch feature/wi-<id> --description <description> --auto-continue
     ```

4. **Dispatch by execution plan**

   - For each group in the execution plan:
     - Call `/behavior:workspace:agent-teams --mode parallel --context "<shared-context>" --tasks "<group-invocations>" --description "Implement group <n>: <ids>" --max-agents 5`
     - Collect results from all agents in the group
     - If there is a **next group** (sequential dependency): call `/behavior:workspace:ask-user-question --question "Group <n> complete. PRs are open for: <pr-urls>. Review and approve the pull requests before continuing. Proceed to group <n+1>?" --options "Continue; Abort"` and wait for user confirmation before dispatching the next group
     - If user selects **Abort**, stop execution and report completed and pending groups
     - If any item in the current group **failed**, skip its dependents in subsequent groups and report them as blocked

5. **Consolidate results**

   - Each agent **must** return a structured result with exactly these fields: `work_item_id`, `branch`, `pr_url`, `status` (`completed | failed | partial`), `error`, `group`
   - If an agent response does not contain these fields, treat the item as `status: failed` with `error: "missing structured result"`
   - Present delivery table: work-item → branch → PR URL → status → group
   - Report per-item failures with error context; a failed item blocks any dependents in subsequent groups

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant W as /orchestrate:implement
    participant WI as /behavior:devops:work-item
    participant AT as /behavior:workspace:agent-teams

    U->>W: --work-items <ids> --portal <p> --project <pr> --repo <r> --target-branch <tb>

    loop Retrieve each work item
        W->>WI: --id <id> --project <project> --platform <portal>
        WI-->>W: title, type, relationships
    end

    W->>W: Build dependency map and execution plan

    loop For each group in plan
        W->>AT: --mode parallel --tasks [impl-A, impl-B, ...]
        par Parallel agents
            AT-->>W: work_item_id, branch, pr_url, status (A)
            AT-->>W: work_item_id, branch, pr_url, status (B)
        end
        W->>W: Check failures; block dependents if any failed
        alt Has next sequential group
            W->>U: ask-user-question — review PRs and confirm to continue
            U-->>W: Continue or Abort
        end
    end

    W-->>U: Delivery summary table
```

## ACCEPTANCE CRITERIA

- All work items retrieved and their relationships inspected before any dispatch
- Dependency map correctly identifies blocked-by relationships
- Independent items dispatched in parallel via `agent-teams --mode parallel`
- Dependent items dispatched only after their predecessors complete successfully
- Failed items block their dependents and are reported clearly
- Each agent result carries `work_item_id`, `branch`, `pr_url`, `status`, `error`, `group`
- Consolidated delivery table covers all items grouped by execution wave

## EXAMPLES

```
/orchestrate:implement --work-items 1605,1606,1607 --portal azure --project my-project --repo order-service --target-branch develop --description "Implement provider module features"

/orchestrate:implement --work-items 1610,1611,1612 --portal github --project my-org/my-project --repo api-gateway --target-branch main --description "Add gateway routing features"
```

## OUTPUT

- Dependency analysis summary: execution plan with groups and dependency chains
- Consolidated delivery table:

| Work Item | Group | Branch | PR URL | Status |
|-----------|-------|--------|--------|--------|
| 1605 | 1 (parallel) | feature/wi-1605 | https://... | completed |
| 1606 | 1 (parallel) | feature/wi-1606 | https://... | completed |
| 1607 | 2 (after 1605) | feature/wi-1607 | https://... | completed |

- Failure report (if any): work-item ID, blocked dependents, error context
