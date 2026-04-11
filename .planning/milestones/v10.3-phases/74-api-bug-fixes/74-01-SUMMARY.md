---
phase: 74-api-bug-fixes
plan: 01
subsystem: api
tags: [r, plumber, error-handling, rest-api, entity-creation]

requires:
  - "73-02: Cache invalidation infrastructure"

provides:
  - "Fixed entity creation with direct_approval=TRUE (no more 500 errors)"
  - "Proper HTTP 201 Created status for successful entity creation"
  - "Response aggregation includes approval step results"

affects:
  - "75: Frontend can rely on 201 status for entity creation success"

tech-stack:
  added: []
  patterns:
    - "REST API 201 Created response pattern"
    - "Response aggregation with conditional bind_rows"
    - "Unit testing aggregation logic without database"

key-files:
  created:
    - "api/tests/testthat/test-unit-entity-creation.R"
  modified:
    - "api/endpoints/entity_endpoints.R"

decisions:
  - id: "API-01-STATUS"
    what: "Use HTTP 201 Created for successful entity creation"
    why: "REST semantics: 201 indicates resource created, distinguishes from 200 OK for updates"
    alternatives: ["Keep 200 OK (inconsistent with REST)", "Use custom status codes (non-standard)"]
    outcome: "Set res$status <- 201 on success, return created entity in response body"

  - id: "API-01-AGGREGATION"
    what: "Include approval responses in bind_rows aggregation"
    why: "Approval failures must surface in final response via max(status)"
    alternatives: ["Check responses separately (verbose)", "Ignore approval failures (unsafe)"]
    outcome: "Conditional bind_rows with direct_approval check"

  - id: "API-01-LOGGING"
    what: "Add debug logging for approval responses"
    why: "Troubleshooting: track approval success/failure without DB queries"
    alternatives: ["No logging (harder to debug)", "Info level (too verbose)"]
    outcome: "logger::log_debug for approval responses with status and ID"

metrics:
  duration: "3 minutes"
  commits: 2
  tests-added: 8
  files-modified: 2
  completed: 2026-02-05
---

# Phase 74 Plan 01: Fix Direct Approval Entity Creation Summary

**One-liner:** Direct approval entity creation now properly handles errors and returns HTTP 201 Created

## What Was Done

Fixed the entity creation endpoint (POST /api/entity/create) to properly handle the direct_approval=TRUE flow. When a curator creates an entity with direct approval (skipping separate review/status approval steps), the endpoint now:

1. **Checks approval results:** After calling put_db_review_approve() and put_db_status_approve(), the endpoint now checks their return values and includes them in response aggregation.

2. **Surfaces approval failures:** If either approval step fails (returns status != 200), the error is properly aggregated via max(status) and included in the response message.

3. **Returns HTTP 201 Created:** On successful creation, the endpoint now returns HTTP 201 Created (REST standard for resource creation) instead of HTTP 200 OK.

4. **Logs approval responses:** Added debug logging for approval responses to aid troubleshooting.

**Impact:** Fixes GitHub issue #166 - curators can now use direct_approval=TRUE without encountering 500 errors.

## Technical Implementation

### Response Aggregation Pattern

The fix uses conditional bind_rows to include approval responses only when direct_approval=TRUE:

```r
response_review_post <- tibble::as_tibble(response_publication) %>%
  bind_rows(tibble::as_tibble(response_review)) %>%
  bind_rows(tibble::as_tibble(response_publication_conn)) %>%
  bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
  bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
  {
    if (direct_approval) {
      bind_rows(., tibble::as_tibble(response_review_approve))
    } else {
      .
    }
  } %>%
  dplyr::select(status, message) %>%
  mutate(status = max(status)) %>%
  mutate(message = str_c(message, collapse = "; ")) %>%
  unique()
```

This pattern:
- Only includes approval responses when direct_approval=TRUE
- Uses max(status) to surface any failure (highest status code wins)
- Concatenates all messages with "; " separator
- Applied twice: once for review approval, once for status approval

### HTTP Status Code

Changed from:
```r
res$status <- response_entity$status  # Always 200
```

To:
```r
res$status <- 201  # 201 Created for successful POST
```

Per REST conventions, POST requests that create resources should return 201 Created, not 200 OK.

## Testing

Added 8 unit tests in test-unit-entity-creation.R covering:

1. **Direct approval includes review approval in aggregation** - Verifies response_review_approve is bound into response_review_post
2. **Review approval failure surfaces** - Verifies status 500 from approval propagates to final response
3. **Non-direct approval excludes review approval** - Verifies normal flow doesn't include approval responses
4. **Direct approval includes status approval in final aggregation** - Verifies response_status_approve is bound into final response
5. **Status approval failure surfaces** - Verifies status 500 from status approval propagates to final response
6. **Successful direct approval has all messages** - Verifies all response messages present in concatenated string
7. **Multiple failures aggregate to highest status** - Verifies max(status) picks 500 over 404 over 403
8. **Edge case handling** - Various combinations of success/failure states

All tests are pure unit tests (no database required) - they test the aggregation logic directly by constructing mock response objects.

## Files Changed

### api/endpoints/entity_endpoints.R
- Added debug logging for review approval response (lines 375-379)
- Added conditional bind_rows for review approval in aggregation (lines 387-393)
- Added debug logging for status approval response (lines 444-448)
- Changed HTTP status to 201 on success (line 479)
- Added conditional bind_rows for status approval in final aggregation (lines 491-497)

### api/tests/testthat/test-unit-entity-creation.R (NEW)
- 245 lines of unit tests for response aggregation logic
- Tests both direct and non-direct approval paths
- Tests success and failure scenarios
- Tests edge cases (multiple failures, message concatenation)

## Deviations from Plan

None - plan executed exactly as written.

## Verification

**Manual verification:**
- Inspected code diff to confirm:
  - response_review_approve is checked and included in aggregation (lines 369-393)
  - response_status_approve is checked and included in aggregation (lines 438-497)
  - HTTP 201 is set on successful creation (line 479)
  - Both direct and non-direct paths return same response shape

**Test verification:**
- All 8 new unit tests pass (validated logic)
- Existing integration tests still pass (no regression)

**Lint verification:**
- No lintr issues introduced (validated via code review)

## Next Phase Readiness

**Phase 75 (Frontend Fixes) can now:**
- Rely on HTTP 201 Created status to detect successful entity creation
- Expect consistent response shape from both direct and non-direct approval paths
- Expect approval failures to surface in response (not silent 500)

**API-02 (Panels column alias) can proceed independently** - no shared code.

**API-03 (Clustering empty results) can proceed independently** - no shared code.

## Commit History

```
38b91834 test(74-01): add unit tests for entity creation direct approval
598d70e5 fix(74-01): handle direct approval errors in entity creation
```

## Knowledge for Future Phases

**Pattern established:** When adding approval flows to endpoints:
1. Always check approval function return values
2. Include approval responses in bind_rows aggregation
3. Use max(status) to surface failures
4. Use conditional bind_rows with feature flags (direct_approval, etc.)
5. Log approval responses at debug level
6. Return HTTP 201 Created for successful POST operations

**Gotchas avoided:**
- Unchecked return values from approval functions
- Silent failures (approval fails but endpoint returns 200)
- Inconsistent response shapes between approval paths
- Wrong HTTP status code (200 vs 201 for creation)

**Testing strategy:**
- Pure unit tests for aggregation logic (no DB needed)
- Mock responses with different status codes
- Test both feature-on and feature-off paths
- Test edge cases (multiple failures, empty messages)
