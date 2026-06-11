# Continuous refactor of oversized files (#346) — workpackage & sprint design

Date: 2026-06-11
Issue: #346 "Refactor oversized source files toward the 600-line soft ceiling"
Status: validated design

## Problem

`scripts/code-quality-file-size-baseline.tsv` currently allows 65 legacy handwritten
source files over the 600-line soft ceiling (top: `ManageReReview.vue` at 1,579 lines).
The ratchet (`make code-quality-audit`) prevents growth but the legacy debt needs a
structured, incremental, behavior-preserving reduction program — not a broad rewrite.

Three baseline entries are already below 600 lines on master (`ModifyEntity.vue` 598,
`external_endpoints.R` 579, `review_endpoints.R` 576) and ~10 more have actual sizes
below their baseline values, so the ratchet can be tightened for free.

## Goals

- Structure all 65 baseline files into thematic workpackages with clear extraction
  strategies, tracked as GitHub sub-issues of #346.
- Define a sprint cadence: each sprint = one behavior-preserving PR reducing 1–3
  baseline entries, verified by the ratchet plus targeted checks.
- Execute Sprint 1 immediately.

## Non-goals

- No behavior changes, route changes, or API contract changes.
- No mechanical splitting; only cohesive responsibility extraction.
- No splitting of Plumber endpoint files into multiple mounted files (no precedent;
  the established pattern is helper/service extraction).

## Approach (chosen)

**Thematic workpackages + per-sprint PRs.** Alternatives considered:

1. *Strict top-down by size* — attacks the biggest files first, but the biggest
   (`ManageReReview.vue`) is the riskiest (active curation, recent #36/#37/#54 work).
   Rejected as the opener.
2. *One mega-branch refactor* — explicitly forbidden by #346 guardrails. Rejected.
3. **Thematic workpackages, risk-ordered sprints (chosen)** — groups files sharing
   patterns so each sprint amortizes one extraction technique; starts with low-risk,
   well-tested, high-impact files to prove the pattern before touching curation flows.

## Workpackages

Each WP becomes a GitHub sub-issue referencing #346. Line counts are current actuals.

| WP | Theme | Files (current lines) | Strategy |
|----|-------|----------------------|----------|
| WP0 | Ratchet tightening | baseline TSV only | `scripts/code-quality-audit.sh --write-baseline`; removes 3 entries, tightens ~10. Zero risk. |
| WP1 | D3/visualization frontend | useD3Lollipop.ts (1125), GeneStructurePlotWithVariants.vue (1306), ProteinDomainLollipopPlot.vue (713), GenomicVisualizationTabs.vue (748), VariantPanel.vue (671), useCytoscape.ts (603) | Split composables into `composables/d3-lollipop/`-style module directories (helpers/scales/tooltip/render/brush-zoom) keeping public API via barrel export; later unify shared tooltip/export logic across both D3 plots. |
| WP2 | Tables frontend | TablesLogs.vue (1221), TablesPhenotypes.vue (1153), GenericTable.vue (923), TablesEntities.vue (843), TablesGenes.vue (782), ApprovalTableView.vue (689) | Extract composables (`useLogDetailDrawer`, filter-state composables), child components (delete modal, phenotype filter toolbar), reuse existing `useTableData`/`useTableMethods`/small components. |
| WP3 | Analyses components | AnalyseGeneClusters.vue (1270), NetworkVisualization.vue (1218), PubtatorNDDGenes.vue (1163), PublicationsNDDTable.vue (1059), PubtatorNDDTable.vue (945), AnalysesCurationUpset.vue (748), AnalysesPhenotypeClusters.vue (709), AnalysesCurationComparisonsTable.vue (672) | Per #346: separate data normalization, rendering setup, export/download, and UI state into composables/modules. |
| WP4 | NDDScore + LLM frontend | NddScoreGeneTable.vue (1156), ManageLLM.vue (938), NddScoreGeneDetail.vue (750), ManageNDDScore.vue (738), LlmSummaryCard.vue (706) | Same table/composable extraction patterns as WP2; preserve "ML prediction, not curated evidence" copy invariants. |
| WP5 | Curation views (high risk) | ManageReReview.vue (1579), ApproveUser.vue (842), ApproveReview.vue (841), EntityView.vue (811), BatchCriteriaForm.vue (747), CreateEntity.vue (637) | Last among frontend WPs; follow the proven `useModifyEntityWorkflows` thin-shell pattern from #36. |
| WP6 | Admin views | ManageBackups.vue (1115), ManageOntology.vue (825), ManageAnnotations.vue (690), ManageUser.vue (675), ManagePubtator.vue (638) | Extract job-polling/upload/confirm-modal composables; reuse `useAsyncJob`. |
| WP7 | API endpoints | publication_endpoints.R (1234), user_endpoints.R (1128), admin_endpoints.R (1084), jobs_endpoints.R (1011), re_review_endpoints.R (856), entity_endpoints.R (848), statistics_endpoints.R (782), llm_admin_endpoints.R (733), backup_endpoints.R (630) | Established pattern: extract to `api/functions/*-endpoint-helpers.R` (registered in `load_modules.R`) and `svc_`-prefixed services; pair with `test-unit-*-endpoint-helpers.R`. Never split mounted files; keep `mount_endpoint()` wiring untouched. |
| WP8 | API services/functions | entity-service.R (1063), omim-functions.R (971), comparisons-functions.R (967), re-review-service.R (929), llm-judge.R (920), async-job-handlers.R (912), response-helpers.R (860), endpoint-functions.R (860), nddscore-import.R (854), llm-cache-repository.R (762), logging-repository.R (744), migration-runner.R (718), async-job-repository.R (638), llm-service.R (610), llm-batch-generator.R (604) | Split by cohesive domain (e.g. async-job-handlers per job family); respect source order and `svc_` prefix invariants; worker-executed code changes require worker restart in verification. |
| WP9 | DB prep scripts | C_Rcommands_set-table-connections.R (791), 11_Rcommands_..._comparisons.R (636) | Likely documented exceptions per AGENTS.md (data-prep/migration-adjacent); decide per file, keep `ndd_entity_view` mirror invariant with migration 026. |

## Sprint plan

Each sprint is one PR. Definition of done per sprint: behavior preserved; baseline
entries only move down; `make code-quality-audit` passes; targeted checks pass
(`make lint-app` / `lint-api`, `npm run type-check`, targeted Vitest/R tests);
baseline updated via `--write-baseline`.

| Sprint | Scope | Expected baseline effect |
|--------|-------|--------------------------|
| **S1 (now)** | WP0 ratchet tightening + WP1: split `useD3Lollipop.ts` into `composables/d3-lollipop/` modules + WP2: extract `TablesLogs.vue` delete-modal component & detail-drawer composable | −3 entries (WP0), useD3Lollipop and TablesLogs under or near ceiling; ~700 lines stale headroom removed |
| S2 | WP7: `publication_endpoints.R` helper extraction (~190 lines) into `publication-endpoint-helpers.R` + unit tests | 1234 → ~1040 |
| S3 | WP7: `user_endpoints.R` (~105 lines) via `user-endpoint-helpers.R` + `user-service.R` extensions | 1128 → ~1020 |
| S4 | WP2: `TablesPhenotypes.vue` (phenotype filter toolbar + composable), `GenericTable.vue` | both under ~900 |
| S5 | WP1: `GeneStructurePlotWithVariants.vue` reusing shared D3 tooltip/export modules from S1 | 1306 → under ~900 |
| S6 | WP5: `ManageReReview.vue` thin-shell decomposition (after patterns proven) | 1579 → stepwise |
| S7+ | Remaining WPs in order WP3 → WP4 → WP6 → WP8 → WP9, 1–3 files per sprint | continuous |

Sprint 1 details (per Explore-agent findings):

- **useD3Lollipop.ts → `app/src/composables/d3-lollipop/`**: `lollipop-helpers.ts`
  (constants + pure visibility/opacity/radius helpers), `lollipop-tooltip.ts`,
  `lollipop-render.ts`, `lollipop-brush-zoom.ts`, slimmed `useD3Lollipop.ts`, and an
  `index.ts` barrel. Public API (`useD3Lollipop`, `LollipopOptions`, `D3LollipopState`,
  `PlotMargin`) unchanged; `composables/index.ts` re-export path updated only
  internally. Single consumer: `ProteinDomainLollipopPlot.vue`. Add a small unit test
  for the pure helpers (none exist today).
- **TablesLogs.vue**: extract the delete-confirmation modal as a child component and
  the log-detail-drawer navigation state as a composable; move `normalizeSelectOptions`
  into `logTableFormatters.ts`-adjacent utility. Existing `TablesLogs.spec.ts` (MSW)
  must keep passing unchanged.

## Risk & error handling

- Every extraction is import-preserving: consumers keep importing from the same
  public path (`@/composables`, same component file name).
- R invariants guarded: no endpoint file splits, `svc_` prefixes kept, helpers
  registered in `load_modules.R`, source order untouched.
- If a sprint's verification fails, the sprint PR shrinks in scope rather than
  weakening checks; the baseline is never raised.
- Curation-critical files (WP5) deliberately last among frontend WPs.

## Testing strategy

- Per sprint: smallest useful check first (targeted Vitest spec / `testthat::test_file`),
  then `make code-quality-audit`, `make lint-app`/`lint-api`, `cd app && npm run
  type-check`, and `make pre-commit` before PR.
- New pure-function modules get small unit tests when extraction creates a testable
  seam that previously had none (e.g. d3-lollipop helpers).

## Tracking

- One GitHub sub-issue per WP1–WP9 (WP0 folds into Sprint 1's PR), each listing its
  files, strategy, and definition of done; all referencing #346. This satisfies the
  #346 acceptance criterion that the top 10 oversized files have planned sub-issues
  or direct reductions.
