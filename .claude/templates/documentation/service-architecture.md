# Service Architecture Template

## Purpose

Template for individual service architecture documentation including container diagrams, flows, and design decisions.

## Description

The document should contain:

- Service description and responsibilities
- C4 Container diagram showing internal components (mermaid)
- Sequence diagrams for key flows (mermaid)
- Clean Architecture layer structure (ASCII tree)
- Key design decisions and patterns
- Authentication and authorization strategy
- Integration patterns with other services
- Persistency and caching strategies
- Security best practices

The service architecture document must follow this format:

```md
# [serviceName] - [serviceDomain] Architecture

[serviceDescription]

## C4 Model - Container Diagram

[C4Container mermaid diagram showing:
- Actors/Persons
- Internal containers (API, services, layers)
- External databases
- External containers/systems
- Relationships with protocols]

## [primaryFlowName] Flow

[Sequence mermaid diagram showing:
- Participants (Client, Service, Database, External Services)
- Request/response flow
- Alternative paths (alt/else blocks)
- Notes for important decisions
- Error handling paths]

## Clean Architecture Layer Structure

[ASCII tree showing:
ServiceName/
├── Domain/
│   ├── Entities/
│   ├── ValueObjects/
│   └── Events/
├── Application/
│   ├── Commands/
│   ├── Queries/
│   └── Interfaces/
├── Infrastructure/
│   ├── Persistence/
│   ├── Services/
│   └── Events/
└── API/
    ├── Controllers/
    └── Middleware/]

## Key Responsibilities

1. **[responsibilityTitle1]**
   - [detail1]
   - [detail2]
   - [...]

2. **[responsibilityTitle2]**
   - [detail1]
   - [detail2]
   - [...]

[...]

## Key Design Decisions

### [decisionCategory1]
- [decision1]
- [decision2]
- [...]

### [decisionCategory2]
- [decision1]
- [decision2]
- [...]

[...]

## Exception Handling
[exceptionHandlingStrategy]

## Event Driven Design
[eventDrivenDesignStrategy]

## Logging
[loggingStrategy]

## Authentication & Authorization
[authStrategy]

### [authFlowName]
1. [step1]
2. [step2]
3. [step3]
[...]

### [nextAuthFlow]
[...]

## Exposed Endpoints
[endpointExposureStrategy]

## Mapping
[mappingStrategy]

## Internal Service Integration
[serviceIntegrationStrategy]

Integration details:
- [integrationDetail1]
- [integrationDetail2]
- [...]

## Secret Store
[secretManagementStrategy]

## Validation Rules
[validationStrategy]

## Persistency
[persistencyStrategy]

Persistency details:
- [persistencyDetail1]
- [persistencyDetail2]
- [...]

## Security Best Practices

### [securityCategory1]
- [securityItem1]
- [securityItem2]
- [...]

### [securityCategory2]
- [securityItem1]
- [securityItem2]
- [...]

[...]

## Recommended Tools

- [tool1]
- [tool2]
- [tool3]
[...]

### [exampleTitle]
```[language]
[exampleCode]
```

[Repeat for additional code examples]
```
