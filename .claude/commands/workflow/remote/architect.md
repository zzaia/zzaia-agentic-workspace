---
name: /workflow:remote:architect
description: Orchestrate architectural documentation and work-item hierarchy creation using Specification Driven Design
argument-hint: "--selected-work-item <id> --portal <url> --project <name> [--description <text>]"
parameters:
  - name: selected-work-item
    description: Work item ID to architect (Epic, Feature, User Story, or Task)
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

Orchestrate architectural documentation and work-item hierarchy creation for a given selected work item using Specification Driven Design (SDD). Decomposes requirements into a parallelize hierarchy of work items, each with embedded SDD documentation at the appropriate abstraction level (Epic → Feature → User Story → Task). Enables human and agent teams collaboration through Azure DevOps discussions during the architectural design. The


## WORKFLOW PHASES

1. **Retrieve Work Item Chain**
   - Call `/behavior:devops:work-item --id <selected-work-item> --project <project>`
   - Collect Title, Description, Acceptance Criteria from each level (Epic → Feature → User Story → Task)
   - **MANDATORY** Selected work item description must not be empty

2. **Gather Repository and Referenced Documentation**
   - Inspect local workspace path `<workspace>` using the `Read` tool for source code, configs, and existing docs
   - Call `/skill:document:read --doc <doc>` if a local document path is provided
   - Call `/behavior:websearch --url <url>` if a URL reference is provided
   - Enrich architectural context with retrieved repository structure and materials

3. **Generate Selected Work Item Architecture**
   - Call `/behavior:management:architect --work-description "<description>" --work-directory <workspace>`
   - Call `/behavior:management:clarify --context "<architectural-design-output>"` to generate critical clarification questions
   - Call `/behavior:devops:work-item --id <selected-work-item> --project <project>` to post a discussion with all clarification questions as a numbered list
   - **MANDATORY** Do NOT create child work items or update descriptions before user responds

4. **Validate Selected Work Item Documentation**
   - Call `/behavior:workspace:ask-user-question --question "Reply to the Azure DevOps discussion with your answers, then confirm to continue"`
   - Call `/behavior:devops:work-item --id <selected-work-item> --project <project>` to read all discussion answers
   - Call `/skill:document:write --template service-architecture --title "<work-item-title>" --work-item <selected-work-item> --target-field discussion` to generate the finalized SDD

5. **Plan Child Work Item Hierarchy**
   - Call `/behavior:management:plan --work-description "<finalized-sdd-content>"` to decompose into a parallelizable agile hierarchy
   - Call `/behavior:devops:work-item --id <selected-work-item> --project <project>` to post the full plan (hierarchy, dependency graph, parallelization map) as a discussion
   - **MANDATORY** Do NOT create any child work items before the user approves the plan

6. **Validate Plan**
   - Call `/behavior:workspace:ask-user-question --question "Reply to the plan discussion in Azure DevOps with your feedback, then confirm to continue"`
   - Call `/behavior:devops:work-item --id <selected-work-item> --project <project>` to read all plan approval/feedback from the discussion

7. **Create Child Work Items**
   - Call `/behavior:devops:work-item --project <project>` to create all work items with dependency links (`related`, `consumes-from`) per the plan
   - Call `/skill:document:write --template service-architecture --title "<child-work-item-title>" --work-item <child-work-item-id> --target-field discussion` for each child work item

8. **Validate Overall Architecture**
   - Call `/behavior:workspace:ask-user-question --question "Review all work items in Azure DevOps and reply to each individual discussion if changes are needed, then confirm to continue"`
   - For each work item: call `/behavior:devops:work-item --id <child-work-item-id> --project <project>` to read answers from its individual discussion
   - Call `/skill:document:write --template service-architecture --title "<work-item-title>" --work-item <child-work-item-id> --target-field discussion` to update the SDD with the answers

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant WM as DevOps Specialist
    participant AR as Architect
    participant DW as document:write
    participant D as DevOps

    U->>C: /workflow:remote:architect --selected-work-item ID [--description TEXT] [--doc PATH] [--url URL]
    C->>C: Validate parameters
    C->>WM: Retrieve selected work item chain
    WM->>D: Query work items
    D-->>WM: Return hierarchy
    WM-->>C: Work item chain data
    opt --doc provided
        C->>C: /skill:document:read inject local file context
    end
    opt --url provided
        C->>C: /behavior:websearch fetch URL context
    end
    opt workspace provided
        C->>C: Inspect repository structure and source code
    end
    C->>AR: /behavior:management:architect with enriched context
    AR-->>C: Architectural design
    C->>C: /behavior:management:clarify generate clarification questions
    C->>WM: Post clarification questions as discussion on selected work item
    WM->>D: Create discussion thread
    D-->>C: Discussion link
    C->>U: /behavior:workspace:ask-user-question: reply in DevOps and confirm
    U-->>C: Confirmation
    C->>WM: Read discussion answers
    WM->>D: Fetch discussion replies
    D-->>WM: Answers
    WM-->>C: Discussion content
    C->>DW: /skill:document:write generate selected work item SDD
    DW-->>C: SDD markdown
    C->>WM: Update selected work item description with finalized SDD
    WM->>D: Update description
    C->>C: /behavior:management:plan decompose SDD into agile hierarchy
    C->>WM: Post plan (hierarchy, dependencies, parallelization map) as discussion on selected work item
    WM->>D: Create plan discussion thread
    D-->>C: Discussion link
    C->>U: /behavior:workspace:ask-user-question: review and approve plan in DevOps discussion
    U-->>C: Confirmation
    C->>WM: Read plan approval from selected work item discussion
    WM->>D: Fetch discussion replies
    D-->>WM: Approval content
    WM-->>C: Confirmed plan
    C->>WM: Create all child work items with dependency links per plan
    WM->>D: Batch create work items and links
    D-->>WM: Child work item IDs
    C->>DW: /skill:document:write generate SDD for all child work items
    DW-->>C: SDD markdown per work item
    C->>WM: Update all child work item descriptions with finalized SDD
    WM->>D: Batch update descriptions
    C->>U: /behavior:workspace:ask-user-question: review all work items in DevOps, reply to each discussion if changes needed, and confirm
    U-->>C: Confirmation
    loop For Each Work Item
        C->>WM: Read answers from work item discussion
        WM->>D: Fetch discussion replies
        D-->>WM: Answers
        WM-->>C: Discussion content
        C->>DW: /skill:document:write update SDD with answers
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
/workflow:remote:architect --selected-work-item 2001 --project MyProject --description "Multi-tenant notification service with email, SMS, and push channels"

/workflow:remote:architect --selected-work-item 1850 --project MyProject --doc ./docs/requirements.pdf

/workflow:remote:architect --selected-work-item 2200 --project MyProject --description "Refactor payment gateway integration" --url https://docs.stripe.com/api --workspace ./workspace/payments.worktrees/master
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
