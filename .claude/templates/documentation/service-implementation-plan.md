# Service Implementation Plan Template

## Purpose

Template for detailed service implementation planning with phases, tasks, technical stack, and integration points.

## Description

The document should contain:

- Service implementation overview with duration and team size
- Phase-by-phase implementation breakdown
- Technical stack categorization
- Architecture compliance requirements
- Testing strategy with coverage targets
- Integration points with other services
- Database schema definitions
- API endpoint specifications
- Event publishing/subscription details
- Configuration requirements
- Performance targets
- Deployment checklist

The service implementation plan document must follow this format:

```md
# [serviceName] - Implementation Plan

## Overview

[serviceImplementationDescription]

**Duration**: [implementationDuration] | **Team Size**: [teamSize]

---

## Implementation Phases

### Phase [number]: [phaseName] ([phaseDuration])

**Objective**: [phaseObjective]

**Tasks**:
- [ ] [taskName] ([taskDuration])
  - [subtask1]
  - [subtask2]
  - [...]
- [ ] [nextTask] ([duration])
- [...]

**Deliverables**:
- [deliverable1]
- [deliverable2]
- [...]

**Dependencies**:
- [dependency1]
- [dependency2]
- [...]

**Risks & Mitigations**:
- **Risk**: [riskDescription]
  - **Mitigation**: [mitigationStrategy]
- **Risk**: [nextRisk]
  - **Mitigation**: [mitigation]
- [...]

---

[Repeat for each phase]

---

## Technical Stack

**[categoryName1]**:
- [tech1]: [purpose]
- [tech2]: [purpose]
- [...]

**[categoryName2]**:
- [tech1]: [purpose]
- [tech2]: [purpose]
- [...]

[...]

---

## Architecture Compliance

### [requirementCategory1]
- ✅ [requirement1]
- ✅ [requirement2]
- [...]

### [requirementCategory2]
- ✅ [requirement1]
- ✅ [requirement2]
- [...]

[...]

---

## Testing Strategy

### [testCategory1] ([coverageTarget])
- [testDescription1]
- [testDescription2]
- [...]

### [testCategory2] ([coverageTarget])
- [testDescription1]
- [testDescription2]
- [...]

[...]

---

## Integration Points

### [integrationName1]
**Type**: [integrationType]
**Protocol**: [integrationProtocol]
**Implementation**:
- [step1]
- [step2]
- [...]

### [integrationName2]
**Type**: [integrationType]
**Protocol**: [integrationProtocol]
**Implementation**:
- [step1]
- [step2]
- [...]

[...]

---

## Database Schema

### [entityName1]
- `[fieldName1]` ([fieldType], [constraints]): [fieldDescription]
- `[fieldName2]` ([fieldType], [constraints]): [fieldDescription]
- [...]

**Relationships**: [relationshipDescription]

### [entityName2]
- `[fieldName1]` ([fieldType], [constraints]): [fieldDescription]
- [...]

**Relationships**: [relationshipDescription]

[...]

---

## API Endpoints

### [httpMethod] [endpointPath]
**Description**: [endpointDescription]
**Authorization**: [endpointAuth]

**Request Body**:
```json
[requestExample]
```

**Response**:
```json
[responseExample]
```

[Repeat for each endpoint]

---

## Event Publishing/Subscription

### [publishOrSubscribe] [eventName]
**Topic**: `[eventTopic]`
**Trigger**: [eventTrigger]

**Payload**:
```json
[payloadExample]
```

[Repeat for each event]

---

## Configuration Requirements

### [configCategory1]
- `[configKey1]`: [configDescription] ([configSource])
- `[configKey2]`: [configDescription] ([configSource])
- [...]

### [configCategory2]
- `[configKey1]`: [configDescription] ([configSource])
- [...]

[...]

---

## Performance Targets

- **[metricName1]**: [targetValue] ([measurementMethod])
- **[metricName2]**: [targetValue] ([measurementMethod])
- [...]

---

## Deployment Checklist

- [ ] [deploymentStep1]
- [ ] [deploymentStep2]
- [ ] [deploymentStep3]
- [...]

---

## Success Criteria

- ✅ [criterion1]
- ✅ [criterion2]
- ✅ [criterion3]
- [...]

---

## Timeline Summary

**[milestoneName1]** ([milestoneDate]): [milestoneDeliverable]
**[milestoneName2]** ([milestoneDate]): [milestoneDeliverable]
[...]
```
