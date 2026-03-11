## Jupyter / Python Notebook Standards

### Notebook Structure

- Begin with a markdown cell: problem or goal explanation, context, requirements, and reference links
- Organize implementation into numbered sequential steps
- Each step must have a preceding markdown cell documenting its purpose and rationale
- End with markdown cells for Considerations and Conclusions
- Cells must be single-responsibility: one logical operation per cell

### Cell Documentation Rules

- Markdown cells explain the **why** before code cells show the **how**
- Explain technique and approach choices with business or technical rationale
- Mark long-running cells with estimated time ex: `[STEP CAN BE SKIPPED > 2h]`
- Use reference links to external documents when available

### Code Quality Rules

- No fluffy or redundant `print` statements; use structured summaries only
- Suppress warnings and verbose logger output at the import cell
- Mark tunable values with `# PARAMETER:` inline comments
- Use conditional logic to avoid re-executing expensive operations ex: checkpoint checks
- Abstract reusable logic into external modules imported per step

### Naming Rules

- Follow snake_case from python-coding-rules.md
- Use `random_seed` as the single source of randomness passed to all components

### Visualization Rules

- Use `matplotlib` for static plots embedded in notebook output
- Convert interactive figures to static images for compatibility ex: `fig.to_image()`
- Always call `plt.tight_layout()` before `plt.show()`
- Provide title and axis labels for all plots

### Restrictions

- No implementation without a preceding markdown documentation cell
- No bare `print` debugging; use structured output only
- No hardcoded credentials or connection strings; use client abstractions
- Follow python-coding-rules.md for all Python code within cells
