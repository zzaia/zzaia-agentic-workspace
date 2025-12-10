---
name: /git
description: Execute comprehensive Git version control operations with standardized branch management
parameters:
  - name: action
    description: The git operation to perform (init, branch, commit, merge, status)
    required: true
  - name: repository
    description: Target repository name for the operation
    required: false
  - name: branch_name
    description: Branch name following standardized prefixes
    required: false
  - name: message
    description: Commit message for commit operations
    required: false
---

## PURPOSE

Execute Git version control operations directly with standardized branch management.

## STANDARDIZED BRANCH PREFIXES

Branch naming must follow these strict conventions:

- `feature/`: New feature development
  - Example: `feature/implement-user-authentication`
  - Used for developing new functionality

- `hotfix/`: Critical production fixes
  - Example: `hotfix/fix-security-vulnerability`
  - Reserved for urgent production issues requiring immediate resolution

- `improvement/`: Enhancements to existing functionality
  - Example: `improvement/optimize-search-performance`
  - Used for incremental improvements to existing systems

- `refactor/`: Code restructuring
  - Example: `refactor/restructure-authentication-service`
  - Used for code quality improvements without changing functionality

## EXECUTION

1. **Parameter Validation**
   - Validate action type and parameters
   - Check branch naming conventions
   - Verify repository context

2. **Direct Git Execution**
   - Execute git commands directly
   - Apply standardized branch prefixes
   - Use conventional commit formatting

3. **Operation Logging**
   - Log git command results
   - Report operation status
   - Display relevant output

## IMPLEMENTATION

- **Direct Git Operations**: No agent dependencies
  - Execute git commands directly in repository
  - Enforce branch naming and commit standards
  - Operate within current repository context

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as /git Command
    participant G as Git
    participant R as Repository

    U->>C: /git <action> <parameters>
    C->>C: Validate parameters and branch naming

    alt Parameters Valid
        alt Operation: init
            C->>G: git init
            G->>R: Initialize repository
        else Operation: branch
            C->>G: git checkout -b <prefix/name>
            G->>R: Create branch with prefix
        else Operation: commit
            C->>G: git add . && git commit -m "<message>"
            G->>R: Stage and commit changes
        else Operation: merge
            C->>G: git merge <branch>
            G->>R: Merge branches
        else Operation: status
            C->>G: git status
            G->>R: Check repository status
        end

        R-->>G: Command result
        G-->>C: Git output
        C-->>U: Operation complete with git output
    else Parameters Invalid
        C-->>U: Error: Invalid parameters or branch naming
    end
```

## EXAMPLES

```bash
# Initialize a new repository
/git init my-project

# Create a feature branch
/git branch feature/user-login my-project

# Commit changes with conventional message
/git commit "feat: add authentication system" my-project

# Merge a feature branch
/git merge feature/user-login my-project

# Check repository status
/git status
```

## OUTPUT

- Direct git command output
- Branch creation/management results
- Commit confirmations
- Error and validation messages

## COMMIT ATTRIBUTION

All commits created by this command MUST include the following attribution footer:

```
🤖 Generated with zzaia workspace

Co-Authored-By: <current-model-name>
```

**Format Requirements**:
- Use "zzaia workspace" as the tool reference
- Include current model attribution without email (e.g., "Claude Sonnet 4.5", "Claude Opus 4.5")
- Dynamically use the model name that is currently active
- Add blank line before attribution block
- Place at end of commit message body

**Example Full Commit**:
```
feat: implement user authentication

- Add JWT token generation
- Implement password hashing
- Create login endpoint

🤖 Generated with zzaia workspace

Co-Authored-By: Claude Sonnet 4.5
```

**Note**: The model name in the example above should be replaced with the actual current model being used (e.g., Claude Opus 4.5, Claude Haiku 4, etc.)

## CONSTRAINTS

1. Branch names MUST follow standardized prefixes
2. Commit messages MUST use conventional commit format
3. Commit messages MUST include zzaia workspace attribution
4. Operations execute in current repository context
5. Direct git command execution with standardized formatting