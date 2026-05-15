# SysNDD Visual Design

Use this rule when changing SysNDD UI/UX, page layouts, tables, mobile rows, authenticated admin/curation surfaces, public data views, or design tokens.

Read `documentation/10-visual-design-guide.md` before editing. It is the canonical visual guide.

Preserve the established direction:

- Compact, clinical, table-first, and quiet.
- Existing shells and table patterns before new layout systems.
- Existing design tokens before one-off colors, spacing, typography, or radius.
- Purpose-built mobile record rows for complex tables.
- No nested card stacks, decorative gradients, or marketing-style operational pages.
- No horizontal overflow; keep important controls footer-safe.

For authenticated admin/curation visual changes, run:

```bash
cd app && PLAYWRIGHT_BASE_URL=http://localhost:5173 npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts --project=chromium-desktop
```
