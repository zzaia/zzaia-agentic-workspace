# Generative UI Data Models

## SQLite Schema Definitions

### Sessions Table
```sql
CREATE TABLE sessions (
    sessionId TEXT PRIMARY KEY,
    title TEXT,
    status TEXT CHECK(status IN ('active', 'idle', 'completed')),
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    lastActivityAt DATETIME,
    taskId TEXT,
    agentId TEXT
);
```

### Messages Table
```sql
CREATE TABLE messages (
    messageId TEXT PRIMARY KEY,
    sessionId TEXT,
    agentId TEXT,
    messageType TEXT,
    content TEXT,
    transformedHtml TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    metadata JSON,
    FOREIGN KEY(sessionId) REFERENCES sessions(sessionId)
);
```

## Entity Relationships
- **One-to-Many**: One session can have multiple messages
- **Foreign Key**: `sessionId` links messages to their parent session

## Data Access Patterns
- **Primary Access Pattern**:
  - Retrieve messages by `sessionId`
  - Sort by `timestamp`
- **Indexing Strategy**:
  ```sql
  CREATE INDEX idx_session_timestamp ON messages(sessionId, timestamp);
  CREATE INDEX idx_session_status ON sessions(status, lastActivityAt);
  ```

## Cache Retention Policy
- **Default Retention**: 30 days
- **Cleanup Strategy**:
  ```sql
  DELETE FROM sessions
  WHERE lastActivityAt < datetime('now', '-30 days');

  DELETE FROM messages
  WHERE sessionId NOT IN (SELECT sessionId FROM sessions);
  ```

## Migration Strategy
- **Versioned Migrations**: Incremental SQL scripts
- **Rollback Support**: Reverse migration scripts
- **Automated Migration**: Part of deployment process

## Data Integrity Constraints
- **UUID Validation**: Strict format checking
- **Content Sanitization**:
  - Markdown-to-HTML transformation
  - XSS prevention
- **Metadata Validation**: JSON schema enforcement

## Performance Considerations
- **Batch Processing**: Bulk insert/update capabilities
- **Compression**: Optional content compression
- **Archiving**: Cold storage for older sessions

## Backup and Recovery
- **Periodic Snapshots**: Full database backup
- **Point-in-Time Recovery**: Transaction log preservation
- **Export Formats**:
  - SQLite
  - JSON
  - CSV (for analytics)

## Monitoring Metrics
- **Cache Hit Ratio**
- **Storage Utilization**
- **Query Performance**
- **Retention Compliance**