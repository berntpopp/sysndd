# SysNDD Frontend Audit — Cross-Cutting Findings (independent senior-designer pass)

Date: 2026-06-13 · Evidence: Lighthouse 13.4 (desktop preset, dev server :5173), Playwright full-page captures (1440×900 + 390×844), source review.

> **Performance caveat:** Lighthouse ran against the **Vite dev server** (unminified, HMR). The uniform Performance ≈ 62–67 is a build artifact and is **not** a design defect. Only genuine outliers are treated as real: GeneNetworks (17), gene-detail CLS, About LCP.

## Verdict in one line
The app already has a **mature, WCAG-documented design-token system** and strong reference surfaces (public tables, Home, gene-detail). It is well above generic "AI-slop" UI. The gap to 9/10 is **consistent application of the existing tokens** + a handful of **mechanical a11y fixes** that recur across many pages through shared components.

## Theme 1 — Heading semantics (affects ~every page) · FOUNDATION
- `TableShell.vue:6` renders the page title as `<h2>` at 16px → the 4 table pages (Entities/Genes/Phenotypes/Panels) have **no `<h1>`** (runtime `h1=0`). Violates the guide's "exactly one route-level `<h1>`" and the 18–22px title rule.
- Lighthouse `heading-order` fails on ~every page → a shared heading-level skip (chrome/footer or section jump). Pin per-page during fix; verify by re-running Lighthouse.
- **Fix:** make `TableShell` title an `<h1>` (configurable level, default 1), 18px; resolve the global heading-order skip.

## Theme 2 — Two coexisting palettes / token drift · FOUNDATION
The shells and several components hardcode a **slate palette + Bootstrap blue** instead of the documented tokens:
- `TableShell`: border `rgba(15,23,42,.1)`, title `#0f172a`, meta `#475569`, desc `#64748b`, **radius 12px** (guide: 6–8px). None tokenized.
- `AnalysisShell`: title `#172033`, subtitle `#526070`, active tab `#0d6efd` (**Bootstrap blue, not brand `--medical-blue-700 #0d47a1`**), radius 8px.
- The two shells **don't even match each other** (radius 12 vs 8; `#0f172a` vs `#172033`; h2 vs h1).
- **Fix:** unify both shells onto `--neutral-*`, `--border-subtle`, `--radius-md`, `--shadow-sm`, brand blue. Single consistent header language across the 4 table + ~9 analysis pages.

## Theme 3 — Ad-hoc low-contrast chips · FOUNDATION + per-page
- `PubtatorNDDTable.vue:826` `.gene-chip { background:#e7f1ff; color:#0d6efd }` ≈ **3.0:1 → fails AA** (and wrong blue). This single chip × rows = the **29 contrast failures** on PubTator; same pattern drives Publications (10), ModelCard (8), API (5).
- Multiple components define their own pastel chip palettes (`#b4e3f9/#0d6efd`, `#ffe0b2/#e65100`, …) rather than using the token system, which already documents WCAG-passing values.
- **Fix:** a shared chip/badge style set keyed to tokens (darken text to `--medical-blue-700` etc.); replace per-component pastel chips.

## Theme 4 — Unlabeled form controls (`select-name`) · FOUNDATION
- Column-filter `<select>` and per-page selects lack accessible names: curationcomparisons-table(8), nddscore(5), entities(3), genenetworks(3), entriesovertime(2), phenotypes(1).
- **Fix:** add `aria-label`/associated `<label>` in shared `TableFilterControls` / `TablePaginationControls` / filter selects.

## Theme 5 — Table cell semantics (`td-has-header`) · FOUNDATION
- Cells not associated with headers across all data tables (entities, genes, phenotypes, nddscore, curationcomparisons-table, publicationsndd, genenetworks).
- **Fix:** ensure `<th scope=...>` / `headers` in the shared table renderer (`GenericTable`).

## Theme 6 — Icon-only buttons without names (`button-name`) · FOUNDATION
- genenetworks(6), phenotypes(3) icon buttons lack accessible labels.
- **Fix:** `aria-label`/tooltip on shared icon-button controls.

## Theme 7 — Layout stability (CLS) · per-page
- gene-detail CLS **0.198**, genenetworks **0.277** (both > 0.1 "good"). Async SWR cards / network render without reserved skeleton height.
- **Fix:** reserve min-height on skeletons / `SectionCard` to prevent reflow.

## Theme 8 — GeneNetworks real performance · per-page (highest single-page cost)
- Perf **17**, TBT **2119ms**, LCP 4087, CLS 0.277, load 5.6s. The public path appears to run **fCoSE layout synchronously on the main thread** (AGENTS.md says public requests must use **precomputed** Cytoscape positions; the browser-fCoSE fallback is firing).
- **Fix:** ensure precomputed-layout `preset` path is served publicly; defer/worker-ize layout; reserve canvas size.

## Theme 9 — gene-detail `aria-prohibited-attr(636)` · per-page
- 636 elements with a prohibited aria attribute — almost certainly the ~2.6K-variant protein-domain lollipop SVG (markers given `aria-label`/role that prohibits naming).
- **Fix:** correct ARIA on the lollipop/genomic-viz SVG (decorative `aria-hidden` + one labelled summary).

## Theme 10 — About LCP 8.7s · per-page
- Largest-contentful-paint 8754ms (outlier). Late-loading LCP element (image/CMS content).
- **Fix:** prioritize/inline the LCP element; size images; avoid late hydration of the hero block.

## Sprint shape (parallelizable)
- **Sprint 0 (Foundation, do first):** Themes 1–6 — shared shells, chips, selects, table semantics, icon labels, headings. One workstream touching shared components; unblocks/raises all pages.
- **Sprints 1–N (per-page, parallel after Sprint 0):** GeneNetworks perf+CLS (8); gene-detail ARIA+CLS (9); analysis-page viz polish; About LCP (10); NDDScore density/labels; PubTator/Publications chip+contrast finalization.
