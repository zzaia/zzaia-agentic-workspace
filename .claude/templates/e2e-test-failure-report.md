# E2E Test Failure Report — [WorkItemTitle]

## Summary

**Work Item**: [#ID — Title]
**Target URL**: [url]
**Executed**: [datetime]
**Result**: ❌ FAILED — [X passed / Y failed / Z total]

---

## Test Execution Results

| # | Scenario | Status | Duration | Error |
|---|----------|--------|----------|-------|
| 1 | [Given/When/Then scenario] | ✅ Pass / ❌ Fail | [Xms] | — |
| 2 | [Given/When/Then scenario] | ❌ Fail | [Xms] | [error message] |

---

## Failures Detail

### ❌ [Scenario Name]

**BDD Scenario:**
- **Given**: [precondition]
- **When**: [action]
- **Then**: [expected outcome]

**Actual Behavior**: [what happened instead]

**Error**: `[error message or stack trace excerpt]`

**Steps to Reproduce**:
1. [step 1]
2. [step 2]
3. [step 3]

---

## New Relic Diagnostics

### Application: [app-name]

| Timestamp | Level | Message | Trace ID |
|-----------|-------|---------|----------|
| [time] | ERROR | [log message] | [trace-id] |

**Correlated Errors**: [description of log correlation to test failures]

---

## Bug Work Items Created

| Bug ID | Title | Severity | Scenario |
|--------|-------|----------|----------|
| #[id] | [title] | [Critical/High/Medium/Low] | [scenario name] |

---

## Passed Scenarios

| # | Scenario | Duration |
|---|----------|----------|
| 1 | [scenario] | [Xms] |

---

## Next Steps

- [ ] Fix bugs listed above
- [ ] Re-run E2E suite after fixes
- [ ] Update BDD scenarios if acceptance criteria changed
