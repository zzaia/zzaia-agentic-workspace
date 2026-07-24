---
name: behavior:development:test:ui
description: Execute a single BDD step via Playwright browser automation with browser console diagnostics
argument-hint: "--step <bdd-step> --environment <url> [--description <text>]"
user-invocable: true
agent: zzaia-tester-specialist
metadata:
  parameters:
    - name: step
      description: BDD step text to execute (single step from Test Case Steps)
      required: true
    - name: environment
      description: Live URL to execute the browser interaction against
      required: true
    - name: description
      description: Additional context or instructions for the operation
      required: false
---

## PURPOSE

Execute a single BDD step as a browser interaction via Playwright, collect browser console diagnostics, and return a concise step report with execution time.

## EXAMPLES

```
/behavior:development:test --type ui --step "User clicks checkout button and sees confirmation page" --environment https://staging.myapp.com --application MyApp
```

## EXECUTION

1. **Authentication** *(if required)*

   - Call `/behavior:workspace:ask-user-question --question "Authentication required. Please perform manual login in the Playwright session, then confirm to continue"`

2. **Execute Step**

   - Call `/capability:playwright:navigate --url <environment> --description "<step>"`
   - Capture: interaction result, screenshot on failure, execution time

3. **Collect Browser Diagnostics**

   - Call `/capability:playwright:debug --url <environment>` for browser console logs

4. **Report Step Result**

   - Return: step name, result (pass/fail), execution time, browser anomalies

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-tester-specialist` — Execute browser step and collect diagnostics
- `zzaia-workspace-manager` — Manage Playwright browser session

## WORKFLOW

```mermaid
sequenceDiagram
    participant C as behavior:development:test:ui
    participant PW as /capability:playwright
    participant TS as zzaia-tester-specialist

    C->>PW: /capability:playwright:navigate --url <environment> --description <step>
    PW-->>C: Interaction result (pass/fail, timing)
    C->>PW: /capability:playwright:debug --url <environment>
    PW-->>C: Browser console logs
    C-->>C: Step report (pass/fail, timing, console logs)
```

## ACCEPTANCE CRITERIA

- Browser step executed via Playwright
- Browser console logs captured regardless of pass/fail
- Concise step report returned with result and timing

## OUTPUT

- Step name and result (pass/fail)
- Execution time
- Browser console errors and warnings
