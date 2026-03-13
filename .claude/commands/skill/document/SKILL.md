---
name: document:read
description: Extract text from PDF and Word documents and inject content into conversation context
argument-hint: "--file <path> [--summary]"
allowed-tools:
  - Bash
  - Read
---

# document:read Skill

Extract text content from PDF and Word documents and inject it into the conversation context.

## When to Use

Invoke this skill when the user provides a `.pdf` or `.docx` file path and wants its content read into context.

## Instructions

1. **Validate** — Run `scripts/validate.sh <file-path>` to confirm the file exists and has a supported extension
   - On failure: report the error message and stop
   - On success: proceed to extraction

2. **Extract** — Run `python3 .claude/scripts/extract-document.py <file-path>` via Bash
   - Capture stdout as extracted content
   - Capture stderr as error output; report and stop if non-empty

3. **Format** — Fill in `template.md` with the extracted metadata and content
   - Replace all `{{placeholders}}` with real values from the extraction output
   - If `--summary` flag is set, include only the metadata block and omit the full body

4. **Inject** — Output the formatted result into the conversation so it is available as context

## Parameters

| Parameter  | Required | Description                              |
|------------|----------|------------------------------------------|
| `--file`   | Yes      | Path to `.pdf` or `.docx` file           |
| `--summary`| No       | Output metadata only, no full body text  |

## Files

| File                    | Purpose                                    |
|-------------------------|--------------------------------------------|
| `template.md`           | Output structure to fill in                |
| `examples/sample.md`    | Reference for expected output format       |
| `scripts/validate.sh`   | Validates file path and extension          |
