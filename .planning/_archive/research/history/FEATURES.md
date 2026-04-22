# Feature Landscape: v10.5 Bug Fixes & Data Integrity

**Domain:** Bug fixes for production neurodevelopmental disorders database
**Researched:** 2026-02-08

## Overview

v10.5 addresses 6 distinct bug categories affecting data display accuracy, backend data integrity, and production configuration. This is a **correctness-focused milestone** — the features described below are not new capabilities but rather specifications of what correct behavior looks like for existing functionality.

| Bug Category | GitHub Issue(s) | Feature Domain | Complexity |
|--------------|----------------|----------------|-----------|
| Cross-database category aggregation | #173 | Data transformation (backend) | Low |
| AdminStatistics display/logic | #172, #171 | Data aggregation & UI state (7 sub-bugs) | Medium |
| PubTator incremental updates | #170 | External API integration | Medium |
| Traefik TLS configuration | #169 | Infrastructure | Low |
| Entity data integrity audit | #167 | Admin tooling & data quality | High |

---

## Table Stakes

Features users **expect** for the system to work correctly. Missing = broken product.

### Bug #173: CurationComparisons Per-Source Category Display

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Per-source category preservation | Each database column shows **that database's** normalized category for the gene, not a cross-database maximum | Cross-database comparison is the entire purpose of the page | Backend: Remove `group_by(symbol) %>% mutate(category_id = min(category_id))` aggregation |
| Category normalization reusability | Shared `normalize_comparison_categories()` function eliminates duplicated normalization logic | DRY principle; same normalization in upset endpoint | Extract to `helper-functions.R` |
| Accurate definitive_only filter | Filter shows genes where **each displayed database** rates them as Definitive | Users filter to high-confidence genes per source | Filter pre-pivot data, not post-aggregation max |
| Correct homepage parity | CurationComparisons stats match homepage counts for SysNDD column | Consistency across views for same data | Both use same category source |

**Complexity:** Low (remove incorrect aggregation + extract shared helper)

**Dependencies:** None — isolated to comparison endpoint and helper utilities

---

### Bug #172/#171: AdminStatistics Time-Series & Re-Review Accuracy (7 Sub-Bugs)

#### Sub-Bug 1: Re-Review Approval Tracking (#172-1)

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Cross-pathway approval sync | When a review/status is approved via ANY pathway (Review page, ApproveReview, ApproveStatus), `re_review_entity_connect.re_review_approved` is set | Re-review leaderboard must reflect all curator work, regardless of UI path | Repository-layer hook: `sync_rereview_approval()` called in `review_approve()` and `status_approve()` |
| Three-segment leaderboard | Chart shows Approved (green) + Pending Review (amber) + Not Yet Submitted (gray) | Complete picture of re-review pipeline state | Update query to include `total_assigned`, compute deltas in frontend |
| Historical backfill | Existing 689 submitted re-reviews with approved underlying records get retroactively marked | Accurate historical statistics | One-time SQL backfill script (tracked in sysndd-administration#1) |

**Complexity:** Medium (touches 3 pathways + backfill script)

**Dependencies:** Requires transactional database changes; backfill must run AFTER prospective fix

---

#### Sub-Bug 2: Entity Trend Forward-Fill Aggregation (#171)

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Cumulative cross-category sum | Global trend line sums each category's `cumulative_count` at each date, forward-filling gaps | Sparse time series require forward-fill for correct cumulative totals | Pure utility: `mergeGroupedCumulativeSeries()` in `timeSeriesUtils.ts` |
| Monotonic non-decreasing values | Chart never shows downward spikes | Cumulative counts can only increase | Derived from correct aggregation algorithm |
| Reusable aggregation logic | Utility function works for any grouped cumulative time series | DRY for future admin charts | Extract to `/utils/` with TypeScript types |

**Complexity:** Medium (algorithmic fix + testing)

**Dependencies:** None — pure frontend transformation

---

#### Sub-Bug 3: Dynamic Percentage Finished (#172-2)

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Self-updating denominator | Progress percentage computed from `COUNT(*) FROM re_review_entity_connect`, not hardcoded 3650 | Database grows over time; metric must reflect current state | Query-based denominator in `/rereview` endpoint |
| Three-tiered progress metrics | **Coverage** (% of NDD entities enrolled), **Submission** (% of enrolled submitted), **Approval** (% of enrolled approved) | Tracks both batch creation progress and reviewer completion | Separate computations with clear naming |
| Backward compatibility | Old `percentage_finished` field kept as alias for `percent_submitted` | Prevents breaking frontend during transition | Deprecated field with comment |

**Complexity:** Low (replace magic number with COUNT query)

**Dependencies:** None — isolated endpoint change

---

#### Sub-Bug 4: KPI Race Condition (#172-3)

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| No temporal coupling | `totalEntities` KPI derived immediately after trend data fetch, inside same function | Parallel `Promise.all()` tasks must be independent | Move computation to `fetchTrendData()` |
| Single responsibility | Each fetch function owns its complete outputs | SRP principle | Remove cross-function data dependency |

**Complexity:** Low (move 2 lines)

**Dependencies:** Must be applied AFTER Sub-Bug 2 fix (uses corrected `trendData`)

---

#### Sub-Bug 5: Inclusive Date Range Calculation (#172-4)

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Inclusive day count | Jan 10 to Jan 20 = 11 days, not 10 | Standard date range interpretation | Extract `inclusiveDayCount()` utility: `(endTime - startTime) / MS_PER_DAY + 1` |
| Equal-length comparison periods | Previous period has same number of days as current period | Fair percentage change calculation | `previousPeriod()` utility uses inclusive count |
| Reusable date utilities | Date math extracted to `/utils/dateUtils.ts` | DRY across admin views | Pure functions with unit tests |

**Complexity:** Low (extract utility + fix callers)

**Dependencies:** None — isolated utility

---

#### Sub-Bug 6: Defensive Data Handling (#172-5)

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Safe array extraction | API response shape validation before `.map()` calls | Prevents crash on error responses | `safeArray<T>()` utility in `apiUtils.ts` |
| Positive-only chart values | `Math.max(0, submitted - approved)` prevents negative bar heights | Chart.js renders negative bars incorrectly | `clampPositive()` utility |
| Null-safe operations | All numeric operations default to `0` on `null`/`undefined` | Inconsistent data shouldn't crash UI | `?? 0` pattern in mappers |

**Complexity:** Low (utility wrappers)

**Dependencies:** None — defensive layer at API boundary

---

#### Sub-Bug 7: Request Cancellation on Granularity Change (#172-7)

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Abort in-flight requests | Switching granularity cancels old request before starting new one | Prevents stale slow response from overwriting fresh data | `AbortController` pattern |
| Immediate UI state clear | `trendData.value = []` before fetch, user sees spinner | No wrong chart visible during transition | Clear data at function start |
| Cleanup on unmount | Abort on component unmount | Prevents memory leaks and orphaned requests | `onUnmounted()` hook |

**Complexity:** Low (standard browser API pattern)

**Dependencies:** None — isolated to AdminStatistics component

---

### Bug #170: PubTator Incremental Update Efficiency

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Fetch only missing annotations | Incremental updates query PMIDs that lack annotations, not all PMIDs | API rate limiting fails when sending 3,000 PMIDs in 30 batches | LEFT JOIN filter: `WHERE a.annotation_id IS NULL` |
| Annotation deduplication | INSERT checks for existing annotation or uses `INSERT IGNORE` | Prevents 36x duplicates like current KIF21A entries | Add UNIQUE constraint or pre-delete logic |
| Backfill missing data | After fix, run update to fetch annotations for ~2,900 PMIDs | Unlocks PubTator gene table and stats frozen since Jan 2025 | One-time batch job with fixed query |

**Complexity:** Medium (query fix + deduplication strategy + backfill)

**Dependencies:** Database schema may need UNIQUE constraint; backfill runs after prospective fix

---

### Bug #169: Traefik Host() Matcher for TLS

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Deterministic TLS cert selection | Router rules include `Host(sysndd.dbmr.unibe.ch)` for explicit domain matching | Eliminates SNI fallback warnings; future-proof for multi-domain | Add to `docker-compose.prod.yml` labels |
| No startup warnings | Traefik starts without "No domain found" warnings | Clean logs for operational monitoring | `Host() && PathPrefix()` combined rule |
| SAN coverage for www subdomain | Certificate renewal includes both `sysndd.dbmr.unibe.ch` and `www.sysndd.dbmr.unibe.ch` | Matches actual traffic patterns | Cert renewal config (before Feb 19 2026) |

**Complexity:** Low (config-only change)

**Dependencies:** None — production deployment only

---

### Bug #167: Entity Data Integrity Audit UI (13 Suffix-Gene Misalignments)

**What correct behavior looks like:**

| Feature | Description | Why Expected | Implementation |
|---------|-------------|--------------|----------------|
| Misalignment detection query | Admin endpoint queries entities where `disease_ontology_id_version` gene doesn't match `entity.hgnc_id` | Surfaces 13 pre-existing critical data errors | Multi-table JOIN with gene extraction |
| Fixability classification | Auto-classifies as "auto-fixable" (1 entity) vs "needs curator" (12 entities) | Curator time optimization | Check if correct suffix exists for same gene |
| Curator decision UI | Admin view shows entity details + current vs correct disease + approve/defer actions | Curator-driven fixes prevent automated mistakes | New admin component with type-to-confirm |
| Orphaned pointer fix | Entity 4269 `replaced_by=4271` (nonexistent) gets cleared | Broken FK prevents proper entity resolution | Direct SQL fix or admin action |
| Compatibility row generation | Add `is_active=FALSE` rows to `disease_ontology_set` for 5 broken inactive entity FKs | Maintains referential integrity for historical entities | Batch INSERT of missing suffix versions |

**Complexity:** High (new admin UI + multi-part data fixes)

**Dependencies:** Requires curator review workflow; cannot be fully automated

---

## Differentiators

Improvements **beyond** just fixing the bug. Nice-to-have for better UX/maintainability.

### Enhanced Re-Review Visibility

| Feature | Value Proposition | Complexity | Implementation |
|---------|-------------------|------------|----------------|
| Period-specific submission rate | Show "0.27 re-reviews submitted per day" for current date range | Curator velocity tracking | Already computed in endpoint, expose in UI |
| Re-review coverage metric | "65.2% of NDD entities enrolled in re-review batches" | Shows batch creation progress vs database growth | New metric in `/rereview` endpoint |
| User-level progress tracking | Per-user "Not Submitted" count in leaderboard tooltip | Identifies stalled assignments | Frontend tooltip using `total_assigned - submitted_count` |

### Test Coverage for Time-Series Utilities

| Feature | Value Proposition | Complexity | Implementation |
|---------|-------------------|------------|----------------|
| Unit tests for `mergeGroupedCumulativeSeries` | Prevents regression of aggregation bugs | Low | Vitest test suite with edge cases (empty groups, single date, month boundaries) |
| Unit tests for date utilities | Verifies inclusive count, leap years, month rollover | Low | Vitest test suite |
| Regression test for comparison normalization | Ensures per-source categories never collapse again | Low | Add to existing `test-unit-endpoint-functions.R` |

### Entity Integrity Audit Proactive Monitoring

| Feature | Value Proposition | Complexity | Implementation |
|---------|-------------------|------------|----------------|
| Scheduled integrity checks | Nightly job detects new misalignments after ontology updates | Medium | Cron + job-manager.R integration |
| Integrity KPI card | AdminStatistics shows "X entities need curator review" | Low | New card on admin dashboard |
| Email alerts on critical issues | Notify admin when truly critical changes blocked | Medium | SMTP integration (Mailpit for dev) |

### PubTator Batch Progress Indicator

| Feature | Value Proposition | Complexity | Implementation |
|---------|-------------------|------------|----------------|
| Incremental progress bar | Show "Fetching annotations: 150/2900 PMIDs" during backfill | Low | Job progress tracking in mirai |
| Success rate reporting | "2,850 annotations fetched, 50 failed (rate limited)" | Low | Count INSERT successes in loop |

---

## Anti-Features

Things to **deliberately NOT build** — common mistakes or scope creep.

### Anti-Feature 1: Automated Suffix-Gene Misalignment Fixes

**What:** Automatically rewrite `disease_ontology_id_version` for the 13 misaligned entities based on heuristics

**Why avoid:**
- Gene-disease associations are **curated scientific claims** — changing them without curator review could introduce errors
- 12 of 13 entities have multiple possible OMIM entries; automated choice could be wrong
- 2 entities (MT-TV, ASCL1) have **no** current OMIM entries; requires research

**What to do instead:**
- Build admin UI for curator-driven review and approval
- Auto-classify fixability to prioritize curator time
- Only auto-fix the 1 entity with unambiguous correction (entity 662, suffix swap)

---

### Anti-Feature 2: Real-Time AdminStatistics Refresh

**What:** WebSocket or polling for live KPI updates without page refresh

**Why avoid:**
- AdminStatistics is a weekly/monthly review tool, not a live dashboard
- Polling adds server load for minimal user value
- Date range selector already provides manual refresh control

**What to do instead:**
- Keep current on-mount + on-filter-change fetch pattern
- Consider cache-control headers for stale-while-revalidate (future optimization)

---

### Anti-Feature 3: Bulk Entity Disease Reassignment Tool

**What:** Admin UI to bulk-update `disease_ontology_id_version` for multiple entities at once

**Why avoid:**
- Each of the 13 misaligned entities has **different** correct disease associations
- Bulk operations on curated data increase risk of mistakes
- Better to fix once correctly than optimize for a one-time task

**What to do instead:**
- Single-entity review UI with preview and confirm
- After curator fixes these 13, the Phase 76 safeguard prevents new drift

---

### Anti-Feature 4: PubTator Full Re-Fetch on Every Update

**What:** Always fetch annotations for all PMIDs, ignore incremental optimization

**Why avoid:**
- NCBI API rate limiting makes this infeasible (current bug proves this)
- Wastes bandwidth and time re-fetching unchanged data
- Doesn't scale as database grows to 10K+ publications

**What to do instead:**
- Fix incremental update to only fetch missing annotations (Bug #170 fix)
- Add last_updated timestamp to support smart refresh (future enhancement)

---

### Anti-Feature 5: Traefik SNI Fallback Configuration

**What:** Document/support the current SNI-based TLS certificate selection as a valid configuration

**Why avoid:**
- It's a fallback due to incomplete router rules, not a best practice
- Generates startup warnings that obscure real issues
- Not deterministic in multi-domain scenarios (future risk)

**What to do instead:**
- Fix the router rules with `Host()` matchers (Bug #169 fix, 2-line change)
- Document the correct pattern in deployment docs

---

### Anti-Feature 6: Chart.js Plugin for Negative Bar Clamping

**What:** Custom Chart.js plugin that intercepts negative values and clamps them

**Why avoid:**
- Root cause is data inconsistency (`approved > submitted`), not rendering
- Plugin hides data quality issues instead of surfacing them
- Adds dependency and maintenance burden

**What to do instead:**
- Defensive data handling at the boundary (`clampPositive()` utility)
- Consider logging a warning when clamping occurs (signals data issue)

---

## Feature Dependencies

Dependencies between fixes and existing features.

### Critical Path

```
Bug #172-2 (percentage fix) ──┬──> Bug #172-1 (approval sync)
                               │    │
                               │    └──> Chart display (3 segments)
                               │
Bug #171 (trend aggregation) ─┴──> Bug #172-3 (KPI race fix)
                                    │
                                    └──> Correct totalEntities display
```

### Independent Fixes

- Bug #173 (CurationComparisons): No dependencies
- Bug #170 (PubTator): No dependencies (backfill after prospective fix)
- Bug #169 (Traefik): No dependencies (config-only)
- Bug #167 (Entity integrity): Depends on curator availability, not code

### Shared Utilities

New utilities benefit multiple bugs:

| Utility | Used By | Benefit |
|---------|---------|---------|
| `timeSeriesUtils.ts` | Bug #171, future trend charts | DRY time-series aggregation |
| `dateUtils.ts` | Bug #172-4, future admin views | DRY date math |
| `apiUtils.ts` | Bug #172-5, all admin components | DRY response validation |
| `normalize_comparison_categories()` | Bug #173, upset endpoint | DRY category normalization |
| `sync_rereview_approval()` | Bug #172-1, future approval paths | DRY re-review tracking |

---

## MVP Recommendation

For v10.5, prioritize fixes by **user impact × data correctness**:

### Must Fix (Blocking for Release)

1. **Bug #173** — CurationComparisons shows wrong categories (high user confusion)
2. **Bug #170** — PubTator broken since Jan 2025 (feature completely unusable)
3. **Bug #172-1** — Re-review leaderboard shows 100% pending (morale impact on curators)
4. **Bug #171** — Entity trend chart shows incorrect totals (strategic dashboard wrong)

### Should Fix (Quality/Maintainability)

5. **Bug #172-2** — Hardcoded denominator (technical debt, future-breaking)
6. **Bug #172-5** — Defensive data handling (prevents crashes on edge cases)
7. **Bug #169** — Traefik warnings (operational cleanliness)

### Can Defer (Low Impact)

8. **Bug #172-3** — KPI race condition (rare timing issue, non-critical)
9. **Bug #172-4** — Off-by-one date range (1-day error in delta calculation)
10. **Bug #172-7** — Granularity change stale data (transient UI glitch)

### Requires Curator Coordination

11. **Bug #167** — Entity integrity audit (13 entities need curator review; build UI in v10.5, fixes happen post-release)

---

## Complexity Assessment

| Bug | Backend Work | Frontend Work | Testing Effort | Total Complexity |
|-----|-------------|---------------|----------------|-----------------|
| #173 | Medium (extract helper, fix endpoint) | None | Low (add regression tests) | **Medium** |
| #171 | None | Medium (pure utility) | Medium (edge cases) | **Medium** |
| #172-1 | High (3 approval paths + backfill) | Low (chart update) | Medium (integration tests) | **High** |
| #172-2 | Low (replace magic number) | Low (update display) | Low | **Low** |
| #172-3 | None | Low (move 2 lines) | None | **Low** |
| #172-4 | None | Low (extract utility) | Low | **Low** |
| #172-5 | None | Low (wrapper utilities) | Low | **Low** |
| #172-7 | None | Low (AbortController) | Low | **Low** |
| #170 | Medium (query + dedup + backfill) | None | Medium (verify 2,900 PMIDs) | **Medium** |
| #169 | None | None (config only) | None (manual verification) | **Low** |
| #167 | High (6 data issues, new admin UI) | High (curator workflow) | High (data validation) | **Very High** |

**Overall milestone complexity:** Medium-High (dominated by #167 and #172-1)

---

## Sources

- Bug analysis: `.planning/bugs/` directory (7 files)
- GitHub issues: #173, #172, #171, #170, #169, #167
- Codebase analysis:
  - `api/functions/endpoint-functions.R` (comparison normalization)
  - `app/src/views/admin/AdminStatistics.vue` (trend aggregation)
  - `api/functions/pubtator-functions.R` (incremental update)
  - `docker-compose.prod.yml` (Traefik config)
- Database snapshot: `.plan/data/202601311251.sysndd_db.sql.gz` (entity integrity audit)
- Project context: `.planning/PROJECT.md`
