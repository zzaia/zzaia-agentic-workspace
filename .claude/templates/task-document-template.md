# Task Document Template

## Purpose

This is a template that defines how the document must be created or updated.

## Description

The document should contain a concise yet complete task specification using the structured plan format:

- Plan header with title, objective, scope, and agent effort and complexity
- Phase breakdown with planning, implementation, testing, and documentation phases
- Detailed action steps with prerequisites and success criteria
- Comprehensive risk assessment and mitigation strategies
- Repository context and cross-repository dependencies
- Next steps and execution guidance
- Avoid putting commands and code to be executed or implemented, this document is only the task guideline;
- References to project files to be created or modified;

The task definition document must always be in the following format:

```md
# Task Title: [title]

# Description

[description]

# Objective

[objective]

# Repositories

[repositories]

# Risk

[risk]

# Effort

[taskEffort]

## Instructions

When developing, you must follow these steps:

1. Step [stepTitle]
   - [stepDefinition]
   - [...]
2. Step [...]
3. Step [...]

**Mandatory Definitions:**

List of mandatory definitions relevant to the task developing:

- [taskDefinition]
- [...]

## Acceptance Criteria

List of mandatory task criteria to ensure development quality:

- [taskAcceptanceCriteria]
- [...]

## Final Considerations

Conclusions and considerations related to the task planning.

[taskConclusions]
```
