---
name: capability:postgresql
description: Execute SQL queries and debug PostgreSQL databases — raw results and issue analysis
argument-hint: "--action <query|debug> [--query <sql>] [--connection-name <name>] [--table <name>] [--description <text>]"
---

# postgresql Skill

Unified entry point for PostgreSQL operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter         | Required | Description                                          |
|-------------------|----------|------------------------------------------------------|
| `--action`        | Yes      | Operation to perform: `query`, `debug`               |
| `--query`         | query    | SQL statement to execute (required for `query`)      |
| `--connection-name`| No      | Named database connection target                     |
| `--table`         | No       | Focus `debug` diagnostics on a specific table        |

## Action Routing

| Action  | Command                                           | Description                                           |
|---------|---------------------------------------------------|-------------------------------------------------------|
| `query` | [@capability:postgresql:query](./query/SKILL.md)  | Execute raw SQL and return query results              |
| `debug` | [@capability:postgresql:debug](./debug/SKILL.md)  | Run auto-diagnostics and surface issues and warnings  |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
