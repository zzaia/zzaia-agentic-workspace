---
name: /work-items
description: Retrieve and manage work items across Azure DevOps, GitHub, and GitLab
parameters:
  - name: --project
    description: Filter work items by project name
    required: false
    type: string
  - name: --title
    description: Filter by work item title (partial match)
    required: false
    type: string
  - name: --id
    description: Retrieve specific work item by ID
    required: false
    type: string
  - name: --assignee
    description: Filter work items by assignee
    required: false
    type: string
  - name: --status
    description: Filter work items by status/state
    required: false
    type: string
  - name: --since
    description: Work items created/updated since this date
    required: false
    type: string
    format: date
  - name: --until
    description: Work items created/updated until this date
    required: false
    type: string
    format: date
  - name: --platform
    description: Specify work item platform (default: auto-detect)
    required: false
    type: string
    enum: ["azure", "github", "git-lab"]
  - name: --limit
    description: Maximum number of work items to retrieve
    required: false
    type: integer
    default: 20
---

## PURPOSE

Provide a unified interface for retrieving and managing work items across multiple DevOps platforms, enabling developers to quickly access and filter work item information.

## EXECUTION

1. **Platform Detection**

   - Automatically detect available work item platforms
   - Use configured credentials from workspace configuration
   - Fallback to specified platform if provided

2. **Work Item Retrieval**

   - Connect to selected platform's API via MCP TOOL
   - Apply provided filters sequentially
   - Retrieve work items matching filter criteria

3. **Output Processing**
   - **List View**: Format multiple results in standardized CLI-friendly table
   - **Detail View**: Display complete work item information when a specific work item is specified
   - Normalize work item attributes across platforms
   - Handle platform-specific metadata

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as /work-items
    participant A as WorkItem Agents
    participant P as DevOps Platforms

    U->>C: Execute with filters
    C->>A: Translate filters
    A->>P: Query work items
    P-->>A: Return work items
    A->>C: Process and normalize results
    C-->>U: Display formatted work items
```

## ACCEPTANCE CRITERIA

- Successfully connect to at least one DevOps platform
- Apply all specified filters correctly
- Return work items in consistent format
- Handle platform-specific variations
- Provide clear error messages for configuration issues

## EXAMPLES

```bash
# List recent project work items
/work-items --project "Finance" --limit 10

# Find specific work item (detailed view)
/work-items --id 46104

# Filter by assignee and status
/work-items --assignee "john.doe" --status "Active"

# Time-based filtering
/work-items --since "2025-09-01" --project "Crypto Hub"

# Specify platform explicitly
/work-items --platform azure --project "Engineering"
```

## OUTPUT FORMAT

### List View (Multiple Work Items)

```
PLATFORM  ID     TITLE                      STATUS   ASSIGNEE   UPDATED
---------------------------------------------------------------
Azure     46104  Implement OAuth Flow       Active   john.doe   2025-09-10
GitHub    1205   Fix Authentication Bug     Open     jane.smith 2025-09-08
GitLab    9876   Update Documentation       Closed   team-lead  2025-09-05
```

### Detailed View

- Complete work item information display

## CONFIGURATION REQUIREMENTS

- Platform-specific API credentials stored in secure workspace configuration
- OAuth/Personal Access Token support
- Extensible plugin architecture for new platforms
