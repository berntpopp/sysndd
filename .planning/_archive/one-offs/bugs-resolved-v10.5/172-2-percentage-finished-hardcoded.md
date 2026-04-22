# Fix Proposal: Hardcoded `percentage_finished` Denominator (#172, Bug 2)

## Problem

```r
# statistics_endpoints.R:311-312
# Example placeholder: dividing total by 3650 for demonstration
percent_finished <- (total_rr / 3650) * 100
```

The `3650` was the total number of entities when the re-review initiative was launched — the initial batch computation target. It's hardcoded, undocumented, and becomes increasingly stale as new entities are added to the database.

## Analysis: What Should "Percentage Finished" Mean?

The re-review system has a clear goal: **systematically re-evaluate all existing entities**. As SysNDD grows, new entities are added continuously. The metric should answer:

> "Of all entities that need (or have ever needed) re-review, what fraction has been processed?"

There are three possible denominators:

| Denominator | Value | Meaning | Grows Over Time? |
|-------------|-------|---------|-----------------|
| Hardcoded 3650 | 3650 | Initial batch target | No (stale) |
| Total NDD entities in database | ~3,688 | All current entities | Yes |
| Total entities in `re_review_entity_connect` | Varies | All entities ever assigned to a batch | Yes (as batches are created) |

**Option 3 is the correct choice.** It represents exactly the entities that have been enrolled in the re-review process. It grows naturally as new batches are created but doesn't include entities that haven't been targeted for re-review yet. This makes the metric a true **progress tracker** toward the re-review goal.

## Proposed Fix

### Compute progress dynamically from `re_review_entity_connect`

Replace the entire percentage computation block in `statistics_endpoints.R`:

```r
#* @get /rereview
function(req, res, start_date, end_date) {
  require_role(req, res, "Administrator")

  # --- Collect base data ---
  re_review_all <- pool %>%
    tbl("re_review_entity_connect") %>%
    collect()

  review_dates <- pool %>%
    tbl("ndd_entity_review") %>%
    select(review_id, review_date) %>%
    collect()

  status_dates <- pool %>%
    tbl("ndd_entity_status") %>%
    select(status_id, status_date) %>%
    collect()

  # --- Compute global progress (independent of date range) ---
  total_in_pipeline    <- nrow(re_review_all)
  total_submitted      <- sum(re_review_all$re_review_submitted == 1, na.rm = TRUE)
  total_approved       <- sum(re_review_all$re_review_approved == 1, na.rm = TRUE)
  percent_submitted    <- if (total_in_pipeline > 0) (total_submitted / total_in_pipeline) * 100 else 0
  percent_approved     <- if (total_in_pipeline > 0) (total_approved / total_in_pipeline) * 100 else 0

  # Total NDD entities for coverage metric
  total_ndd_entities <- pool %>%
    tbl("ndd_entity_view") %>%
    filter(ndd_phenotype == "Yes") %>%
    summarise(n = n()) %>%
    pull(n)

  percent_coverage <- if (total_ndd_entities > 0) (total_in_pipeline / total_ndd_entities) * 100 else 0

  # --- Compute date-range-filtered stats ---
  re_review_dated <- re_review_all %>%
    filter(re_review_submitted == 1) %>%
    left_join(review_dates, by = "review_id") %>%
    left_join(status_dates, by = "status_id") %>%
    {
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(date = max(review_date, status_date, na.rm = TRUE)) %>%
          ungroup()
      } else {
        mutate(., date = as.Date(NA))
      }
    } %>%
    filter(date >= as.Date(start_date) & date <= as.Date(end_date))

  period_submitted <- nrow(re_review_dated)
  day_diff <- as.numeric(difftime(as.Date(end_date), as.Date(start_date), units = "days"))
  avg_per_day <- if (day_diff > 0) period_submitted / day_diff else 0

  list(
    # Global progress metrics
    total_in_pipeline     = total_in_pipeline,
    total_submitted       = total_submitted,
    total_approved        = total_approved,
    percent_submitted     = round(percent_submitted, 2),
    percent_approved      = round(percent_approved, 2),
    # Coverage: how much of the database is enrolled in re-review
    total_ndd_entities    = total_ndd_entities,
    percent_coverage      = round(percent_coverage, 2),
    # Period-specific metrics
    period_submitted      = period_submitted,
    average_per_day       = round(avg_per_day, 4),
    # Deprecated (kept for backward compat, will be removed)
    total_rereviews       = period_submitted,
    percentage_finished   = round(percent_submitted, 2)
  )
}
```

### What This Gives

Three meaningful, self-updating metrics:

1. **`percent_submitted`** = "Of all entities enrolled in re-review batches, what % has been submitted by reviewers?" (the primary progress tracker)
2. **`percent_approved`** = "Of all enrolled entities, what % has been approved by a curator?" (currently 0 due to Bug 1, will become useful once approval workflow is used or Bug 1 fix redefines the metric)
3. **`percent_coverage`** = "Of all NDD entities in the database, what % has been enrolled in a re-review batch?" (tracks how much of the database has been targeted)

### Frontend: Update KPI card

In `AdminStatistics.vue`, update the re-review statistics display:

```typescript
// Replace single "percentage_finished" with structured progress
reReviewStats.value = {
  periodSubmitted: extractValue(data.period_submitted),
  avgPerDay: extractValue(data.average_per_day),
  totalInPipeline: extractValue(data.total_in_pipeline),
  totalSubmitted: extractValue(data.total_submitted),
  percentSubmitted: extractValue(data.percent_submitted),
  percentCoverage: extractValue(data.percent_coverage),
};
```

Display as two progress indicators:

```
Re-Review Progress
├── Pipeline Coverage: 65.2% (2,401 of 3,688 entities enrolled)
├── Submission Progress: 28.7% (689 of 2,401 submitted)
└── Period Stats: 99 submitted (0.27/day)
```

## Why This Design

| Principle | How Applied |
|-----------|-------------|
| **No Magic Numbers** | Denominator computed from actual data, never hardcoded |
| **SRP** | Three distinct metrics, each answering one question |
| **OCP** | Adding new batches automatically updates all metrics without code changes |
| **Future-Proof** | Works whether database has 3,650 or 30,000 entities |
| **Backward Compatible** | `total_rereviews` and `percentage_finished` kept as deprecated aliases |
| **KISS** | Simple ratio math, no complex modeling |

## Test Scenarios

1. Empty database → all percentages = 0, no division by zero
2. All entities submitted → `percent_submitted = 100%`
3. No batches created → `total_in_pipeline = 0`, `percent_coverage = 0%`
4. New batch created → `total_in_pipeline` increases, `percent_submitted` decreases (more work to do)
5. New NDD entity added to database → `percent_coverage` decreases (more entities not yet enrolled)

## Files Changed

- `api/endpoints/statistics_endpoints.R` (rewrite `/rereview` endpoint)
- `app/src/views/admin/AdminStatistics.vue` (update stats display)
