---
name: latex:write
description: Generate PDF files from Jinja2 LaTeX templates using tectonic CLI engine
argument-hint: "--template <path> --output <path> [--data <json>]"
user-invocable: true
agent: zzaia-document-specialist
metadata:
  scripts:
    - name: render-latex.py
      script: ./scripts/render-latex.py
  parameters:
    - name: template
      description: "Template to use or path to a .tex.j2 file: architecture-overview, bdd-scenarios, implementation-plan, integration-tests-plan, service-architecture, service-data-model, event-notification, test-result-report, pull-request-review, document"
      required: true
    - name: output
      description: Output PDF file path where compiled PDF will be saved
      required: true
    - name: data
      description: JSON string containing template variables for Jinja2 rendering
      required: false
---

## PURPOSE

Compile LaTeX documents to PDF using the tectonic engine. Accepts a Jinja2-templated `.tex.j2` file, auto-generates diagrams from Mermaid/Graphviz code in `--data`, renders the template, and produces a PDF output file.

## EXECUTION

1. **Validate Input**: Check template path and output directory

   - Verify template file exists and has `.tex.j2` extension
   - Verify output directory is writable
   - Parse JSON data if provided

2. **Auto-generate Diagrams**: Scan `--data` for `diagram_*` keys containing diagram code

   - Keys starting with `diagram_` whose value is Mermaid or Graphviz source are auto-rendered to PNG
   - PNGs are saved to `<output_dir>/diagrams/`
   - The key value is replaced with the PNG path before template rendering
   - Keys already containing file paths (`.png`, `/path/to/file`) are passed through unchanged

3. **Render Template**: Run `./scripts/render-latex.py` to process Jinja2 template

   - Load `.tex.j2` template file
   - Render with resolved data (diagram keys now contain PNG paths)
   - Write temporary `.tex` file to workspace

4. **Compile with Tectonic**: Execute tectonic CLI engine

   - Run `tectonic` on rendered `.tex` file
   - Capture compilation output and errors
   - Handle missing or invalid LaTeX syntax

4. **Deliver Output**: Move compiled PDF to requested output path

   - Verify PDF was generated successfully
   - Copy to `--output` location
   - Clean up temporary files

## DELEGATION

**MANDATORY**: Always invoke the agents defined in this command's frontmatter for their designated responsibilities. Never skip, replace, or simulate their behavior directly.

- `zzaia-document-specialist` — Manage template rendering and PDF generation workflow

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as Command
    participant P as Python Hook
    participant T as Tectonic
    participant F as File System

    U->>C: /capability:latex:write --template <path> --output <path> [--data <json>]
    C->>C: Validate template and output paths
    C->>P: Execute render-latex.py with template and data
    P->>F: Load .tex.j2 template file
    F-->>P: Template content
    P->>P: Render Jinja2 with provided data
    P->>F: Write temporary .tex file
    P->>T: Execute tectonic <file.tex>
    T->>T: Compile LaTeX to PDF
    T-->>P: Compiled PDF path
    P->>F: Move PDF to output path
    P-->>C: Completion status
    C-->>U: PDF ready
```

## ACCEPTANCE CRITERIA

- Accepts `.tex.j2` Jinja2-templated LaTeX files
- Renders template with JSON-provided variables
- Compiles LaTeX to PDF using tectonic CLI
- Delivers PDF to specified output path
- Handles missing template files with clear error messages
- Handles invalid JSON data with format guidance
- Handles tectonic compilation errors with meaningful output
- Cleans up temporary files after successful compilation
- Reports missing tectonic dependency with installation instructions

## EXAMPLES

```
/capability:latex:write --template ./templates/document.tex.j2 --output ~/report.pdf --data '{"title":"My Report","author":"John Doe"}'
/capability:latex:write --template /absolute/path/template.tex.j2 --output ./output/document.pdf
```

## OUTPUT

- PDF file at specified `--output` path
- Compilation status and any LaTeX warnings or errors
- Temporary `.tex` file removed after successful compilation
