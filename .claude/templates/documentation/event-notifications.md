# Event Notification System Template

## Purpose

Template for documenting event-driven architecture including event catalog, topic configuration, and idempotency patterns.

## Description

The document should contain:

- Event system overview and infrastructure
- Event catalog with detailed schemas and field definitions
- Message broker topic configuration
- Service mesh pub/sub component setup
- Idempotency implementation patterns
- Error handling and retry strategies
- Monitoring and observability metrics
- Testing strategies for event flows

The event notifications document must follow this format:

```md
# [projectName] - Event Notification System

## Overview

[eventSystemDescription]

**Infrastructure**: [eventInfrastructure]

---

## Event Catalog

### [categoryName] (Published by [publisherService])

#### [eventNumber]. [eventName]

**Description**: [eventDescription]

**Publisher**: [publisher]
**Subscribers**: [subscribers]

**Payload Schema**:
```json
{
  "event_id": "uuid",
  "event_type": "[eventType]",
  "timestamp": "[timestampFormat]",
  "payload": {
    "[field1]": [value1],
    "[field2]": [value2],
    [...]
  }
}
```

**Field Definitions**:
- `[fieldPath]` ([fieldType], [required/optional]): [fieldDescription]
- `[nextField]` ([type], [requirement]): [description]
- [...]

**Subscriber Behavior** ([subscriberName]):
- [action1]
- [action2]
- [...]

---

[Repeat for each event]

## [MessageBroker] Topic Configuration

### Topic Naming Convention
`[topicNamingPattern]`

**Examples**:
- `[exampleTopic1]`
- `[exampleTopic2]`
- [...]

### Topic Configuration
- **[configKey1]**: [configValue] ([purpose])
- **[configKey2]**: [configValue] ([purpose])
- [...]

---

## [ServiceMesh] Pub/Sub Component Configuration

### [serviceName] ([publisherOrSubscriber])
```yaml
apiVersion: [apiVersion]
kind: Component
metadata:
  name: [componentName]
spec:
  type: [componentType]
  version: [version]
  metadata:
    - name: [metadataKey1]
      value: "[metadataValue1]"
    - name: [metadataKey2]
      value: "[metadataValue2]"
    [...]
```

[Repeat for each service]

---

## Idempotency Strategy

[idempotencyDescription]

### Implementation Patterns

**[eventType1]**:
- [step1]
- [step2]
- [...]

**[eventType2]**:
- [step1]
- [step2]
- [...]

[...]

---

## Error Handling

### Retry Strategy
- [retryDescription1]
- [retryDescription2]
- [...]

### Dead Letter Queue
- [dlqDescription1]
- [dlqDescription2]
- [...]

---

## Monitoring & Observability

### Metrics
- `[metricName1]` ([metricType]): [metricDescription]
- `[metricName2]` ([metricType]): [metricDescription]
- [...]

### Logging
- [loggingRequirement1]
- [loggingRequirement2]
- [...]

---

## Testing Strategy

### Unit Tests
- [unitTestDescription1]
- [unitTestDescription2]
- [...]

### Integration Tests
- [integrationTestDescription1]
- [integrationTestDescription2]
- [...]

### Load Tests
- [loadTestDescription1]
- [loadTestDescription2]
- [...]
```
