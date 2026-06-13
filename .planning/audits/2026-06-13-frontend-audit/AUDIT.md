# SysNDD Frontend Design Audit — 2026-06-13

**Reviewer stance:** senior product designer + frontend engineer ("145-IQ" calibration), judging against SysNDD's own stated design intent (a *clinical-research operations tool*: compact, trustworthy, table-first, quiet), not generic web aesthetics.

**Method:**
- **Lighthouse 13.4** (desktop preset, `performance/accessibility/best-practices/seo`) against the dev server `:5173` — 25 public pages → `lighthouse/summary.csv`, `lighthouse/findings.json`.
- **Playwright** headless full-page captures at **1440×900** (+ **390×844** mobile for table/data pages) with console-error / failed-request / DOM-metric capture → `screenshots/`, `capture.json`. The first-visit usage banner was pre-acknowledged so it didn't overlay captures.
- **7 parallel cluster review-agents** each *viewed the screenshots* and *read the component source*, anchored a11y to the Lighthouse failing audits, and returned schema-validated 1–10 scores across 10 dimensions → `ratings.json`.
- Independent senior pass cross-checked the agents and traced shared-component root causes → `FINDINGS-cross-cutting.md`.

> ⚠️ **Performance caveat:** dev-server Lighthouse deflates Performance to a uniform ≈ 62–67 (unminified/HMR). That baseline is **not** a design defect and is excluded from design scoring. Genuine perf outliers (GeneNetworks 17, gene-detail CLS, About LCP) **are** counted.

---

## Scoreboard

Dimensions: Hier=visual hierarchy, Type=typography, Color=color/contrast, Cons=consistency, Space=spacing/density, Resp=responsiveness, A11y=accessibility, DViz=data-viz, State=interaction/loading/empty/error, Clar=content clarity.

| Page | Overall | Hier | Type | Color | Cons | Space | Resp | A11y | DViz | State | Clar |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `home` | **8** | 8 | 8 | 8 | 8 | 8 | 9 | 9 | 8 | 7 | 9 |
| `entities` | **7** | 7 | 8 | 7 | 8 | 8 | 8 | 5 | 8 | 8 | 8 |
| `genes` | **8** | 7 | 8 | 8 | 8 | 8 | 9 | 7 | 8 | 8 | 8 |
| `phenotypes` | **6** | 7 | 8 | 6 | 7 | 8 | 8 | 4 | 7 | 8 | 8 |
| `panels` | **7** | 7 | 7 | 7 | 7 | 6 | 8 | 8 | 7 | 8 | 8 |
| `curationcomparisons` | **7** | 8 | 7 | 7 | 8 | 7 | 8 | 8 | 6 | 8 | 8 |
| `curationcomparisons-similarity` | **5** | 7 | 6 | 6 | 7 | 5 | 5 | 7 | 4 | 6 | 5 |
| `curationcomparisons-table` | **7** | 8 | 7 | 7 | 8 | 7 | 8 | 5 | 8 | 8 | 8 |
| `phenotypecorrelations` | **6** | 7 | 6 | 7 | 8 | 5 | 6 | 8 | 5 | 8 | 7 |
| `phenotypefunctionalcorrelation` | **5** | 6 | 6 | 7 | 7 | 4 | 5 | 8 | 5 | 7 | 7 |
| `variantcorrelations` | **5** | 7 | 5 | 6 | 7 | 5 | 6 | 7 | 5 | 5 | 6 |
| `entriesovertime` | **6** | 7 | 7 | 6 | 6 | 6 | 6 | 6 | 6 | 7 | 7 |
| `publicationsndd` | **7** | 8 | 8 | 7 | 8 | 8 | 7 | 7 | 8 | 8 | 8 |
| `pubtatorndd` | **5** | 7 | 6 | 4 | 6 | 6 | 6 | 6 | 6 | 7 | 6 |
| `genenetworks` | **4** | 6 | 6 | 5 | 5 | 5 | 4 | 4 | 6 | 6 | 5 |
| `nddscore` | **6** | 6 | 7 | 6 | 6 | 7 | 8 | 5 | 7 | 7 | 6 |
| `nddscore-modelcard` | **7** | 7 | 8 | 5 | 7 | 8 | 7 | 6 | 8 | 6 | 7 |
| `about` | **7** | 7 | 7 | 8 | 7 | 7 | 7 | 8 | 7 | 8 | 8 |
| `documentation` | **7** | 7 | 7 | 8 | 6 | 6 | 8 | 8 | 6 | 6 | 8 |
| `mcp` | **8** | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 7 | 6 | 9 |
| `api` | **5** | 5 | 5 | 5 | 3 | 6 | 6 | 5 | 6 | 7 | 6 |
| `login` | **8** | 8 | 8 | 8 | 7 | 8 | 7 | 7 | 7 | 8 | 8 |
| `register` | **5** | 5 | 5 | 6 | 4 | 5 | 6 | 6 | 6 | 6 | 5 |
| `gene-detail` | **6** | 8 | 8 | 7 | 8 | 8 | 8 | 4 | 7 | 8 | 8 |
| `entity-detail` | **4** | 4 | 6 | 6 | 5 | 6 | 6 | 6 | 5 | 5 | 4 |

**Mean overall: 6.24 / 10** · all 25 pages below the 9/10 bar.

**Weakest dimensions (means):** accessibility **6.48**, data-viz **6.52**, color/contrast **6.60**, spacing/density **6.60**, consistency **6.76**. → the gap to 9 is dominated by *systemic, shared-component* issues, not bespoke per-page redesigns.

**Tiering:**
- **Strong (8):** home, genes, mcp, login — keep as reference; small polish to reach 9.
- **Solid (7):** entities, panels, curationcomparisons, curationcomparisons-table, publicationsndd, nddscore-modelcard, about, documentation — a11y + consistency lifts.
- **Mid (6):** phenotypes, gene-detail, nddscore, phenotypecorrelations, entriesovertime — a11y (4–5) is the anchor.
- **Weak (4–5):** genenetworks, entity-detail, api, pubtatorndd, register, similarity/functional/variant correlations — real defects (perf, broken/empty content, off-brand embeds, contrast, data-viz).

---

## Cross-cutting themes (root causes)

Full detail + file:line evidence in **`FINDINGS-cross-cutting.md`**. Summary:

1. **Heading semantics** (FOUNDATION) — `TableShell.vue:6` title is `<h2>`→ 4 table pages have **no `<h1>`**; universal `heading-order` skip in shared chrome.
2. **Two coexisting palettes / token drift** (FOUNDATION) — shells + chips hardcode slate (`#0f172a`/`#172033`) and Bootstrap blue (`#0d6efd`) instead of the documented `--medical-blue-700`/`--neutral-*`/`--border-subtle`; radius inconsistent (12px vs 8px); the two shells don't match each other.
3. **Ad-hoc low-contrast chips** (FOUNDATION) — e.g. `PubtatorNDDTable.gene-chip {#e7f1ff/#0d6efd}` ≈ 3:1, fails AA → the 29 PubTator + 10 Publications + 8 ModelCard contrast failures.
4. **Unlabeled `<select>`** (FOUNDATION) — filter/page-size selects lack accessible names (`select-name`) across tables/analyses/nddscore.
5. **Table cell semantics** (FOUNDATION) — `td-has-header` missing in the shared renderer/filter row.
6. **Icon buttons without names** (FOUNDATION) — `button-name` (genenetworks 6, phenotypes 3).
7. **Layout stability** — CLS gene-detail 0.198, genenetworks 0.277 (async cards without reserved height).
8. **GeneNetworks performance** — perf 17 / TBT 2119ms: public path runs fCoSE on the main thread instead of the precomputed `preset` layout.
9. **gene-detail `aria-prohibited-attr(636)`** — protein-domain lollipop SVG ARIA.
10. **About LCP 8.7s** — late-loading LCP element.

---

## Path to 9/10 — parallelizable sprints

**Sprint 0 — Foundation (do first; lifts every page's A11y + Consistency + Color):** themes 1–6, concentrated in shared components (`TableShell`, `AnalysisShell`, `GenericTable`/filter row, `TablePaginationControls`/`TableFilterControls`, chip styles, design-token CSS). Single workstream, verified by re-running Lighthouse (a11y → 99–100) + unit/type/lint.

**Sprints 1–N — per-page (parallel after Sprint 0, isolated worktrees):**
- **S1 GeneNetworks** — precomputed-layout/preset perf path, CLS reservation, icon-button + select labels. (4→8+)
- **S2 gene-detail + entity-detail** — lollipop ARIA, skeleton height (CLS), entity-detail content/h1/failed-requests. (4–6→8+)
- **S3 Analysis viz polish** — correlograms / matrix / time / variant: spacing, legends/axes/empty states, data-viz color scales. (5–6→8+)
- **S4 PubTator / Publications / NDDScore tables** — finalize chip contrast, dense-table density + labels. (5–6→8+)
- **S5 API / About / Register** — off-brand Swagger embed framing, About LCP, Register form parity with Login. (5→8+)
- **S6 Reference polish** — home loading states + hero trim, genes/mcp/login micro-polish to 9.

See `SPEC.md` and `PLAN.md` (Phase B) for the executable breakdown.
