---
name: capability:document:templates:integration-tests-plan
description: Template for integration test plans defining scope, test cases, environments, and success criteria
user-invocable: false
---

# [ServiceName] - Integration Tests Plan

## Overview

[Brief description of integration testing scope and strategy]

**Stack**: [test framework] | **Environment**: [test environment] | **Coverage target**: [X%]

---

## Scope

### In Scope
- [component/flow 1]
- [component/flow 2]

### Out of Scope
- [excluded component 1]
- [excluded component 2]

---

## Test Environment

| Resource | Type | Configuration |
|----------|------|---------------|
| [resource1] | [type] | [config] |
| [resource2] | [type] | [config] |

**Setup**: [setup command or script]

---

## Test Scenarios

### [ScenarioGroup1]

#### TC-001: [Test Case Name]
**Given**: [precondition]
**When**: [action]
**Then**: [expected outcome]
**Tags**: `[tag1]`, `[tag2]`

---

#### TC-002: [Test Case Name]
**Given**: [precondition]
**When**: [action]
**Then**: [expected outcome]
**Tags**: `[tag1]`

---

### [ScenarioGroup2]

#### TC-00N: [Test Case Name]
**Given**: [precondition]
**When**: [action]
**Then**: [expected outcome]

---

## Test Data

### [DataCategory1]
- [dataItem1]: [description]
- [dataItem2]: [description]

### [DataCategory2]
- [dataItem1]: [description]

---

## CI/CD Integration

**Pipeline stage**: [stage name]
**Trigger**: [trigger condition]
**Timeout**: [Xm]

**Steps**:
1. [step1]
2. [step2]
3. [step3]

---

## Success Criteria

- ✅ [criterion1]
- ✅ [criterion2]
- ✅ [criterion3]
