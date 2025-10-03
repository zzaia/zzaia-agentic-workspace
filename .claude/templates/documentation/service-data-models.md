# Service Data Models Template

## Purpose

Template for comprehensive data modeling documentation including ERDs, entities, value objects, and domain events.

## Description

The document should contain:

- Entity Relationship Diagram (mermaid ERD)
- Detailed entity descriptions with business rules
- Value objects with validation rules
- Domain events with payload definitions
- Aggregate roots with invariants
- Database constraints and indexes
- Migration strategy
- Data seeding requirements
- Performance optimization strategies

The service data models document must follow this format:

```md
# [serviceName] - Data Models

## Entity Relationship Diagram

[Mermaid ERD diagram showing:
- Entities with their columns and types
- Relationships between entities
- Primary and foreign keys
- Cardinality (||--o{, etc.)]

## Entity Descriptions

### [entityName1] Entity
[entityDescription]

**Key Attributes**:
- `[attributeName1]` ([attributeType], [constraints]): [attributeDescription]
- `[attributeName2]` ([attributeType], [constraints]): [attributeDescription]
- [...]

**Business Rules**:
- [businessRule1]
- [businessRule2]
- [...]

**Security Considerations**:
- [securityItem1]
- [securityItem2]
- [...]

**Relationships**:
- [relationshipDescription1]
- [relationshipDescription2]
- [...]

**Synchronization [direction] [targetService]**:
- [syncDetail1]
- [syncDetail2]
- [...]

**[cacheSystem] Caching**:
- [cacheDetail1]
- [cacheDetail2]
- [...]

**Database Indexes**:
- [indexDescription1]
- [indexDescription2]
- [...]

**Validation Rules**:
- [validationRule1]
- [validationRule2]
- [...]

---

### [entityName2] Entity
[...]

---

## Value Objects

### [valueObjectName1]
[valueObjectDescription]

**Properties**:
- `[propertyName1]` ([propertyType]): [propertyDescription]
- `[propertyName2]` ([propertyType]): [propertyDescription]
- [...]

**Validation**:
- [validationRule1]
- [validationRule2]
- [...]

**Example**:
```[language]
[exampleCode]
```

---

### [valueObjectName2]
[...]

---

## Domain Events

### [eventName1]
**Trigger**: [eventTrigger]
**Published By**: [eventPublisher]

**Event Payload**:
- `[fieldName1]` ([fieldType]): [fieldDescription]
- `[fieldName2]` ([fieldType]): [fieldDescription]
- [...]

**Subscribers**:
- [subscriberName1]: [subscriberAction1]
- [subscriberName2]: [subscriberAction2]
- [...]

---

### [eventName2]
[...]

---

## Aggregate Roots

### [aggregateName1] Aggregate
[aggregateDescription]

**Entities**:
- [entityName1]: [entityRole]
- [entityName2]: [entityRole]
- [...]

**Invariants**:
- [invariantRule1]
- [invariantRule2]
- [...]

**Domain Operations**:
- `[operationName1]`: [operationDescription]
- `[operationName2]`: [operationDescription]
- [...]

---

### [aggregateName2] Aggregate
[...]

---

## Database Constraints

### [constraintType1] Constraints
- [constraintDescription1]
- [constraintDescription2]
- [...]

### [constraintType2] Constraints
- [constraintDescription1]
- [constraintDescription2]
- [...]

[...]

---

## Migration Strategy

### Phase [number]: [phaseName]
1. [migrationStep1]
2. [migrationStep2]
3. [...]

**Rollback**: [rollbackDescription]

---

### Phase [nextNumber]: [nextPhaseName]
[...]

---

## Data Seeding

### [seedCategory1]
- [seedDescription1]
- [seedDescription2]
- [...]

### [seedCategory2]
- [seedDescription1]
- [seedDescription2]
- [...]

[...]

---

## Performance Optimization

### [optimizationCategory1]
- [optimizationDescription1]
- [optimizationDescription2]
- [...]

### [optimizationCategory2]
- [optimizationDescription1]
- [optimizationDescription2]
- [...]

[...]
```
