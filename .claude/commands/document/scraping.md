---
name: /scraping
description: Search, extract, and download PDF and Word documents from URLs or web searches with filtering capabilities and user confirmation checkpoints
parameters:
  - name: url
    description: Direct URL to scrape documents from (mutually exclusive with search)
    required: false
  - name: search
    description: Description or keywords to find documents via web search (mutually exclusive with url)
    required: false
  - name: filters
    description: JSON object with filter specifications for refining document search on target page
    required: false
  - name: download
    description: Enable local download of discovered documents (always requires user confirmation)
    required: false
  - name: output-path
    description: Local path for downloaded documents (default workspace/downloads/)
    required: false
---

## PURPOSE

Discover and extract PDF/Word documents from web sources using browser automation (Playwright) or web search.

## EXECUTION

1. **Strategy**: Playwright for form-based sites, WebSearch/WebFetch for static sites
2. **Automation**: Navigate, fill forms, submit, extract links via browser_run_code
3. **Extraction**: Parse document URLs and metadata, apply filters
4. **Confirmation**: Present results, download if user confirms

## AGENTS

- **agent-general-purpose**: Clarify search criteria and filters and execute the scraping. Use multiple agents in case of parallel tasks.

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant B as Browser/Search

    U->>C: /scraping <parameters>
    C->>B: Navigate/Search
    B-->>C: Extract documents
    C->>U: Present results
    U->>C: Confirm download
    C->>U: Download files
```

## ACCEPTANCE CRITERIA

- Prioritizes Playwright for interactive sites, fallback to WebSearch
- Discovers PDF/Word documents with metadata extraction
- Applies filters, requires user confirmation for downloads
- Handles errors gracefully with meaningful messages

## EXAMPLES

```bash
# Form-based site with filters
/document:scraping url=https://site.com/search filters='{"term": "value"}'

# Web search with download
/document:scraping search="research papers 2025" download=true output-path=/workspace/docs

# URL without download
/document:scraping url=https://site.com/resources download=false
```

## OUTPUT

- Document table with metadata (title, type, size, URL)
- Confirmation prompts and download progress
- Summary statistics and error logs
