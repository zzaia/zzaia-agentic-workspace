# Service Architecture Template

## Purpose

Template for individual service architecture documentation including container diagrams, flows, and design decisions.

## Description

The document should contain:

- Service description and core responsibilities
- Architecture Decision Records (ADRs)
- C4 Container diagram (mermaid)
- Sequence diagrams for key flows (mermaid)
- Clean Architecture layer structure (ASCII tree)
- Technical implementation details

The service architecture document must follow this format:

```md
# [Service Name] Architecture

[Brief service description and purpose]

## Core Responsibilities

[Description of what this service does]

---

### ADR 001: [Decision Title]

**Decision**: [What was decided]

[Details in bullet points or paragraphs]

**Rationale**: [Why this decision was made]

---

### ADR 002: [Next Decision]

[Follow same pattern]

---

[Additional ADRs as needed]

## C4 Container Diagram

\```mermaid
C4Container
    title Container diagram for [Service Name]

    System_Ext(externalSystem, "External System", "Description")

    Container_Boundary(serviceBoundary, "[Service Name]") {
        Container(api, "API Layer", "Tech", "Description")
        Container(application, "Application Layer", "MediatR", "CQRS orchestration")
        Container(domain, "Domain Layer", "Models", "Business rules")
        Container(infrastructure, "Infrastructure Layer", "Tech", "Integrations")
    }

    System_Ext(database, "Database", "Tech")
    Container_Ext(messaging, "Messaging", "Kafka/Dapr")

    Rel(externalSystem, api, "Uses", "Protocol")
    Rel(api, application, "Orchestrates")
    Rel(application, domain, "Uses")
    Rel(application, infrastructure, "Calls")
    Rel(infrastructure, database, "Persists", "Protocol")
    Rel(infrastructure, messaging, "Publishes", "Events")

    UpdateLayoutConfig($c4ShapeInRow="4", $c4BoundaryInRow="1")
\```

## [Primary Flow Name]

\```mermaid
sequenceDiagram
    participant Client as Client
    participant API as API Layer
    participant App as Application
    participant Domain as Domain
    participant DB as Database
    participant Event as Event Bus

    Note over Client,Event: [Flow Description]
    Client->>API: Request
    API->>App: Command/Query
    App->>Domain: Execute logic
    Domain->>DB: Persist
    DB-->>Domain: Acknowledgment
    Domain->>Event: Publish event
    Event-->>Domain: Confirmation
    Domain-->>App: Result
    App-->>API: Response
    API-->>Client: Response

    alt Error case
        App->>App: Handle error
        App-->>API: Error response
    end
\```

## Clean Architecture Layer Structure

\```
[ServiceName]/
├── Common/ (Shared libraries)
│   └── [SharedComponents]/
├── [ServiceName].Domain/
│   ├── Entities/
│   ├── ValueObjects/
│   ├── DomainEvents/
│   └── Enums/
├── [ServiceName].Application/
│   ├── Commands/
│   ├── Queries/
│   ├── Handlers/
│   ├── Behaviors/
│   ├── Validators/
│   ├── Mappings/
│   ├── DTOs/
│   └── Interfaces/
├── [ServiceName].Infrastructure/
│   ├── Persistence/
│   ├── Integration/
│   ├── Messaging/
│   └── Services/
├── [ServiceName].API/
│   ├── Controllers/
│   ├── Middleware/
│   └── Extensions/
└── [ServiceName].Tests/
    ├── Unit/
    └── Integration/
\```

## Event-Driven Design
[Event handling strategy and patterns]

## Logging
[Logging strategy and pipeline behaviors]

## Mapping
[Mapping library and patterns]

## Secret Store
[Secret management strategy]

## Environment Variables
[Environment variable management]

## Validation Rules
[Validation strategy]

## Resilience Patterns
[Circuit breaker, retry, timeout configurations]

## Scaling Strategy
[HPA configuration and replica strategy]

## Recommended Tools
- [Tool 1]
- [Tool 2]
- [Tool 3]
\```
