---
name: skill:document:templates:pull-request-review
description: Template for structured pull request code review reports with findings, risks, and recommendations
user-invocable: false
---

# Pull Request Review — [PRTitle]

## Summary

**PR**: [#ID — Title]
**Repository**: [repo-name]
**Branch**: `[source-branch]` → `[target-branch]`
**Reviewed**: [datetime]
**Result**: [✅ Approved / ⚠️ Approved with suggestions / ❌ Changes requested] — [X issues found]

---

## Issues Found

### 1. [Issue Title]

**Severity**: [Critical / High / Medium / Low]
**File**: `[file/path.ext]` — line [N]
**Category**: [Bug / Security / Performance / Design / Style / Test]

**Problem**: [Clear description of the issue]

**Suggestion**:
```[language]
// suggested fix or example
```

---

### 2. [Issue Title]

**Severity**: [Critical / High / Medium / Low]
**File**: `[file/path.ext]` — line [N]
**Category**: [Bug / Security / Performance / Design / Style / Test]

**Problem**: [Clear description of the issue]

**Suggestion**: [Inline suggestion or code block]

---

## Positives

- [What was done well — architecture, tests, naming, etc.]
- [Another positive observation]

---

## Summary Table

| # | File | Severity | Category | Status |
|---|------|----------|----------|--------|
| 1 | `[file]` | [severity] | [category] | 🔴 Must fix / 🟡 Suggested / 🔵 Optional |
| 2 | `[file]` | [severity] | [category] | 🔴 Must fix / 🟡 Suggested / 🔵 Optional |

---

## Decision

**Verdict**: [✅ Approved / ⚠️ Approved with suggestions / ❌ Changes requested]

[Brief rationale for the decision]
