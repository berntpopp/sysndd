---
name: sysndd-visual-design
description: Use when changing SysNDD UI, UX, visual design, page layouts, tables, mobile rows, design tokens, authenticated admin/curation surfaces, or public data views
---

# SysNDD Visual Design

Use this skill before editing any SysNDD frontend surface that changes how the app looks or feels.

## Required Reference

Read `documentation/10-visual-design-guide.md` before making UI edits. Treat it as the source of truth for visual positioning, tokens, layout patterns, component rules, and route-specific debt.

## Operating Rules

- Keep SysNDD compact, clinical, table-first, and quiet.
- Prefer existing `AuthenticatedPageShell`, `TableShell`, mobile-row, chip, token, and form patterns.
- Do not introduce marketing-style hero layouts, decorative gradients, nested card stacks, or new one-off palettes.
- Use purpose-built mobile record rows for complex tables instead of stacked Bootstrap table output.
- Keep cards at 8px radius or less unless an existing component contract requires otherwise.
- Use existing design tokens for color, spacing, typography, and radius.
- Preserve footer-safe scrolling and avoid horizontal overflow.

## Verification

For authenticated admin/curation visual changes, run:

```bash
cd app && PLAYWRIGHT_BASE_URL=http://localhost:5173 npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts --project=chromium-desktop
```

Before handoff, choose the repo verification lane appropriate to the change from `AGENTS.md`.
