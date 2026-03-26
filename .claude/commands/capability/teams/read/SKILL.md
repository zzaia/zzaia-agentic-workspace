---
name: read
description: Read and filter Microsoft Teams chat or channel conversations using Microsoft 365 MCP
argument-hint: "--chat-name <name> [--begin-message <boundary>] [--last-message <boundary>] [--filter <keyword>] [--limit <count>]"
user-invocable: true
agent: zzaia-web-searcher 
metadata:
  parameters:
    - name: chat-name
      description: Name of Teams chat or channel to read (partial match supported)
      required: true
    - name: begin-message
      description: Filter start boundary — message text snippet, date (YYYY-MM-DD), time (HH:MM), or datetime
      required: false
    - name: last-message
      description: Filter end boundary — same format as begin-message; omit to return messages to latest
      required: false
    - name: filter
      description: Keyword or phrase to filter messages by content (case-insensitive)
      required: false
    - name: limit
      description: Page size for each MCP fetch call (default 50, max 1000); pagination continues automatically until all messages in the range are retrieved
      required: false
---

## PURPOSE

Read and retrieve Microsoft Teams chat or channel conversations with support for filtering by date range, message content, and keyword search. Uses Microsoft 365 MCP tools to access Teams data.

## EXECUTION

1. **Resolve Chat/Channel**: Search Teams chats and channels using `--chat-name`

   - Query Microsoft 365 MCP for available chats and channels
   - Match against provided name (partial match supported)
   - Confirm unique chat or return disambiguation if multiple matches
   - Handle ambiguous names by clarifying with user

2. **Retrieve Messages**: Fetch all messages from matched conversation with automatic pagination

   - Use Microsoft 365 MCP Teams tools to retrieve message history in pages (`--limit` controls page size, default 50)
   - **Paginate until complete**: continue fetching next pages until the end boundary (`--last-message`) is reached or no more messages are available — never stop early because a single page was exhausted
   - Page size is capped at 1000 messages per call; values above 1000 are silently clamped
   - Retrieve metadata: sender, timestamp, content
   - Preserve message order and threading information across all pages

3. **Apply Range Filters**: Parse and apply `--begin-message` and `--last-message` boundaries

   - If boundary is a date (YYYY-MM-DD): filter messages on/after that date
   - If boundary is time (HH:MM): filter by time within date
   - If boundary is text snippet: find message containing text and use as anchor
   - If datetime: use exact datetime comparison

4. **Apply Keyword Filter**: Filter messages by `--filter` if provided

   - Case-insensitive search within message content
   - Include only messages matching keyword

5. **Format Output**: Return all collected messages after filters

   - Chat/channel name matched
   - Total message count retrieved (all pages) and count after filters
   - Each message: `[YYYY-MM-DD HH:MM] Sender: message content`
   - Applied filters summary
   - Page count and source confirmation (Teams MCP)

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-web-searcher` — Analyze and disambiguate query parameters if chat name or boundaries are ambiguous

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant A as zzaia-web-searcher
    participant M as Microsoft 365 MCP

    U->>C: /capability:teams:read --chat-name <name> [filters]
    C->>A: Clarify parameters if ambiguous
    A-->>C: Resolved parameters
    C->>M: Search chats/channels by name
    M-->>C: Matching chat/channel
    C->>M: Fetch page (--limit size)
    M-->>C: Message page + next cursor
    loop Until end boundary reached or no more pages
        C->>M: Fetch next page
        M-->>C: Message page + next cursor
    end
    C->>C: Apply date/time/text range filters
    C->>C: Apply keyword filter
    C-->>U: All matching messages (all pages)
```

## ACCEPTANCE CRITERIA

- Resolves chat/channel name using Microsoft 365 MCP (partial match support)
- Paginates automatically until all messages in the `--begin-message`/`--last-message` range are fetched — never stops at a single page
- `--limit` controls page size per MCP call (default 50), not total result count
- Retrieves complete message history with sender and timestamp across all pages
- Parses date (YYYY-MM-DD), time (HH:MM), and text anchors for range filtering
- Case-insensitive keyword filtering on message content
- Returns messages in chronological order
- Handles missing chat with clear error message
- Handles ambiguous chat names by asking user for clarification
- Output shows page count, applied filters, and result count

## EXAMPLES

```
/capability:teams:read --chat-name "Product Launch" --limit 25
/capability:teams:read --chat-name "engineering" --filter "deployment" --limit 100
/capability:teams:read --chat-name "#general" --begin-message "2026-03-20" --last-message "2026-03-26"
/capability:teams:read --chat-name "planning" --begin-message "Started work on" --filter "deadline"
/capability:teams:read --chat-name "status-updates" --begin-message "10:00" --last-message "16:30" --limit 50
```

## OUTPUT

- Matched chat or channel name with confirmation
- Total messages retrieved (all pages) and count after filters
- Formatted message list: `[YYYY-MM-DD HH:MM] Sender: message content`
- Applied filters summary (date range, keywords, page size)
- Page count and source confirmation (Microsoft 365 MCP)
- Any clarification requests if parameters are ambiguous
