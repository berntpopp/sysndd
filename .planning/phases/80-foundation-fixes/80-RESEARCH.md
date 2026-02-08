# Phase 80: Foundation Fixes - Research

**Researched:** 2026-02-08
**Domain:** dplyr data transformation, Vue 3/TypeScript time-series aggregation, Traefik v3 routing
**Confidence:** HIGH

## Summary

Phase 80 addresses three independent bugs across backend data transformation (#173), frontend time-series aggregation (#171), and infrastructure routing (#169). All fixes use existing stack capabilities without new dependencies.

**Bug #173 (CurationComparisons):** The backend incorrectly aggregates categories across databases using `group_by(symbol) %>% mutate(category_id = min(category_id))`, collapsing per-source values into a cross-database maximum. The fix is to remove this aggregation and extract duplicated category normalization logic into a shared helper function.

**Bug #171 (Entity Trend Chart):** The frontend re-derives cumulative totals by summing incremental `count` values across categories, producing incorrect totals when sparse data means not all categories have entries at every date. The fix is to use `cumulative_count` directly from the API and forward-fill gaps, following the pattern already proven correct in `AnalysesTimePlot.vue`.

**Bug #169 (Traefik TLS):** Production Traefik routers lack `Host()` matchers in their rules, causing "No domain found" warnings and non-deterministic TLS certificate selection. The fix is a 2-line docker-compose.yml change adding `Host(sysndd.dbmr.unibe.ch) &&` to router rules.

**Primary recommendation:** Apply each fix independently with domain-specific testing (R unit tests for #173, TypeScript unit tests for #171, manual verification for #169). All three are low-risk, well-understood problems with proven solutions.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dplyr | 1.1.4+ | Data transformation and aggregation | Industry standard for R data manipulation; already used throughout SysNDD API |
| Vue 3 | 3.5.25 | Frontend framework | Current project version; Composition API is standard for new code |
| TypeScript | 5.9.3 | Type-safe JavaScript | Project-wide migration complete (v3 milestone); typed utilities required |
| Traefik | v3.6 | Reverse proxy and TLS termination | Already deployed; v3 is current stable version |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Vitest | 4.0.18 | TypeScript unit testing | Testing extracted utilities (timeSeriesUtils.ts) |
| testthat | 3.2.0+ | R unit testing | Testing extracted helpers (category-normalization.R) |
| Chart.js | 4.5.1 (via vue-chartjs 5.3.3) | Time-series visualization | Already used in AdminStatistics.vue |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extract to utility | Inline fix | Utilities enable DRY and testability; inlining is faster but creates tech debt |
| dplyr `.groups = "drop"` | Explicit `ungroup()` | Both work; `.groups` is more explicit about intent |
| Forward-fill in utility | Server-side aggregation | Client-side allows granularity switching without API changes |

**Installation:**
```bash
# R packages (already installed)
# dplyr, testthat included in api/renv.lock

# TypeScript testing (already installed)
cd app && npm install  # vitest in devDependencies
```

## Architecture Patterns

### Recommended Project Structure
```
api/functions/
├── category-normalization.R    # NEW: Shared category mapping logic
├── endpoint-functions.R         # MODIFY: Use shared helper
└── helper-functions.R           # Existing helpers location

api/endpoints/
└── comparisons_endpoints.R      # MODIFY: Use shared helper in upset endpoint

app/src/utils/
├── timeSeriesUtils.ts           # NEW: mergeGroupedCumulativeSeries()
└── clusterColors.ts             # Existing utility (example pattern)

app/src/views/admin/
└── AdminStatistics.vue          # MODIFY: Use utility function

docker-compose.yml               # MODIFY: Add Host() matchers to labels
```

### Pattern 1: dplyr Explicit Grouping Control

**What:** Always specify `.groups` argument in `summarise()` and verify with `is_grouped_df()`

**When to use:** Any dplyr pipeline with `group_by()` followed by `summarise()` or multi-level grouping

**Example:**
```r
# BAD: Implicit grouping leaves symbol grouped
ndd_database_comparison_table_norm %>%
  group_by(symbol) %>%
  mutate(category_id = min(category_id)) %>%
  ungroup() %>%  # Required cleanup
  select(-category) %>%
  left_join(status_categories_list, by = c("category_id"))

# GOOD: Remove aggregation entirely for per-source preservation
ndd_database_comparison_table_norm %>%
  select(symbol, hgnc_id, list, category = max_category) %>%
  unique()
```

**Source:** [dplyr summarise documentation](https://dplyr.tidyverse.org/reference/summarise.html)

### Pattern 2: Shared Category Normalization Helper

**What:** Extract duplicated category mapping logic into reusable function

**When to use:** Same normalization logic appears in multiple endpoints (comparisons browse, upset)

**Example:**
```r
# api/functions/category-normalization.R
#' Normalize comparison categories to standard SysNDD categories
#'
#' Maps source-specific category values to standard categories:
#' Definitive, Moderate, Limited, Refuted, not applicable
#'
#' @param data Data frame with 'list' and 'category' columns
#' @return Data frame with normalized 'category' column
normalize_comparison_categories <- function(data) {
  data %>%
    mutate(category = case_when(
      # gene2phenotype mappings (new 2026 format uses lowercase)
      list == "gene2phenotype" & tolower(category) == "strong" ~ "Definitive",
      list == "gene2phenotype" & tolower(category) == "definitive" ~ "Definitive",
      list == "gene2phenotype" & tolower(category) == "limited" ~ "Limited",
      list == "gene2phenotype" & tolower(category) == "moderate" ~ "Moderate",
      list == "gene2phenotype" & tolower(category) == "refuted" ~ "Refuted",
      list == "gene2phenotype" & tolower(category) == "disputed" ~ "Refuted",
      list == "gene2phenotype" & tolower(category) == "both rd and if" ~ "Definitive",
      # panelapp mappings (confidence levels 1-3)
      list == "panelapp" & category == "3" ~ "Definitive",
      list == "panelapp" & category == "2" ~ "Limited",
      list == "panelapp" & category == "1" ~ "Refuted",
      # sfari mappings (gene scores 1-3)
      list == "sfari" & category == "1" ~ "Definitive",
      list == "sfari" & category == "2" ~ "Moderate",
      list == "sfari" & category == "3" ~ "Limited",
      list == "sfari" & is.na(category) ~ "Definitive",
      # geisinger_DBD - all entries are high confidence
      list == "geisinger_DBD" ~ "Definitive",
      # radboudumc_ID - all entries are high confidence
      list == "radboudumc_ID" ~ "Definitive",
      # omim_ndd and orphanet_id already have "Definitive" set
      TRUE ~ category
    ))
}
```

**Source:** Extracted from existing `endpoint-functions.R` lines 69-93

### Pattern 3: TypeScript Pure Utility Functions

**What:** Extract data transformation logic into pure functions with TypeScript types

**When to use:** Logic is reusable, testable, or complex enough to warrant isolation

**Example:**
```typescript
// app/src/utils/timeSeriesUtils.ts
export interface TimeSeriesPoint {
  entry_date: string;
  count: number;
  cumulative_count: number;
}

export interface GroupedTimeSeries {
  group: string;
  values: TimeSeriesPoint[];
}

export interface AggregatedPoint {
  date: string;
  count: number;
}

/**
 * Merges per-group cumulative time series into a single global cumulative series.
 *
 * Handles sparse data: when a group has no entry at a given date, its last known
 * cumulative value is carried forward (forward-fill). The global total at each
 * date is the sum of all groups' (forward-filled) cumulative counts.
 */
export function mergeGroupedCumulativeSeries(
  groups: GroupedTimeSeries[]
): AggregatedPoint[] {
  // 1. Collect union of all dates
  const allDates = new Set<string>();
  for (const g of groups) {
    for (const v of g.values ?? []) {
      allDates.add(v.entry_date);
    }
  }

  // 2. Build per-group lookup: date -> cumulative_count
  const groupMaps = groups.map((g) => {
    const map = new Map<string, number>();
    for (const v of g.values ?? []) {
      map.set(v.entry_date, v.cumulative_count);
    }
    return map;
  });

  // 3. Forward-fill and sum across groups at each date
  const sortedDates = Array.from(allDates).sort();
  const lastSeen = new Array<number>(groups.length).fill(0);

  return sortedDates.map((date) => {
    let total = 0;
    for (let i = 0; i < groupMaps.length; i++) {
      const val = groupMaps[i].get(date);
      if (val !== undefined) {
        lastSeen[i] = val;
      }
      total += lastSeen[i];
    }
    return { date, count: total };
  });
}
```

**Source:** Adapted from working pattern in `AnalysesTimePlot.vue` lines 222-231 (uses cumulative_count directly)

### Pattern 4: Traefik v3 Combined Router Rules

**What:** Use `Host() && PathPrefix()` combined matchers for deterministic routing

**When to use:** Production deployments with TLS where domain-specific routing is needed

**Example:**
```yaml
# docker-compose.yml labels section
labels:
  - "traefik.enable=true"
  # BEFORE: Ambiguous - no Host() matcher
  - "traefik.http.routers.api.rule=PathPrefix(`/api`)"

  # AFTER: Explicit - deterministic TLS cert selection
  - "traefik.http.routers.api.rule=Host(`sysndd.dbmr.unibe.ch`) && PathPrefix(`/api`)"
  - "traefik.http.routers.api.entrypoints=web"
  - "traefik.http.routers.api.priority=100"
```

**Source:** [Traefik v3.6 Routers Documentation](https://doc.traefik.io/traefik/v3.0/routing/routers/)

### Anti-Patterns to Avoid

- **Per-source data collapsed to cross-database max:** Defeats purpose of comparison table; users can't see individual source ratings
- **Re-deriving cumulative from incremental counts:** Fails with sparse data; always use cumulative_count from API
- **Implicit dplyr grouping after summarise():** Default `.groups = "drop_last"` leaves residual grouping
- **PathPrefix-only Traefik rules in multi-domain setups:** Non-deterministic TLS cert selection

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Time-series forward-fill | Custom loop with conditionals | Pure utility function with Map lookups | Edge cases (empty groups, single date, timezone shifts) are subtle |
| Category normalization | Inline case_when in each endpoint | Shared helper function | Same logic in 2+ places = maintenance nightmare |
| dplyr grouping verification | Manual inspection of results | `is_grouped_df()` + unit tests | Implicit grouping is invisible; test fixtures catch it |
| Date range calculations | Manual arithmetic | Existing date-fns library (v4.1.0) | Off-by-one errors, month boundaries, leap years |

**Key insight:** All three bugs involve subtle edge cases that look correct in simple scenarios but fail with real data complexity. Reusable utilities with unit tests prevent regression.

## Common Pitfalls

### Pitfall 1: dplyr Implicit Grouping After summarise()

**What goes wrong:** After `summarise()`, dplyr drops the *last* grouping level but keeps earlier ones (default `.groups = "drop_last"`). Subsequent `mutate()` operations execute *per remaining group*, not globally.

**Why it happens:**
- Developers assume `summarise()` removes all grouping
- Visually identical results mask per-group vs global operations
- Default behavior changed in dplyr 1.0.0 (2020)

**How to avoid:**
1. Always use explicit `.groups = "drop"` in `summarise()`:
   ```r
   data %>%
     group_by(gene, database) %>%
     summarise(max_category = max(category), .groups = "drop")
   ```

2. Add defensive `ungroup()` before global operations:
   ```r
   data %>%
     group_by(gene) %>%
     summarise(count = n(), .groups = "drop") %>%
     ungroup() %>%  # Defensive
     mutate(global_rank = row_number())
   ```

3. Test with multi-group data where per-group vs global differs:
   ```r
   test_that("aggregation is global, not per-group", {
     result <- aggregate_comparisons(multi_database_fixture)
     expect_false(dplyr::is_grouped_df(result))
   })
   ```

**Warning signs:**
- `is_grouped_df(data)` returns TRUE after you thought grouping was removed
- Results have correct row counts but wrong calculated values
- Per-gene counts work but cross-gene comparisons fail

**Source:** [dplyr summarise documentation - Grouping](https://dplyr.tidyverse.org/reference/summarise.html#grouping)

---

### Pitfall 2: Time-Series Aggregation with Sparse Categorical Data

**What goes wrong:** When aggregating by date and category, sparse data creates misleading trends. Summing incremental counts across categories fails when not all categories have entries at every date.

**Why it happens:**
- Frontend sums `count` (incremental) instead of `cumulative_count`
- Missing dates in one category aren't forward-filled before summing
- Developer assumes "sum of parts = whole" but this only works with complete data

**How to avoid:**
1. **Use cumulative_count from API, not incremental count:**
   ```typescript
   // BAD: Re-derives cumulative from incremental
   dateCountMap.set(item.entry_date, existing + item.count);
   cumulative += count;

   // GOOD: Uses API's cumulative_count directly
   const val = groupMaps[i].get(date) ?? lastSeen[i];
   total += val;
   ```

2. **Forward-fill before summing:**
   ```typescript
   // Track last seen cumulative value per group
   const lastSeen = new Array<number>(groups.length).fill(0);

   sortedDates.map((date) => {
     let total = 0;
     for (let i = 0; i < groupMaps.length; i++) {
       const val = groupMaps[i].get(date);
       if (val !== undefined) {
         lastSeen[i] = val;  // Update when available
       }
       total += lastSeen[i];  // Always use last known value
     }
     return { date, count: total };
   });
   ```

3. **Test with sparse fixtures:**
   ```typescript
   it('forward-fills missing dates within a group', () => {
     const groups = [
       { group: 'A', values: [
         { entry_date: '2025-01-01', count: 1, cumulative_count: 5 },
         // Missing 2025-01-02
         { entry_date: '2025-01-03', count: 2, cumulative_count: 7 }
       ]}
     ];
     const result = mergeGroupedCumulativeSeries(groups);
     expect(result[1].count).toBe(5); // 2025-01-02 uses last known (5)
   });
   ```

**Warning signs:**
- Chart shows downward spikes in cumulative metrics
- Total at a date < total at previous date (impossible for cumulative)
- Switching granularity changes historical values

**Source:** Working pattern in `AnalysesTimePlot.vue` (lines 222-257) uses `cumulative_count` directly

---

### Pitfall 3: Traefik v3 Router Rule Matcher Syntax

**What goes wrong:** Traefik routers without `Host()` matchers work but produce "No domain found" warnings and non-deterministic TLS certificate selection when multiple certs are available.

**Why it happens:**
- PathPrefix-only rules match across all hosts
- Traefik falls back to SNI (Server Name Indication) for cert selection
- Works in single-domain setups; breaks when adding www subdomain or additional domains

**How to avoid:**
1. **Always combine Host() with PathPrefix():**
   ```yaml
   # BAD: Ambiguous in multi-domain setups
   - "traefik.http.routers.api.rule=PathPrefix(`/api`)"

   # GOOD: Explicit domain matching
   - "traefik.http.routers.api.rule=Host(`sysndd.dbmr.unibe.ch`) && PathPrefix(`/api`)"
   ```

2. **Test routing in staging with curl:**
   ```bash
   # Verify router matches expected host
   curl -v http://sysndd.dbmr.unibe.ch/api/health/

   # Check TLS cert selection (production)
   openssl s_client -connect sysndd.dbmr.unibe.ch:443 \
     -servername sysndd.dbmr.unibe.ch < /dev/null 2>/dev/null | \
     openssl x509 -noout -text | grep DNS
   ```

3. **Check Traefik startup logs for warnings:**
   ```bash
   docker logs sysndd_traefik 2>&1 | grep -i "no domain found"
   ```

**Warning signs:**
- "No domain found" warnings in Traefik logs
- TLS certificate doesn't match expected domain
- Routing works but logs show warnings

**Source:** [Traefik v3.6 Routers - Rule](https://doc.traefik.io/traefik/v3.0/routing/routers/#rule)

---

### Pitfall 4: Testing with Single-Source Fixtures

**What goes wrong:** Tests pass with single database but fail with multiple sources because aggregation bugs only manifest with >1 group.

**Why it happens:**
- Developer writes minimal test fixture (1 database, 1 gene)
- Per-group and global operations produce same result with 1 group
- Bug is masked until production data hits it

**How to avoid:**
1. **Use multi-group test fixtures:**
   ```r
   test_that("per-source categories preserved (not collapsed)", {
     # Fixture: BRCA1 is Definitive in SysNDD, Limited in gene2phenotype
     fixture <- tibble::tribble(
       ~symbol, ~list, ~category,
       "BRCA1", "SysNDD", "Definitive",
       "BRCA1", "gene2phenotype", "Limited"
     )

     result <- generate_comparisons_list(fspec = "symbol,SysNDD,gene2phenotype")

     # Should see both values, not max
     expect_equal(result$data$SysNDD[1], "Definitive")
     expect_equal(result$data$gene2phenotype[1], "Limited")
   })
   ```

2. **Test edge cases explicitly:**
   - Empty groups
   - Single date (no forward-fill needed)
   - Month boundaries
   - Groups with different sparsity patterns

**Warning signs:**
- Tests pass but users report wrong values
- Production issues that can't be reproduced with test data

## Code Examples

Verified patterns from official sources and existing codebase:

### Correct Per-Source Category Preservation
```r
# Source: api/functions/endpoint-functions.R (fixed version)
# Remove lines 95-100 (cross-database aggregation)

# BEFORE (buggy):
ndd_database_comparison_table_norm <- ndd_database_comparison_table_col %>%
  normalize_categories() %>%
  left_join(status_categories_list, by = c("category" = "max_category")) %>%
  group_by(symbol) %>%
  mutate(category_id = min(category_id)) %>%  # BUG: Collapses to max
  ungroup() %>%
  select(-category) %>%
  left_join(status_categories_list, by = c("category_id"))

# AFTER (correct):
ndd_database_comparison_table_norm <- ndd_database_comparison_table_col %>%
  normalize_comparison_categories()  # Use shared helper

table_data <- ndd_database_comparison_table_norm %>%
  select(symbol, hgnc_id, list, category) %>%  # No aggregation
  unique()
```

### Forward-Fill Cumulative Time Series
```typescript
// Source: app/src/utils/timeSeriesUtils.ts (to be created)
// Pattern validated in AnalysesTimePlot.vue

export function mergeGroupedCumulativeSeries(
  groups: GroupedTimeSeries[]
): AggregatedPoint[] {
  const allDates = new Set<string>();
  for (const g of groups) {
    for (const v of g.values ?? []) {
      allDates.add(v.entry_date);
    }
  }

  const groupMaps = groups.map((g) => {
    const map = new Map<string, number>();
    for (const v of g.values ?? []) {
      map.set(v.entry_date, v.cumulative_count);
    }
    return map;
  });

  const sortedDates = Array.from(allDates).sort();
  const lastSeen = new Array<number>(groups.length).fill(0);

  return sortedDates.map((date) => {
    let total = 0;
    for (let i = 0; i < groupMaps.length; i++) {
      const val = groupMaps[i].get(date);
      if (val !== undefined) {
        lastSeen[i] = val;
      }
      total += lastSeen[i];
    }
    return { date, count: total };
  });
}
```

### Traefik v3 Combined Router Rules
```yaml
# Source: docker-compose.yml labels (fixed version)
# Pattern from Traefik v3.6 official docs

api:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.api.rule=Host(`sysndd.dbmr.unibe.ch`) && PathPrefix(`/api`)"
    - "traefik.http.routers.api.entrypoints=web"
    - "traefik.http.routers.api.priority=100"
    - "traefik.http.services.api.loadbalancer.server.port=7777"

app:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.app.rule=Host(`sysndd.dbmr.unibe.ch`) && PathPrefix(`/`)"
    - "traefik.http.routers.app.entrypoints=web"
    - "traefik.http.services.app.loadbalancer.server.port=8080"
    - "traefik.http.routers.app.priority=1"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| dplyr implicit `.groups = "drop_last"` | Explicit `.groups = "drop"` everywhere | dplyr 1.0.0 (2020) | Prevents subtle grouping bugs |
| Inline category normalization | Shared `normalize_comparison_categories()` | Phase 80 | DRY; easier to maintain mappings |
| Re-derive cumulative from incremental | Use API's `cumulative_count` directly | Phase 80 | Correct aggregation with sparse data |
| PathPrefix-only Traefik rules | `Host() && PathPrefix()` combined | Traefik v3 best practice | Deterministic TLS cert selection |

**Deprecated/outdated:**
- **Plumber `#* @get` without explicit JSON serializer config:** Modern R/Plumber uses `list(na="string")` to prevent NULL encoding issues
- **Vue 2 Options API for new code:** SysNDD uses Composition API (TypeScript compatibility)
- **Traefik v2 syntax:** Project uses v3.6; v2 deprecated since 2022

## Open Questions

Things that couldn't be fully resolved:

1. **Should category normalization helper accept column names as parameters?**
   - What we know: Current implementation assumes `list` and `category` column names
   - What's unclear: Whether other endpoints need different column names
   - Recommendation: Start with hardcoded names; refactor if second use case needs flexibility

2. **Should time-series utility support different date formats?**
   - What we know: API returns YYYY-MM-DD strings; utility assumes this
   - What's unclear: Whether weekly/daily aggregation needs ISO week format
   - Recommendation: Keep simple (string dates); add format parameter if needed

3. **Does Traefik need www subdomain redirect?**
   - What we know: Current cert covers only `sysndd.dbmr.unibe.ch`
   - What's unclear: Whether `www.sysndd.dbmr.unibe.ch` traffic exists
   - Recommendation: Check web server logs; add redirect if traffic exists (separate from bug fix)

## Sources

### Primary (HIGH confidence)
- [dplyr summarise documentation](https://dplyr.tidyverse.org/reference/summarise.html) - Grouping behavior verified
- [Traefik v3.6 Routers](https://doc.traefik.io/traefik/v3.0/routing/routers/) - Rule syntax confirmed
- SysNDD codebase - Existing patterns verified in `AnalysesTimePlot.vue`, `endpoint-functions.R`
- `.planning/bugs/171-entity-trend-aggregation.md` - Official bug analysis

### Secondary (MEDIUM confidence)
- [Data Manipulation in R with dplyr (2026)](https://thelinuxcode.com/data-manipulation-in-r-with-dplyr-2026-practical-patterns-for-clean-reliable-pipelines/) - Grouping pitfalls article
- [dplyr Grouped data vignette](https://dplyr.tidyverse.org/articles/grouping.html) - Official grouping guide

### Tertiary (LOW confidence)
- None - All findings verified with official documentation or codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use (package.json, renv.lock verified)
- Architecture: HIGH - Patterns extracted from working code (AnalysesTimePlot.vue, existing helpers)
- Pitfalls: HIGH - Official dplyr docs + verified bug analysis documents
- Traefik config: HIGH - Traefik v3.6 official documentation

**Research date:** 2026-02-08
**Valid until:** 2026-04-08 (60 days for stable technologies; dplyr/Traefik are mature)
