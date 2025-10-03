# Implementation Plan Template

## Purpose

Template for master implementation planning with timeline, phases, team structure, and success criteria.

## Description

The document should contain:

- Project overview with duration and technology stack
- Phase hierarchy with Gantt chart visualization (mermaid)
- Detailed phase breakdown with tasks and deliverables
- Technology stack categorization
- Timeline summary comparing parallel vs sequential execution
- Team structure recommendations
- Success criteria across technical, operational, and business dimensions
- Risk mitigation strategies
- Next steps for execution

The implementation plan document must follow this format:

```md
# [projectName] - Master Implementation Plan

## Overview

[projectDescription]

**Duration**: [estimatedDuration] | **Tech**: [technologyStack]

---

## Implementation Phase Hierarchy

[Gantt mermaid diagram showing:
- Phases with parallel/sequential indicators
- Task timelines and dependencies
- Critical path visualization
- Resource allocation across timeline]

**Legend**: [legendDescription] | **Total**: [totalDuration]

---

## Phase [number]: [phaseName] ([duration])

**Parallel**: [yes/no] | **Team**: [teamComposition]

Tasks:
- [ ] [taskName] ([taskDuration])
  - [taskDetail1]
  - [taskDetail2]
  - [...]
- [ ] [nextTask] ([duration])
- [...]

**Outputs**: [deliverableDescription]

**Dependencies**: [dependencyDescription]

**Reference**: `[referenceDocPath]`

---

[Repeat for each phase]

---

## Technology Stack

**[categoryName]**: [technologies]

**[nextCategory]**: [technologies]

[...]

---

## Timeline Summary

**Parallel Execution**: ~[parallelDuration]

**Sequential Execution**: ~[sequentialDuration]

**Time Saved**: ~[timeSaved] ([efficiencyPercentage])

---

## Team Structure

### Recommended (Parallel)
- [count] [role]
- [count] [role]
- [...]

### Minimum (Sequential)
- [count] [role]
- [count] [role]
- [...]

---

## Success Criteria

**Technical**
- ✅ [technicalCriterion1]
- ✅ [technicalCriterion2]
- [...]

**Operational**
- ✅ [operationalCriterion1]
- ✅ [operationalCriterion2]
- [...]

**Business**
- ✅ [businessCriterion1]
- ✅ [businessCriterion2]
- [...]

---

## Risk Mitigation

**[riskName]** → [mitigationStrategy]

**[nextRisk]** → [mitigation]

[...]

---

## Next Steps

1. [step1]
2. [step2]
3. [step3]
[...]
```
