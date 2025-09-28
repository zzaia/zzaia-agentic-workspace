---
name: /review
description: Comprehensive code review across git changes, repositories, and pull requests
parameters:
  - name: target
    description: The review target (changes/repo/pr)
    required: true
  - name: path
    description: Path to the repository or specific changes
    required: false
  - name: pr_url
    description: Pull request URL for review
    required: false
  - name: depth
    description: Depth of review analysis (light/standard/deep)
    required: false
    default: standard
---

## PURPOSE

Conduct comprehensive code reviews with multi-dimensional analysis, providing actionable insights into code quality, potential improvements, and architectural considerations.

## EXECUTION

1. **Initialization**

   - Validate review target and parameters
   - Prepare review environment
   - Configure review scope and depth

2. **Code Review Execution**

   - Perform comprehensive static code analysis
   - Check coding standards compliance
   - Identify potential security vulnerabilities
   - Assess performance and architectural quality
   - Execute builds and tests and retrieve errors and warnings
   - Analyze changes in broader project context
   - Review dependency interactions
   - Check for potential regression risks
   - Check for the code duplication
   - Analyze where to make the code simpler

3. **Reporting**
   - Generate detailed review report
   - Provide actionable recommendations
   - Highlight critical findings
   - Suggest potential refactoring strategies

## AGENTS

- **zzaia-code-reviewer**: Comprehensive code quality review and static analysis

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant R as /review Command
    participant CR as Code Reviewer
    participant T as Target (Git/Repo/PR)

    U->>R: /review <target> [path] [options]
    R->>CR: Execute comprehensive review
    CR->>T: Analyze code and changes
    CR->>T: Check standards and security
    CR->>T: Assess architecture and performance
    CR->>T: Execute builds and tests
    T-->>CR: Analysis results
    CR->>CR: Generate comprehensive report
    CR-->>R: Review findings and recommendations
    R-->>U: Present review report
```

## ACCEPTANCE CRITERIA

- Comprehensive code quality assessment
- Detection of potential security vulnerabilities
- Actionable and clear recommendations
- Support for multiple review targets
- Consistent and standardized reporting

## EXAMPLES

```bash
# Review current repository changes
/review changes

# Review specific repository
/review repo /path/to/repository

# Review pull request
/review pr https://github.com/owner/repo/pull/123

# Deep review of repository
/review repo /path/to/repository --depth deep
```

## OUTPUT

- Detailed markdown review report
- JSON-formatted analysis results
- Potential code improvement suggestions
- Security vulnerability report
- Architectural quality assessment
