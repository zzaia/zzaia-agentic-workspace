---
name: playwright
description: Manage Playwright browser sessions — diagnose console logs, network errors, and page snapshots
argument-hint: "--action <debug> [--url <page-url>]"
agents:
  - name: zzaia-workspace-manager
    description: Invokes Playwright MCP tools to collect session data and generate diagnostic report
parameters:
  - name: action
    description: "Action to perform: debug"
    required: true
  - name: url
    description: Filter report to a specific page URL. If omitted, covers all open pages.
    required: false
---

## PURPOSE

Single interface for Playwright browser session management. Routes to diagnostics based on `--action`.

## ACTIONS

| Action  | Description                                                              |
|---------|--------------------------------------------------------------------------|
| `debug` | Collect console logs, network errors, and snapshots; generate issue report |

## EXECUTION

### action=debug

1. **Discover Pages** — `mcp__playwright__browser_tabs`; filter by `--url` if set
2. **Collect Console Logs** — `mcp__playwright__browser_console_messages`; separate errors, warnings, info
3. **Collect Network Requests** — `mcp__playwright__browser_network_requests`; flag 4xx/5xx and blocked
4. **Capture Page State** — `mcp__playwright__browser_snapshot` + `mcp__playwright__browser_take_screenshot`
5. **Report** — Categorize by severity ❌ ⚠️ 🔴 🚫; group by page URL; output markdown report

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-workspace-manager` — Executes all Playwright MCP tool calls and generates the diagnostic report

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant WM as Workspace Manager
    participant P as Playwright MCP

    U->>C: /workspace:playwright --action debug [--url <url>]
    C->>WM: Delegate with parameters
    WM->>P: browser_tabs
    P-->>WM: Open tabs
    loop For each page
        WM->>P: browser_console_messages
        WM->>P: browser_network_requests
        WM->>P: browser_snapshot
        WM->>P: browser_take_screenshot
        P-->>WM: Page data
    end
    WM-->>C: Severity-grouped markdown report
    C-->>U: Display report
```

## ACCEPTANCE CRITERIA

- Read-only — no writes, no state changes
- Uses `mcp__playwright__` tools only; does not simulate
- Handles optional `--url` filter
- Report grouped by page URL with severity indicators

## EXAMPLES

```
/workspace:playwright --action debug
/workspace:playwright --action debug --url https://localhost:3000/dashboard
```

## OUTPUT

- Markdown report per page URL
- Severity-grouped findings: Errors, Warnings, Failed Requests, Blocked Requests
- Console messages, network details, screenshots, and DOM snapshots
