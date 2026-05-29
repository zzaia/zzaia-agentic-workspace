---
name: capability:ecs:debug
description: Analyze AWS ECS cluster state — surface deployment issues and service health problems
argument-hint: "--cluster <name> [--service <name>] [--description <text>]"
user-invocable: true
agent: zzaia-devops-specialist
metadata:
  parameters:
    - name: cluster
      description: ECS cluster name or ARN to analyze
      required: true
    - name: service
      description: Optional service name to focus analysis on specific service
      required: false
    - name: description
      description: Additional context or instructions
      required: false
---

## PURPOSE

Retrieve and analyze ECS cluster resources. Surfaces deployment failures, service health issues, container failures, and task state anomalies. Returns structured diagnostic findings — not raw data.

## EXECUTION

1. **Retrieve Resources** — Call `/capability:ecs:query --cluster <cluster> --resource all`

2. **Analyze — Deployment Issues**
   - Identify services with 0 running tasks while desired > 0
   - Flag services where running task count < desired task count
   - Detect recent deployment failures or rollback patterns
   - Check task definition update failures and constraint violations
   - Surface image pull failures or ECR access issues

3. **Analyze — Container Health**
   - Identify tasks in STOPPED state and capture exit codes
   - Flag tasks with health check failures
   - Detect container crashed or exited unexpectedly patterns
   - Check for memory/CPU pressure or resource constraint violations
   - Surface container dependency or startup order issues

4. **Return Findings** — Structured diagnostic output with severity-tagged issues and health violations

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-devops-specialist` — Query ECS MCP and analyze cluster state

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant A as DevOps Agent
    participant ECS as ECS MCP

    U->>C: /capability:ecs:debug --cluster <name> [--service <name>]
    C->>A: Dispatch with cluster and optional service
    A->>ECS: Retrieve cluster resources
    ECS-->>A: Raw resource set
    A->>A: Inspect services, analyze task states, check container health, detect patterns
    A-->>C: Structured diagnostic findings
    C-->>U: Deployment issues, container failures, service health, resource constraints
```

## ACCEPTANCE CRITERIA

- Resources retrieved from specified cluster
- Services with task count mismatches identified
- Tasks in stopped/failed state reported with exit codes
- Deployment failures and rollback patterns detected
- Health check failures flagged with container context
- Image pull and ECR access issues surfaced
- Resource constraint violations and pressure conditions identified

## EXAMPLES

```
/capability:ecs:debug --cluster production
```

```
/capability:ecs:debug --cluster staging --service api-service
```

## OUTPUT

- **Service Health Issues**: Services with 0 running tasks, desired vs running mismatch
- **Deployment Failures**: Recent failures, rollback patterns, constraint violations
- **Container Failures**: Stopped tasks with exit codes, crashes, health check failures
- **Resource Issues**: Memory/CPU pressure, constraint violations, image pull errors
- **Cluster Health**: Overall deployment stability and service readiness
