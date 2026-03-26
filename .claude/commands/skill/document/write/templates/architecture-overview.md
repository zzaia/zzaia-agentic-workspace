---
name: skill:document:templates:architecture-overview
description: Template for high-level system architecture overview covering components, interactions, and design decisions
user-invocable: false
---

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

## C4 Context Diagram

```mermaid
C4Context
    title System Context

    Person(user, "User Type", "User description")
    System(mainSystem, "System Name", "System description")
    System_Ext(externalSystem, "External System", "External system description")

    Rel(user, mainSystem, "Uses", "Protocol")
    Rel(externalSystem, mainSystem, "Provides data", "Protocol")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
```

## C4 Container Diagram

```mermaid
C4Container
    title Container Architecture

    System_Boundary(layer1, "Layer 1") {
        Container(container1, "Container 1", "Tech", "Description")
        Container(container2, "Container 2", "Tech", "Description")
    }

    System_Boundary(layer2, "Layer 2") {
        Container(container3, "Container 3", "Tech", "Description")
    }

    Rel(container1, container2, "Relationship")
    Rel(container2, container3, "Relationship")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
```

## Project Structure

```
[ProjectName]/
├── src/
├── deploy/
├── docs/
└── tests/
```

## Architecture Components

### [Component Category]
- **[Component Name]**: [Brief description] ([Technologies])

### [Platform/Infrastructure]
- **[Infrastructure Component]**: [Brief description]

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| [Layer] | [Technologies] |

## Related Documentation

- [Doc Title](path/to/doc.md) - Description
