---
name: capability:document:templates:implementation-plan
description: Template for master implementation plans with phased delivery, milestones, and task breakdown
user-invocable: false
---

# [Project Name] - Master Implementation Plan

## Overview

[Brief project description and scope]

**Effort**: [total effort points] (parallel) | **Tech**: [key technologies]

> Effort estimated using Fibonacci sequence: 1, 2, 3, 5, 8, 13, 21, 34, 55

---

## Implementation Phase Hierarchy

```mermaid
gantt
    title Implementation Timeline - Parallel vs Sequential
    dateFormat YYYY-MM-DD

    section Phase 1 (Parallel)
    [Task 1]                :active, task1, YYYY-MM-DD, Xd

    section Phase 2 (Parallel)
    [Task 2A]               :active, task2a, after task1, Xd
    [Task 2B]               :active, task2b, after task1, Xd

    section Phase 3 (Sequential)
    [Task 3]                :crit, task3, after task2b, Xd
```

**Legend**: Green (Active) = Parallel execution | Red (Critical) = Sequential execution | **Total**: [effort points]

---

## Phase 1: [Phase Name] ([effort] points)

**Parallel**: ✅/❌ | **Team**: [Team composition]

- [ ] [Task 1] ([effort])
- [ ] [Task 2] ([effort])

---

## Phase 2: [Service Development] ([effort] points)

**Parallel**: ✅ | **Team**: [Team composition]

### 2A: [Component A] ([effort] points)
**Reference**: `docs/[path]/[component-a]-implementation-plan.md`

- [ ] [Task 1] ([effort])

**Outputs**: [Key deliverables]

**Dependencies**: [Any dependencies]

---

## Technology Stack

**[Category 1]**: [Technologies]

**[Category 2]**: [Technologies]

---

## Effort Summary

**Parallel Execution**: [effort points]

**Sequential Execution**: [effort points]

**Efficiency Gain**: [effort points] ([percentage]% reduction)

---

## Team Structure

### Recommended (Parallel)
- [count] [Role 1]
- [count] [Role 2]

### Minimum (Sequential)
- [count] [Role 1]

---

## Success Criteria

**Technical**
- ✅ [Criterion 1]

**Operational**
- ✅ [Criterion 1]

**Business**
- ✅ [Criterion 1]

---

## Risk Mitigation

**[Risk 1]** → [Mitigation strategy]

**[Risk 2]** → [Mitigation strategy]

---

## Next Steps

1. [Step 1]
2. [Step 2]
3. [Step 3]
