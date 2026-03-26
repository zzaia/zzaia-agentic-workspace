---
name: skill:document:templates:bdd-scenarios
description: Template for BDD Given/When/Then scenarios derived from acceptance criteria and work item requirements
user-invocable: false
---

# BDD Scenarios — [FeatureTitle]

## Overview

**Feature**: [Feature name and short description]
**Work Item**: [#ID — Title]
**Domain**: [Bounded context or domain area]

---

## Feature: [FeatureName]

[One-sentence description of what this feature delivers for the user or business]

### Background

```gherkin
Background:
  Given [shared precondition that applies to all scenarios]
  And [additional shared precondition]
```

---

### Scenario: [Scenario 1 Title]

```gherkin
Scenario: [Descriptive name of the happy path or primary flow]
  Given [initial context or system state]
  When [action performed by actor or system]
  Then [expected observable outcome]
  And [additional assertion]
```

---

### Scenario: [Scenario 2 Title]

```gherkin
Scenario: [Alternative or edge case flow]
  Given [initial context]
  When [action]
  Then [expected outcome]
```

---

### Scenario Outline: [Parameterized Scenario Title]

```gherkin
Scenario Outline: [Scenario with multiple data combinations]
  Given [context with <parameter>]
  When [action with <input>]
  Then [outcome matches <expected>]

  Examples:
    | parameter | input | expected |
    | [value1]  | [v1]  | [e1]     |
    | [value2]  | [v2]  | [e2]     |
```

---

## Acceptance Criteria Mapping

| Scenario | Acceptance Criterion | Status |
|----------|----------------------|--------|
| [Scenario 1] | [criterion text] | ⬜ Pending / ✅ Covered |
| [Scenario 2] | [criterion text] | ⬜ Pending / ✅ Covered |

---

## Out of Scope

- [Behavior explicitly not covered by these scenarios]
- [Edge case deferred to another feature or work item]
