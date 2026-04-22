# SysNDD Documentation

This directory contains the Quarto-based human-facing SysNDD documentation site.

Build it from this directory:

```bash
quarto render
```

Key source files:

- `index.qmd` and the numbered `.qmd` chapters for published content
- `08-development.qmd` for concise developer onboarding
- `09-deployment.qmd` for concise deployment guidance

Planning and LLM-oriented documentation does not belong here. Keep that material under `.planning/`.
