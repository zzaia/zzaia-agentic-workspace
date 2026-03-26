---
name: teams
description: Microsoft Teams operations — read and filter chat/channel conversations
argument-hint: "--action <read> [--chat-name <name>] [--begin-message <boundary>] [--last-message <boundary>] [--filter <keyword>] [--limit <count>]"
---

# teams Skill

Unified entry point for Microsoft Teams operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter       | Required | Description                                           |
|-----------------|----------|-------------------------------------------------------|
| `--action`      | Yes      | Operation to perform: `read`                          |
| `--chat-name`   | Yes*     | Name of Teams chat or channel (partial match OK)      |
| `--begin-message` | No     | Filter start boundary: message text, date, or time    |
| `--last-message`  | No     | Filter end boundary: message text, date, or time      |
| `--filter`      | No       | Keyword/phrase to filter messages by content          |
| `--limit`       | No       | Max messages to return (default: 50)                  |

*Required when `--action read`

## Action Routing

| Action | Command                             | Description                                  |
|--------|-------------------------------------|----------------------------------------------|
| `read` | [@capability:teams:read](./read/SKILL.md)   | Read and filter Teams chat/channel messages  |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
