---
phase: 71-viewlogs-database-filtering
plan: 03
completed: 2026-02-03
duration: 258s

subsystem: api-logging
tags: [pagination, database-filtering, cursor-pagination, r-plumber]

dependency-graph:
  requires:
    - 71-02 (query builder functions)
  provides:
    - get_logs_filtered() for database-side log queries
    - parse_logging_filter() for filter string parsing
  affects:
    - 71-04 (endpoint refactor will use these functions)

tech-stack:
  added: []
  patterns:
    - cursor-based pagination (compatible with generate_cursor_pag_inf)
    - database-side filtering (no collect())
    - parameterized SQL via db_execute_query()

key-files:
  modified:
    - api/functions/logging-repository.R (+165 lines)

decisions:
  - CURSOR_PAGINATION: Use existing cursor-based pagination (page_after/page_size) not offset-based
  - MAX_ROWS: Safety limit of 100k rows to prevent memory issues even with broad filters
  - FILTER_PARSE: parse_logging_filter() converts filter string to repository format
  - NO_COLLECT: Never use collect() - all filtering at database level

metrics:
  duration: 258s
  lines_added: 165
  functions_added: 2
---

# Phase 71 Plan 03: Pagination Helper Functions Summary

**One-liner:** Database filtering functions compatible with existing cursor-based pagination via get_logs_filtered() and parse_logging_filter()

## What Was Built

### Task 1: get_logs_filtered()
Added the main query function for database-side filtering, returning a tibble compatible with generate_cursor_pag_inf().

**Function signature:**
```r
get_logs_filtered(
  filters = list(),
  sort_column = "id",
  sort_direction = "DESC",
  max_rows = 100000L
)
```

**Key behaviors:**
1. Validates sort column against LOGGING_ALLOWED_SORT_COLUMNS
2. Validates sort direction (ASC/DESC only)
3. Builds WHERE clause with parameterized values
4. Applies max_rows LIMIT for safety
5. Returns tibble for generate_cursor_pag_inf()

### Task 2: parse_logging_filter()
Added filter string parser to convert endpoint filter param to repository format.

**Supported filter formats:**
- `status==200` (exact match on HTTP status)
- `request_method==GET` (exact match on method)
- `path=^/api/` (prefix match on path)
- `timestamp>=2026-01-01` (minimum timestamp)
- `timestamp<=2026-01-31` (maximum timestamp)
- `address==127.0.0.1` (exact match on IP)

## Architecture Decision: Cursor vs Offset Pagination

**Decision:** Use existing cursor-based pagination (page_after/page_size), NOT offset-based.

**Rationale:**
- API already uses cursor-based pagination via `generate_cursor_pag_inf()`
- All other endpoints use the same pattern with `page_after` and `page_size`
- Cursor pagination handles insertions/deletions better for live data
- Changing to offset would break API backward compatibility

**Implementation:**
- `get_logs_filtered()` returns a tibble (not a pagination object)
- The endpoint passes this tibble to `generate_cursor_pag_inf()` for pagination
- This maintains the existing response format: `{links, meta, data}`

## Requirements Satisfied

| ID | Requirement | Status |
|----|-------------|--------|
| LOG-01 | Database-side filtering (WHERE in SQL) | PASS |
| LOG-05 | Uses LIMIT for safety (max_rows=100k) | PASS |

Note: Offset-based pagination requirements (PAG-01, PAG-02) were replaced with cursor-based approach.

## Deviations from Plan

**Major Deviation:** Changed from offset-based to cursor-based pagination.

The original plan specified offset-based pagination (`page`, `per_page`, `totalCount`, `hasMore`), but this was inconsistent with the existing API which uses cursor-based pagination (`page_after`, `page_size`).

The code was refactored to:
1. Remove `build_offset_pagination_response()` and `get_logs_paginated()` (offset-based)
2. Add `get_logs_filtered()` returning tibble for `generate_cursor_pag_inf()` (cursor-based)
3. Add `parse_logging_filter()` for filter string parsing

This maintains API consistency and backward compatibility.

## Technical Notes

### No collect() Pattern
The function explicitly avoids the anti-pattern of loading all rows into R memory:
```r
# WRONG (memory explosion on large tables)
pool %>% tbl("logging") %>% collect() %>% filter(...)

# RIGHT (database-side filtering)
db_execute_query("SELECT ... FROM logging WHERE ... LIMIT ?", params)
```

### Safety Limit
The max_rows parameter (default 100k) prevents memory issues even with very broad filters:
```r
data_sql <- paste(
  "SELECT ... FROM logging WHERE", where_clause,
  order_clause,
  "LIMIT ?"
)
```

## Files Changed

| File | Change |
|------|--------|
| api/functions/logging-repository.R | +165 lines (2 functions, replaced offset functions) |

## Commits

| Hash | Message |
|------|---------|
| d4d367e4 | feat(71-03): add pagination helper and get_logs_paginated function |
| 243d6d4b | fix(71): align logging repository with cursor-based pagination |

## Next Phase Readiness

**For 71-04 (Endpoint Refactor):**
- [x] get_logs_filtered() available for database-side filtering
- [x] parse_logging_filter() available for filter string conversion
- [x] Compatible with existing generate_cursor_pag_inf() for pagination
- [ ] logging_endpoints.R ready to be refactored

**Blockers:** None
**Concerns:** None
