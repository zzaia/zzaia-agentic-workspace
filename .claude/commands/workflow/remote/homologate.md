---
name: /workflow:remote:homologate
description: Orchestrate homologation testing with BDD, live URL testing, diagnostics, and bug reporting
argument-hint: "--work-item <id> --project <project> --url <target-url> --application <app-name> --type e2e|ui|integration [--test-case <id>] [--description <context>] [--doc <file-path>] [--ref-url <url>]"
parameters:
  - name: work-item
    description: Work item ID to homologate
    required: true
  - name: project
    description: Azure DevOps project name
    required: true
  - name: url
    description: Target application URL to run tests against
    required: true
  - name: application
    description: New Relic application name to query logs from
    required: true
  - name: type
    description: "Test type: e2e (API end-to-end interaction), ui (browser/UI interaction via Playwright), integration (service integration)"
    required: true
  - name: test-case
    description: Existing Azure DevOps Test Case work item ID to use. If omitted, a new Test Case is created under the work item.
    required: false
  - name: description
    description: Additional context for BDD generation
    required: false
  - name: doc
    description: Local document file path to inject as context
    required: false
  - name: ref-url
    description: URL reference to fetch and inject as context
    required: false
agents:
  - name: zzaia-devops-specialist
    description: Retrieve work items, post discussions, create bug work items
  - name: zzaia-tester-specialist
    description: Execute tests against the target URL following BDD
  - name: zzaia-document-specialist
    description: Generate BDD and test result documentation
---

## PURPOSE

Orchestrate homologation testing by retrieving work item details, generating BDD scenarios from acceptance criteria, executing tests against a live URL, correlating failures with diagnostics, and creating bug work items for each approved failure.

## TEST TYPES

| `--type` | Scope | Tool |
|----------|-------|------|
| `e2e` | API end-to-end interaction — validates backend contracts and service flows | API client / k6 |
| `ui` | Browser/UI interaction — validates user-facing flows via browser automation | Playwright |
| `integration` | Service integration — validates inter-service communication and contracts | k6 / NBomber |

## WORKFLOW PHASES

1. **Retrieve Work Item and Resolve Test Case**: Fetch work item details and ensure a Test Case exists

   - Call `/devops:work-item --action read --id <work-item> --project <project>`
   - Retrieve full hierarchy: title, description, acceptance criteria, and all child work items
   - **MANDATORY**: description must not be empty
   - **MANDATORY**: work item is **read-only** — no updates, comments, or writes to the work item in any phase
   - If `--test-case` provided: Call `/devops:work-item --action read --id <test-case> --project <project>` to load existing Test Case
   - If `--test-case` NOT provided: Call `/devops:work-item --action create --type "Test Case" --title "Test Case: <work-item-title>" --parent <work-item> --project <project>` to create a new Test Case linked as child — use its ID as `<test-case>` for all subsequent phases

2. **Gather Referenced Documentation**: Enrich testing context with external materials if provided

   - If `--doc` provided: Call `/document:read --doc <doc>`
   - If `--ref-url` provided: Call `/websearch --url <ref-url>`
   - Compile retrieved content into testing context

3. **Generate BDD Documentation**: Translate acceptance criteria and child work items into BDD scenarios

   - Call `/management:business --context "<work-item-details + child-work-items>" --description "<provided-description>"`
   - Produce Given/When/Then scenarios appropriate for `--type` (API flows for e2e, UI flows for ui, contract flows for integration)
   - Call `/document:write --template bdd-scenarios --title "BDD Scenarios: <work-item-title>" --work-item <test-case> --target-field description` to write BDD as the Test Case description
   - **MANDATORY**: Do NOT proceed to testing before user confirmation

4. **Validate BDD**: Confirm generated BDD scenarios are correct before testing

   - Use **AskUserQuestion** to ask user to review the BDD in the Test Case and confirm to continue
   - Call `/devops:work-item --action read-discussion --id <test-case> --project <project>` to retrieve user replies and any BDD changes requested
   - Apply any corrections from discussion replies before proceeding to testing

5. **Execute Tests**: Run tests against the target URL following validated BDD scenarios

   - If authentication is required (login, token, credential): Use **AskUserQuestion** to ask the user to provide the credential or perform the manual login in the Playwright session before proceeding
   - Call `/development:test --action run --type <type> --environment <url> --repo <application>`
   - For `ui` type: Playwright browser automation drives UI interactions
   - For `e2e` type: API client validates endpoint contracts and service flows
   - Capture all pass/fail results, response times, error details per scenario

6. **Retrieve Diagnostic Logs**: Collect all available diagnostics if failures occurred

   - If failures detected:
     - Call `/devops:debug-new-relic --application <application[i]>` for each involved application
     - Call `/workspace:debug-playwright --url <url>` to retrieve browser logs (always for `ui` type; conditional for others)
     - Call `/development:review --target repo --context "failures related to <failed-scenarios>" --repo <application[i]>`
   - Correlate all findings (New Relic, browser, local) with failed test scenarios

7. **Generate Test Result Report**: Document all test outcomes and diagnostics

   - Call `/document:write --template e2e-test-failure-report --title "<type> Test Results: <work-item-title>" --context "<test-results + diagnostic-logs>" --work-item <test-case> --target-field discussion`
   - **MANDATORY**: Report must be posted before user validation

8. **Validate Report and Define Bugs**: Review failures and decide which bugs to create

   - Use **AskUserQuestion** to ask user to reply to the report in the Test Case discussion with the approved bug list
   - Call `/devops:work-item --action read-discussion --id <test-case> --project <project>` to retrieve user replies with approved failures, severity adjustments, and dismissals
   - Compile the final approved bug list from discussion replies before proceeding
   - **MANDATORY**: Do NOT create any bug work items before user explicitly approves the final list

9. **Create Bug Work Items**: Create one bug work item per approved failure

   - For each approved failure: Call `/devops:work-item --action create --type Bug --title "<failure-description>" --description "<steps-to-reproduce + expected-vs-actual + diagnostic-evidence>" --severity <severity> --parent <test-case> --project <project>`
   - Provide summary list of all created bug IDs with links

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-devops-specialist` — Retrieve work items, post discussions, create child bug work items
- `zzaia-tester-specialist` — Execute tests against the target URL, capture results and error details
- `zzaia-document-specialist` — Generate BDD scenarios, create test result documentation

## WORKFLOW DIAGRAM

```mermaid
sequenceDiagram
    participant U as User
    participant W as /workflow:remote:homologate
    participant WI as /devops:work-item
    participant DR as /document:read
    participant WS as /websearch
    participant BDD as /management:business
    participant TST as /development:test
    participant NR as /devops:debug-new-relic
    participant PW as /workspace:debug-playwright
    participant DW as /document:write

    U->>W: /workflow:remote:homologate --type <e2e|ui|integration> <params>
    W->>WI: --action read --id <work-item> --project <project>
    WI-->>W: Work item + child work items
    alt --test-case provided
        W->>WI: --action read --id <test-case> --project <project>
        WI-->>W: Existing Test Case loaded
    else --test-case NOT provided
        W->>WI: --action create --type "Test Case" --parent <work-item> --project <project>
        WI-->>W: New Test Case created (id = <test-case>)
    end
    opt --doc provided
        W->>DR: --doc <file>
        DR-->>W: Document content
    end
    opt --ref-url provided
        W->>WS: --url <ref-url>
        WS-->>W: Reference content
    end
    W->>BDD: --context <details+children> --description <ctx>
    BDD-->>W: BDD scenarios (Given/When/Then)
    W->>DW: --template bdd-scenarios --title "BDD: <title>" --work-item <test-case> --target-field description
    DW-->>W: BDD written to Test Case description
    W->>U: AskUserQuestion (review Test Case BDD & confirm)
    U-->>W: Confirmed
    W->>WI: --action read-discussion --id <test-case> --project <project>
    WI-->>W: User replies and BDD corrections
    W->>TST: --action run --type <type> --environment <url> --repo <app>
    TST-->>W: Test results (pass/fail per scenario)
    alt failures detected
        loop for each involved application
            W->>NR: --application <app[i]>
            NR-->>W: Server-side error logs
        end
        W->>PW: --url <url>
        PW-->>W: Browser console errors and network failures
        W->>W: /development:review --target repo --context <failed-scenarios> --repo <app>
    end
    W->>DW: --template e2e-test-failure-report --title "Results: <title>" --context <results+logs> --work-item <test-case> --target-field discussion
    DW-->>W: Report posted to Test Case discussion
    W->>U: AskUserQuestion (reply to Test Case discussion with approved bug list)
    U-->>W: Confirmed
    W->>WI: --action read-discussion --id <test-case> --project <project>
    WI-->>W: Approved failures, severities, dismissals
    loop for each approved bug
        W->>WI: --action create --type Bug --title <failure> --description <details> --severity <sev> --parent <id> --project <project>
        WI-->>W: Bug created
    end
    W-->>U: Workflow complete — bug summary and links
```

## ACCEPTANCE CRITERIA

- Work item and all child work items retrieved with non-empty description
- Test Case resolved: existing one loaded if `--test-case` provided, otherwise a new Test Case created as child of the work item
- BDD scenarios generated appropriate to the test type and written to Test Case description
- Tests executed against target URL with full pass/fail capture per scenario
- Test failures correlated with New Relic, browser, and local diagnostics
- Test result report generated and posted as work item discussion before user validation
- User explicitly reviews report and approves the final bug list with severities before any creation
- Bug work items created only for user-approved failures with full evidence and parent link
- All sub-command invocations delegate to designated agents

## EXAMPLES

```
/workflow:remote:homologate --work-item 12345 --project MyProject --url https://staging.myapp.com --application MyApp --type e2e

/workflow:remote:homologate --work-item 67890 --project MyProject --url https://staging.myapp.com --application MyApp --type ui --description "Validate checkout user flow"

/workflow:remote:homologate --work-item 54321 --project MyProject --url https://qa.myapp.com --application MyApp --type integration --doc /path/to/requirements.md

/workflow:remote:homologate --work-item 11111 --project MyProject --url https://qa.myapp.com --application MyApp --type ui --ref-url https://example.com/acceptance-criteria
```

## OUTPUT

- Phase 1: Work item details with acceptance criteria and child items
- Phase 3: BDD scenarios posted as work item discussion
- Phase 5: Test execution results with pass/fail counts and timing per scenario
- Phase 6: Diagnostic report (New Relic, browser, local) correlated to failures
- Phase 7: Comprehensive test result report posted as work item discussion
- Phase 9: Summary list of created bug work item IDs with Azure DevOps links
