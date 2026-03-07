---
name: /architect-remote
description: Orchestrate architectural documentation and work-item hierarchy creation using Specification Driven Design
argument-hint: "--selected-work-item <id> --devops-portal <url> --project <name> [--description <text>]"
parameters:
  - name: selected-work-item
    description: Work item ID to architect (Epic, Feature, User Story, or Task)
    required: true
  - name: devops-portal
    description: Azure DevOps organization portal URL (e.g. https://dev.azure.com/my-org)
    required: true
  - name: project
    description: Azure DevOps project name
    required: true
  - name: description
    description: Additional user context, goals, or constraints to guide SDD generation
    required: false
  - name: workspace
    description: Local workspace path to inspect repository structure and source code
    required: false
  - name: doc
    description: Local document file path (PDF or Word) to inject into architectural context
    required: false
  - name: url
    description: URL reference to fetch and inject into architectural context
    required: false
---

## PURPOSE

Orchestrate architectural documentation and work-item hierarchy creation for a given selected work item using Specification Driven Design (SDD). Decomposes requirements into a parallelize hierarchy of work items, each with embedded SDD documentation at the appropriate abstraction level (Epic → Feature → User Story → Task). Enables human and agent teams collaboration through Azure DevOps discussions during the architectural design.


## WORKFLOW PHASES 

1. **Retrieve Work Item Chain**
   - Call `/devops:work-item` with `selected-work-item` parameter to retrieve the full hierarchy
   - Collect Title, Description, Acceptance Criteria from each level (Epic → Feature → User Story → Task)
   - **MANDATORY** Selected work item description must not be empty

2. **Gather Repository and Referenced Documentation**
   - Inspect local workspace repositories using the `Read` tool for file path references (source code, configs, existing docs)
   - Call `/document:read` for any local document file references (PDF, Word) found in work items or workspace
   - Call `/websearch` for any URL references found in work items
   - Enrich architectural context with retrieved repository structure and materials

3. **Generate Selected Work Item Architecture**
   - Call `/management:architect` with context and description parameters to produce the architectural design
   - Call `/management:clarify --context` passing the architectural design output to generate critical clarification questions
   - Call `/devops:work-item` to post a discussion on the selected work item with all clarification questions as a numbered list
   - **MANDATORY** Do NOT create child work items or update descriptions with architectural documentation before user responds

4. **Validate Selected Work Item Documentation**
   - Use the tool **AskUserQuestion** to ask user to reply to the Azure DevOps discussion and confirm to continue
   - Call `/devops:work-item` to read all discussion answers from the selected work item
   - Call `/document:write` generate the finalized SDD documentation in markdown following the templates
   - Call `/devops:work-item` to update selected work item related description with finalized SDD documentation 

5. **Plan Child Work Item Hierarchy**
   - Call `/management:plan --work-description` passing the finalized SDD content to decompose it into a parallelizable agile hierarchy
   - Call `/devops:work-item` to post the full resumed plan (hierarchy, dependency graph, parallelization map) as a discussion on the selected work item
   - **MANDATORY** Do NOT create any child work items before the user approves the plan

6. **Validate Plan**
   - Use **AskUserQuestion** to ask user to reply to the plan discussion in Azure DevOps and confirm to continue
   - Call `/devops:work-item` to read all plan approval/feedback from the selected work item discussion

7. **Create Child Work Items**
   - Call `/devops:work-item` to create all work items with all establish dependency links (`related`, `consumes-from`) between dependent items per the plan 
   - Call `/document:write` to produce the finalized SDD markdown for all work items
   - Call `/devops:work-item` to update all work items related description with finalized SDD documentation 

8. **Validate Overall Architecture**
   - Use **AskUserQuestion** to ask user to review all work items in Azure DevOps, reply to each individual discussion if changes are needed, and confirm to continue
   - For each work item: call `/devops:work-item` to read answers from its individual discussion
   - Call `/document:write` to update the SDD with the answers for each respective work item
   - Call `/devops:work-item` to update each work item description with the revised SDD

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant WM as DevOps Specialist
    participant AR as Architect
    participant DW as document:write
    participant D as DevOps

    U->>C: /architect-remote --selected-work-item ID [--description TEXT] [--doc PATH] [--url URL]
    C->>C: Validate parameters
    C->>WM: Retrieve selected work item chain
    WM->>D: Query work items
    D-->>WM: Return hierarchy
    WM-->>C: Work item chain data
    opt --doc provided
        C->>C: /document:read inject local file context
    end
    opt --url provided
        C->>C: /websearch fetch URL context
    end
    opt workspace provided
        C->>C: Inspect repository structure and source code
    end
    C->>AR: /management:architect with enriched context
    AR-->>C: Architectural design
    C->>C: /management:clarify generate clarification questions
    C->>WM: Post clarification questions as discussion on selected work item
    WM->>D: Create discussion thread
    D-->>C: Discussion link
    C->>U: AskUserQuestion: reply in DevOps and confirm
    U-->>C: Confirmation
    C->>WM: Read discussion answers
    WM->>D: Fetch discussion replies
    D-->>WM: Answers
    WM-->>C: Discussion content
    C->>DW: /document:write generate selected work item SDD
    DW-->>C: SDD markdown
    C->>WM: Update selected work item description with finalized SDD
    WM->>D: Update description
    C->>C: /management:plan decompose SDD into agile hierarchy
    C->>WM: Post plan (hierarchy, dependencies, parallelization map) as discussion on selected work item
    WM->>D: Create plan discussion thread
    D-->>C: Discussion link
    C->>U: AskUserQuestion: review and approve plan in DevOps discussion
    U-->>C: Confirmation
    C->>WM: Read plan approval from selected work item discussion
    WM->>D: Fetch discussion replies
    D-->>WM: Approval content
    WM-->>C: Confirmed plan
    C->>WM: Create all child work items with dependency links per plan
    WM->>D: Batch create work items and links
    D-->>WM: Child work item IDs
    C->>DW: /document:write generate SDD for all child work items
    DW-->>C: SDD markdown per work item
    C->>WM: Update all child work item descriptions with finalized SDD
    WM->>D: Batch update descriptions
    C->>U: AskUserQuestion: review all work items in DevOps, reply to each discussion if changes needed, and confirm
    U-->>C: Confirmation
    loop For Each Work Item
        C->>WM: Read answers from work item discussion
        WM->>D: Fetch discussion replies
        D-->>WM: Answers
        WM-->>C: Discussion content
        C->>DW: /document:write update SDD with answers
        DW-->>C: Updated SDD markdown
        C->>WM: Update work item description with revised SDD
        WM->>D: Update description
    end
    C-->>U: Complete - all work items architected with SDD
```

## ACCEPTANCE CRITERIA

- Selected work item chain retrieved and understood
- Referenced documentation integrated into context
- Selected work item SDD discussion posted before any structural changes
- Selected work item description updated with finalized markdown SDD
- Work-item plan (hierarchy, dependency graph, parallelization map) posted as discussion on selected work item
- Plan validated via DevOps discussion before any child work items are created
- Child work items created with SDD documentation embedded in descriptions from the start
- Dependency links established between child work items per the validated plan
- Overall architecture validated by user reviewing individual work item discussions before completion
- All work item SDDs updated with answers from their individual Azure DevOps discussions
- Leaf-level tasks designed as independent, parallelizable pull requests

## EXAMPLES

```
/architect-remote --selected-work-item 2001 --devops-portal https://dev.azure.com/my-org --project MyProject --description "Multi-tenant notification service with email, SMS, and push channels"

/architect-remote --selected-work-item 1850 --devops-portal https://dev.azure.com/my-org --project MyProject --doc ./docs/requirements.pdf

/architect-remote --selected-work-item 2200 --devops-portal https://dev.azure.com/my-org --project MyProject --description "Refactor payment gateway integration" --url https://docs.stripe.com/api --workspace ./workspace/payments.worktrees/master
```

## OUTPUT

- Phase completion status at each step
- Work item chain summary with hierarchy visualization
- SDD discussion thread links for selected and child work items
- Finalized work item descriptions with embedded markdown SDD
- List of created child work items with IDs, types, and dependencies
- Parallelization map indicating which tasks can run concurrently
- Dependency graph showing consumes-from and related relationships
- Revised SDD documents per work item incorporating discussion feedback from Phase 8
