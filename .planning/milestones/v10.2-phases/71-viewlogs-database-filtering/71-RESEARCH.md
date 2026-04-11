# Phase 71: ViewLogs Database Filtering - Research

**Researched:** 2026-02-03
**Domain:** R/Plumber API database-side filtering, MySQL indexing, pagination
**Confidence:** HIGH

## Summary

This phase refactors the `/api/logs` endpoint to use database-side filtering instead of loading the entire logging table into R memory. Currently, the endpoint loads all rows with `collect()` before applying any filters, which creates performance issues as the log table grows.

The research identified:
1. **Current problem**: The logging endpoint uses `pool %>% tbl("logging") %>% collect()` which loads ALL rows into R memory before filtering
2. **Existing patterns**: The LLM cache repository (`llm-cache-repository.R`) already implements the exact pattern needed - offset-based pagination with parameterized SQL queries
3. **Clear migration path**: Use `db_execute_query()` from `db-helpers.R` for parameterized queries, following the established repository pattern

**Primary recommendation:** Implement a new `logging-repository.R` following the `llm-cache-repository.R` pattern with `get_logs_paginated()` function that builds SQL dynamically with column whitelist validation.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DBI | 1.2.x | Database interface | Already used via db-helpers.R |
| pool | 1.0.x | Connection pooling | Already configured globally |
| RMariaDB | 1.3.x | MySQL driver | Already configured |
| rlang | 1.1.x | Error handling with abort() | Already used for structured errors |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tibble | 3.2.x | Data frame output | Return type from db_execute_query |
| logger | 0.3.x | Logging | Debug/info logging |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw SQL | dbplyr | dbplyr adds complexity for simple queries; raw SQL with parameterization is simpler and already used |
| cursor pagination | offset pagination | Cursor pagination already exists but offset is required for LOG-05; offset is simpler for count queries |

**Installation:**
No new packages required - all dependencies already installed.

## Architecture Patterns

### Recommended Project Structure
```
api/
├── functions/
│   ├── db-helpers.R           # Existing - use db_execute_query()
│   ├── logging-repository.R   # NEW - database operations for logs
│   └── helper-functions.R     # Existing - has generate_filter_expressions
├── endpoints/
│   └── logging_endpoints.R    # MODIFY - use repository layer
└── db/
    └── migrations/
        └── 011_logging_indexes.sql  # NEW - add indexes
```

### Pattern 1: Paginated Query with Dynamic WHERE Clause
**What:** Build SQL dynamically with validated columns and parameterized values
**When to use:** Any endpoint that needs filtering + pagination with database-side execution
**Example:**
```r
# Source: api/functions/llm-cache-repository.R (existing pattern)
get_logs_paginated <- function(
  filters = list(),       # list(timestamp_from = "...", status = "...")
  sort_column = "id",
  sort_direction = "DESC",
  page = 1L,
  per_page = 50L
) {
  # 1. Validate columns against whitelist
  allowed_columns <- c("id", "timestamp", "address", "status", "path", "request_method")

  # 2. Build WHERE clause dynamically
  where_clauses <- "1=1"
  params <- list()

  if (!is.null(filters$status)) {
    where_clauses <- paste(where_clauses, "AND status = ?")
    params <- append(params, filters$status)
  }

  # 3. Get count for pagination metadata
  count_sql <- paste("SELECT COUNT(*) as total FROM logging WHERE", where_clauses)
  count_result <- db_execute_query(count_sql, params)
  total <- count_result$total[1]

  # 4. Get paginated data with LIMIT/OFFSET
  offset <- (page - 1L) * per_page
  data_sql <- paste(
    "SELECT * FROM logging WHERE", where_clauses,
    "ORDER BY", sort_column, sort_direction,
    "LIMIT ? OFFSET ?"
  )
  data_params <- append(params, list(per_page, offset))
  data_result <- db_execute_query(data_sql, data_params)

  # 5. Return with pagination metadata
  list(
    data = data_result,
    totalCount = total,
    pageSize = per_page,
    offset = offset,
    currentPage = page,
    totalPages = ceiling(total / per_page),
    hasMore = (offset + nrow(data_result)) < total
  )
}
```

### Pattern 2: Column Whitelist Validation
**What:** Validate filter/sort columns against allowed list to prevent SQL injection
**When to use:** Any dynamic SQL construction
**Example:**
```r
# Source: Based on existing patterns in llm-cache-repository.R
LOGGING_ALLOWED_COLUMNS <- c(
  "id", "timestamp", "address", "agent", "host",
  "request_method", "path", "query", "status", "duration"
)

validate_column <- function(column, allowed = LOGGING_ALLOWED_COLUMNS) {
  if (!column %in% allowed) {
    rlang::abort(
      message = paste("Invalid column:", column),
      class = "invalid_filter_error"
    )
  }
  column
}
```

### Pattern 3: Offset-Based Pagination Response
**What:** Standardized pagination response format
**When to use:** All paginated endpoints
**Example:**
```r
# Source: Requirement PAG-02
build_offset_pagination_response <- function(data, total, page, per_page) {
  offset <- (page - 1L) * per_page
  list(
    data = data,
    meta = list(
      totalCount = total,
      pageSize = per_page,
      offset = offset,
      currentPage = page,
      totalPages = ceiling(total / per_page),
      hasMore = (offset + nrow(data)) < total
    )
  )
}
```

### Anti-Patterns to Avoid
- **collect() before filter:** Never do `tbl(...) %>% collect() %>% filter()` - this loads entire table into memory
- **String concatenation for values:** Never do `paste0("WHERE status = '", status, "'")` - use parameterized queries
- **Unvalidated column names:** Always validate against whitelist before including in SQL
- **Exposing raw DB errors:** Catch database errors and return structured error responses

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parameterized queries | Manual escaping | db_execute_query() with ? placeholders | Already handles connection pooling, cleanup, error handling |
| Connection management | Manual checkout/return | db_execute_query() / db_with_transaction() | Automatic cleanup via on.exit() |
| Error responses | Ad-hoc list structures | rlang::abort() with class | Structured error handling already in place |
| Filter string parsing | Custom parser | Adapt generate_filter_expressions() | Already handles complex filter syntax |

**Key insight:** The `llm-cache-repository.R` file already implements nearly identical pagination pattern. Follow this exact structure.

## Common Pitfalls

### Pitfall 1: Memory Explosion from collect()
**What goes wrong:** Loading 100K+ log rows into R memory before filtering
**Why it happens:** Using dbplyr's lazy evaluation but calling collect() too early
**How to avoid:** Never call collect() on logging table; use raw SQL with LIMIT/OFFSET
**Warning signs:** Endpoint times out or R process memory spikes

### Pitfall 2: SQL Injection via Column Names
**What goes wrong:** User controls sort/filter column names which get interpolated into SQL
**Why it happens:** Columns can't use ? placeholders, only values can
**How to avoid:** Strict whitelist validation for ANY string that goes into SQL structure
**Warning signs:** Dynamic SQL construction without validation

### Pitfall 3: Inconsistent Error Types
**What goes wrong:** Invalid filter returns 500 instead of 400
**Why it happens:** Unhandled error bubbles up as internal error
**How to avoid:** Wrap validation in tryCatch, return explicit 400 with `invalid_filter_error` type
**Warning signs:** Error responses without error_type field

### Pitfall 4: Missing Count Query
**What goes wrong:** Pagination controls show incorrect totals
**Why it happens:** Forgetting to run separate COUNT query for totalCount
**How to avoid:** Always run count query with same WHERE clause before data query
**Warning signs:** totalPages showing 0 or 1 when there are more pages

### Pitfall 5: Index Not Used
**What goes wrong:** Queries still slow despite indexes
**Why it happens:** Query not SARGable (e.g., LIKE '%value%' or function on column)
**How to avoid:** Use prefix matching (LIKE 'value%'), avoid functions on indexed columns
**Warning signs:** EXPLAIN shows full table scan

## Code Examples

Verified patterns from official sources:

### Database-Side Filtering with Pagination
```r
# Source: api/functions/llm-cache-repository.R lines 569-620
get_logs_paginated <- function(
  status = NULL,
  request_method = NULL,
  path_prefix = NULL,
  timestamp_from = NULL,
  timestamp_to = NULL,
  page = 1L,
  per_page = 50L,
  sort_column = "id",
  sort_direction = "DESC"
) {
  # Validate sort column
  allowed_sort <- c("id", "timestamp", "status", "path", "duration")
  if (!sort_column %in% allowed_sort) {
    rlang::abort(
      message = paste("Invalid sort column:", sort_column),
      class = "invalid_filter_error"
    )
  }

  # Coerce to integer
  page <- as.integer(page)
  per_page <- as.integer(per_page)

  # Build WHERE clause dynamically
  where_clauses <- "1=1"
  params <- list()

  if (!is.null(status) && status != "") {
    where_clauses <- paste(where_clauses, "AND status = ?")
    params <- append(params, as.integer(status))
  }

  if (!is.null(request_method) && request_method != "") {
    where_clauses <- paste(where_clauses, "AND request_method = ?")
    params <- append(params, request_method)
  }

  if (!is.null(path_prefix) && path_prefix != "") {
    where_clauses <- paste(where_clauses, "AND path LIKE ?")
    params <- append(params, paste0(path_prefix, "%"))  # Prefix match for index use
  }

  if (!is.null(timestamp_from) && timestamp_from != "") {
    where_clauses <- paste(where_clauses, "AND timestamp >= ?")
    params <- append(params, timestamp_from)
  }

  if (!is.null(timestamp_to) && timestamp_to != "") {
    where_clauses <- paste(where_clauses, "AND timestamp <= ?")
    params <- append(params, timestamp_to)
  }

  # Get total count
  count_sql <- paste("SELECT COUNT(*) as total FROM logging WHERE", where_clauses)
  count_result <- db_execute_query(count_sql, params)
  total <- count_result$total[1] %||% 0L

  # Get paginated data
  offset <- (page - 1L) * per_page
  data_sql <- paste(
    "SELECT id, timestamp, address, agent, host, request_method, path, query, post, status, duration, file, modified",
    "FROM logging WHERE", where_clauses,
    "ORDER BY", sort_column, sort_direction,
    "LIMIT ? OFFSET ?"
  )
  data_params <- append(params, list(per_page, offset))
  data_result <- db_execute_query(data_sql, data_params)

  build_offset_pagination_response(data_result, total, page, per_page)
}
```

### Error Response Pattern
```r
# Source: api/endpoints/llm_admin_endpoints.R lines 143-150
# Return 400 for invalid filter
if (!column %in% ALLOWED_COLUMNS) {
  res$status <- 400
  return(list(
    error = "INVALID_FILTER",
    error_type = "invalid_filter_error",
    message = paste("Invalid filter column:", column, ". Allowed:", paste(ALLOWED_COLUMNS, collapse = ", "))
  ))
}
```

### Migration File Structure
```sql
-- Source: api/db/migrations/006_add_llm_summary_cache.sql (pattern)
-- Migration 011: Add indexes for logging table filtering

-- IDX-01: Index on timestamp for date range queries
CREATE INDEX IF NOT EXISTS idx_logging_timestamp ON logging(timestamp);

-- IDX-02: Index on status for status filtering
CREATE INDEX IF NOT EXISTS idx_logging_status ON logging(status);

-- IDX-03: Index on path for prefix filtering (first 100 chars)
CREATE INDEX IF NOT EXISTS idx_logging_path ON logging(path(100));

-- IDX-04: Composite index for common filter: timestamp + status
CREATE INDEX IF NOT EXISTS idx_logging_timestamp_status ON logging(timestamp, status);

-- IDX-05: Composite index for pagination: id DESC + status (for filtered pagination)
CREATE INDEX IF NOT EXISTS idx_logging_id_status ON logging(id DESC, status);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| dbplyr with collect() | Raw SQL with db_execute_query() | Already current in llm-cache-repository.R | Better memory control, explicit query structure |
| Cursor pagination (page_after) | Offset pagination (LIMIT/OFFSET) | Requirement LOG-05 | Simpler count queries, standard REST pattern |
| generate_filter_expressions() | Simpler column-whitelist approach | For this specific use case | Logging filters are simpler than entity filters |

**Deprecated/outdated:**
- Using `tbl() %>% collect() %>% filter()` for large tables - causes memory issues
- The existing logging endpoint pattern - must be replaced

## Open Questions

Things that couldn't be fully resolved:

1. **Filter syntax compatibility**
   - What we know: Current frontend uses filterObjToStr() which produces complex expressions like `contains(status,'200')`
   - What's unclear: Should we maintain exact same syntax or simplify for logging-specific use?
   - Recommendation: Create simplified logging-specific filter parser; frontend sends simple params like `status=200`

2. **Path filtering index effectiveness**
   - What we know: MySQL can use prefix index for LIKE 'prefix%' but not '%contains%'
   - What's unclear: How much of path column variance is in first 100 chars?
   - Recommendation: Use path(100) prefix index; document that contains-style path search won't use index

3. **Frontend pagination controls**
   - What we know: TablesLogs.vue currently uses cursor pagination (page_after, prevItemID, nextItemID)
   - What's unclear: Whether frontend changes are needed for offset pagination
   - Recommendation: API returns both formats in meta for backward compatibility, phase out cursor fields

## Sources

### Primary (HIGH confidence)
- api/functions/db-helpers.R - Parameterized query pattern with db_execute_query()
- api/functions/llm-cache-repository.R - Complete pagination pattern (get_generation_logs_paginated)
- api/endpoints/logging_endpoints.R - Current implementation showing the problem
- api/functions/migration-runner.R - Migration system for adding indexes
- db/15_Rcommands_sysndd_db_logging_table.R - Logging table schema

### Secondary (MEDIUM confidence)
- api/functions/helper-functions.R - generate_filter_expressions() for potential adaptation
- api/endpoints/llm_admin_endpoints.R - Error response patterns

### Tertiary (LOW confidence)
- app/src/components/tables/TablesLogs.vue - Frontend filter/pagination usage (may need updates)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, patterns well-established
- Architecture: HIGH - llm-cache-repository.R provides exact template
- Pitfalls: HIGH - Common issues well-documented in existing code patterns

**Research date:** 2026-02-03
**Valid until:** Indefinite (stable patterns in codebase)
