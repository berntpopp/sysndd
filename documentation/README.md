# SysNDD Documentation

This directory contains the Quarto-based human-facing SysNDD documentation site.

Build it from this directory:

```bash
quarto render
```

From the repository root, the equivalent render and screenshot checks are:

```bash
quarto render documentation
node scripts/documentation/verify-doc-screenshots.mjs
```

Regenerate the Playwright-backed documentation screenshots from the repository root:

```bash
make docs-screenshots
make docs-screenshots-down
```

The screenshot target seeds its own documentation fixture data. The stack serves the app/API through `http://localhost:8088` by default; set `PLAYWRIGHT_HOST_PORT=<port>` when that port is already in use.

Key source files:

- `index.qmd` and the numbered `.qmd` chapters for published content
- `08-development.qmd` for concise developer onboarding
- `09-deployment.qmd` for concise deployment guidance

Design guidance for UI and documentation review lives in `10-visual-design-guide.md` and `11-admin-visual-review.md`; these files are maintained as developer-facing references unless they are intentionally added to Quarto navigation.

Planning and LLM-oriented documentation does not belong here. Keep that material under `.planning/`.
