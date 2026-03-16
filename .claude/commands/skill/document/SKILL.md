---
name: document
description: Document operations — read, write, and scrape PDF/Word documents
argument-hint: "--action <read|write|scrap> --description <text> [options]"
---

# document Skill

Unified entry point for document operations. Routes to the appropriate sub-command based on `--action`.

## Parameters

| Parameter       | Required | Description                                         |
|-----------------|----------|-----------------------------------------------------|
| `--action`      | Yes      | Operation to perform: `read`, `write`, or `scrap`   |
| `--description` | No       | Broader description of what to do within the action |

## Action Routing

| Action  | Command                             | Description                                      |
|---------|-------------------------------------|--------------------------------------------------|
| `read`  | [@skill:document:read](./read/SKILL.md)   | Extract text from PDF/Word files into context    |
| `write` | [@skill:document:write](./write/SKILL.md) | Generate and deliver markdown documents          |
| `scrap` | [@skill:document:scrap](./scrap/SKILL.md) | Discover and download documents from web sources |

## Instructions

1. **Parse** `--action` from the invocation arguments
2. **Delegate** to the corresponding command per the table above, forwarding all remaining arguments
3. **Follow** the delegated command's own instructions in full
