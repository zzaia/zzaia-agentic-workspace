# Architecture Overview Template

## Purpose

Template for system-wide architecture documentation covering all services, infrastructure, and architectural decisions.

## Description

The document should contain:

- High-level system description
- Architecture Decision Records (ADRs) for key decisions
- C4 Context diagram (mermaid)
- C4 Container diagram (mermaid)
- Project structure (ASCII tree)
- Architecture components summary
- Technology stack table
- Related documentation links

The architecture overview document must follow this format:

```md
# [Project Name] - Architecture Overview

[Brief system description and architectural approach]

---

### ADR 001: [Decision Title]

**Decision**: [What was decided]

[Details in bullet points]

**Rationale**: [Why this decision was made and its benefits]

---

### ADR 002: [Next Decision]

[Follow same pattern]

---

[Additional ADRs as needed]

## C4 Context Diagram

\```mermaid
C4Context
    title System Context

    Person(user, "User Type", "User description")

    System(mainSystem, "System Name", "System description")

    System_Ext(externalSystem, "External System", "External system description")

    Rel(user, mainSystem, "Uses", "Protocol")
    Rel(externalSystem, mainSystem, "Provides data", "Protocol")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
\```

## C4 Container Diagram

\```mermaid
C4Container
    title Container Architecture

    System_Boundary(layer1, "Layer 1") {
        Container(container1, "Container 1", "Tech", "Description")
        Container(container2, "Container 2", "Tech", "Description")
    }

    System_Boundary(layer2, "Layer 2") {
        Container(container3, "Container 3", "Tech", "Description")
        Container(container4, "Container 4", "Tech", "Description")
    }

    System_Boundary(layer3, "Layer 3") {
        Container(storage1, "Storage 1", "Tech", "Description")
        Container(storage2, "Storage 2", "Tech", "Description")
    }

    Rel(container1, container2, "Relationship")
    Rel(container2, container3, "Relationship")
    Rel(container3, storage1, "Writes")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
\```

## Project Structure

\```
[ProjectName]/
├── src/
│   ├── [ProjectName].sln
│   ├── [Component1]/
│   ├── [Component2]/
│   └── Shared/
├── deploy/
│   ├── k8s/
│   ├── docker/
│   └── [orchestration]/
├── docs/
│   ├── architecture-overview.md
│   └── [subsystem]/
└── tests/
\```

## Architecture Components

### [Component Category 1]
- **[Component Name]**: [Brief description] ([Technologies])

**Details**: [Link to detailed documentation]

### [Component Category 2]
- **[Component Name]**: [Brief description]

### [Platform/Infrastructure]
- **[Infrastructure Component]**: [Brief description]
- **[Security Component]**: [Brief description]
- **[Observability Component]**: [Brief description]

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| [Layer 1] | [Technologies] |
| [Layer 2] | [Technologies] |
| [Layer 3] | [Technologies] |
| [Layer 4] | [Technologies] |

## Related Documentation

- [Doc Title 1](path/to/doc.md) - Description
- [Doc Title 2](path/to/doc.md) - Description
- [Doc Title 3](path/to/doc.md) - Description
\```
