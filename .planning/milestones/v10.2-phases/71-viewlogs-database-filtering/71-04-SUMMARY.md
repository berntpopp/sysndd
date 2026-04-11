---
phase: 71-viewlogs-database-filtering
plan: 04
completed: 2026-02-03
duration: 125s

subsystem: api-logging
tags: [logging-endpoint, database-filtering, memory-optimization, r-plumber]

dependency-graph:
  requires:
    - 71-02 (query builder functions)
    - 71-03 (get_logs_filtered, parse_logging_filter)
  provides:
    - GET /api/logs with database-side filtering
    - 400 response for invalid filters
  affects:
    - 72-XX (documentation phase can document the filtering API)

tech-stack:
  added: []
  patterns:
    - repository pattern for data access
    - tryCatch with custom error class for 400 responses
    - database-side filtering via parameterized SQL

key-files:
  modified:
    - api/endpoints/logging_endpoints.R (+114 lines, -74 lines)

decisions:
  - EXPLICIT_SELECT: Use dplyr::select() to avoid masking issues
  - ERROR_CLASS: Catch invalid_filter_error to return 400 instead of 500
  - SORT_PARAM: parse_sort_param() handles "id" (ASC) and "-timestamp" (DESC) formats

metrics:
  duration: 125s
  lines_added: 114
  lines_removed: 74
  net_change: +40
---

# Phase 71 Plan 04: Endpoint Refactor Summary

**One-liner:** Refactored GET /api/logs to use database-side filtering via get_logs_filtered(), eliminating collect() memory anti-pattern

## What Was Built

### Task 1: Source Repository
Added source statement for logging-repository.R at the top of the endpoint file with existence check:
```r
if (!exists("get_logs_filtered", mode = "function")) {
  if (file.exists("functions/logging-repository.R")) {
    source("functions/logging-repository.R", local = FALSE)
  }
}
```

### Task 2: parse_sort_param Helper
Added helper function to parse sort parameter with direction prefix:
```r
parse_sort_param <- function(sort) {
  if (startsWith(sort, "-")) {
    list(column = substring(sort, 2), direction = "DESC")
  } else {
    list(column = sort, direction = "ASC")
  }
}
```
Examples: "id" -> ASC, "-timestamp" -> DESC

### Task 3: Endpoint Refactor
**Removed (anti-pattern):**
```r
logs_raw <- pool %>%
  tbl("logging") %>%
  collect()  # <-- LOADS ALL ROWS INTO MEMORY

logs_raw <- logs_raw %>%
  arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
  filter(!!!rlang::parse_exprs(filter_exprs))
```

**Replaced with:**
```r
sort_parts <- parse_sort_param(sort)
filter_list <- parse_logging_filter(filter)

logs_raw <- get_logs_filtered(
  filters = filter_list,
  sort_column = sort_parts$column,
  sort_direction = sort_parts$direction
)
```

**Added error handling:**
```r
tryCatch(
  {
    # ... endpoint logic ...
  },
  invalid_filter_error = function(e) {
    res$status <- 400
    list(
      error = "INVALID_FILTER",
      error_type = "invalid_filter_error",
      message = e$message
    )
  }
)
```

### Task 4: Documentation Update
Updated roxygen documentation to describe:
- Database-side filtering approach
- Supported filter formats (status==, request_method==, path=^, timestamp>=, timestamp<=, address==)
- 400 response for invalid filter/sort columns

### Task 5: Verification
Verified:
- No collect() in GET endpoint (only in comment)
- Uses get_logs_filtered() for data fetching
- Uses parse_logging_filter() for filter conversion
- Has invalid_filter_error handler returning 400
- All lines under 120 characters

## Requirements Satisfied

| ID | Requirement | Status |
|----|-------------|--------|
| LOG-01 | GET /api/logs uses get_logs_filtered() | PASS |
| LOG-04 | Invalid filter columns return 400 with invalid_filter_error | PASS |
| - | No collect() in GET endpoint | PASS |
| - | Cursor-based pagination preserved via generate_cursor_pag_inf() | PASS |
| - | API backward compatible (same params: sort, filter, page_after, page_size) | PASS |

## Deviations from Plan

None - plan executed exactly as written.

## Technical Notes

### Memory Optimization
The key fix for issue #152:
- **Before:** Loading 100k+ log rows into R memory with collect(), then filtering
- **After:** Filtering at database level with WHERE clause, only fetching needed rows

### Backward Compatibility
All existing API parameters preserved:
- `sort` - Column to sort by (now supports "-column" for DESC)
- `filter` - Comma-separated filters
- `fields` - Column selection
- `page_after` - Cursor pagination
- `page_size` - Results per page
- `fspec` - Field specification
- `format` - json or xlsx

### Error Response Format
Invalid filters now return structured 400 response:
```json
{
  "error": "INVALID_FILTER",
  "error_type": "invalid_filter_error",
  "message": "Invalid sort column: 'invalid'. Allowed columns: id, timestamp, ..."
}
```

## Files Changed

| File | Change |
|------|--------|
| api/endpoints/logging_endpoints.R | +114 lines, -74 lines (net +40) |

## Commits

| Hash | Message |
|------|---------|
| a78ca64c | feat(71-04): refactor logging endpoint for database-side filtering |

## Phase 71 Completion

With this plan, Phase 71 (ViewLogs Database Filtering) is **COMPLETE**.

**Summary of Phase 71:**
- Plan 01: Database indexes for logging table
- Plan 02: Query builder functions (whitelist validation, WHERE clause builder)
- Plan 03: Repository functions (get_logs_filtered, parse_logging_filter)
- Plan 04: Endpoint refactor (this plan)

**Issue #152 Status:** RESOLVED - ViewLogs endpoint no longer loads entire table into memory before filtering.
