---
name: read
description: Extract text and images from PDF and Word documents and inject content into conversation context
argument-hint: "<file-path>"
disable-model-invocation: true
---

## PURPOSE

Extract structured text content from PDF and Word documents to reference in conversation context.

## EXECUTION

1. **Validate Input** — Confirm file path exists and extension is `.pdf` or `.docx`

2. **Extract Content** — Run the extraction script:

```bash
python3 .claude/commands/document/read/scripts/extract-document.py $ARGUMENTS
```

   - PDF: Extracts text and images (base64) per page using pymupdf
   - DOCX: Extracts paragraphs and tables using python-docx

3. **Present Results** — Output document metadata and full extracted content

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this skill's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-document-specialist` — Extract and structure content from PDF and Word documents

## SCRIPTS

- [`scripts/extract-document.py`](scripts/extract-document.py) — extracts text and images from PDF/DOCX files; pass file path as argument

## ACCEPTANCE CRITERIA

- Extracts all text from PDF files with page markers
- Extracts paragraphs and tables from DOCX files with section markers
- Displays document metadata (filename, type, item count, character count)
- Handles missing files with clear error messages
- Handles unsupported formats with format guidance
- Reports missing dependencies with installation instructions

## EXAMPLES

```
/document:read /path/to/report.pdf
/document:read ./contract.docx
/document:read /absolute/path/document.pdf
```

## OUTPUT

- Document metadata header (filename, type, count, size)
- Full extracted text with page/table separators
- Section markers for organizational clarity
- Plain text format for context injection
