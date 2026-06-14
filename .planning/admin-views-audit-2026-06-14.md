# SysNDD Admin Views — Audit & Scorecard (2026-06-14)

Audit of all 11 Administrator-guarded views. Method: 11 parallel static code-review
agents (Vue + composables + typed client + R endpoint per view), live Playwright
walkthrough authenticated as `pw_admin` on the local dev stack (Traefik `:80`),
runtime console/network capture, and production Lighthouse on the public shell.

Perf note: production public shell Lighthouse = **100 / 100 / 100 / 100**
(FCP/LCP 0.5s, TBT 0ms, CLS 0.002). The local dev server (Vite, unbundled,
150 module requests) is **not** representative for perf; per-view perf signals
below use build-agnostic metrics (API-call count, DOM size, render patterns).

## Scorecard (overall /10)

| View | Perf | Funct | UX | A11y | Code | **Overall** | Runtime |
|------|:----:|:----:|:--:|:----:|:----:|:-----------:|---------|
| ManageUser        | 8 | 8 | 8 | 7 | 7 | **8** | clean |
| ManageMetadata    | 9 | 7 | 8 | 7 | 9 | **8** | ❌ TypeError |
| ManageAbout       | 8 | 6 | 8 | 6 | 8 | **7** | clean |
| ViewLogs          | 8 | 7 | 8 | 6 | 6 | **7** | clean |
| ManageBackups     | 8 | 6 | 8 | 8 | 6 | **7** | clean |
| ManageAnnotations | 6 | 8 | 8 | 7 | 8 | **7** | clean |
| ManageNDDScore    | 8 | 6 | 8 | 6 | 9 | **7** | clean |
| ManageOntology    | 7 | 6 | 7 | 6 | 5 | **6** | clean |
| AdminStatistics   | 7 | 6 | 7 | 5 | 5 | **6** | clean |
| ManageLLM         | 8 | 5 | 8 | 6 | 6 | **6** | ❌ 500 + cards=0 |
| ManagePubtator    | 8 | 7 | 8 | 5 | 5 | **6** | clean |

## Confirmed runtime bugs (verified live)

1. **ManageLLM — `GET /api/llm/config` → 500** (Configuration tab data fails to load).
   Root cause: `llm_admin_runtime_config()` and `.llm_model_runtime_config()` call
   `exists("dw", envir=.GlobalEnv, inherits=FALSE)` / `get(...)`. In the live runtime a
   package masks base `exists`/`get` so `inherits=` is rejected
   (`unused arguments (envir, inherits)`). `filters.R:67` uses `exists(..., envir=)`
   *without* `inherits` and works → confirms `inherits=` is the trigger.
   Fix: `base::exists` / `base::get` at:
   - `api/endpoints/llm_admin_endpoints.R:11-12`
   - `api/functions/llm-model-config.R:26-27, 43-44`
   - `api/functions/analyses-functions.R:25` (STRING cache; defensive)
   Also: the RFC9457 500 handler doesn't log the underlying error to stdout (ops gap).

2. **ManageLLM — cache per-type cards always render 0.** `LlmCacheManager.vue` reads
   `stats.by_type.functional.count/.validated/.pending` but the API returns
   `by_type:{functional:13,phenotype:5}` (scalars) + global `by_status:{pending,validated,rejected}`.
   Cards show 0 while the table correctly shows 18 summaries.

3. **ManageMetadata — `TypeError: field.replace is not a function`** in `humanizeLabel`.
   Catalog returns Plumber 1-element arrays (`pk=["modifier_id"]`, `slug=["modifier"]`);
   `vocab.pk` isn't unwrapped before `humanizeLabel`, so `.replace` runs on an array.
   Fix: unwrap descriptor scalars in `api/metadata.ts` (or normalize) + defensive `humanizeLabel`.

4. **ManageLLM — `/api/llm/logs` → 500** on some pagination params (input-handling; lower priority).

## Systemic findings (cross-cutting)

- **Typed-client bypass + dead clients.** Raw `axios` / `apiClient.raw` with hand-built
  `${VITE_API_URL}/api/...` URLs while a fully-implemented typed client exists unused:
  ManageUser (composables), ManageOntology, ManageBackups (composables),
  ManageAnnotations (`useAnnotationsApi`), AdminStatistics (composables),
  ManageLLM (`useLlmAdmin` + dead `llm_admin.ts`), ManagePubtator (`usePubtatorAdmin`).
  Violates AGENTS.md "typed clients only". Has already caused type drift
  (e.g. `updated_count` vs `updated`).
- **Dropped problem+json detail.** Error catches read `e.response.data.message||.error`
  instead of `extractApiErrorMessage` (RFC9457 `detail`/`title`): ManageUser, ManageBackups,
  ViewLogs, ManageNDDScore, AdminStatistics, ManagePubtator. (ManageMetadata is the model.)
- **A11y gaps.** No `aria-live`/`role=status` on progress/loading regions (most job views);
  incomplete ARIA tab pattern — `role=tabpanel` without `role=tablist`/`tab` (ManageLLM, ManageMetadata);
  icon-only buttons relying on `title` only; canvas charts have no table/`aria` fallback (AdminStatistics);
  click-only rows without keyboard handlers (ViewLogs).
- **Missing confirmations on heavy/irreversible ops.** ManageAnnotations (ontology update,
  force-apply, comparisons refresh, refresh-all), ManageOntology (anchored-vocab edit).
- **Server-side write hardening.** `api/endpoints/ontology_endpoints.R:252-263` interpolates
  client-supplied column names into the UPDATE SET clause with no allowlist (post-auth
  injection / mass-assignment surface). Contrast with `validate_query_column` discipline.
- **Native dialogs.** `window.prompt()` (ManageUser presets), `confirm()` (ViewLogs export,
  ManageBackups) instead of app modal language.
- **Generic admin `<title>`.** Most admin views render "SysNDD |" not a view-specific title
  (ViewLogs does it right: "Logging | SysNDD").
- **File-size over ceiling.** `TablesLogs.vue` 1160 lines (≈2× the 600 soft ceiling);
  `ManageOntology.vue` 721; `PubtatorNDDTable.vue` 929 / `PubtatorNDDGenes.vue` 900 (siblings).
- **Stale LLM cost/model copy.** Cost estimate hardcodes "Gemini 2.0 Flash" pricing while the
  default model is `gemini-3.5-flash`; pricing not centralized with `llm-model-config.R`.

## Fixes applied & verified (2026-06-14)

All verified live (Playwright + API) and via gates: vitest (affected specs), whole-app
`type-check`, eslint (changed files), R `lintr` (changed files), new R static guard.

1. **ManageLLM `/api/llm/config` 500 → 200.** `base::exists`/`base::get` at
   `llm_admin_endpoints.R`, `llm-model-config.R` (×2), `analyses-functions.R` (defensive).
   New guard `api/tests/testthat/test-unit-base-exists-get-guard.R`. Verified: Configuration
   tab renders (model `gemini-3.5-flash`, rate limits), 0 console errors.
2. **ManageLLM cache cards 0 → real.** `get_cache_statistics()` now returns nested
   `by_type.{functional,phenotype} = {count,validated,pending,rejected}` (matches the
   pre-existing `CacheTypeStats` frontend contract). Verified: cards show 13/13/0 and 5/1/4.
3. **ManageMetadata `field.replace` TypeError fixed.** `api/metadata.ts` now normalises
   Plumber array-wrapped descriptor scalars (`fetchMetadataCatalog`/`fetchMetadataRows`);
   `humanizeLabel` made defensive. New spec. Verified: page + tab switching + anchored
   tier all work, 0 console errors.
4. **Ontology UPDATE column allowlist (security).** `ontology_endpoints.R` (`PUT
   variant/update`) now allowlists field names against real table columns → 400 on any
   un-allowlisted/injected identifier. Verified: injected `evil_col` → 400; legit field → 200.

## Path to >9/10 (themes — remaining)

- T1 Correctness: fix the 4 runtime bugs + ontology UPDATE allowlist + log the 500 cause.
- T2 Consistency: migrate admin data access onto the existing typed clients; delete dead clients.
- T3 Resilience: route all admin error catches through `extractApiErrorMessage`.
- T4 Accessibility: `aria-live` on job/progress regions, complete ARIA tab pattern,
  chart fallbacks, keyboard-operable rows, icon-button labels.
- T5 Polish: replace native dialogs with modals; per-view titles; confirmations on heavy ops;
  design-token cleanups; split oversized files.
