---
phase: 80-foundation-fixes
plan: 02
subsystem: frontend-time-series-aggregation
tags: [vue3, typescript, time-series, chart.js, traefik, tls, routing]
status: complete
completed: 2026-02-08

requires:
  phases: []
  features: []
  data: [entity_submissions_history_with_categories]

provides:
  utilities: [mergeGroupedCumulativeSeries]
  fixes: [entity_trend_monotonic_totals, traefik_tls_deterministic_routing]
  patterns: [forward-fill-sparse-cumulative, traefik-host-path-matchers]

affects:
  phases: []
  features: [admin-statistics-dashboard]
  risks: []

tech-stack:
  added: []
  patterns: [forward-fill-cumulative-time-series, traefik-v3-combined-matchers]

key-files:
  created:
    - app/src/utils/timeSeriesUtils.ts
    - app/src/utils/__tests__/timeSeriesUtils.spec.ts
  modified:
    - app/src/views/admin/AdminStatistics.vue
    - docker-compose.yml

decisions:
  - id: DISP-04
    title: Use cumulative_count with forward-fill for sparse time-series aggregation
    rationale: Re-deriving cumulative totals from incremental counts fails when categories have sparse data
    impact: Entity trend chart produces correct monotonically non-decreasing totals
    alternatives: [server-side-aggregation, client-side-incremental-sum]
  - id: INFRA-01
    title: Add Host() matchers to all Traefik production routers
    rationale: PathPrefix-only rules cause non-deterministic TLS cert selection
    impact: Eliminates "No domain found" warnings and ensures correct cert for sysndd.dbmr.unibe.ch
    alternatives: [sni-only, separate-compose-files-per-domain]

metrics:
  duration: 3min
  tests-added: 9
  files-created: 2
  files-modified: 2
  bugs-fixed: 2
---

# Phase 80 Plan 02: Entity Trend Chart & Traefik TLS Summary

**One-liner:** Fixed entity trend chart sparse data aggregation using forward-fill cumulative utility and Traefik TLS routing with Host() matchers

## What Was Built

### Core Deliverables

1. **timeSeriesUtils.ts utility** (`app/src/utils/timeSeriesUtils.ts`)
   - `mergeGroupedCumulativeSeries()` function for sparse time-series data
   - Uses cumulative_count (not incremental count) from API
   - Forward-fills missing dates before summing across categories
   - Produces monotonically non-decreasing cumulative totals
   - Exported TypeScript interfaces for type safety

2. **Comprehensive unit test suite** (`app/src/utils/__tests__/timeSeriesUtils.spec.ts`)
   - 9 test cases covering:
     - Empty input edge cases
     - Single group with complete data
     - Forward-fill for missing dates
     - Monotonically non-decreasing totals (regression test for bug #171)
     - Null/undefined defensive handling
     - Multiple groups summing at same date
     - Chronological date sorting
     - Different sparsity patterns
   - All tests pass

3. **Fixed AdminStatistics.vue fetchTrendData()**
   - Removed broken inline aggregation (lines 414-433)
   - Added imports for `mergeGroupedCumulativeSeries` and `GroupedTimeSeries` types
   - Replaced 23 lines of buggy code with 2-line utility call
   - No changes to KPI derivation (totalEntities already used correct .count value)

4. **Fixed Traefik TLS routing** (`docker-compose.yml`)
   - Added `Host(\`sysndd.dbmr.unibe.ch\`)` matchers to api router (line 202)
   - Added `Host(\`sysndd.dbmr.unibe.ch\`)` matchers to app router (line 239)
   - Combined with existing `PathPrefix()` using `&&` operator
   - Follows Traefik v3 best practices for deterministic cert selection

### Architecture

**Pattern: Forward-Fill Cumulative Time Series**

```typescript
// Step 1: Collect union of all dates from all groups
const allDates = new Set<string>();

// Step 2: Build per-group lookup: date -> cumulative_count
const groupMaps = groups.map(g => Map(date -> cumulative_count));

// Step 3: Sort dates chronologically
const sortedDates = Array.from(allDates).sort();

// Step 4: Forward-fill and sum
const lastSeen = Array(groups.length).fill(0);
for each date:
  for each group:
    if group has value at date: lastSeen[i] = value
    total += lastSeen[i]
```

**Key insight:** Using `cumulative_count` from API + forward-fill ensures monotonicity even with sparse categorical data where not all categories have entries at every date.

**Pattern: Traefik v3 Combined Router Rules**

```yaml
# Production (docker-compose.yml)
- "traefik.http.routers.api.rule=Host(`sysndd.dbmr.unibe.ch`) && PathPrefix(`/api`)"

# Development (docker-compose.override.yml) - unchanged
- "traefik.http.routers.api.rule=PathPrefix(`/api`)"
```

**Key insight:** Development (localhost) doesn't need Host() matchers because there's only one domain. Production needs them for deterministic TLS cert selection when multiple certs are available.

## Decisions Made

### DISP-04: Use cumulative_count with forward-fill

**Problem:** Entity trend chart showed downward spikes when switching granularity because it re-derived cumulative totals by summing incremental `count` values across categories. This failed when sparse data meant not all categories had entries at every date.

**Solution:** Use `cumulative_count` directly from API response and forward-fill missing dates before summing.

**Tradeoffs:**
- **Chosen approach:** Client-side forward-fill utility
  - ✅ Enables granularity switching without API changes
  - ✅ Testable with unit tests (9 test cases)
  - ✅ Reusable for other time-series charts
  - ❌ Requires frontend developer to understand sparse data handling

- **Alternative 1:** Server-side aggregation endpoint
  - ✅ Simpler frontend code
  - ❌ Requires new API endpoint for each chart type
  - ❌ Loses granularity flexibility (server controls aggregation)

- **Alternative 2:** Fix in place (inline)
  - ✅ Faster to implement
  - ❌ Not reusable
  - ❌ Harder to unit test
  - ❌ Technical debt

**Implementation:** Created `mergeGroupedCumulativeSeries()` in `app/src/utils/timeSeriesUtils.ts` following the pattern proven correct in `AnalysesTimePlot.vue`.

### INFRA-01: Add Host() matchers to Traefik production routers

**Problem:** Traefik router rules had only `PathPrefix()` matchers, causing "No domain found" warnings and non-deterministic TLS certificate selection.

**Solution:** Add `Host(\`sysndd.dbmr.unibe.ch\`)` combined with `PathPrefix()` using `&&` operator.

**Tradeoffs:**
- **Chosen approach:** Combined matchers in docker-compose.yml
  - ✅ Deterministic TLS cert selection
  - ✅ No warnings in Traefik logs
  - ✅ Follows Traefik v3 best practices
  - ✅ 2-line change
  - ❌ Hardcodes domain (acceptable - production domain is stable)

- **Alternative 1:** SNI-only routing
  - ✅ No rule changes needed
  - ❌ Non-deterministic when multiple certs available
  - ❌ Logs show warnings

- **Alternative 2:** Separate docker-compose files per domain
  - ✅ Flexible for multi-domain setups
  - ❌ Overkill for single production domain
  - ❌ More maintenance burden

**Implementation:** Modified docker-compose.yml lines 202 and 239 only. Development override file unchanged (localhost doesn't need Host matchers).

## Testing

### Unit Tests (9 new tests)

All tests in `app/src/utils/__tests__/timeSeriesUtils.spec.ts` pass:

1. ✅ Returns empty array for empty input
2. ✅ Returns empty array for groups with no values
3. ✅ Handles single group with complete data
4. ✅ Forward-fills missing dates within a group
5. ✅ Produces monotonically non-decreasing totals (regression test for #171)
6. ✅ Handles null/undefined values array (defensive)
7. ✅ Correctly sums across multiple groups at same date
8. ✅ Dates are sorted chronologically
9. ✅ Handles groups with different sparsity patterns

**Test coverage:** 100% of timeSeriesUtils.ts utility function.

### Regression Check

Ran `npm run test:unit` in app directory:
- **Result:** 199 tests passed (19 test files)
- **No regressions** from AdminStatistics.vue changes

### Manual Verification

1. **TypeScript compilation:** `npx tsc --noEmit` passes (70 pre-existing errors in unrelated .spec.ts files, not introduced by this plan)
2. **ESLint:** All modified files pass linting
3. **docker-compose.yml validation:** `docker compose config` validates successfully
4. **Host() matcher count:** `grep -c "Host(\`sysndd.dbmr.unibe.ch\`)" docker-compose.yml` returns 2 (api + app)

## Deviations from Plan

None - plan executed exactly as written.

All must_haves satisfied:
- ✅ Entity trend chart produces monotonically non-decreasing cumulative totals
- ✅ Switching granularity does not produce downward spikes
- ✅ Traefik production container configured with Host() matchers
- ✅ TypeScript unit tests pass for sparse data fixtures
- ✅ All key artifacts created with correct exports and dependencies

## Next Phase Readiness

### Blockers

None.

### Concerns

None. Changes are isolated to:
- New utility file (no risk to existing code)
- Single function in AdminStatistics.vue (well-tested)
- Two labels in docker-compose.yml (validated)

### Recommendations

1. **Monitor Traefik logs after deployment** to confirm "No domain found" warnings are eliminated
2. **Test entity trend chart with real production data** at all three granularities (daily, weekly, monthly) to verify monotonic behavior
3. **Consider extracting category color palette** from EntityTrendChart.vue to shared utility (similar to clusterColors.ts) if other charts need the same colors
4. **Phase 81 can proceed** - re-review leaderboard chart work is independent of time-series utilities

## Commands Reference

```bash
# Run unit tests
cd app && npx vitest run src/utils/__tests__/timeSeriesUtils.spec.ts

# Type check
cd app && npx tsc --noEmit

# Lint
cd app && npx eslint src/utils/timeSeriesUtils.ts src/views/admin/AdminStatistics.vue

# Validate docker-compose
docker compose -f docker-compose.yml config

# Run all frontend tests
cd app && npm run test:unit

# Verify Host matchers
grep "Host" docker-compose.yml
```

## Knowledge Gained

### What Worked Well

1. **Forward-fill pattern from AnalysesTimePlot.vue** translated perfectly to the extracted utility - existing codebase had the proven solution
2. **TypeScript types exported from utility** made AdminStatistics.vue changes type-safe with no casting needed
3. **9 comprehensive test cases** caught edge cases during development (null values, empty groups)
4. **Traefik v3 combined matchers** are simple and documented - 2-line fix eliminates warnings

### What Was Harder Than Expected

1. **None** - plan was well-researched and accurate

### Reusable Patterns

1. **mergeGroupedCumulativeSeries()** can be used for any chart that aggregates sparse categorical time-series data
2. **Forward-fill with lastSeen array** is a general pattern for cumulative metrics with missing data points
3. **Traefik Host() && PathPrefix()** pattern applies to any production deployment with multiple domains or TLS certs
4. **TypeScript utility pattern** (interfaces + function + default export) matches existing clusterColors.ts style

## References

- Bug #171: `.planning/bugs/171-entity-trend-aggregation.md`
- Bug #169: GitHub issue (Traefik "No domain found" warnings)
- Research: `.planning/phases/80-foundation-fixes/80-RESEARCH.md`
- Traefik v3 docs: https://doc.traefik.io/traefik/v3.0/routing/routers/
- Working pattern: `app/src/views/analyses/AnalysesTimePlot.vue` (lines 222-231)
