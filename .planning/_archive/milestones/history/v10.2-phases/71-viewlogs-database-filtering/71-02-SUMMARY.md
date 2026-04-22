---
phase: 71-viewlogs-database-filtering
plan: 02
subsystem: api-logging
tags: [security, sql-injection, query-builder, repository-pattern]

dependency-graph:
  requires: []
  provides: [logging-repository, column-validation, query-builder]
  affects: [71-03, 71-04]

tech-stack:
  added: []
  patterns: [repository-layer, whitelist-validation, parameterized-queries]

key-files:
  created:
    - api/functions/logging-repository.R
  modified: []

decisions:
  - id: LOGGING_COLUMNS
    choice: "13 columns in whitelist matching logging table schema"
    rationale: "Full table schema for flexibility; TEXT columns excluded from sort whitelist"
  - id: SORT_COLUMNS
    choice: "9 sortable columns (exclude agent, path, query, post)"
    rationale: "TEXT columns are expensive to sort and rarely useful"
  - id: ERROR_CLASS
    choice: "invalid_filter_error class for validation failures"
    rationale: "Allows endpoint to catch and return 400 instead of 500"

metrics:
  duration: 2m 23s
  completed: 2026-02-03
---

# Phase 71 Plan 02: Query Builder Repository Summary

**One-liner:** Logging repository with column whitelist validation and parameterized SQL builder for SQL injection prevention.

## What Was Built

Created `api/functions/logging-repository.R` with:

1. **Column whitelists (LOG-02):**
   - `LOGGING_ALLOWED_COLUMNS` - 13 columns matching logging table schema
   - `LOGGING_ALLOWED_SORT_COLUMNS` - 9 sortable columns (excludes TEXT columns)

2. **Validation functions (LOG-02, LOG-04):**
   - `validate_logging_column()` - validates column names against whitelist
   - `validate_sort_direction()` - ensures only ASC/DESC accepted
   - Both throw `invalid_filter_error` class for endpoint error handling

3. **Query builders (LOG-03):**
   - `build_logging_where_clause()` - builds parameterized WHERE clauses with ? placeholders
   - `build_logging_order_clause()` - builds validated ORDER BY clauses

4. **Security documentation:**
   - Comprehensive `@section Security Notes:` explaining whitelist approach
   - SQL injection attack examples showing how they are blocked
   - Explanation of two-layer security (column validation + parameterized values)

## Technical Decisions

### Column Whitelist Design
All 13 columns from the logging table are included in the filter whitelist:
- id, timestamp, address, agent, host, request_method, path, query, post, status, duration, file, modified

Sort whitelist excludes TEXT columns (agent, path, query, post) because:
- Sorting TEXT columns is expensive (requires full table scan)
- Rarely useful for log browsing

### Error Handling Pattern
Using `rlang::abort()` with `class = "invalid_filter_error"` allows:
- Endpoint to `tryCatch` and return 400 Bad Request
- Error message includes list of allowed columns for debugging
- Consistent with existing error patterns (db_query_error, etc.)

### WHERE Clause Builder Pattern
- Starts with "1=1" for easy AND concatenation
- All values use ? placeholders (parameterized)
- LIKE uses `prefix%` pattern for index-friendly prefix search
- Empty/NULL filters are ignored

## Key Code Patterns

### Whitelist Validation
```r
validate_logging_column <- function(column, allowed = LOGGING_ALLOWED_COLUMNS, context = "filter") {
  if (!column %in% allowed) {
    rlang::abort(
      message = paste0("Invalid ", context, " column: '", column, "'..."),
      class = "invalid_filter_error"
    )
  }
  column
}
```

### Parameterized WHERE Builder
```r
build_logging_where_clause <- function(filters = list()) {
  where_clause <- "1=1"
  params <- list()

  if (!is.null(filters$status) && filters$status != "") {
    where_clause <- paste(where_clause, "AND status = ?")
    params <- append(params, as.integer(filters$status))
  }
  # ... more filters ...

  list(clause = where_clause, params = params)
}
```

## Deviations from Plan

None - plan executed exactly as written.

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 14d66cbd | feat | Add logging repository with query builder functions |

## Next Phase Readiness

**Ready for Plan 71-03 (Unit Tests):**
- All exports defined and documented
- Clear function signatures for testing
- Error classes specified for assertion

**Ready for Plan 71-04 (Endpoint Refactor):**
- Query builders ready to use in logging_endpoints.R
- Column validation protects against SQL injection
- Parameterized query pattern matches existing db_execute_query() usage
