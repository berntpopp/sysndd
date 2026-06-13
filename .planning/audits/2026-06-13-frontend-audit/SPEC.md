# SPEC — Lift every public SysNDD page to ≥ 9/10

Date: 2026-06-13 · Input: `AUDIT.md`, `FINDINGS-cross-cutting.md`, `ratings.json`

## Goal

Raise the design quality of every **public** SysNDD page from the audited mean **6.24/10** to **≥ 9/10**, judged on the same 10-dimension rubric, **without regressing** the reference surfaces (home, genes, mcp, login) and **without violating** the existing design-token system, the visual guide (`documentation/10-visual-design-guide.md`), or the 600-line file ceiling.

"9/10" operationalized per page:
- Lighthouse **Accessibility ≥ 99** and **best-practices/SEO = 100** (already 100); no failing `heading-order`, `select-name`, `td-has-header`, `button-name`, `color-contrast`, `aria-prohibited-attr`, `label-content-name-mismatch` audits.
- **CLS ≤ 0.1**; no genuine perf outlier (GeneNetworks off the main thread).
- Exactly one route-level `<h1>`; consistent token-based header language; no horizontal overflow at 1440/390.
- Designed loading / empty / error states; chips meet AA; data-viz has legend/axis/empty-state treatment.

## Non-goals

- No redesign of the established table information architecture (it is the reference). Polish, not replace.
- No new color palette — use existing tokens; **remove** ad-hoc slate/Bootstrap-blue hardcodes.
- No backend/API changes except where a public read path serves the wrong artifact (GeneNetworks layout) — and only via the documented precomputed-snapshot path, never synchronous heavy compute on a public route.
- Authenticated admin/curation pages are out of scope (separate known-debt program in the visual guide).

## Constraints / invariants

- Frontend API access stays through typed clients in `app/src/api/*` (no raw axios / `localStorage.token`).
- Keep handwritten files < 600 lines; extract cohesive helpers if a shell grows.
- Reduced-motion tokens already exist — any new motion must respect them.
- Verify with: `make lint-app`, `cd app && npm run type-check` (+ `:strict`), `npm run test:unit`, and re-run the Lighthouse batch.
- Work on a feature branch off `master`; atomic commits; PR per the repo's release convention.

## Approach — foundation first, then parallel per-page

The audit shows the gap is dominated by **shared-component** defects (a11y 6.48, consistency 6.76, color 6.60). So:

### Sprint 0 — Foundation (sequential prerequisite; one workstream)
Concentrated edits to shared components + tokens. Each fix is multi-page leverage.

- **F1 Headings:** `TableShell` title → configurable heading level defaulting to `<h1>` (size 18px/semibold, tokenized); ensure each public route resolves to exactly one `<h1>`. Trace + fix the global `heading-order` skip (navbar/footer/banner level). AC: `heading-order` passes on all 25 pages; table pages have `h1=1`.
- **F2 Token unification of shells:** `TableShell` + `AnalysisShell` adopt `--neutral-*`, `--border-subtle`, `--radius-md`, `--shadow-sm`, and brand `--medical-blue-700` for active states. Remove slate (`#0f172a`/`#172033`) and Bootstrap blue (`#0d6efd`). Both shells visually consistent. AC: no hardcoded hex in the two shells except via tokens; visual diff acceptable on reference pages.
- **F3 Chip system:** introduce shared, token-based chip styles (or a `<DataChip>`/utility classes) meeting AA; replace `PubtatorNDDTable` / `PublicationsNDDTable` / `NddScoreModelCard` / API pastel chips. AC: `color-contrast` failures → 0 on pubtator/publications/modelcard/api.
- **F4 Select labels:** shared filter `<select>` + page-size select get `aria-label`/associated `<label>` in `GenericTable` filter row + `TablePaginationControls`/`TableFilterControls`. AC: `select-name` → 0 across all tables/analyses/nddscore.
- **F5 Table cell semantics:** filter row + body cells associate with headers (`scope`/`headers` or move filters to a labeled region) in the shared renderer. AC: `td-has-header` → 0.
- **F6 Icon-button names:** shared icon buttons (download/copy/expand/network controls) get `aria-label`/tooltip. AC: `button-name` → 0 (genenetworks, phenotypes).

### Sprints 1–6 — per-page (parallel after Sprint 0, isolated git worktrees)
- **S1 GeneNetworks (4→9):** serve precomputed Cytoscape `preset` layout on the public path (no main-thread fCoSE); reserve canvas height (CLS); finish icon/select labels; tidy two-panel hierarchy.
- **S2 Detail pages (gene-detail 6, entity-detail 4 → 9):** fix lollipop/genomic-viz `aria-prohibited-attr`; reserve `SectionCard` skeleton heights (CLS); entity-detail content/h1 and the 5 failed requests; tighten detail hierarchy.
- **S3 Analysis viz (similarity 5, functional 5, variant 5, phenotypecorrelations 6, entriesovertime 6 → 9):** spacing/density, legends/axes/units, empty + loading + error states, token-based sequential/diverging color scales, mobile reflow.
- **S4 Heavy tables (pubtatorndd 5, publicationsndd 7, nddscore 6, curationcomparisons-table 7 → 9):** finalize chip contrast (post-F3), reduce column overload / progressive disclosure, labels, density.
- **S5 API/About/Register (5/7/5 → 9):** frame the Swagger/Redoc embed on-brand (API consistency = 3 is the single worst dim); About LCP element; Register parity with Login.
- **S6 Reference polish (home/genes/mcp/login 8 → 9):** home loading states + hero trim toward operational tone; micro-polish.

## Verification & exit

For each sprint: targeted unit/type/lint + **re-run the Lighthouse batch** and re-capture screenshots; a **re-rating** pass (same agents/rubric) must put the touched pages ≥ 9. The Playwright authenticated-design spec and `verify-seo-app` must stay green. Nothing merges that regresses a reference page.

## Risks

- Touching shared shells risks regressing the strong table pages → mitigate with screenshot diff + keeping IA identical.
- GeneNetworks precomputed-layout path may need a worker/admin refresh to exist for the public preset → if absent, fall back gracefully (documented behavior) and at minimum fix CLS + a11y; flag perf as snapshot-dependent.
- Token unification may shift pixels on many pages → land F2 early, eyeball reference pages, keep changes conservative.
