---
name: capability:document:templates:service-data-model
description: Template for service data model documentation with entity relationships, fields, and constraints
user-invocable: false
---

# [serviceName] - Data Models

## Entity Relationship Diagram

```mermaid
erDiagram
    [ENTITY1] {
        [type] [field1] PK
        [type] [field2]
    }
    [ENTITY2] {
        [type] [field1] PK
        [type] [field2] FK
    }
    [ENTITY1] ||--o{ [ENTITY2] : "[relationship]"
```

## Entity Descriptions

### [entityName1] Entity
[entityDescription]

**Key Attributes**:
- `[attributeName1]` ([attributeType], [constraints]): [attributeDescription]

**Business Rules**:
- [businessRule1]

**Security Considerations**:
- [securityItem1]

**Relationships**:
- [relationshipDescription1]

**Database Indexes**:
- [indexDescription1]

**Validation Rules**:
- [validationRule1]

---

## Value Objects

### [valueObjectName1]
[valueObjectDescription]

**Properties**:
- `[propertyName1]` ([propertyType]): [propertyDescription]

**Validation**:
- [validationRule1]

**Example**:
```[language]
[exampleCode]
```

---

## Domain Events

### [eventName1]
**Trigger**: [eventTrigger]
**Published By**: [eventPublisher]

**Event Payload**:
- `[fieldName1]` ([fieldType]): [fieldDescription]

**Subscribers**:
- [subscriberName1]: [subscriberAction1]

---

## Aggregate Roots

### [aggregateName1] Aggregate
[aggregateDescription]

**Entities**:
- [entityName1]: [entityRole]

**Invariants**:
- [invariantRule1]

**Domain Operations**:
- `[operationName1]`: [operationDescription]

---

## Database Constraints

### [constraintType1] Constraints
- [constraintDescription1]

---

## Migration Strategy

### Phase 1: [phaseName]
1. [migrationStep1]

**Rollback**: [rollbackDescription]

---

## Data Seeding

### [seedCategory1]
- [seedDescription1]

---

## Performance Optimization

### [optimizationCategory1]
- [optimizationDescription1]
