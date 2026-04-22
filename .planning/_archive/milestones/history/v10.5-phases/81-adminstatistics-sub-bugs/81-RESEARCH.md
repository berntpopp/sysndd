# Phase 81: AdminStatistics Sub-Bugs - Research

**Researched:** 2026-02-08
**Domain:** Full-stack bug fixes (R/Plumber API + Vue 3 TypeScript frontend)
**Confidence:** HIGH

## Summary

Phase 81 fixes 7 AdminStatistics bugs covering re-review approval tracking, dynamic progress metrics, race conditions, date calculations, defensive data handling, and request cancellation. The research reveals a clear architectural pattern: repository functions already use transactions via `db_with_transaction()`, endpoint logic duplicates repository mutations, and the frontend lacks defensive utilities and request lifecycle management.

**Key findings:**
- Re-review approval sync requires a single shared utility (`sync_rereview_approval()`) called from repository transaction blocks, not endpoint duplication
- Repository functions (`review_approve()`, `status_approve()`) already use `db_with_transaction()` with proper parameter handling via `db_execute_statement()`
- Re-review endpoint currently has 60+ lines of inline SQL duplicating repository logic — should delegate instead
- Frontend has no AbortController usage anywhere; no defensive data utilities exist
- Time-series utility from Phase 80 (`mergeGroupedCumulativeSeries`) is not yet implemented but design is documented

**Primary recommendation:** Follow repository-layer pattern for sync logic, extract frontend utilities to new files in `app/src/utils/`, use existing transaction infrastructure.

## Standard Stack

### Core (Backend)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DBI | Latest | Database interface abstraction | R standard for DB operations |
| RMariaDB | Latest | MySQL/MariaDB driver | Production driver for MySQL in R |
| pool | Latest | Connection pooling | Manages connections efficiently |
| dplyr | Latest | Data manipulation | Standard tidyverse tool, used throughout codebase |

### Core (Frontend)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.x | Component framework | Project standard |
| TypeScript | Latest | Type safety | Project standard |
| Axios | Latest | HTTP client | Project standard for API calls |
| Chart.js | Latest | Charting (via vue-chartjs) | Used in ReReviewBarChart.vue |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rlang | Latest | Error handling (`abort()`) | Repository validation errors |
| logger | Latest | Structured logging | All db-helpers operations |

**Installation:** Already installed in project

## Architecture Patterns

### Recommended Project Structure (New Files)
```
api/functions/
├── re-review-sync.R          # NEW: Shared re-review approval sync utility
├── review-repository.R       # MODIFY: Add sync call in transaction
├── status-repository.R       # MODIFY: Add sync call in transaction

app/src/utils/
├── dateUtils.ts              # NEW: inclusiveDayCount(), previousPeriod()
├── apiUtils.ts               # NEW: safeArray<T>(), clampPositive()
└── timeSeriesUtils.ts        # NEW: mergeGroupedCumulativeSeries() (from Phase 80)

api/endpoints/
├── re_review_endpoints.R     # MODIFY: Delegate to repository functions
└── statistics_endpoints.R    # MODIFY: Dynamic denominator, leaderboard query

app/src/views/admin/
├── AdminStatistics.vue       # MODIFY: Add AbortController, use utilities, fix race
└── components/charts/
    └── ReReviewBarChart.vue  # MODIFY: Use clampPositive(), add third segment
```

### Pattern 1: Repository Transaction Hook (Re-Review Sync)
**What:** Shared utility called from repository transaction blocks
**When to use:** Cross-table sync that must be atomic with primary mutation
**Example:**
```r
# api/functions/re-review-sync.R
sync_rereview_approval <- function(review_ids = NULL,
                                    status_ids = NULL,
                                    approving_user_id,
                                    conn = pool) {
  if (is.null(review_ids) && is.null(status_ids)) return(invisible(NULL))

  # Build WHERE clause
  conditions <- c()
  params <- list()

  if (!is.null(review_ids) && length(review_ids) > 0) {
    placeholders <- paste(rep("?", length(review_ids)), collapse = ", ")
    conditions <- c(conditions, paste0("review_id IN (", placeholders, ")"))
    params <- c(params, as.list(review_ids))
  }

  if (!is.null(status_ids) && length(status_ids) > 0) {
    placeholders <- paste(rep("?", length(status_ids)), collapse = ", ")
    conditions <- c(conditions, paste0("status_id IN (", placeholders, ")"))
    params <- c(params, as.list(status_ids))
  }

  where_clause <- paste(conditions, collapse = " OR ")

  sql <- paste0(
    "UPDATE re_review_entity_connect ",
    "SET re_review_approved = 1, approving_user_id = ? ",
    "WHERE (", where_clause, ") ",
    "AND re_review_submitted = 1 ",
    "AND re_review_approved = 0"
  )

  all_params <- c(list(approving_user_id), params)
  db_execute_statement(sql, all_params, conn = conn)
}
```

**Integration point:**
```r
# review-repository.R, inside review_approve() transaction (after line 310)
sync_rereview_approval(
  review_ids = review_ids,
  status_ids = NULL,
  approving_user_id = approving_user_id,
  conn = conn  # Pass transaction connection
)
```

**Critical details:**
- Must be called INSIDE `db_with_transaction()` block (before closing brace)
- Use `conn = conn` parameter to participate in transaction (not global pool)
- `db_execute_statement()` and `db_execute_query()` both accept `conn` parameter
- Parameters must be unwrapped via `unname()` internally (db-helpers.R line 187, 307)

### Pattern 2: Endpoint Delegation (DRY)
**What:** Endpoints delegate to repository functions instead of inline SQL
**When to use:** When endpoint duplicates repository mutation logic
**Example:**
```r
# re_review_endpoints.R /approve/<id> — BEFORE (60+ lines inline SQL)
# ...manual UPDATE statements for status_approved, review_approved, re_review_approved...

# AFTER (delegate to repository)
function(req, res, re_review_id, status_ok = FALSE, review_ok = FALSE) {
  require_role(req, res, "Curator")

  re_review_data <- pool %>%
    tbl("re_review_entity_connect") %>%
    filter(re_review_entity_id == re_review_id) %>%
    collect()

  if (nrow(re_review_data) == 0) {
    res$status <- 404
    return(list(error = "Re-review record not found"))
  }

  # Delegate to repository (which now auto-syncs re_review_approved)
  status_approve(re_review_data$status_id, req$user_id, approved = as.logical(status_ok))
  review_approve(re_review_data$review_id, req$user_id, approved = as.logical(review_ok))

  list(message = "Re-review approved successfully")
}
```

### Pattern 3: Frontend Defensive Utilities
**What:** Boundary validation functions that prevent crashes from malformed API data
**When to use:** When mapping API responses to UI state
**Example:**
```typescript
// app/src/utils/apiUtils.ts
export function safeArray<T>(data: unknown): T[] {
  return Array.isArray(data) ? data : [];
}

export function clampPositive(n: number): number {
  return Math.max(0, n ?? 0);
}

// Usage in AdminStatistics.vue
const data = safeArray<LeaderboardItem>(response.data?.data);
leaderboardData.value = data.map((item) => ({
  user_name: item.display_name || 'Unknown',
  entity_count: item.entity_count ?? 0,
}));
```

### Pattern 4: AbortController Request Lifecycle
**What:** Create controller per request, abort on change, cleanup on unmount
**When to use:** User-triggered refetch scenarios (granularity change, date range change)
**Example:**
```typescript
// AdminStatistics.vue
import { onUnmounted } from 'vue';

let trendAbortController: AbortController | null = null;

async function fetchTrendData(): Promise<void> {
  // Cancel previous request
  trendAbortController?.abort();
  trendAbortController = new AbortController();

  // Clear stale data immediately
  trendData.value = [];
  loading.value.trend = true;

  try {
    const response = await axios.get(`${apiUrl}/api/statistics/entities_over_time`, {
      params: { aggregate: 'entity_id', group: 'category', summarize: granularity.value },
      headers: getAuthHeaders(),
      signal: trendAbortController.signal,  // Bind to request
    });
    trendData.value = mergeGroupedCumulativeSeries(response.data.data ?? []);
  } catch (error) {
    if ((error as Error).name !== 'AbortError') {  // Suppress abort errors
      console.error('Failed to fetch trend data:', error);
      makeToast('Failed to fetch trend data', 'Error', 'danger');
    }
  } finally {
    loading.value.trend = false;
  }
}

onUnmounted(() => {
  trendAbortController?.abort();
});
```

### Pattern 5: Dynamic Query Metrics
**What:** Compute denominators from COUNT queries, not hardcoded values
**When to use:** Progress percentages, coverage metrics
**Example:**
```r
# statistics_endpoints.R /rereview endpoint
re_review_all <- pool %>%
  tbl("re_review_entity_connect") %>%
  collect()

total_in_pipeline <- nrow(re_review_all)
total_submitted <- sum(re_review_all$re_review_submitted == 1, na.rm = TRUE)
percent_submitted <- if (total_in_pipeline > 0) (total_submitted / total_in_pipeline) * 100 else 0
```

### Anti-Patterns to Avoid
- **Cross-function data dependencies in Promise.all():** Parallel tasks must be independent (Bug #172-3)
- **Hardcoded magic numbers:** Denominators like 3650 become stale (Bug #172-2)
- **Endpoint-layer database writes:** Violates repository pattern, causes duplication (Bug #172-1)
- **Trusting API response shape:** Frontend must validate with `safeArray()`, `??` operators (Bug #172-5/6)
- **Reusing aborted AbortController:** Create new controller per request (Bug #172-7)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Database transactions | Manual BEGIN/COMMIT/ROLLBACK | `db_with_transaction()` | Handles connection management, auto-rollback on error, supports both pool and direct connections |
| Parameterized queries | String interpolation | `db_execute_query/statement()` with params | SQL injection protection, automatic `unname()` for `?` placeholders |
| Request cancellation | Timeout-based cancellation | `AbortController` (browser standard) | Proper cleanup, prevents orphaned requests, integrates with axios |
| API response validation | Ad-hoc null checks | `safeArray<T>()` utility | DRY, consistent behavior across all admin views |
| Date range math | Manual millisecond arithmetic | `inclusiveDayCount()` utility | Off-by-one errors common, testable pure function |

**Key insight:** The codebase already has robust transaction and query infrastructure (`db-helpers.R`). The bug is architectural (endpoint doing repository work), not technical.

## Common Pitfalls

### Pitfall 1: Multi-Table Sync Outside Transaction
**What goes wrong:** Re-review approval flag set in separate query from review/status approval, not atomic
**Why it happens:** Endpoint logic appears independent from repository logic
**How to avoid:** Call sync utility INSIDE repository transaction block, pass `conn` parameter
**Warning signs:** Multiple `db_execute_statement()` calls across related tables without `db_with_transaction()`

### Pitfall 2: Named Parameters with `?` Placeholders
**What goes wrong:** `DBI::dbBind()` fails with named lists when using `?` placeholders
**Why it happens:** R convention uses named lists, but `?` requires positional parameters
**How to avoid:** `db_execute_statement()` already calls `unname(params)` internally (line 307)
**Warning signs:** Error "number of items to replace is not a multiple of replacement length"

### Pitfall 3: Grouped Queries Without `.groups = "drop"`
**What goes wrong:** dplyr returns grouped tibble, causes downstream errors
**Why it happens:** `summarise()` retains grouping by default
**How to avoid:** Always add `.groups = "drop"` to `summarise()` calls
**Warning signs:** Unexpected grouping attributes in result tibbles
**Current code:**
```r
# statistics_endpoints.R line 703-707 (leaderboard query)
leaderboard <- re_review_with_users %>%
  group_by(user_id) %>%
  summarise(
    submitted_count = n(),
    approved_count = sum(re_review_approved == 1, na.rm = TRUE)
    # MISSING: .groups = "drop"
  )
```

### Pitfall 4: Reading `trendData` Before `fetchTrendData()` Finishes
**What goes wrong:** `kpiStats.value.totalEntities` reads from empty array, gets 0
**Why it happens:** `Promise.all([fetchTrendData(), fetchKPIStats()])` runs in parallel
**How to avoid:** Compute dependent values inside the function that owns the data
**Warning signs:** Cross-function reactive dependencies in parallel execution blocks

### Pitfall 5: Date Range Off-By-One
**What goes wrong:** Jan 10 to Jan 20 computes as 10 days instead of 11 (inclusive)
**Why it happens:** Subtraction gives difference, not count: `20 - 10 = 10`
**How to avoid:** `Math.round((end - start) / MS_PER_DAY) + 1` for inclusive count
**Warning signs:** Comparison periods don't match length, percentage deltas skewed

### Pitfall 6: Negative Bar Values from Data Inconsistency
**What goes wrong:** `submitted_count - approved_count` can be negative if data is inconsistent
**Why it happens:** No validation that approved ≤ submitted
**How to avoid:** `Math.max(0, submitted - approved)` or `clampPositive()` utility
**Warning signs:** Chart.js warnings, bars render with zero height

### Pitfall 7: Null/Undefined API Response Crashes
**What goes wrong:** `.map()` on `response.data.data` when API returns error shape `{ error: "..." }`
**Why it happens:** No type guard at API boundary
**How to avoid:** `safeArray<T>(response.data?.data)` returns `[]` on any failure
**Warning signs:** "Cannot read property 'map' of undefined" in production logs

### Pitfall 8: Reusing Aborted AbortController
**What goes wrong:** Cannot reuse an aborted controller, subsequent requests fail
**Why it happens:** Trying to optimize by reusing controller object
**How to avoid:** Create new `AbortController()` at start of each fetch function
**Warning signs:** "AbortError" on first request, not just when aborting

### Pitfall 9: File Sourcing Order in start_sysndd_api.R
**What goes wrong:** Service functions shadow repository functions if sourced before them
**Why it happens:** `source()` with `local = TRUE` evaluates in order, last wins for name conflicts
**How to avoid:** Repository functions sourced BEFORE services (lines 114-122 vs 159-166)
**Warning signs:** Repository function called but service implementation runs instead
**For this phase:** New `re-review-sync.R` should be sourced around line 122 (after status-repository.R, before legacy-wrappers.R)

## Code Examples

Verified patterns from current codebase:

### Transaction Pattern (review-repository.R:264-330)
```r
# Source: /home/bernt-popp/development/sysndd/api/functions/review-repository.R
review_approve <- function(review_ids, approving_user_id, approved = TRUE) {
  review_ids <- as.integer(review_ids)

  # Validate inputs
  if (length(review_ids) == 0) {
    rlang::abort(
      message = "review_ids cannot be empty",
      class = c("review_validation_error", "validation_error")
    )
  }

  # Use transaction for atomic multi-statement operation
  db_with_transaction({
    # Get entity_ids for these reviews
    review_placeholders <- paste(rep("?", length(review_ids)), collapse = ", ")
    sql_get_entities <- paste0(
      "SELECT entity_id FROM ndd_entity_review WHERE review_id IN (",
      review_placeholders, ")"
    )
    entity_data <- db_execute_query(sql_get_entities, as.list(review_ids))
    entity_ids <- unique(entity_data$entity_id)

    if (approved) {
      # Reset all reviews to not primary
      entity_placeholders <- paste(rep("?", length(entity_ids)), collapse = ", ")
      sql_reset_primary <- paste0(
        "UPDATE ndd_entity_review SET is_primary = 0 WHERE entity_id IN (",
        entity_placeholders, ")"
      )
      db_execute_statement(sql_reset_primary, as.list(entity_ids))

      # Set specified reviews to primary
      sql_set_primary <- paste0(
        "UPDATE ndd_entity_review SET is_primary = 1 WHERE review_id IN (",
        review_placeholders, ")"
      )
      db_execute_statement(sql_set_primary, as.list(review_ids))

      # Add approving_user_id
      sql_set_user <- paste0(
        "UPDATE ndd_entity_review SET approving_user_id = ? WHERE review_id IN (",
        review_placeholders, ")"
      )
      db_execute_statement(sql_set_user, c(list(approving_user_id), as.list(review_ids)))

      # Set review_approved = 1
      sql_set_approved <- paste0(
        "UPDATE ndd_entity_review SET review_approved = 1 WHERE review_id IN (",
        review_placeholders, ")"
      )
      db_execute_statement(sql_set_approved, as.list(review_ids))
    } else {
      # Rejection: set approving_user_id and review_approved = 0
      sql_set_user <- paste0(
        "UPDATE ndd_entity_review SET approving_user_id = ? WHERE review_id IN (",
        review_placeholders, ")"
      )
      db_execute_statement(sql_set_user, c(list(approving_user_id), as.list(review_ids)))

      sql_set_rejected <- paste0(
        "UPDATE ndd_entity_review SET review_approved = 0 WHERE review_id IN (",
        review_placeholders, ")"
      )
      db_execute_statement(sql_set_rejected, as.list(review_ids))
    }

    # INSERT SYNC CALL HERE (after line 326, before return)

    return(review_ids)
  })
}
```

### Leaderboard Query (statistics_endpoints.R:662-709)
```r
# Source: /home/bernt-popp/development/sysndd/api/endpoints/statistics_endpoints.R:662-709
# Current implementation (filters to submitted only)
re_review_data <- pool %>%
  tbl("re_review_entity_connect") %>%
  collect() %>%
  filter(re_review_submitted == 1) %>%  # REMOVE THIS FILTER for three-segment chart
  left_join(review_dates, by = "review_id") %>%
  left_join(status_dates, by = "status_id")

# Aggregate by user
leaderboard <- re_review_with_users %>%
  group_by(user_id) %>%
  summarise(
    submitted_count = n(),
    approved_count = sum(re_review_approved == 1, na.rm = TRUE)
    # ADD: .groups = "drop"
    # ADD: total_assigned = n()  (when filter removed)
  ) %>%
  arrange(desc(submitted_count))
```

### Frontend Data Extraction (AdminStatistics.vue:536-541)
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/views/admin/AdminStatistics.vue:536-541
// Current pattern for unwrapping R/Plumber arrays
const extractValue = (val: number | number[]): number =>
  Array.isArray(val) ? (val[0] ?? 0) : (val ?? 0);

return {
  total_new_entities: extractValue(response.data.total_new_entities),
  unique_genes: extractValue(response.data.unique_genes),
  average_per_day: extractValue(response.data.average_per_day),
};
```

### Chart Data Mapping (ReReviewBarChart.vue:51-68)
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/views/admin/components/charts/ReReviewBarChart.vue:51-68
// Current two-segment implementation
const chartData = computed(() => ({
  labels: props.reviewers.map((r) => r.user_name),
  datasets: [
    {
      label: 'Approved',
      data: props.reviewers.map((r) => r.approved_count),
      backgroundColor: COLORS.approved,
    },
    {
      label: 'Pending',
      data: props.reviewers.map((r) => r.submitted_count - r.approved_count),
      // NEEDS: clampPositive() wrapper
      backgroundColor: COLORS.submitted,
    },
    // ADD: 'Not Yet Submitted' segment
  ],
}));
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Endpoint inline SQL for approvals | Repository functions with transactions | Established pattern | Re-review endpoint violates this (Bug #172-1) |
| Hardcoded denominator (3650) | Dynamic COUNT query | Should change in v10.5 | Makes metrics accurate as database grows |
| Cross-function dependencies in Promise.all | Compute derived values inside owning function | Should change in v10.5 | Eliminates race conditions |
| Manual date arithmetic | Utility functions (`inclusiveDayCount`) | New pattern for v10.5 | Prevents off-by-one errors |
| Trust API response shape | Defensive utilities (`safeArray<T>`) | New pattern for v10.5 | Prevents crashes from malformed responses |

**Deprecated/outdated:**
- Inline SQL in endpoints when repository function exists (use delegation instead)
- Magic numbers for progress percentages (compute from COUNT queries)
- Parallel fetches with cross-dependencies (restructure to make independent)

## Open Questions

1. **Re-review backfill script location and execution**
   - What we know: Bug fix proposal mentions sysndd-administration#1 tracking script
   - What's unclear: Whether backfill runs in this phase or separately, CI integration
   - Recommendation: Phase 81 implements prospective fix only; backfill is separate admin task (not in CI)

2. **R/Plumber array wrapping behavior**
   - What we know: API returns scalars as single-element arrays `[value]`
   - What's unclear: Whether this is configurable via Plumber serializer settings
   - Recommendation: Keep `extractValue()` pattern; changing serializer might break existing clients

3. **Re-review leaderboard three-segment data shape**
   - What we know: Need `total_assigned`, `submitted_count`, `approved_count`
   - What's unclear: Whether API should compute pending client-side or server-side
   - Recommendation: Return all three raw counts; client computes pending = submitted - approved (with clamping)

4. **AbortController support in all admin endpoints**
   - What we know: Phase 81 only adds to `fetchTrendData()`
   - What's unclear: Whether other fetches (leaderboard, KPIs) need cancellation
   - Recommendation: Add to `fetchTrendData()` only (granularity change is only user-triggered refetch)

## Sources

### Primary (HIGH confidence)
- `/home/bernt-popp/development/sysndd/api/functions/review-repository.R` - Transaction pattern, parameter handling
- `/home/bernt-popp/development/sysndd/api/functions/status-repository.R` - Status approval parallel implementation
- `/home/bernt-popp/development/sysndd/api/functions/db-helpers.R` - Transaction utilities, connection management
- `/home/bernt-popp/development/sysndd/api/endpoints/re_review_endpoints.R` - Current inline SQL duplication
- `/home/bernt-popp/development/sysndd/api/endpoints/statistics_endpoints.R` - Leaderboard query, hardcoded denominator
- `/home/bernt-popp/development/sysndd/app/src/views/admin/AdminStatistics.vue` - Promise.all race, date calculation, data extraction
- `/home/bernt-popp/development/sysndd/app/src/views/admin/components/charts/ReReviewBarChart.vue` - Chart structure, negative values
- `/home/bernt-popp/development/sysndd/db/09_Rcommands_sysndd_db_table_re_review.R` - Schema creation script
- `/home/bernt-popp/development/sysndd/api/start_sysndd_api.R` - File sourcing order
- `/home/bernt-popp/development/sysndd/api/tests/testthat/helper-db.R` - Test patterns

### Secondary (MEDIUM confidence)
- Bug fix proposals (.planning/bugs/172-*.md) - Detailed problem analysis and proposed solutions
- Phase 80 bug fix proposal (171-entity-trend-aggregation.md) - Time-series utility design (dependency)

### Tertiary (LOW confidence)
- None (all research based on codebase inspection)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified from imports and package usage
- Architecture: HIGH - Patterns extracted from current working code
- Pitfalls: HIGH - Identified from actual bug analysis and code patterns

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (30 days - stable codebase patterns)

**Phase dependencies:**
- Phase 80 must complete first (provides `mergeGroupedCumulativeSeries()` utility)
- Bug #172-3 fix depends on #171 time-series utility being available

**Key implementation notes:**
1. Transaction sync must use `conn` parameter, not global `pool`
2. New utilities (`dateUtils.ts`, `apiUtils.ts`) go in `app/src/utils/`
3. `re-review-sync.R` sourced around line 122 in `start_sysndd_api.R`
4. Test using `skip_if_no_test_db()` pattern from helper-db.R
5. Leaderboard query needs `.groups = "drop"` added to summarise()
6. AbortController cleanup in `onUnmounted()` lifecycle hook
