# Fix Proposal: Re-Review Approved Flag Never Set (#172, Bug 1)

## Problem

The "Top Re-Reviewers" chart shows all bars as 100% Pending because `re_review_approved = 0` for every record in `re_review_entity_connect`. There are 689 submitted re-reviews but zero approved.

## Root Cause (Usage Problem, Not Code Bug)

The re-review approval flag is ONLY set by one endpoint:

```
PUT /api/re_review/approve/<re_review_entity_id>
```

This endpoint is called exclusively from the `/Review` page (`app/src/views/review/Review.vue:1323-1343`).

**However**, the primary curator (Christiane Zweier) uses the direct approval pages instead:

| Page | Endpoint Called | Sets `re_review_approved`? |
|------|----------------|---------------------------|
| `/Review` | `PUT /api/re_review/approve/<id>` | **YES** |
| `/ApproveReview` | `PUT /api/review/approve/<id>` | **NO** |
| `/ApproveStatus` | `PUT /api/status/approve/<id>` | **NO** |

The direct approval endpoints (`/api/review/approve`, `/api/status/approve`) correctly update `ndd_entity_review.review_approved` and `ndd_entity_status.status_approved`, but they have **no knowledge of `re_review_entity_connect`**. The re-review tracking table is completely bypassed.

## Architecture Trace

The three approval workflows share no common code path:

```
/Review page
  └→ PUT /api/re_review/approve/<id>      (re_review_endpoints.R:75-173)
       ├→ UPDATE ndd_entity_status SET status_approved = 1
       ├→ UPDATE ndd_entity_review SET review_approved = 1
       └→ UPDATE re_review_entity_connect SET re_review_approved = 1  ← ONLY HERE

/ApproveReview page
  └→ PUT /api/review/approve/<id>          (review_endpoints.R:567-597)
       └→ svc_approval_review_approve()    (approval-service.R:10-78)
            └→ review_approve()            (review-repository.R:244-330)
                 └→ UPDATE ndd_entity_review SET review_approved = 1
                    (re_review_entity_connect NOT touched)

/ApproveStatus page
  └→ PUT /api/status/approve/<id>          (status_endpoints.R:278-305)
       └→ svc_approval_status_approve()    (approval-service.R:81-149)
            └→ status_approve()            (status-repository.R:239-313)
                 └→ UPDATE ndd_entity_status SET status_approved = 1
                    (re_review_entity_connect NOT touched)
```

The database link exists: `re_review_entity_connect` stores `review_id` and `status_id` that reference the same records being approved. But the direct approval code never queries this relationship.

## Fix: Two Parts

### Part 1: Prospective — Sync `re_review_approved` From Curation Endpoints

When a review or status is approved via the direct curation endpoints, check if it corresponds to a submitted re-review record and mark it approved.

#### Approach: Repository Layer Hook (DRY, Single Point of Change)

The correct layer is the **repository** (`review-repository.R`, `status-repository.R`). Both the service layer and the re-review endpoint delegate to these functions. Adding the sync here means ALL approval paths — including any future ones — automatically propagate to `re_review_entity_connect`.

**New shared utility function** in `api/functions/re-review-sync.R`:

```r
#' Sync re_review_entity_connect.re_review_approved when a review or status
#' is approved through any pathway.
#'
#' Finds re_review_entity_connect records that reference the given review_id
#' or status_id, have been submitted (re_review_submitted = 1), and are not
#' yet approved. Sets re_review_approved = 1 and records the approving user.
#'
#' Safe to call even when no matching re_review record exists (no-op).
#' Must be called WITHIN an existing transaction.
#'
#' @param review_ids Integer vector of approved review_ids (or NULL)
#' @param status_ids Integer vector of approved status_ids (or NULL)
#' @param approving_user_id Integer user ID of the approver
#' @param conn Database connection (from active transaction)
sync_rereview_approval <- function(review_ids = NULL,
                                    status_ids = NULL,
                                    approving_user_id,
                                    conn = pool) {
  if (is.null(review_ids) && is.null(status_ids)) return(invisible(NULL))

  # Build WHERE clause for matching re_review records
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

  # Only update submitted, non-approved records
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

#### Integrate into `review-repository.R`

Add a single call inside the existing transaction block in `review_approve()`:

```r
# review-repository.R, inside review_approve() transaction, after approval logic
# (approximately line 325, before closing the transaction)

# Sync re-review tracking
sync_rereview_approval(
  review_ids = review_ids,
  status_ids = NULL,
  approving_user_id = approving_user_id,
  conn = conn
)
```

#### Integrate into `status-repository.R`

Same pattern in `status_approve()`:

```r
# status-repository.R, inside status_approve() transaction, after approval logic

# Sync re-review tracking
sync_rereview_approval(
  review_ids = NULL,
  status_ids = status_ids,
  approving_user_id = approving_user_id,
  conn = conn
)
```

#### Why repository layer, not service or endpoint?

| Layer | Pros | Cons |
|-------|------|------|
| Endpoint | Quick, minimal change | Violates DRY (3 endpoints × 2 for review/status) |
| Service | Closer to business logic | Still 2 service functions to modify; service doesn't own DB writes |
| **Repository** | **Single point of DB mutation; inside existing transaction; all callers benefit** | Slight coupling to re_review table |

The repository is the right level because:
- It owns the transaction boundary (atomicity guaranteed)
- Both `/api/review/approve` and `/api/re_review/approve` ultimately call `review_approve()` — so the sync happens regardless of entry point
- Any future approval pathway also gets the sync for free (OCP)

#### Remove duplicate logic from `re_review_endpoints.R`

The re-review approve endpoint (`re_review_endpoints.R:75-173`) currently has its own inline SQL for approving reviews and statuses AND setting `re_review_approved`. After this fix, it should delegate to the repository functions instead, which now handle the sync automatically:

```r
# re_review_endpoints.R /approve/<id> — SIMPLIFIED
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

  # Delegate to repository functions (which now auto-sync re_review_approved)
  if (as.logical(status_ok)) {
    status_approve(re_review_data$status_id, req$user_id, approved = TRUE)
  } else {
    status_approve(re_review_data$status_id, req$user_id, approved = FALSE)
  }

  if (as.logical(review_ok)) {
    review_approve(re_review_data$review_id, req$user_id, approved = TRUE)
  } else {
    review_approve(re_review_data$review_id, req$user_id, approved = FALSE)
  }

  list(message = "Re-review approved successfully")
}
```

This eliminates ~60 lines of inline SQL that duplicated the repository logic (DRY).

### Part 2: Backfill Historical Data

**Tracked separately:** [berntpopp/sysndd-administration#1](https://github.com/berntpopp/sysndd-administration/issues/1)

One-time database script to retroactively set `re_review_approved = 1` for submitted re-reviews whose underlying reviews and statuses have already been approved via the direct curation pages. Should be run AFTER the prospective fix (Part 1) is deployed to prevent new drift.

### Part 3: Chart Fix (AdminStatistics)

With Parts 1 and 2 in place, the existing chart code becomes correct — it already shows Approved vs Pending based on `re_review_approved`. The only change needed is to also show a third segment for "Not Yet Submitted" to give a complete picture.

Update the leaderboard query to remove the `re_review_submitted == 1` filter (line 665) so we count ALL assigned entities:

```r
# statistics_endpoints.R — remove submitted filter, add total_assigned
leaderboard <- re_review_with_users %>%
  group_by(user_id) %>%
  summarise(
    total_assigned = n(),
    submitted_count = sum(re_review_submitted == 1, na.rm = TRUE),
    approved_count = sum(re_review_approved == 1, na.rm = TRUE),
    .groups = "drop"
  )
```

Frontend chart shows three segments:

```typescript
{ label: 'Approved',      data: r.approved_count,                                    color: green }
{ label: 'Pending Review', data: Math.max(0, r.submitted_count - r.approved_count),   color: amber }
{ label: 'Not Submitted',  data: Math.max(0, r.total_assigned - r.submitted_count),   color: gray  }
```

## Design Principles Applied

| Principle | How Applied |
|-----------|-------------|
| **DRY** | Single `sync_rereview_approval()` function called from both repository functions; eliminates duplicated inline SQL from re_review endpoint |
| **SRP** | Each repository owns its table mutations; sync function has one job |
| **OCP** | New approval pathways (future API endpoints, bulk operations) automatically sync because the repository layer handles it |
| **LSP** | All three approval entry points produce the same end state |
| **Defensive** | Sync is a no-op when no matching re_review record exists; backfill is idempotent |
| **KISS** | Single SQL UPDATE with JOIN for backfill; no complex state machine |
| **Regression Prevention** | Backfill script has dry-run + confirmation; prospective fix is inside existing transactions |

## Files Changed

### Prospective Fix
- `api/functions/re-review-sync.R` (NEW — shared sync utility)
- `api/functions/review-repository.R` (add `sync_rereview_approval` call inside transaction)
- `api/functions/status-repository.R` (add `sync_rereview_approval` call inside transaction)
- `api/endpoints/re_review_endpoints.R` (simplify `/approve` to delegate to repositories)

### Backfill Script
- `db/backfill_rereview_approved.R` (NEW — one-time migration script)

### Chart Fix
- `api/endpoints/statistics_endpoints.R` (remove submitted filter, add total_assigned)
- `app/src/views/admin/components/charts/ReReviewBarChart.vue` (three-segment stacked bar)
- `app/src/views/admin/AdminStatistics.vue` (update data mapping for new fields)
