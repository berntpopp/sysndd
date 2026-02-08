# Requirements: v10.5 Bug Fixes & Data Integrity

**Defined:** 2026-02-08
**Milestone:** v10.5
**Source:** Research synthesis + bug analysis files in `.planning/bugs/`

---

## v1 Requirements

Requirements for v10.5 milestone. Each maps to roadmap phases.

### Data Display Correctness

- [x] **DISP-01**: CurationComparisons shows per-source category values (no cross-database max aggregation) (#173)
- [x] **DISP-02**: Shared `normalize_comparison_categories()` helper extracted to `category-normalization.R` for DRY reuse (#173)
- [x] **DISP-03**: `definitive_only` filter applies per-source, not post-aggregation (#173)
- [x] **DISP-04**: Entity trend chart forward-fills sparse category data via `mergeGroupedCumulativeSeries()` utility (#171)
- [x] **DISP-05**: Global trend total is monotonically non-decreasing (no downward spikes) (#171)

### AdminStatistics Sub-Bugs

- [ ] **STAT-01**: Re-review approval synced across all pathways via repository-layer `sync_rereview_approval()` hook (#172-1)
- [ ] **STAT-02**: Re-review endpoint simplified to delegate to repository functions (DRY) (#172-1)
- [ ] **STAT-03**: Three-segment leaderboard chart: Approved + Pending + Not Submitted (#172-1)
- [ ] **STAT-04**: Dynamic percentage denominator from `COUNT(*)` instead of hardcoded 3650 (#172-2)
- [ ] **STAT-05**: `totalEntities` KPI computed inside `fetchTrendData()` (no cross-function race) (#172-3)
- [ ] **STAT-06**: Inclusive date range: `inclusiveDayCount()` and `previousPeriod()` in `dateUtils.ts` (#172-4)
- [ ] **STAT-07**: `safeArray<T>()` and `clampPositive()` utilities prevent crashes and negative bars (#172-5/6)
- [ ] **STAT-08**: AbortController cancels in-flight requests on granularity change (#172-7)

### External API Integration

- [ ] **API-01**: PubTator annotation fetch uses LEFT JOIN to query only PMIDs missing annotations (#170)
- [ ] **API-02**: PubTator batch INSERT uses `INSERT IGNORE` for deduplication (#170)
- [ ] **API-03**: PubTator API calls rate-limited at 350ms delay between requests (#170)

### Infrastructure

- [x] **INFRA-01**: Traefik router rule includes `Host()` matcher for deterministic TLS cert selection (#169)
- [x] **INFRA-02**: No "No domain found" Traefik startup warnings (#169)

### Data Integrity Tooling

- [ ] **INTEG-01**: Admin endpoint detects suffix-gene misalignment entities via multi-table JOIN (#167)
- [ ] **INTEG-02**: Fixability classification: auto-fixable vs needs-curator (#167)
- [ ] **INTEG-03**: Admin view `ManageEntityIntegrity.vue` with entity details and curator actions (#167)
- [ ] **INTEG-04**: Orphaned pointer (entity 4269) surfaced for curator decision (#167)
- [ ] **INTEG-05**: Compatibility rows (`is_active=FALSE`) generated for broken inactive entity FKs (#167)
- [ ] **INTEG-06**: Migration script idempotent with stored procedure guards (#167)

### Regression Tests

- [ ] **TEST-01**: R unit tests for category normalization, re-review sync, dynamic denominator, PubTator incremental query, detection query
- [ ] **TEST-02**: TypeScript unit tests for `mergeGroupedCumulativeSeries()`, `inclusiveDayCount()`, `previousPeriod()`, `safeArray()`, `clampPositive()`
- [ ] **TEST-03**: Integration test for re-review approval sync across pathways

## v2 Requirements

Deferred to future milestones.

- **BACK-01**: Historical re-review backfill script (689 records) -- tracked in berntpopp/sysndd-administration#1
- **BACK-02**: PubTator backfill for ~2,900 PMIDs missing annotations
- **INTEG-07**: Scheduled nightly integrity checks after ontology updates
- **INTEG-08**: Integrity KPI card on AdminStatistics dashboard
- **INTEG-09**: Email alerts on critical entity integrity issues

## Out of Scope

| Feature | Reason |
|---------|--------|
| Automated suffix-gene fixes | Requires curator judgment for 12 of 13 entities |
| Real-time AdminStatistics refresh | Weekly review tool, not live dashboard |
| Bulk entity disease reassignment | Each entity needs individual curator review |
| PubTator full re-fetch on every update | Rate limiting makes this infeasible |
| Chart.js negative bar clamping plugin | Fix data, not rendering |
| Traefik SNI fallback documentation | Fix the root cause instead |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DISP-01 | Phase 80 | Complete |
| DISP-02 | Phase 80 | Complete |
| DISP-03 | Phase 80 | Complete |
| DISP-04 | Phase 80 | Complete |
| DISP-05 | Phase 80 | Complete |
| INFRA-01 | Phase 80 | Complete |
| INFRA-02 | Phase 80 | Complete |
| STAT-01 | Phase 81 | Pending |
| STAT-02 | Phase 81 | Pending |
| STAT-03 | Phase 81 | Pending |
| STAT-04 | Phase 81 | Pending |
| STAT-05 | Phase 81 | Pending |
| STAT-06 | Phase 81 | Pending |
| STAT-07 | Phase 81 | Pending |
| STAT-08 | Phase 81 | Pending |
| TEST-03 | Phase 81 | Pending |
| API-01 | Phase 82 | Pending |
| API-02 | Phase 82 | Pending |
| API-03 | Phase 82 | Pending |
| INTEG-01 | Phase 83 | Pending |
| INTEG-02 | Phase 83 | Pending |
| INTEG-03 | Phase 83 | Pending |
| INTEG-04 | Phase 83 | Pending |
| INTEG-05 | Phase 83 | Pending |
| INTEG-06 | Phase 83 | Pending |
| TEST-01 | Cross-cutting (P80-P83) | Pending |
| TEST-02 | Cross-cutting (P80-P81) | Pending |

**Coverage:**
- v1 requirements: 27 total
- Mapped to phases: 27 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-02-08*
*Traceability updated: 2026-02-08 (roadmap phases 80-83)*
