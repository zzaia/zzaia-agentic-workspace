---
name: skill:document:templates:test-result-report
description: Template for test execution result reports with pass/fail summary, diagnostics, and failure evidence
user-invocable: false
---

# Test Result Report — [WorkItemTitle]

## Summary

**Work Item**: [#ID — Title]
**Test Case**: [#ID — Title]
**Target URL**: [url]
**Test Type**: [e2e | ui | integration]
**Executed**: [datetime]
**Result**: [✅ PASSED | ⚠️ FINDINGS | ❌ FAILED] — [X passed / Y findings / Z failed / W total]

---

## Test Steps

| Step | Scenario | Status | Response | Evidence | Notes |
|------|----------|--------|----------|----------|-------|
| 1 | [Given/When/Then scenario] | ✅ Pass | [HTTP status / timing] | — | — |
| 2 | [Given/When/Then scenario] | ⚠️ Finding | [HTTP status / timing] | [IDs, keys, tokens observed] | [Anomaly or warning detail] |
| 3 | [Given/When/Then scenario] | ❌ Failed | [HTTP status / timing] | [IDs, keys, tokens observed] | [Error detail] |
| 4 | [Given/When/Then scenario] | ❓ Inconclusive | [HTTP status / timing] | — | [Reason inconclusive] |

---

## Findings

### Finding 1 — S[severity]: [Title]

- **Step**: [step number and scenario]
- **Endpoint / Action**: [Method and route or UI action]
- **Behavior**: [Observed behavior]
- **Impact**: [Impact on system or user]
- **Evidence**: [Relevant IDs, log entries, screenshots, stack traces]

---

## Bug Work Items Created

| Bug ID | Title | Severity | Step |
|--------|-------|----------|------|
| #[id] | [title] | [Critical / High / Medium / Low] | [step number] |
