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

Enable efficient document discovery and extraction from web sources by searching for PDF and Word documents (doc, docx) through direct URLs or keyword-based web searches. The command provides user confirmation checkpoints before listing documents and downloading, supports filtering on target pages, and integrates with web scraping tools and web search capabilities.

## EXECUTION

1. **Input Validation & Search Discovery**: Validate parameters and determine search strategy
   - Validate that either url or search parameter is provided (mutually exclusive)
   - If search provided, use the web search command to locate document sources
   - If url provided, prepare direct scraping of target page
   - Parse and validate filters parameter if provided

2. **Document Discovery & Extraction**: Locate and catalog documents on target source
   - Scrape target page/URL for document links (PDF, doc, docx only)
   - Extract metadata for each document (title, size, type, URL)
   - Apply user-specified filters to refine results
   - Compile comprehensive list of discovered documents

3. **User Confirmation & Download Coordination**: Confirm actions before execution
   - Present formatted list of all discovered documents
   - Request user confirmation to proceed with download
   - If download enabled, confirm output path and disk space
   - Coordinate batch downloading of confirmed documents
   - Report progress and handle partial failures

## AGENTS

- **zzaia-task-clarifier**: Clarify document search criteria and filter requirements
- **web-scraper-agent**: Execute document extraction from target URLs using MCP tools
- **document-processor-agent**: Extract metadata and process document listings

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant TC as Task Clarifier
    participant WS as Web Scraper
    participant WF as Web Fetch/Search
    participant DP as Document Processor

    U->>C: /scraping <parameters>
    C->>TC: Validate parameters and search criteria
    TC-->>C: Confirmation of input validity

    alt Search by Keywords
        C->>WF: Web search for document sources
        WF-->>C: List of potential document sources
    else Direct URL
        C->>C: Prepare target URL for scraping
    end

    C->>WS: Scrape target page for documents
    WS->>WF: Fetch page content with MCP tools
    WF-->>WS: Page HTML/content

    WS->>DP: Extract document links and metadata
    DP-->>WS: Structured document list with metadata

    WS-->>C: Return discovered documents

    C->>U: Present formatted document list
    U->>C: Confirm listing and download intent

    alt Download Enabled
        C->>WS: Batch download confirmed documents
        WS->>WF: Download each document
        WF-->>WS: Document binary data
        WS->>C: Save to output-path
        C->>U: Report download completion and file locations
    else No Download
        C->>U: Return document metadata only
    end
```

## ACCEPTANCE CRITERIA

- Command accepts either url or search parameter (mutually exclusive, at least one required)
- Discovers and lists only PDF and Word documents (doc, docx extensions)
- Extracts document metadata including title, size, type, and source URL
- Applies user-specified filters to refine document search results
- Presents complete document list requiring explicit user confirmation before download
- Downloads documents to specified output path with progress reporting
- Handles network errors and partial failures gracefully
- Integrates with web search capabilities for keyword-based document discovery
- Provides meaningful error messages for invalid parameters or failed operations
- All user confirmations are explicit and documented in output

## EXAMPLES

```
/scraping url=https://example.com/documents filters='{"format": "pdf", "date": "2024"}'

/scraping search="machine learning research papers" download=true output-path=/workspace/downloads/ml-papers

/scraping url=https://company.com/resources filters='{"category": "technical", "language": "english"}' download=false

/scraping search="legal compliance documents 2025" download=true
```

## OUTPUT

- Formatted table of discovered documents with metadata (title, type, size, URL)
- Confirmation prompts for listing and download actions
- Download progress reporting with file paths and status
- Summary statistics (total documents found, downloaded count, file sizes)
- Error logs for failed document retrievals
