# Project State: SysNDD

**Last updated:** 2026-02-01
**Current milestone:** v10.0 Data Quality & AI Insights

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-31)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v10.0 — Bug fixes, Publications/Pubtator improvements, LLM cluster summaries

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 64 (LLM Admin Dashboard) - COMPLETE
**Plan:** 4/4 complete
**Status:** All plans complete with post-implementation bug fixes
**Progress:** v10.0 [████████████████████] 12/12 phases (100%)

**Last completed:** Phase 64-04 - UI Components + Bug Fixes
**Last activity:** 2026-02-01 — LLM Admin Dashboard complete with UI testing and bug fixes
**Next plan:** None - Milestone v10.0 complete, ready for verification

---

## Quick Tasks

| ID | Name | Status | Summary |
|----|------|--------|---------|
| 001 | LLM Benchmark Test Scripts | Complete | test-llm-benchmark.R with Phase 63 ground truth |
| 002 | PubTator Admin API Fix | Complete | Fix auto_unbox serialization, frontend array access, ManageAnnotations stats |

---

## Milestone v10.0 Roadmap

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 55 | Bug Fixes | BUG-01 to BUG-08 | ✓ Complete |
| 56 | Variant Correlations & Publications | VCOR-01, VCOR-02, PUB-01 to PUB-04 | ✓ Complete |
| 56.1 | Admin Publication Bulk Management | PUB-ADMIN-01, PUB-ADMIN-02, PUB-ADMIN-03 | ✓ Complete |
| 57 | Pubtator Improvements | PUBT-01 to PUBT-06 | ✓ Complete |
| 58 | LLM Foundation | LLM-01 to LLM-04 | ✓ Complete |
| 57.1 | PubTator Async Repository Refactor | SQL injection fix | ✓ Complete |
| 59 | LLM Batch, Caching & Validation | LLM-05, LLM-06, LLM-09, LLM-10 | ✓ Complete |
| 60 | LLM Display | LLM-07, LLM-08, LLM-12 | ✓ Complete |
| 61 | ~~LLM Validation~~ | Merged into Phase 59 | N/A |
| 62 | Admin & Infrastructure | ADMIN-01, INFRA-01 | ✓ Complete |
| 63 | LLM Pipeline Overhaul | LLM-FIX-01 to LLM-FIX-07 | ✓ Complete |
| 64 | LLM Admin Dashboard | LLM-ADMIN-01 to LLM-ADMIN-10 | ✓ Complete |

**Phases:** 10 active (55-64, Phase 61 merged into 59)
**Requirements:** 53 mapped (100% coverage)

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 265
- Milestones shipped: 10 (v1-v10)
- Phases completed: 60

**By Milestone:**

| Milestone | Phases | Plans | Shipped |
|-----------|--------|-------|---------|
| v1 Developer Experience | 1-5 | 19 | 2026-01-21 |
| v2 Docker Infrastructure | 6-9 | 8 | 2026-01-22 |
| v3 Frontend Modernization | 10-17 | 53 | 2026-01-23 |
| v4 Backend Overhaul | 18-24 | 42 | 2026-01-24 |
| v5 Analysis Modernization | 25-27 | 16 | 2026-01-25 |
| v6 Admin Panel Modernization | 28-33 | 20 | 2026-01-26 |
| v7 Curation Workflow Modernization | 34-39 | 21 | 2026-01-27 |
| v8 Gene Page & Genomic Data | 40-46 | 25 | 2026-01-29 |
| v9 Production Readiness | 47-54 | 16 | 2026-01-31 |
| v10 Data Quality & AI Insights | 55-63 | 25 | 2026-02-01 |

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 687 + 11 E2E | 20.3% coverage, 24 integration + 53 migration + 11 E2E tests |
| **Frontend Tests** | 144 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 29 | 7 original + 7 admin + 10 curation + 5 gene page |
| **Migrations** | 8 files + runner | api/functions/migration-runner.R ready, llm_prompt_templates added |
| **Lintr Issues** | 0 | From 1,240 in v4 |
| **ESLint Issues** | 0 | 240 errors fixed in v7 |
| **Bundle Size** | ~600 KB gzipped | Vite 7.3.1, 164ms dev startup |

---

## Accumulated Context

### Phase Dependencies (v10.0)

```
Phase 55 (Bug Fixes)
    |
    +---------------------------+
    |                           |
    v                           v
Phase 56 (Variant & Pubs)  Phase 58 (LLM Foundation) ✓
    |                           |
    v                           v
Phase 57 (Pubtator) ✓      Phase 59 (LLM Batch, Caching & Validation)
                                |
                                v
                           Phase 60 (LLM Display)

Phase 61 merged into Phase 59 (LLM-as-judge in pipeline)
Phase 62 (Admin & Infra) can run parallel after Phase 55
```

### Research Findings (from research/SUMMARY.md)

- **Use ellmer >= 0.4.0** for Gemini API (not gemini.R)
- **Entity validation mandatory** — LLMs invent plausible gene names
- **LLM-as-judge has 64-68% agreement** — use rule-based validators as primary
- **easyPubMed deprecated functions** retiring 2026 — update to epm_* API
- **Existing patterns cover 80%** — external-proxy, mirai jobs, pubtator caching

### Key Technical Notes

1. **LLM integration point:** New `api/functions/llm-service.R` following external-proxy pattern
2. **Summary storage:** New `llm_cluster_summary_cache` table following pubtator cache pattern
3. **Batch generation:** Follow HGNC update job pattern via mirai
4. **Summary display:** Extend AnalyseGeneClusters.vue and AnalysesPhenotypeClusters.vue
5. **Admin panel:** Follow ManageAnnotations.vue pattern

### Decisions from Phase 55

**Plan 01 (Entity Bugs):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Created atomic function but kept legacy endpoint | Refactoring /create endpoint would be high-risk; provide function for future use | entity_create_with_review_status() available for future migration |
| 2026-01-31 | Focus on observability over enforcement | Logging provides immediate debugging value without breaking existing flow | PARTIAL CREATION warnings detect orphaned entities in production |
| 2026-01-31 | Used db_with_transaction pattern | Reuse existing battle-tested transaction infrastructure | Consistent error handling and rollback across all atomic operations |

**Plan 02 (Curation Bugs):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Self-service authorization for contributions endpoint | Users should view own data regardless of role | Viewer users can access /user/{id}/contributions for their own ID |
| 2026-01-31 | Warning logging vs hard validation for PMID deletion | Root cause in frontend; blocking would break workflows | Operations continue but losses are detected via logs |
| 2026-01-31 | Floor vs ceiling for time aggregation | Ceiling shifts dates to next period incorrectly | Entities-over-time chart now aligns with database dates |
| 2026-01-31 | Explicit field protection in repository updates | Preserve attribution (review_user_id should never change) | review_update explicitly removes review_user_id from updates |
| 2026-01-31 | Close disease rename approval as wontfix | Current behavior is functional; approval workflow adds complexity without proportional benefit | Issue #41 closed, infrastructure reverted |

### Decisions from Phase 56

**Plan 02 (Publications Enhancements):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Combined Tasks 1 and 2 | Initialization guards are integral to the caching implementation pattern | Cleaner implementation, single coherent commit |
| 2026-01-31 | Used D3 rollups for time aggregation | Built-in D3 function, cleaner than manual grouping | Consistent with D3 patterns elsewhere in codebase |
| 2026-01-31 | Added YTD label to current year metric | "Publications [year] (YTD)" clarifies it's year-to-date | Clearer user understanding of metric scope |

**Additional Bug Fixes (Post-Plan):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Replace YoY Growth with 5-Year Average | -100% was misleading (comparing 2026 with 0 pubs to 2024) | Shows "583/yr" - more meaningful metric |
| 2026-01-31 | API-only filtering (no client-side) | User requirement: "no client side filter EVER! all API!" | Single minCount variable, fetchStats on change |
| 2026-01-31 | Convert API params to integers | Plumber passes query params as strings; numeric comparison failed | `as.integer()` ensures correct filtering |
| 2026-01-31 | Smart tooltip edge positioning | Tooltips cut off at container edges | Flips left/right based on edge proximity |
| 2026-01-31 | Fetch actual newest publication date | Stats showed aggregated year bucket (2025-01-01) not actual date | Separate API call shows "2025-07-14" |

### Decisions from Phase 57

**Plan 01 (Stats Fix and API Enhancement):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | pmids as comma-separated string | Excel export compatibility - arrays don't export well to XLSX format | pmids field is a string, not JSON array |
| 2026-01-31 | Default sort: -is_novel,oldest_pub_date | Surface coverage gaps (novel genes) first, then prioritize long-overlooked genes | Novel genes appear first in API response |
| 2026-01-31 | Fetch novel count via API filter | Consistent with other stats, avoids downloading all data to client | Admin panel uses filter=is_novel==1 |

**Plan 02 (Genes Table Enhancements):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Emit pattern for novel count | Consistent with must_haves.key_links, simpler than provide/inject | Parent view listens for @novel-count emit |
| 2026-01-31 | Truncate PMIDs to 5 chips | Keeps table readable, overflow badge shows more exist | Row expansion shows full list |
| 2026-01-31 | Helper functions for filter content | TypeScript type safety - content can be string or string[] | Proper binding in template |
| 2026-01-31 | Fetch is_novel in Stats view | Accurate summary card counts without separate API call | Single fetch provides chart + card data |

### Decisions from Phase 56.1

**Plan 01 (Publication Bulk Management API):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | 350ms delay between PubMed requests | NCBI limit is 3 req/sec without API key; 350ms = 2.86 req/sec gives safety margin | Rate limiting prevents API blocks |
| 2026-01-31 | Per-PMID error handling | Bulk operations should complete for all valid items even if some fail | One bad PMID doesn't stop entire refresh |
| 2026-01-31 | Return not_found status | Distinguish between "PMID not in database" vs "PubMed API error" | Clearer error reporting for admins |

**Handoff notes:**

1. **v10.0 Roadmap Created (2026-01-31):**
   - 8 phases (55-62), 34 requirements
   - Bug fixes first (Phase 55), then features
   - LLM phases (58-61) form sequential chain
   - Phase 62 can run parallel after Phase 55

2. **Phase 55 Bug Status:**
   - ✓ #122: EIF2AK2 publication update incomplete (BUG-01) - Logging added in 55-01
   - ✓ #115: GAP43 entity not visible (BUG-02) - Atomic function prevents orphaning in 55-01
   - ✓ #114: MEF2C entity updating issues (BUG-03) - Logging detects partial updates in 55-01
   - ✓ Viewer profile / auto-logout (BUG-04) - Fixed in 55-02
   - ✓ PMID deletion during re-review (BUG-05) - Fixed: Frontend now merges original publications with additions in useReviewForm.ts
   - ✓ #44: Entities over time counts incorrect (BUG-06) - Fixed: (1) floor aggregation, (2) removed inheritance filter to match homepage, (3) lessThan with next month for full month inclusion, (4) same NDD filter across all views
   - ✓ #41: Disease renaming bypasses approval (BUG-07) - Closed as wontfix, current behavior is intentional
   - ✓ Re-reviewer identity lost (BUG-08) - Fixed in 55-02

3. **LLM Implementation Notes:**
   - Add ellmer >= 0.4.0 to renv
   - GEMINI_API_KEY in environment variable
   - Structured JSON output with entity validation
   - Batch pre-generation via mirai (no real-time generation)

4. **Phase 57 Complete (Pubtator):**
   - ✓ PUBT-01: Stats page fixed (Plan 01)
   - ✓ PUBT-02: Gene prioritization display (Plan 02)
   - ✓ PUBT-03: Novel gene highlighting (Plan 02)
   - ✓ PUBT-04: Gene-literature exploration (Plan 02)
   - ✓ PUBT-05: Excel export (Plan 02)
   - ✓ PUBT-06: Documentation (Plans 01 + 02)

5. **Phase 56.1 Complete (Admin Publication Management):**
   - ✓ Plan 01: API endpoints complete
     - GET /publications/stats for publication statistics
     - POST /admin/publications/refresh for bulk PubMed refresh
   - ✓ Plan 02: ManageAnnotations Publications Refresh UI
     - Publication Metadata Refresh section with stats badges
     - Refresh All Publications button with async job tracking
     - Real-time progress bar and job history integration

6. **Phase 58 Complete (LLM Foundation):**
   - ✓ Plan 01: LLM Infrastructure Setup
     - Migration 006: llm_cluster_summary_cache and llm_generation_log tables
     - api/functions/llm-cache-repository.R: hash generation, cache lookup/storage, logging
     - api/functions/llm-service.R: Gemini API client with ellmer, structured output types
     - ellmer 0.4.0 and coro 1.1.0 added to renv.lock
   - ✓ Plan 02: Entity Validation Pipeline
     - api/functions/llm-validation.R: gene symbol and pathway validation
     - Strict validation: any invalid gene rejects entire summary
     - Integrated into generate_cluster_summary() with retry loop
     - calculate_derived_confidence() for objective confidence scoring
     - 23 unit tests in test-llm-validation.R

### Decisions from Phase 58

**Plan 01 (LLM Infrastructure Setup):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Multi-valued JSON index outside stored procedure | MySQL limitation with CAST(...AS...ARRAY) in procedures | idx_tags applied via prepared statement |
| 2026-01-31 | Default model gemini-2.0-flash | Preview models (gemini-3-pro-preview) may be unstable | Production stability over cutting-edge features |
| 2026-01-31 | Conservative rate limit (30 RPM) | Half of Paid Tier 1 limit to avoid 429 errors | Safe margin for rate limiting |

**Plan 02 (Entity Validation Pipeline):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | STRICT validation mode | Any invalid gene symbol should reject entire summary | Prevents hallucinated gene names in database |
| 2026-01-31 | Common word filtering | DNA, RNA, ATP, HPO, OMIM etc. are not gene symbols | Reduces false positives in gene extraction |
| 2026-01-31 | Case-insensitive pathway matching | Pathways may have varying capitalization | More flexible validation without losing accuracy |
| 2026-01-31 | Derived confidence separate from LLM confidence | LLM self-assessment may be unreliable | Objective metric based on FDR values and term counts |

### Decisions from Phase 57.1

**Plan 01 (PubTator Async Parameterized Queries):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Single commit for all tasks | Tasks are interdependent - partial refactoring would break the function | Atomic change ensures code is always in working state |
| 2026-01-31 | Preserve manual transaction handling | db_with_transaction uses pool, mirai daemons need direct connections | dbBegin/dbCommit/dbRollback still used, only query execution changed |
| 2026-01-31 | Use NA directly in params | DBI's dbBind() handles NA to NULL conversion automatically | Simpler code, no manual ifelse(is.na(...), "NULL", ...) needed |

### Decisions from Phase 59

**Plan 01 (Batch LLM Generation Orchestrator):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Graceful failure for individual clusters | Failed clusters should not stop entire batch - log and continue | Batch completes even with some failures |
| 2026-01-31 | Job chaining in promise callback (main process) | Clustering completes in daemon, promise callback fires in main process where create_job() is safe | Clean separation - no mirai-in-mirai issues |
| 2026-01-31 | Cache-first lookup for each cluster | Avoid regenerating summaries when cluster composition hasn't changed | Fast re-runs, cost savings on API calls |

**Plan 02 (LLM-as-judge Validation Pipeline):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Use same model for judging as generation | Consistency in evaluation approach | All judgments use gemini-2.0-flash by default |
| 2026-01-31 | Graceful degradation on judge failure | Prefer usability over perfection | Failed judge -> low_confidence (pending) instead of hard error |
| 2026-01-31 | Judge function handles caching | Simplify batch executor logic | Reduced duplicate cache save logic in batch executor |
| 2026-01-31 | Store judge metadata in summary JSON | Enable judge calibration analysis | llm_judge_verdict and llm_judge_reasoning available for debugging |

### Decisions from Phase 60

**Plan 01 (LLM Display):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Dockerfile R version 4.4.3 | renv.lock specifies 4.4.3; P3M binaries must match | ellmer/S7 packages load correctly |
| 2026-02-01 | Use derived_confidence for display | LLM self-assessment unreliable; FDR-based scoring is objective | More trustworthy confidence indicators |
| 2026-02-01 | Hide summary for multi-cluster | Summaries are per-cluster; combined view would be confusing | Clean UX when viewing all clusters |
| 2026-02-01 | 404 responses handled silently | No summary is expected for new clusters; error toast annoying | Better UX for clusters without summaries |

**Phase 60 Complete (LLM Display):**
- ✓ Plan 01: LLM summary display infrastructure
  - Dockerfile R version fixed for ellmer compatibility
  - GET /api/analysis/functional_cluster_summary endpoint
  - GET /api/analysis/phenotype_cluster_summary endpoint
  - LlmSummaryCard.vue reusable component (271 lines)
  - Integration in AnalyseGeneClusters.vue and AnalysesPhenotypeClusters.vue

---

### Decisions from Phase 62

**Plan 01 (Comparisons Data Refresh):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Store source URLs in database config table | Admin can edit URLs without code deployment when external sources change | comparisons_config table holds all source URLs |
| 2026-02-01 | Local HGNC symbol lookup only (no API calls in daemon) | Rate limiting and reliability - use existing non_alt_loci_set table | Faster refresh, no network dependency |
| 2026-02-01 | All-or-nothing refresh pattern | Partial updates would leave inconsistent data state | Database transaction ensures atomic updates |

**Plan 02 (Documentation Migration):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Simplified 04-database-structure to static | Original had R code for dynamic tables; removes R dependency from CI | Simpler workflow, no R setup needed |
| 2026-02-01 | Used Quarto fenced divs for images | Cleaner than raw HTML div tags | Quarto-native syntax |
| 2026-02-01 | Removed PR builds | Per CONTEXT.md decision | Push to master only triggers deployment |

**Phase 62 Complete (Admin & Infrastructure):**
- ✓ Plan 01: Comparisons Data Refresh Infrastructure
  - Migration 007: comparisons_config and comparisons_metadata tables
  - api/functions/comparisons-functions.R: 944 lines of parsing logic
  - api/functions/comparisons-sources.R: source config management
  - POST /api/jobs/comparisons_update/submit endpoint
  - GET /api/comparisons/metadata endpoint
  - ManageAnnotations.vue: Comparisons Data Refresh section
  - CurationComparisons.vue: Dynamic metadata display
- ✓ Plan 02: Documentation Migration to Quarto
  - documentation/_quarto.yml: Website config with navbar, sidebar, footer
  - 9 qmd files converted from Rmd
  - .github/workflows/gh-pages.yml: Quarto + actions/deploy-pages
  - Old bookdown files removed

---

## Session Continuity

**Last session:** 2026-02-01
**Stopped at:** Phase 64-04 complete with UI testing and bug fixes
**Next action:** Milestone v10.0 verification or /gsd:complete-milestone
**Resume file:** None

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 001 | Create reusable LLM prompt benchmark test scripts | 2026-02-01 | 0da5e633 | [001-llm-benchmark-test-scripts](./quick/001-llm-benchmark-test-scripts/) |
| 002 | PubTator Admin API serialization + frontend fix | 2026-02-01 | 80ca7049..8ccf36d9 | [002-pubtator-admin-fix](./quick/002-pubtator-admin-fix/) |

### Roadmap Evolution
- Phase 63 added: LLM Pipeline Overhaul (fix cascading failures from Phases 58-60)
- Plan 63-01 complete: Docker ICU fix, debug logging, Gemini model name correction
- Plan 63-02 complete: DBI NULL to NA fix, ellmer API fix, pipeline verified working
- Plan 63-03 complete: Playwright MCP browser verification, all LLM-FIX requirements verified
- Phase 64 added: LLM Admin Dashboard (admin UI for LLM config, prompts, cache, logs)

### Decisions from Phase 63 Plan 02

**Plan 02 (LLM Pipeline Verification):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Convert NULL to NA for DBI params | DBI::dbBind requires length 1; NULL has length 0, NA has length 1 | All optional params now bind correctly |
| 2026-02-01 | Pass prompt as unnamed arg to ellmer | ellmer chat_structured uses `...` which must be unnamed | LLM calls succeed |
| 2026-02-01 | Load llm-batch-generator at end of job-manager | trigger_llm_batch_generation calls create_job; must define create_job first | Function resolution works |
| 2026-02-01 | Build db_config for daemon | Mirai daemons lack main process pool access | Daemon can connect to database |

### Decisions from Phase 63

**Plan 01 (Foundation Layer Fixes):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Use noble P3M URL instead of jammy | rocker/r-ver:4.4.3 uses Ubuntu 24.04 with ICU 74, not jammy with ICU 70 | Docker builds complete without ICU errors |
| 2026-02-01 | Add message() logging to db-helpers.R | message() writes immediately to stdout; helps debug daemon issues | Entry-point tracing available in container logs |
| 2026-02-01 | Change default model to gemini-2.0-flash | gemini-3-pro-preview is not a valid Gemini model name | Gemini API calls should succeed |

**Plan 03 (LLM Display Verification):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Hash-based invalidation is correct behavior | Cluster composition changes should invalidate old summaries to avoid stale data | Old summaries don't display for changed clusters |
| 2026-02-01 | 404 responses handled silently | No summary is expected for new/changed clusters; error toast annoying | LlmSummaryCard hides gracefully when no summary exists |
| 2026-02-01 | Playwright MCP for browser verification | Automated UI testing provides consistent verification evidence | Screenshots captured as verification artifacts |

**Phase 63 Complete (LLM Pipeline Overhaul):**
- ✓ Plan 01: Foundation Layer Fixes
  - Docker noble P3M URL for ICU 74 compatibility
  - Debug logging in db-helpers.R
  - Gemini model name correction (gemini-2.0-flash)
- ✓ Plan 02: LLM Pipeline Verification
  - DBI NULL to NA fix for parameter binding
  - ellmer chat_structured API call syntax fix
  - Database connection handling in daemons
- ✓ Plan 03: LLM Display Verification
  - Playwright MCP browser automation verification
  - All 7 LLM-FIX requirements verified
  - Hash-based cache invalidation confirmed working
  - See: 63-VERIFICATION.md for full verification report

---

### Decisions from Phase 64

**Plan 01 (LLM Admin Backend API):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Session-only model changes via Sys.setenv() | No need for DB persistence; model changes are temporary | Model resets on API restart |
| 2026-02-01 | Prompt templates are read-only (code-defined) | No llm_prompt_templates table exists yet | PUT /prompts/:type logs but doesn't persist |
| 2026-02-01 | Cost estimation uses Gemini 2.0 Flash pricing | $0.075/1M input + $0.30/1M output is standard pricing | Estimates may need adjustment for other models |

**Phase 64 Complete (LLM Admin Dashboard):**
- ✓ Plan 01: LLM Admin Backend API
  - api/endpoints/llm_admin_endpoints.R: 10 admin endpoints
  - api/functions/llm-cache-repository.R: 4 new admin query functions
  - api/start_sysndd_api.R: /api/llm mount added
- ✓ Plan 02: Prompt Template Database Functions
  - db/migrations/008_add_llm_prompt_templates.sql: table + 4 seeded prompts
  - api/functions/llm-service.R: 4 new functions (get/save/default/all)
- ✓ Plan 03: Frontend Foundation
  - app/src/types/llm.ts: 16 TypeScript interfaces for LLM admin API
  - app/src/composables/useLlmAdmin.ts: composable with 10 API methods
  - app/src/router/routes.ts: ManageLLM route with Administrator guard
- ✓ Plan 04: UI Components + Bug Fixes
  - app/src/views/admin/ManageLLM.vue: 5-tab dashboard (Overview, Config, Prompts, Cache, Logs)
  - app/src/components/llm/LlmConfigPanel.vue: Model selection with rate limits
  - app/src/components/llm/LlmPromptEditor.vue: Prompt template editing
  - app/src/components/llm/LlmCacheManager.vue: Cache management with validation
  - app/src/components/llm/LlmLogViewer.vue: Generation log viewer
  - Bug fixes: Structured model objects from API, Plumber array unwrapping, null handling
  - See: 64-UI-TEST-REPORT.md for comprehensive test documentation

### Decisions from Phase 64 Plan 02

**Plan 02 (Prompt Template Database Functions):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | ENUM for prompt_type | Constrains to 4 valid types at database level | Invalid types rejected by DB |
| 2026-02-01 | Unique (prompt_type, version) | Prevents duplicate versions for same prompt type | Version history integrity |
| 2026-02-01 | is_active flag for versioning | Enables soft versioning - deactivate old, activate new | Version switching without data loss |
| 2026-02-01 | Seed defaults in migration | Prompts available immediately after migration | Zero-config startup |
| 2026-02-01 | Hardcoded fallback | Backward compatibility if migration hasn't run | Graceful degradation |

### Decisions from Phase 64 Plan 03

**Plan 03 (Frontend Foundation):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Use Ref<T> instead of Readonly<Ref<T>> | Vue's readonly() creates DeepReadonly conflicting with mutable array types; matches usePubtatorAdmin pattern | Simpler type inference |
| 2026-02-01 | Placeholder ManageLLM.vue for route target | Pre-existing ManageLLM.vue referenced non-existent components; Plan 64-04 handles full UI | Type-check passes, clean separation |

### Decisions from Phase 64 Plan 04

**Plan 04 (UI Components):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Return structured model objects from API | Frontend modelOptions computed property expected objects with model_id, display_name, recommended_for | Model dropdown displays correctly |
| 2026-02-01 | Add unwrapPlumberValue() helper in composable | R/Plumber wraps scalar values in single-element arrays; frontend expects primitives | Clean data binding throughout dashboard |
| 2026-02-01 | Use typeof check for nullable numbers in templates | Prevents "[object Object]" display when value is null array | RPD limit displays correctly or hides |

---

### Quick Task 002: PubTator Admin Fix

**Date:** 2026-02-01
**Issue:** PubTator admin page crashed with JavaScript errors when using Check Status or Submit Fetch Job buttons

**Root Cause:** R/plumber API endpoints returned array-wrapped values (`["value"]`) instead of scalars (`"value"`), causing:
1. `jobId.substring(0, 8)` to fail (array has no substring method)
2. `lastStatus.cached[0]` to fail when API returned scalars after partial fix

**Decisions:**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-02-01 | Add `auto_unbox=TRUE` to all PubTator endpoints | Standard JSON serialization; arrays for single values is R quirk | API returns proper JSON scalars |
| 2026-02-01 | Add `auto_unbox=TRUE` to job status endpoint | Job polling endpoint had same issue | Job progress tracking works |
| 2026-02-01 | Remove `[0]` array accesses in frontend | Frontend was inconsistent - some places expected arrays, others scalars | Consistent scalar access throughout |
| 2026-02-01 | Add type check for `cache_date` | Empty object `{}` is truthy but not a valid date string | "Invalid Date" no longer displayed |
| 2026-02-01 | Unwrap array-wrapped `meta` in ManageAnnotations | Paginated endpoints return `meta` as array; stats lookup failed | PubTator stats display in ManageAnnotations |
| 2026-02-01 | Fix route name `PubtatorNDD` → `PubtatorNDDStats` | Route `PubtatorNDD` doesn't exist; `PubtatorNDDStats` is correct | "View Pubtator Analysis" link works |

**Files Changed:**

| File | Changes |
|------|---------|
| `api/endpoints/publication_endpoints.R` | Added `auto_unbox=TRUE` to 5 endpoints (lines 712, 787, 873, 1007, 1141) |
| `api/endpoints/jobs_endpoints.R` | Added `auto_unbox=TRUE` to job status endpoint (line 934) |
| `app/src/views/admin/ManagePubtator.vue` | Removed 13 `[0]` array accesses, added cache_date type check |
| `app/src/composables/usePubtatorAdmin.ts` | Removed 2 `[0]` array accesses in cacheProgress computed |
| `app/src/views/admin/ManageAnnotations.vue` | Unwrap meta array in fetchPubtatorStats(), fix route name |

**Verification:**
- ✅ Check Status button shows cache status correctly
- ✅ Submit Fetch Job creates and tracks jobs (tested with MECP2, 2 pages → 20 publications cached)
- ✅ Job progress displays correctly (status, progress bar, elapsed time)
- ✅ Clear Cache confirmation dialog works
- ✅ Backfill Gene Symbols button enables when cache exists
- ✅ ManageAnnotations PubTator stats display (580 publications, 180 genes, 180 literature only)
- ✅ "View Pubtator Analysis" and "Manage Cache" links work
- ✅ No JavaScript console errors

**Report:** `.planning/LLM_ADMIN_TESTING_REPORT.md` (updated with fix status)

---

*State initialized: 2026-01-20*
*Last updated: 2026-02-01 — Phase 64 complete (LLM Admin Dashboard with bug fixes)*
