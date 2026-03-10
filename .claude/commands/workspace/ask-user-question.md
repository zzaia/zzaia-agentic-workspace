---
name: /workspace:ask-user-question
description: Prompt the user for input using AskUserQuestion with free-form or numbered selection
argument-hint: "--question <text> [--options <semicolon-separated-list>]"
parameters:
  - name: question
    description: The question or prompt text to present to the user
    required: true
  - name: options
    description: Semicolon-separated list of selectable options displayed as a numbered list
    required: false
---

## PURPOSE

Use **AskUserQuestion** to pause execution and request user input. Supports free-form questions or numbered option selection.

## EXECUTION

- If `--options` provided: split by `;`, display as numbered list, ask user to select or confirm
- If only `--question`: ask as free-form and wait for response
- **MANDATORY**: always use **AskUserQuestion** — never simulate or skip

## EXAMPLES

```
/workspace:ask-user-question --question "Ready to proceed?"

/workspace:ask-user-question --question "Select issues to fix" --options "Missing null check; Unused import; Low test coverage"
```
