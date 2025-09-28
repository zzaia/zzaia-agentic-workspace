---
name: /migrations
description: Entity Framework Core migrations management across repositories
parameters:
  - name: repository
    description: Target repository name
    required: true
  - name: branch
    description: Target branch name
    required: true
  - name: action
    description: Migration action (add, remove, list, update, script, drop)
    required: true
  - name: migration-name
    description: Name for new migration (for add action)
    required: false
---

## PURPOSE

Manage Entity Framework Core database migrations with standardized actions and security best practices.

## EXECUTION

- **CRITICAL**: Always apply migrations in the .Data project or in the project where the DbContext is implemented
- NEVER apply migrations in the main application where appsettings are located
- This is a security measure to prevent direct database modifications in the primary application layer

1. **Validation Phase**

   - Verify repository and branch existence
   - Check EF Core project configuration
   - Validate migration action permissions

2. **Migration Preparation**

   - Switch to specified repository and branch
   - Restore project dependencies
   - Validate database connection

3. **Migration Execution**
   - Perform specified migration action
   - Generate migration scripts
   - Log migration details

## EXECUTION APPROACH

Direct EF Core migration management with comprehensive validation and security measures.

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as /migrations Command
    participant W as Workspace
    participant EF as EF Core
    participant DB as Database

    U->>C: /migrations <repo> <branch> <action> [name]
    C->>W: Validate repository and branch
    W-->>C: Repository context
    C->>EF: Check current database state
    C->>EF: Execute migration action
    EF->>DB: Apply changes (if applicable)
    DB-->>EF: Database response
    EF-->>C: Migration results
    C-->>U: Migration execution summary
```

## PARAMETERS

- `repository`: Git repository name containing the EF Core project
- `branch`: Specific branch for migration execution
- `action`: Migration operation type
  - `add`: Create new migration capturing model changes
  - `remove`: Remove last migration
  - `list`: List all migrations
  - `update`: Apply pending migrations to database
  - `script`: Generate SQL migration script
  - `drop`: Drop database (caution)
- `migration-name`: Optional descriptive name for migration (recommended for `add` action)

## EXAMPLES

```bash
# Add a new migration
/migrations compliance-hub main add AddUserProfile

# Update database to latest migration
/migrations customer-portal develop update

# List all migrations
/migrations identity-service feature/auth list

# Generate SQL script
/migrations my-project main script
```

## OUTPUT

- Detailed migration script preview
- Database schema change log
- Migration execution status
- Security validation results
- Database state snapshot
