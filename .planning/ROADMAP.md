# Roadmap: SysNDD Developer Experience

## Milestones

- ✅ **v1.0 Developer Experience** - Phases 1-5 (shipped 2026-01-21)
- ✅ **v2.0 Docker Infrastructure** - Phases 6-9 (shipped 2026-01-22)
- ✅ **v3.0 Frontend Modernization** - Phases 10-17 (shipped 2026-01-23)
- ✅ **v4.0 Backend Overhaul** - Phases 18-24 (shipped 2026-01-24)
- ✅ **v5.0 Analysis Modernization** - Phases 25-27 (shipped 2026-01-25)
- ✅ **v6.0 Admin Panel** - Phases 28-33 (shipped 2026-01-26)
- ✅ **v7.0 Curation Workflows** - Phases 34-39 (shipped 2026-01-27)
- ✅ **v8.0 Gene Page** - Phases 40-46 (shipped 2026-01-29)
- ✅ **v9.0 Production Readiness** - Phases 47-54 (shipped 2026-01-31)
- ✅ **v10.0 Data Quality & AI Insights** - Phases 55-65 (shipped 2026-02-01)
- ✅ **v10.1 Production Deployment Fixes** - Phases 66-68 (shipped 2026-02-03)
- ✅ **v10.2 Performance & Memory Optimization** - Phases 69-72 (shipped 2026-02-03)
- ✅ **v10.3 Bug Fixes & Stabilization** - Phases 73-75 (shipped 2026-02-06)
- ✅ **v10.4 OMIM Optimization & Refactor** - Phases 76-79 (shipped 2026-02-07)
- 🚧 **v10.5 Bug Fixes & Data Integrity** - Phases 80-82 (in progress)

## Phases

<details>
<summary>✅ v1.0 through v10.4 (Phases 1-79) - See MILESTONES.md</summary>

Phases 1-79 delivered across milestones v1.0 through v10.4. See `.planning/MILESTONES.md` for full history.

</details>

### 🚧 v10.5 Bug Fixes & Data Integrity (In Progress)

**Milestone Goal:** Fix 5 open bugs across CurationComparisons (#173), AdminStatistics (#172, #171), PubTator (#170), and Traefik (#169). Delivers correct data display, accurate admin statistics, working PubTator incremental updates, and clean infrastructure configuration.

**Phases:** 3 (80-82)
**Requirements:** 24 requirements mapped (100% coverage)
**Risk profile:** Medium-High (dominated by #172-1 approval sync)

#### Phase 80: Foundation Fixes

**Goal:** Administrators see correct per-source categories in CurationComparisons, accurate monotonic entity trend charts, and Traefik starts without TLS warnings

**Depends on:** Nothing (first phase in milestone)

**Requirements:** DISP-01, DISP-02, DISP-03, DISP-04, DISP-05, INFRA-01, INFRA-02

**Success Criteria** (what must be TRUE):
1. CurationComparisons table shows each database's own category rating for every gene, not a cross-database maximum
2. The `definitive_only` filter shows genes where the displayed database rates them as Definitive, not genes where any database does
3. Entity trend chart in AdminStatistics produces monotonically non-decreasing cumulative totals across all granularities (daily, weekly, monthly)
4. Traefik production container starts without "No domain found" warnings and serves the correct TLS certificate for `sysndd.dbmr.unibe.ch`
5. R unit tests pass for `normalize_comparison_categories()` with multi-source test fixtures; TypeScript unit tests pass for `mergeGroupedCumulativeSeries()` with sparse data fixtures

**Plans:** 2 plans

Plans:
- [x] 80-01-PLAN.md -- CurationComparisons category normalization fix (#173)
- [x] 80-02-PLAN.md -- Entity trend time-series aggregation fix (#171) and Traefik TLS config (#169)

**Key files (new):**
- `api/functions/category-normalization.R`
- `app/src/utils/timeSeriesUtils.ts`

**Key files (modified):**
- `api/functions/endpoint-functions.R`
- `api/endpoints/comparisons_endpoints.R`
- `app/src/views/admin/AdminStatistics.vue`
- `docker-compose.yml`

**Pitfalls:**
- dplyr implicit grouping after `summarise()` -- always use `.groups = "drop"` and verify with `is_grouped_df()` (Pitfall 1)
- Sparse time-series forward-fill must carry forward cumulative values, not incremental counts (Pitfall 2)
- Traefik v3 router rule syntax -- use `Host()` matcher combined with `PathPrefix()` (Pitfall 7)

---

#### Phase 81: AdminStatistics Sub-Bugs

**Goal:** Re-review leaderboard reflects all curator approvals regardless of UI path used, AdminStatistics KPIs are accurate, and granularity changes cancel stale requests

**Depends on:** Phase 80 (Bug #172-3 KPI race fix depends on #171 time-series utility)

**Requirements:** STAT-01, STAT-02, STAT-03, STAT-04, STAT-05, STAT-06, STAT-07, STAT-08, STAT-09, STAT-10, STAT-11, TEST-03

**Success Criteria** (what must be TRUE):
1. When a review or status is approved via `/ApproveReview` or `/ApproveStatus`, the corresponding `re_review_entity_connect.re_review_approved` flag is set atomically within the same transaction
2. Re-review leaderboard chart shows three segments per reviewer: Approved (green), Pending Review (amber), Not Yet Submitted (gray)
3. Re-review progress percentage uses a dynamic denominator from `COUNT(*)` on `re_review_entity_connect`, not a hardcoded 3650
4. `totalEntities` KPI is derived inside `fetchTrendData()` with no cross-function race condition in `Promise.all()`
5. Date range "Jan 10 to Jan 20" computes as 11 days (inclusive), and previous period comparison uses equal-length periods
6. Switching granularity (daily/weekly/monthly) immediately clears stale chart data, cancels in-flight requests via AbortController, and shows a loading spinner until fresh data arrives
7. API responses that return error shapes or null data do not crash the admin view; negative bar values are clamped to zero

**Plans:** 3 plans

Plans:
- [x] 81-01-PLAN.md -- Re-review approval sync and leaderboard chart fix (#172-1)
- [x] 81-02-PLAN.md -- Dynamic denominator, date utilities, defensive data handling, and request cancellation (#172-2, #172-3, #172-4, #172-5/6, #172-7)
- [x] 81-03-PLAN.md -- Entity trend chart filter controls: NDD/Non-NDD/All toggle, Combined/By Category display, per-category checkboxes (#172-8)

**Key files (new):**
- `api/functions/re-review-sync.R`
- `app/src/utils/dateUtils.ts`
- `app/src/utils/apiUtils.ts`

**Key files (modified):**
- `api/functions/review-repository.R`
- `api/functions/status-repository.R`
- `api/endpoints/re_review_endpoints.R`
- `api/endpoints/statistics_endpoints.R`
- `app/src/views/admin/AdminStatistics.vue`
- `app/src/views/admin/components/charts/ReReviewBarChart.vue`
- `app/src/views/admin/components/charts/EntityTrendChart.vue`
- `app/src/utils/timeSeriesUtils.ts`

**Pitfalls:**
- Multi-table approval sync must happen inside `db_with_transaction()` -- never separate queries for related approval flags (Pitfall 3)
- AbortController: create a new controller per request, never reuse an aborted one; clean up on `onUnmounted()` (Pitfall 8)
- Use `.groups = "drop"` in leaderboard `summarise()` query (Pitfall 1)
- Omit filter param when matching API default to avoid URL encoding issues (Pitfall 9)
- Y-axis running maximum with separate watchers for reset-vs-keep semantics (Pitfall 10)

---

#### Phase 82: PubTator Backend Fix

**Goal:** PubTator incremental annotation update fetches only PMIDs missing annotations and stores results without duplicate key errors

**Depends on:** Nothing (independent of Phases 80-81)

**Requirements:** API-01, API-02, API-03

**Success Criteria** (what must be TRUE):
1. Incremental PubTator update queries only PMIDs that lack annotations via a LEFT JOIN filter (`WHERE a.annotation_id IS NULL`)
2. Batch INSERT uses `INSERT IGNORE` so duplicate `(pmid, gene_symbol)` pairs are silently skipped instead of causing errors
3. NCBI API calls are rate-limited with a minimum 350ms delay between requests
4. R unit tests verify the LEFT JOIN query returns only unannotated PMIDs and that duplicate inserts are handled gracefully

**Plans:** 1 plan

Plans:
- [x] 82-01-PLAN.md -- PubTator incremental query fix, INSERT IGNORE dedup, and rate limiting (#170)

**Post-plan fixes (discovered during E2E testing):**

1. **Migration 017: ensure `gene_symbols` column** -- `pubtator_search_cache.gene_symbols` column was missing; idempotent migration adds it via stored procedure guard (`f2e9626c`)

2. **Fix 18 broken `db_with_transaction` callers** -- Codebase audit found 18 of 21 `db_with_transaction` callers using expression pattern instead of `function(txn_conn)` pattern, providing zero atomicity (inner DB calls got separate pool connections). Mechanical fix: wrap body in `function(txn_conn) { ... }` and pass `conn = txn_conn` to all inner `db_execute_*` calls. Two callers (`review-repository.R`, `status-repository.R`) also had undefined `conn` variable bugs. Files: `pubtator-functions.R`, `review-repository.R`, `status-repository.R`, `phenotype-repository.R`, `publication-repository.R`, `ontology-repository.R`, `llm-cache-repository.R`, `llm-service.R`, `re-review-service.R`, `user-service.R`, `admin_endpoints.R`, `about_endpoints.R` (`d326f22d`)

3. **BioCJSON parsing pipeline rewrite** -- Root cause of 72% annotation loss: three cascading bugs in the old parsing pipeline:
   - `pubtator_v3_parse_nonstandard_json` split JSON on `"} "` — unnecessary since BioCJSON returns standard JSON
   - `reassemble_pubtator_docs` used `lapply(df, func)` iterating over COLUMNS not ROWS
   - `pubtator_v3_data_from_pmids` accumulated batches with `c(list1, list2)` creating duplicate named keys, silently losing all but first batch

   **Fix:** Replaced all three broken functions with one clean `pubtator_parse_biocjson(url)` using `jsonlite::fromJSON()` directly, and switched batch accumulation to `dplyr::bind_rows()`. Results: annotation coverage improved from 110→491 PMIDs (out of 500), gene_symbols from 285→452 (`a8c8a65e`)

4. **Static analysis tests for transaction patterns** -- Codebase-wide tests scanning all R files to ensure every `db_with_transaction` uses `function(txn_conn)` pattern and every inner `db_execute_*` passes `conn =` (`30b03ea7`)

**Key files (new):**
- `db/migrations/017_ensure_pubtator_gene_symbols.sql`
- `api/tests/testthat/test-unit-transaction-patterns.R`

**Key files (modified):**
- `api/functions/pubtator-functions.R` (incremental query + BioCJSON rewrite)
- `api/endpoints/publication_endpoints.R` (removed backward-compat gene_symbols code)
- `api/functions/review-repository.R` (transaction fix)
- `api/functions/status-repository.R` (transaction fix)
- `api/functions/phenotype-repository.R` (transaction fix)
- `api/functions/publication-repository.R` (transaction fix)
- `api/functions/ontology-repository.R` (transaction fix)
- `api/functions/llm-cache-repository.R` (transaction fix)
- `api/functions/llm-service.R` (transaction fix)
- `api/services/re-review-service.R` (transaction fix)
- `api/services/user-service.R` (transaction fix)
- `api/endpoints/admin_endpoints.R` (transaction fix)
- `api/endpoints/about_endpoints.R` (transaction fix)

**Pitfalls:**
- Non-idempotent batch INSERTs cause duplicate key errors on retries -- use `INSERT IGNORE` or `ON DUPLICATE KEY UPDATE` (Pitfall 4)
- NCBI rate limit is 3 req/s; use 350ms delay (not 333ms) for safety margin
- Test idempotency: inserting the same batch twice must not error and must not create duplicates
- BioCJSON returns standard JSON `{"PubTator3": [...]}` -- use `fromJSON()` directly, NOT custom line-splitting parsers (Pitfall 11)
- `lapply(data.frame, func)` iterates over COLUMNS not ROWS -- always use `lapply(seq_len(nrow(df)), ...)` or `purrr::map()` (Pitfall 12)
- `c(named_list1, named_list2)` with duplicate names silently drops duplicates -- use `dplyr::bind_rows()` for data frame accumulation (Pitfall 13)
- `db_with_transaction` requires `function(txn_conn)` pattern, NOT expression -- expression pattern gives zero atomicity (Pitfall 14)

---

## Requirement Coverage

| Requirement | Phase | Description |
|-------------|-------|-------------|
| DISP-01 | Phase 80 | Per-source category values (no cross-database max) |
| DISP-02 | Phase 80 | Extract `normalize_comparison_categories()` helper |
| DISP-03 | Phase 80 | `definitive_only` filter applies per-source |
| DISP-04 | Phase 80 | `mergeGroupedCumulativeSeries()` for sparse trend data |
| DISP-05 | Phase 80 | Monotonically non-decreasing global trend total |
| INFRA-01 | Phase 80 | Traefik Host() matcher for TLS cert selection |
| INFRA-02 | Phase 80 | No "No domain found" Traefik startup warnings |
| STAT-01 | Phase 81 | Cross-pathway `sync_rereview_approval()` hook |
| STAT-02 | Phase 81 | Re-review endpoint delegates to repository functions |
| STAT-03 | Phase 81 | Three-segment leaderboard chart |
| STAT-04 | Phase 81 | Dynamic percentage denominator from COUNT query |
| STAT-05 | Phase 81 | `totalEntities` computed inside `fetchTrendData()` |
| STAT-06 | Phase 81 | `inclusiveDayCount()` and `previousPeriod()` date utilities |
| STAT-07 | Phase 81 | `safeArray()` and `clampPositive()` defensive utilities |
| STAT-08 | Phase 81 | AbortController for request cancellation |
| STAT-09 | Phase 81 | NDD/Non-NDD/All trend chart filter toggle |
| STAT-10 | Phase 81 | Combined/By Category display mode for trend chart |
| STAT-11 | Phase 81 | Per-category checkbox filters with fixed y-axis |
| TEST-03 | Phase 81 | Integration test for re-review approval sync |
| API-01 | Phase 82 | LEFT JOIN query for missing-only annotation fetching |
| API-02 | Phase 82 | INSERT IGNORE for batch deduplication |
| API-03 | Phase 82 | 350ms rate limiting per NCBI API call |
| TEST-01 | Cross-cutting | R unit tests -- each phase delivers its portion |
| TEST-02 | Cross-cutting | TypeScript unit tests -- each phase delivers its portion |

**Coverage:** 24/24 requirements mapped (100%)

**Cross-cutting note:** TEST-01 and TEST-02 are composite requirements spanning all phases. Each phase delivers regression tests for its own fixes. Complete test coverage verified after Phase 82.

## Risk Register

| Risk | Severity | Phase | Mitigation |
|------|----------|-------|------------|
| dplyr implicit grouping produces wrong aggregations | HIGH | 80 | Explicit `.groups = "drop"` + `is_grouped_df()` assertions |
| Sparse time-series forward-fill on counts instead of cumulative values | HIGH | 80 | Forward-fill cumulative values only; sparse data test fixtures |
| Multi-table approval sync without transaction safety | CRITICAL | 81 | All updates inside `db_with_transaction()`; test rollback |
| AbortController memory leaks from reused controllers | MEDIUM | 81 | New controller per request; `onUnmounted()` cleanup |
| Non-idempotent batch INSERTs for PubTator | MEDIUM | 82 | `INSERT IGNORE`; idempotency test (same batch twice) |
| NCBI API rate limiting causes batch failures | MEDIUM | 82 | 350ms delay; `httr2::req_retry()` with backoff |
| BioCJSON parsing drops annotations for multi-batch fetches | CRITICAL | 82 | Replaced custom parser with `fromJSON()` + `bind_rows()` |
| `db_with_transaction` expression pattern provides zero atomicity | CRITICAL | 82 | Converted all 18 callers to `function(txn_conn)` pattern |
| Missing `gene_symbols` column blocks PubTator storage | HIGH | 82 | Migration 017 adds column idempotently |
| Traefik TLS cert renewal deadline (Feb 19, 2026) | HIGH | 80 | Prioritize in first plan of Phase 80 |

## Progress

**Execution Order:** 80 -> 81 -> 82

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 80. Foundation Fixes | v10.5 | 2/2 | ✓ Complete | 2026-02-08 |
| 81. AdminStatistics Sub-Bugs | v10.5 | 3/3 | ✓ Complete | 2026-02-09 |
| 82. PubTator Backend Fix | v10.5 | 1/1 | ✓ Complete | 2026-02-08 |

---
*Roadmap created: 2026-01-20*
*Last updated: 2026-02-09 -- Phase 82 post-plan fixes (BioCJSON rewrite, transaction atomicity, migration 017)*
