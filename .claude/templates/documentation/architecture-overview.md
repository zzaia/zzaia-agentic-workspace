# Architecture Overview Template

## Purpose

Template for system-wide architecture documentation covering all services, infrastructure, and architectural decisions.

## Description

The document should contain:

- High-level system architecture with C4 Context diagram (mermaid)
- Application responsibilities and service descriptions
- Infrastructure components and dependencies
- Development and deployment tooling
- Key architectural decisions and rationale
- External service integrations
- Communication patterns and protocols

The architecture overview document must follow this format:

```md
# [projectName] - System Architecture Overview

[systemDescription]

## System Architecture Diagram

[C4Context mermaid diagram showing:
- Actors/Users
- Frontend containers
- API Gateway/BFF
- Backend services
- Infrastructure components (databases, caching, messaging)
- External services
- Relationships with protocols]

## Application Responsibilities

### [applicationName]
[applicationDescription]

Key responsibilities:
- [responsibility1]
- [responsibility2]
- [...]

### [nextApplication]
[...]

## Infrastructure Overview

Infrastructure components and configuration:

- [infrastructureComponent1]: [description]
- [infrastructureComponent2]: [description]
- [...]

Database architecture:
- [databaseType]: [configuration and purpose]
- [...]

Messaging/Event infrastructure:
- [messagingSystem]: [configuration]
- [...]

## Development and Deployment

Development tooling:
- [tool1] for [purpose]
- [tool2] for [purpose]
- [...]

Deployment strategy:
- [deploymentApproach]
- [...]

## Key Architectural Decisions

### [decisionTitle1]
[decisionDescription]

Rationale:
- [reason1]
- [reason2]
- [...]

### [decisionTitle2]
[...]

## External Service Integration

External services and APIs:
- [serviceName]: [purpose and integration method]
- [...]

## Communication Patterns

Service communication:
- [pattern1]: [description]
- [pattern2]: [description]
- [...]

## Security Architecture

Security measures:
- [securityMeasure1]
- [securityMeasure2]
- [...]
```
