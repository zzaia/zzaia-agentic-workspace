---
name: /ask
description: Intelligent answering, query and clarification system with read-only access
parameters:
  - name: question
    description: Natural language question or query to be answered
    required: true
  - name: context
    description: Optional context specification (file path, repository reference, or topic area)
    required: false
---

## PURPOSE

Provide intelligent question answering, clarification or query through read-only information gathering without system modifications.

## EXECUTION

1. **Query Analysis**

   - Parse the input question
   - Identify key components and intent
   - Extract context requirements
   - Identify multiple questions, queries or clarifications are asked

2. **Information Gathering**

   - Use read-only tools for data collection
   - Search relevant files and documentation
   - Gather external information if needed
   - For each employed agent use than in parallel
   - Call multiple agents in case of multiple questions or queries

3. **Response Generation**
   - Synthesize comprehensive answer from one or multiple sources
   - Provide actionable insights
   - Suggest follow-up actions

## AGENTS

ALWAYS Use specific agents defined here, select by description

- **zzaia-task-clarifier**: Agent for query analysis related to tasks in codebases
- **general-purpose**: Agent for web research and external information gathering using /websearch command

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as /ask Command
    participant TC as Task Clarifier
    participant GP as General Purpose
    participant S as System/Files

    U->>C: /ask <question> [context]
    C->>C: Parse input & identify intent

    par Information Gathering
        C->>TC: Query analysis (read-only)
        TC->>S: Search files/docs
        S-->>TC: Local data
    and
        alt External research needed
            C->>GP: Use /websearch command
            GP-->>C: Web research results
        end
    end

    C->>C: Synthesize comprehensive answer
    C-->>U: Formatted response
```

## EXAMPLES

```bash
# General system question
/ask "How does authentication work in this system?"

# Specific technical question
/ask "What are the database migration patterns used?" context="compliance-hub"

# Architecture question
/ask "Explain the microservices communication strategy"

# Multiple questions
/ask "Explain the microservices communication strategy in this repository. Also the news about the microservice architecture"

```

## OUTPUT

- Direct, comprehensive answer to the question
- Key insights and technical details
- Practical implications and recommendations
- Related resources and references
- Suggested follow-up actions or considerations
