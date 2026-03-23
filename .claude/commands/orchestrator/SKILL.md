---
name: orchestrate
description: Orchestrate multi-item workflows across repositories
argument-hint: "--action <implement> [options]"
---

# orchestrate Skill

Unified entry point for workflow orchestration operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `--action` | Yes | Operation: `implement` |

## Action Routing

| Action | Command | Description |
|--------|---------|-------------|
| `implement` | [@orchestrate:implement](./implement/SKILL.md) | Analyse work-item dependencies and orchestrate implementation in optimal order |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
