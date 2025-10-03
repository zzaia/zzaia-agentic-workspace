---
name: /plan
description: Generate or update comprehensive action plans for user-requested work in a multi-repository workspace
parameters:
  - name: work_description
    description: Detailed description of the work to be planned, or work item ID (e.g., ADO-12345, GH-67890)
    required: true
---

## PURPOSE

Generate or update comprehensive, actionable plans for user-requested work by analyzing requirements from user descriptions or work items, with detailed phase breakdown, risk assessment, and implementation strategy. Serves as a pre-development planning step before using `/develop` command.

## EXECUTION

1. **Work Item Retrieval & Display** (if work item ID provided)

   - Use zzaia-work-item-manager to fetch work item details
   - **Display all work item information to user** (title, description, pro acceptance criteria, status)
   - **Ask user to confirm proceeding to clarification phase**
   - Extract requirements, acceptance criteria, and context for analysis

2. **Initial Requirements Analysis**

   - Use zzaia-task-clarifier for rigorous problem analysis
   - Identify involved projects, applications and architectural concerns
   - Generate critical questions and risk assessments
   - Receive suggestions for plan improvements

3. **User Interaction & Clarification**

   - **Wait for user confirmation before proceeding** (from phase 1)
   - Present task clarifier analysis and recommendations
   - Ask clarifying questions based on agent feedback
   - Gather additional requirements and constraints
   - Refine scope and success criteria with user input

4. **Technical Planning & Documentation**

   - Review existing implementations and architecture
   - Generate architecture plan through direct analysis
     - Identify application layers that must be implemented
     - Identify all patterns, tools, packages and SDKs that will be used
     - Identify the communication interface between applications
   - Generate step-by-step implementation plan
     - Identify steps that can be executed in parallel
     - Identify steps that must be executed sequentially
     - Let's keep all steps related to one application ALWAYS as sequential
     - Let's keep multi applications steps ALWAYS as parallel
   - No need to write code in documentations

5. **Plan Finalization**

   - Use zzaia-documentation-architect to generate implementation plan documentation
   - **MANDATORY**: Use `implementation-plan.md` template from `.claude/templates/documentation/`
   - **MANDATORY**: Use `service-implementation-plan.md` template for each service/application
   - Generate comprehensive implementation plan with:
     - Phase hierarchy with Gantt chart
     - Parallel vs sequential execution strategy
     - Team structure and resource allocation
     - Success criteria and risk mitigation
     - Timeline summary and next steps
   - Create service-specific implementation plans for each application
   - Display the overall information in prompt
   - Estimate agentic developing effort, complexity, and resource requirements

6. **User Interaction & Improvements**

   - Ask if user has any more improvements or rectifications to plan or during implementation
   - Refine the plan and implementation definitions and documents with user input

## AGENTS

- **zzaia-work-item-manager**: Work item retrieval and data preparation
- **zzaia-task-clarifier**: Critical analysis, problem understanding, and improvement recommendations (analysis-only, no file creation)
- **zzaia-documentation-architect**: Documentation and knowledge transfer planning

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as /plan Command
    participant WM as Work Item Manager
    participant TC as Task Clarifier
    participant DA as Documentation Architect

    U->>C: /plan <work_description or work_item_id>

    alt Work Item ID provided
        C->>WM: Retrieve work item details
        WM-->>C: Work item data and context
        C->>U: Display work item details
        U-->>C: Confirm to proceed to clarification
    end

    C->>TC: Analyze requirements and identify risks
    TC-->>C: Critical analysis and improvement suggestions

    C->>U: Present analysis and ask clarifying questions
    U-->>C: Provide additional details and answers

    C->>C: Technical planning with refined requirements
    C->>DA: Documentation planning
    DA-->>C: Knowledge transfer plan

    C->>C: Create work item file in ./workspace/work-items/
    C-->>U: Comprehensive action plan with file location
```

## EXAMPLES

```bash
# Plan from user description
/plan implement user authentication system

# Plan from Azure DevOps work item
/plan ADO-12345

# Plan from GitHub issue
/plan GH-67890

# Plan infrastructure work
/plan migrate database to new server

# Plan documentation project
/plan create API documentation for microservices
```

## DOCUMENTATION TEMPLATES

MANDATORY EXCLUSIVE TEMPLATES:

- `implementation-plan.md` - Master implementation plan
- `service-implementation-plan.md` - Service-specific implementation details

## OUTPUT LOCATIONS

- `./workspace/work-items/<WorkItemName>/implementation-plan.md`
- `./workspace/work-items/<WorkItemName>/<service-name>/<service-name>-implementation-plan.md`

## OUTPUT

- Interactive clarification session with user
- Critical analysis and risk assessment from task clarifier
- Comprehensive implementation plan with phase breakdown
- Implementation strategy with parallel/sequential execution
- Resource requirements and time estimates
- Service-specific implementation plans
- All documentation using mandatory templates
