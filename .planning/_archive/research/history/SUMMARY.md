# Project Research Summary

**Project:** SysNDD v10.5 — Bug Fixes & Data Integrity
**Domain:** Production bug fixes for neurodevelopmental disorders gene database
**Researched:** 2026-02-08
**Confidence:** HIGH

## Executive Summary

SysNDD v10.5 is a correctness-focused milestone addressing 6 bugs (GitHub issues #167, #169, #170, #171, #172, #173) that affect data display accuracy, backend data integrity, and production infrastructure. The bugs range from a simple Traefik configuration fix to a complex entity data integrity audit requiring curator-driven review workflows. All fixes can be implemented using existing stack capabilities -- no new dependencies are needed, and all patterns are validated in the current codebase.

The recommended approach is to fix bugs in dependency order: start with isolated, low-risk fixes (CurationComparisons category bug, Traefik config, time-series utility extraction), then tackle the interconnected AdminStatistics sub-bugs that have explicit ordering constraints, followed by the PubTator backend fix, and finally the highest-complexity item -- the entity data integrity audit UI. This ordering minimizes risk by validating patterns on simpler fixes before applying them to complex multi-pathway approval logic.

The primary risks are (1) dplyr implicit grouping causing silent data corruption in the category normalization fix, (2) transaction safety across multiple approval pathways in the re-review sync fix, and (3) non-idempotent database migration scripts for the entity integrity fixes. All three have well-documented prevention strategies: explicit `.groups = "drop"`, wrapping related updates in `db_with_transaction()`, and using stored procedure guards for idempotent DDL. The Traefik TLS certificate renewal has a hard deadline (Feb 19, 2026) that should be prioritized accordingly.

## Key Findings

### Recommended Stack

No new dependencies required. All 6 bugs are fixable with existing technologies at their current versions. The stack is fully up to date (Vue 3.5.25, TypeScript 5.9.3, R 4.5.2, Traefik v3.6, MySQL 8.4.8).

**Core patterns to leverage:**
- **AbortController** (browser native): Request cancellation for AdminStatistics race conditions -- replaces deprecated CancelToken
- **httr2 req_retry**: Exponential backoff for PubTator API rate limiting -- already used in 17+ API files
- **dplyr group_by + summarise with `.groups = "drop"`**: Cross-database category aggregation fix -- explicit ungrouping prevents silent data corruption
- **Chart.js v4.5.1 + vue-chartjs**: Time-series visualization already proven in EntityTrendChart.vue
- **Bootstrap-Vue-Next v0.42.0 BTable**: Admin UI tables already validated in ManageAnnotations.vue

See: `.planning/research/STACK.md`

### Expected Features

**Must fix (blocking for release):**
- **#173** CurationComparisons per-source category display -- shows wrong cross-database max instead of per-source values
- **#170** PubTator incremental update -- broken since Jan 2025, 96% annotation storage failure rate
- **#172-1** Re-review approval tracking -- leaderboard shows 100% pending despite completed work
- **#171** Entity trend chart aggregation -- cumulative totals incorrect due to sparse data

**Should fix (quality/maintainability):**
- **#172-2** Dynamic percentage denominator -- hardcoded 3650 will diverge from reality
- **#172-5** Defensive data handling -- prevents crashes on edge cases
- **#169** Traefik Host() matcher -- TLS cert renewal deadline Feb 19, 2026

**Can defer (low impact):**
- **#172-3** KPI race condition -- rare timing issue
- **#172-4** Off-by-one date range -- 1-day error in delta calculation
- **#172-7** Granularity change stale data -- transient UI glitch

**Requires curator coordination:**
- **#167** Entity data integrity audit -- 13 entities need curator review; build UI now, fixes happen post-release

**Anti-features (deliberately do not build):**
- Automated suffix-gene misalignment fixes (requires curator judgment)
- Real-time AdminStatistics refresh (weekly review tool, not live dashboard)
- Bulk entity disease reassignment (each of 13 entities needs individual review)

See: `.planning/research/FEATURES.md`

### Architecture Approach

All fixes are surgical interventions in an existing architecture with well-established patterns. The R API follows repository + service + endpoint layering; the Vue frontend uses composables + components + views. Fixes introduce 7 new files and modify 14 existing files. No schema changes, no new dependencies, no architectural pivots.

**Major integration points:**
1. **Shared utilities extraction** (DRY) -- `timeSeriesUtils.ts`, `dateUtils.ts`, `category-normalization.R` serve multiple bugs
2. **Repository layer enhancement** -- `sync_rereview_approval()` hooks into all approval pathways via Open-Closed Principle
3. **SQL query fix** -- PubTator LEFT JOIN for incremental-only annotation fetching
4. **New admin view** -- `ManageEntityIntegrity.vue` with full-stack implementation (endpoint + component + route)
5. **Docker config patch** -- Traefik router labels with Host() matcher

See: `.planning/research/ARCHITECTURE.md`

### Critical Pitfalls

1. **dplyr implicit grouping after summarise()** -- Default `.groups = "drop_last"` leaves residual grouping that produces visually correct but semantically wrong aggregations. Always use `.groups = "drop"` and verify with `is_grouped_df()`. Directly relevant to #173.

2. **Sparse time-series aggregation creates misleading trends** -- Forward-fill on cumulative data requires carrying forward the last known cumulative value, not the last count. Summing across categories without gap-filling produces impossible downward spikes. Directly relevant to #171.

3. **Multi-table approval sync without transaction safety** -- Re-review approval touches 3 tables across multiple code paths. Without `db_with_transaction()`, concurrent requests create inconsistent state (approved in one table, pending in another). Directly relevant to #172-1.

4. **Non-idempotent batch INSERTs for PubTator annotations** -- Retries and overlapping batches cause duplicate key errors. Use `INSERT IGNORE` or `ON DUPLICATE KEY UPDATE`. Directly relevant to #170.

5. **Non-idempotent database migration scripts** -- Migration #006 for entity integrity fixes must use stored procedure guards or IF NOT EXISTS patterns to survive re-application. Directly relevant to #167.

See: `.planning/research/PITFALLS.md`

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Foundation Fixes (Independent, Low Risk)

**Rationale:** These three fixes have zero dependencies on each other and no dependencies on other phases. They establish shared utilities that later phases consume. Starting here builds confidence and delivers immediate user-visible improvements.

**Delivers:** Correct CurationComparisons display, clean Traefik TLS, reusable time-series utility

**Addresses:**
- Bug #173: CurationComparisons per-source category (backend fix + helper extraction)
- Bug #169: Traefik Host() matcher for TLS (config-only, has Feb 19 deadline)
- Bug #171: Entity trend chart aggregation (new `timeSeriesUtils.ts` utility)

**Avoids:** Pitfall 1 (dplyr grouping -- use `.groups = "drop"`), Pitfall 2 (sparse time-series -- forward-fill cumulative values), Pitfall 7 (Traefik v3 syntax -- test routing in staging)

### Phase 2: AdminStatistics Sub-Bugs (Interconnected)

**Rationale:** The 7 AdminStatistics sub-bugs have explicit ordering constraints: #172-3 (KPI race fix) depends on #171 (trend aggregation from Phase 1). The remaining sub-bugs (#172-2, #172-4, #172-5, #172-7) are independent but naturally group together as they all modify the same AdminStatistics.vue component.

**Delivers:** Correct re-review leaderboard, dynamic percentages, defensive data handling, request cancellation

**Addresses:**
- Bug #172-1: Re-review approval sync (repository hook + backfill script)
- Bug #172-2: Dynamic percentage denominator (replace magic number)
- Bug #172-3: KPI race condition (move 2 lines, depends on Phase 1)
- Bug #172-4: Inclusive date range calculation (extract utility)
- Bug #172-5: Defensive data handling (safe array extraction, clamp positive)
- Bug #172-7: Request cancellation on granularity change (AbortController)

**Avoids:** Pitfall 3 (transaction safety -- `db_with_transaction()` for approval sync), Pitfall 8 (AbortController memory leaks -- new controller per request)

### Phase 3: PubTator Backend Fix

**Rationale:** Independent of other phases but requires careful testing with external API. The fix involves SQL query changes and deduplication logic that should be validated thoroughly before the backfill job runs. Keeping this separate isolates external API risk.

**Delivers:** Working PubTator incremental updates, annotation backfill for ~2,900 PMIDs

**Addresses:**
- Bug #170: PubTator annotation storage (LEFT JOIN for missing-only, INSERT IGNORE for dedup, rate-limited backfill)

**Avoids:** Pitfall 4 (non-idempotent batch INSERTs -- use INSERT IGNORE), external API rate limiting (350ms delay between calls)

### Phase 4: Entity Data Integrity Audit

**Rationale:** This is the highest-complexity item (full-stack: new admin endpoint, new Vue component, route registration, migration script). It also requires curator availability for the actual data fixes post-deployment. Building it last means all simpler patterns are validated first, and the UI can be shipped independently of curator action.

**Delivers:** Admin UI for 13 suffix-gene misalignment entities, fixability classification, curator decision workflow

**Addresses:**
- Bug #167: Entity data integrity audit (detection query, admin UI, compatibility row generation, orphaned pointer fix)

**Avoids:** Pitfall 5 (non-idempotent migrations -- stored procedure guards), Pitfall 6 (API schema changes -- use separate endpoint for audit data)

### Phase Ordering Rationale

- **Dependency chain:** Phase 1 produces `timeSeriesUtils.ts` which Phase 2 consumes (Bug #172-3 depends on #171)
- **Risk escalation:** Phases ordered from lowest to highest complexity (Low -> Medium -> Medium -> Very High)
- **Isolation:** Phase 3 (PubTator) is quarantined because it interacts with external NCBI API and has unique failure modes
- **Curator coordination:** Phase 4 (entity audit) is last because data fixes require human review after UI deployment
- **Deadline awareness:** Bug #169 (Traefik TLS) is in Phase 1 due to Feb 19, 2026 cert renewal deadline

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Bug #172-1):** Re-review approval sync touches 3 approval pathways and needs database schema inspection to identify all call sites for `review_approve()` and `status_approve()`
- **Phase 4 (Bug #167):** Entity integrity audit requires understanding the exact 13 misaligned entities and their correct disease mappings; curator workflow design needs discussion

Phases with standard patterns (skip research-phase):
- **Phase 1:** All three fixes use well-documented patterns (dplyr aggregation, Traefik Host(), TypeScript utility extraction)
- **Phase 3:** PubTator fix follows established httr2 retry patterns already used in 17+ API files

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No new dependencies; all versions verified current; all patterns validated in existing codebase |
| Features | HIGH | All bugs derived from detailed analysis files in `.planning/bugs/`; complexity assessments grounded in codebase inspection |
| Architecture | HIGH | All integration points map directly to existing files; no architectural changes needed |
| Pitfalls | HIGH | Critical pitfalls backed by official dplyr/MySQL docs and confirmed against SysNDD-specific code patterns |

**Overall confidence:** HIGH -- This is a bug fix milestone in a well-understood codebase with no new dependencies. All patterns are validated.

### Gaps to Address

- **PubTator API rate limit (3 req/s):** Official documentation confirms limit but empirical testing needed to verify optimal batch size (100 PMIDs per request is API recommendation, untested in SysNDD context)
- **Re-review historical backfill:** The 689 submitted re-reviews with approved underlying records need a backfill script; the exact SQL for this should be validated against production data before execution
- **Entity 4269 orphaned pointer:** `replaced_by=4271` references a nonexistent entity; the correct resolution (clear vs reassign) needs curator input
- **Traefik TLS cert renewal deadline:** Feb 19, 2026 -- this is a hard deadline that should be tracked independently of the milestone timeline

## Sources

### Primary (HIGH confidence)
- SysNDD codebase (api/, app/, docker-compose.prod.yml) -- direct inspection
- Bug analysis files in `.planning/bugs/` (7 detailed files) -- authored by project team
- GitHub issues #167, #169, #170, #171, #172, #173 -- official bug reports
- PROJECT.md -- project context and architectural history

### Secondary (MEDIUM confidence)
- [dplyr summarise documentation](https://dplyr.tidyverse.org/reference/summarise.html) -- `.groups` behavior
- [Traefik v3.6 HTTP Routers](https://doc.traefik.io/traefik/v3.6/routing/routers/) -- Host() matcher syntax
- [httr2 req_retry](https://httr2.r-lib.org/) -- exponential backoff patterns
- [Axios Cancellation](https://axios-http.com/docs/cancellation) -- AbortController integration
- [PubTator3 API Documentation](https://www.ncbi.nlm.nih.gov/research/pubtator3/) -- rate limits

### Tertiary (LOW confidence)
- Time-series sparse data handling articles -- general patterns, not R/Vue-specific
- MySQL transaction isolation articles -- general guidance applied to SysNDD context

---
*Research completed: 2026-02-08*
*Ready for roadmap: yes*
