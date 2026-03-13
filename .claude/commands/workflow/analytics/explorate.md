---
name: /workflow:analytics:explorate
description: Comprehensive research workflow for domain, problem, and dataset exploration
argument-hint: "[--domain <context>]"
version: 1.0
agents:
  - name: zzaia-domain-exploration
    description: Identifies top commercially viable problems in data science and software engineering
  - name: zzaia-problem-exploration
    description: Transforms problem statements into comprehensive technical research reports
  - name: zzaia-dataset-exploration
    description: Discovers and evaluates optimal machine learning datasets
---

## Usage
```
/explorate [optional: domain context]
```

# Explorate Command

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-domain-exploration` — Identifies top commercially viable problems in data science and software engineering
- `zzaia-problem-exploration` — Transforms problem statements into comprehensive technical research reports
- `zzaia-dataset-exploration` — Discovers and evaluates optimal machine learning datasets

## Workflow Steps

0. **Domain Exploration**
   - Invoke @agent-zzaia-domain-exploration
   - Objective: Identify top commercially viable problems in data science and software engineering
   - Output: Ranked list of potential problem domains with commercial viability scores

**User Selection**
   - Ask the user by prompt for the selected domain
   - Save the the selected domain information in current-domain.md file in the respective folder 

1. **Problem Refinement**
   - Invoke @agent-zzaia-problem-exploration
   - Objective: Deeply research and refine selected problem domain
   - Output: Comprehensive problem definition with technical solution approaches

**User Selection**
   - Ask the user by prompt for the selected problem 
   - Save the the selected problem information in current-problem.md file in the respective folder 

2. **Dataset Exploration**
   - Invoke @agent-zzaia-dataset-exploration
   - Objective: Find and evaluate datasets from UCI, Kaggle, Google Datasets, and Hugging Face
   - Output: Ranked list of suitable datasets with suitability scores

**User Selection**
   - Ask the user by prompt for the selected dataset 
   - Save the the selected dataset information in current-dataset.md file in the respective folder 

## Key Characteristics
- Structured, sequential workflow
- Focuses on commercial viability and technical feasibility
- Provides comprehensive research across multiple phases
- Generates actionable insights for data science projects