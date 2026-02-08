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
- 🚧 **v10.5 Bug Fixes & Data Integrity** - Phases 80-83 (in progress)

## Phases

<details>
<summary>✅ v1.0 through v10.4 (Phases 1-79) - See MILESTONES.md</summary>

Phases 1-79 delivered across milestones v1.0 through v10.4. See `.planning/MILESTONES.md` for full history.

</details>

### 🚧 v10.5 Bug Fixes & Data Integrity (In Progress)

**Milestone Goal:** Fix 6 open bugs across CurationComparisons (#173), AdminStatistics (#172, #171), PubTator (#170), Traefik (#169), and entity data integrity (#167). Delivers correct data display, accurate admin statistics, working PubTator incremental updates, clean infrastructure configuration, and a curator-driven entity integrity audit tool.

**Phases:** 4 (80-83)
**Requirements:** 27 v1 requirements mapped (100% coverage)
**Risk profile:** Medium-High (dominated by #172-1 approval sync and #167 entity integrity audit)

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
- [ ] 80-01-PLAN.md -- CurationComparisons category normalization fix (#173)
- [ ] 80-02-PLAN.md -- Entity trend time-series aggregation fix (#171) and Traefik TLS config (#169)

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

**Requirements:** STAT-01, STAT-02, STAT-03, STAT-04, STAT-05, STAT-06, STAT-07, STAT-08, TEST-03

**Success Criteria** (what must be TRUE):
1. When a review or status is approved via `/ApproveReview` or `/ApproveStatus`, the corresponding `re_review_entity_connect.re_review_approved` flag is set atomically within the same transaction
2. Re-review leaderboard chart shows three segments per reviewer: Approved (green), Pending Review (amber), Not Yet Submitted (gray)
3. Re-review progress percentage uses a dynamic denominator from `COUNT(*)` on `re_review_entity_connect`, not a hardcoded 3650
4. `totalEntities` KPI is derived inside `fetchTrendData()` with no cross-function race condition in `Promise.all()`
5. Date range "Jan 10 to Jan 20" computes as 11 days (inclusive), and previous period comparison uses equal-length periods
6. Switching granularity (daily/weekly/monthly) immediately clears stale chart data, cancels in-flight requests via AbortController, and shows a loading spinner until fresh data arrives
7. API responses that return error shapes or null data do not crash the admin view; negative bar values are clamped to zero

**Plans:** 2 plans

Plans:
- [ ] 81-01: Re-review approval sync and leaderboard chart fix (#172-1)
- [ ] 81-02: Dynamic denominator, date utilities, defensive data handling, and request cancellation (#172-2, #172-3, #172-4, #172-5/6, #172-7)

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

**Pitfalls:**
- Multi-table approval sync must happen inside `db_with_transaction()` -- never separate queries for related approval flags (Pitfall 3)
- AbortController: create a new controller per request, never reuse an aborted one; clean up on `onUnmounted()` (Pitfall 8)
- Use `.groups = "drop"` in leaderboard `summarise()` query (Pitfall 1)

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
- [ ] 82-01: PubTator incremental query fix, INSERT IGNORE dedup, and rate limiting (#170)

**Key files (modified):**
- `api/functions/pubtator-functions.R`

**Pitfalls:**
- Non-idempotent batch INSERTs cause duplicate key errors on retries -- use `INSERT IGNORE` or `ON DUPLICATE KEY UPDATE` (Pitfall 4)
- NCBI rate limit is 3 req/s; use 350ms delay (not 333ms) for safety margin
- Test idempotency: inserting the same batch twice must not error and must not create duplicates

---

#### Phase 83: Entity Data Integrity Audit

**Goal:** Administrators can view, classify, and act on the 13 suffix-gene misalignment entities through a dedicated admin panel

**Depends on:** Nothing (independent of Phases 80-82, but last for pattern validation)

**Requirements:** INTEG-01, INTEG-02, INTEG-03, INTEG-04, INTEG-05, INTEG-06

**Success Criteria** (what must be TRUE):
1. Admin endpoint returns the list of entities where `disease_ontology_id_version` gene does not match `entity.hgnc_id`, with fixability classification (auto-fixable vs needs-curator)
2. `ManageEntityIntegrity.vue` admin view displays entity details, current vs correct disease association, and curator action buttons (approve/defer/skip)
3. Orphaned pointer (entity 4269, `replaced_by=4271` referencing nonexistent entity) is surfaced for curator decision
4. Compatibility rows (`is_active=FALSE`) are generated for broken inactive entity foreign keys to maintain referential integrity
5. Migration script is idempotent: running it twice produces no errors and the same end state (stored procedure guards)
6. Entity integrity audit is accessible from the admin panel navigation

**Plans:** 2 plans

Plans:
- [ ] 83-01: Detection endpoint and fixability classification (#167 backend)
- [ ] 83-02: ManageEntityIntegrity admin view, compatibility rows, and migration script (#167 frontend + data)

**Key files (new):**
- `api/endpoints/admin_integrity_endpoints.R`
- `app/src/views/admin/ManageEntityIntegrity.vue`
- `app/src/components/admin/EntityIntegrityTable.vue`
- `db/migrations/006_entity_integrity_fixes.sql`

**Key files (modified):**
- `app/src/router/index.ts`
- `app/src/views/admin/AdminPanel.vue`
- `api/start_sysndd_api.R` (source new endpoint file)

**Pitfalls:**
- Non-idempotent migration scripts block deployments -- use stored procedure guards with IF NOT EXISTS checks (Pitfall 5)
- Use a separate endpoint (`/api/admin/integrity`) for audit data instead of modifying existing entity endpoints (Pitfall 6)
- Automated fixes only for the 1 unambiguous entity (662); all others require curator judgment

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
| TEST-03 | Phase 81 | Integration test for re-review approval sync |
| API-01 | Phase 82 | LEFT JOIN query for missing-only annotation fetching |
| API-02 | Phase 82 | INSERT IGNORE for batch deduplication |
| API-03 | Phase 82 | 350ms rate limiting per NCBI API call |
| INTEG-01 | Phase 83 | Detection endpoint via multi-table JOIN |
| INTEG-02 | Phase 83 | Fixability classification (auto-fixable vs needs-curator) |
| INTEG-03 | Phase 83 | `ManageEntityIntegrity.vue` admin view |
| INTEG-04 | Phase 83 | Orphaned pointer (entity 4269) surfaced |
| INTEG-05 | Phase 83 | Compatibility rows for broken inactive entity FKs |
| INTEG-06 | Phase 83 | Idempotent migration script with stored procedure guards |
| TEST-01 | Cross-cutting | R unit tests -- each phase delivers its portion |
| TEST-02 | Cross-cutting | TypeScript unit tests -- each phase delivers its portion |

**Coverage:** 27/27 v1 requirements mapped (100%)

**Cross-cutting note:** TEST-01 and TEST-02 are composite requirements spanning all phases. Each phase delivers regression tests for its own fixes. Complete test coverage verified after Phase 83.

## Risk Register

| Risk | Severity | Phase | Mitigation |
|------|----------|-------|------------|
| dplyr implicit grouping produces wrong aggregations | HIGH | 80 | Explicit `.groups = "drop"` + `is_grouped_df()` assertions |
| Sparse time-series forward-fill on counts instead of cumulative values | HIGH | 80 | Forward-fill cumulative values only; sparse data test fixtures |
| Multi-table approval sync without transaction safety | CRITICAL | 81 | All updates inside `db_with_transaction()`; test rollback |
| AbortController memory leaks from reused controllers | MEDIUM | 81 | New controller per request; `onUnmounted()` cleanup |
| Non-idempotent batch INSERTs for PubTator | MEDIUM | 82 | `INSERT IGNORE`; idempotency test (same batch twice) |
| NCBI API rate limiting causes batch failures | MEDIUM | 82 | 350ms delay; `httr2::req_retry()` with backoff |
| Non-idempotent migration script blocks deployment | CRITICAL | 83 | Stored procedure guards; test re-application |
| API schema changes break frontend | MEDIUM | 83 | Separate endpoint; optional fields only |
| Traefik TLS cert renewal deadline (Feb 19, 2026) | HIGH | 80 | Prioritize in first plan of Phase 80 |

## Progress

**Execution Order:** 80 -> 81 -> 82 -> 83

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 80. Foundation Fixes | v10.5 | 0/2 | Not started | - |
| 81. AdminStatistics Sub-Bugs | v10.5 | 0/2 | Not started | - |
| 82. PubTator Backend Fix | v10.5 | 0/1 | Not started | - |
| 83. Entity Data Integrity Audit | v10.5 | 0/2 | Not started | - |

---
*Roadmap created: 2026-01-20*
*Last updated: 2026-02-08 -- Phase 80 plans created*
