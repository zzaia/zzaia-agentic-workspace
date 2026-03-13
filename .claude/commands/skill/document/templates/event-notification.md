---
name: skill:document:templates:event-notification
description: Template for documenting event-driven notification systems including producers, consumers, and message contracts
user-invocable: false
---

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
    "[field1]": "[value1]",
    "[field2]": "[value2]"
  }
}
```

**Field Definitions**:
- `[fieldPath]` ([fieldType], [required/optional]): [fieldDescription]

**Subscriber Behavior** ([subscriberName]):
- [action1]

---

## [MessageBroker] Topic Configuration

### Topic Naming Convention
`[topicNamingPattern]`

**Examples**:
- `[exampleTopic1]`

### Topic Configuration
- **[configKey1]**: [configValue] ([purpose])

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
```

---

## Idempotency Strategy

[idempotencyDescription]

### Implementation Patterns

**[eventType1]**:
- [step1]

---

## Error Handling

### Retry Strategy
- [retryDescription1]

### Dead Letter Queue
- [dlqDescription1]

---

## Monitoring & Observability

### Metrics
- `[metricName1]` ([metricType]): [metricDescription]

### Logging
- [loggingRequirement1]

---

## Testing Strategy

### Unit Tests
- [unitTestDescription1]

### Integration Tests
- [integrationTestDescription1]

### Load Tests
- [loadTestDescription1]
