---
name: playwright
description: Manage Playwright browser sessions — diagnose console logs, network errors, and page snapshots
argument-hint: "--action <debug|navigate> [--url <page-url>] [--description <details>]"
---

# playwright Skill

Unified entry point for Playwright browser session management. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter       | Required | Description                                                                     |
|-----------------|----------|---------------------------------------------------------------------------------|
| `--action`      | Yes      | Operation to perform: `debug`, `navigate`                                       |
| `--url`         | No       | Target or filter page URL                                                       |
| `--description` | No       | Broader description of what to do within the action                             |

## Action Routing

| Action     | Command                                       | Description                                                              |
|------------|-----------------------------------------------|--------------------------------------------------------------------------|
| `debug`    | [@skill:playwright:debug](./debug/SKILL.md)   | Collect console logs, network errors, and snapshots; generate issue report |
| `navigate` | [@skill:playwright:navigate](./navigate/SKILL.md) | Navigate to a URL and interact with the page via Playwright MCP          |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
