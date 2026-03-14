---
name: test
description: Develop and run tests using framework detection and comprehensive test execution
argument-hint: "--type <unit|e2e|ui> [--step <bdd-step>] [options]"
---

# behavior:development:test

Unified entry point for test execution. Routes to the appropriate sub-behavior based on `--type`.

## Parameters

| Parameter | Required | Description                                             |
|-----------|----------|---------------------------------------------------------|
| `--type`  | Yes      | Test mode: `unit`, `e2e`, `ui`                          |
| `--step`  | No       | BDD step to execute (required for `e2e` and `ui` types) |

## Action Routing

| Type  | Command                                              | Description                                        |
|-------|------------------------------------------------------|----------------------------------------------------|
| `unit`  | [@behavior:development:test:unit](./unit/SKILL.md)   | Unit test execution within a project                       |
| `e2e` | [@behavior:development:test:e2e](./e2e/SKILL.md)     | API end-to-end BDD step execution with diagnostics |
| `ui`  | [@behavior:development:test:ui](./ui/SKILL.md)       | Browser/UI BDD step execution via Playwright       |

## Instructions

1. **Parse** `--type` from the invocation arguments
2. **Delegate** to the corresponding sub-behavior per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
