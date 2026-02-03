# functions/logging-repository.R
#
# Database repository for logging table operations.
# Provides query building, column validation, and pagination.
#
# Key features:
# - Column whitelist validation to prevent SQL injection
# - Parameterized queries via db_execute_query()
# - Offset-based pagination with metadata
#
# Security model:
# - Column names cannot use parameterized queries (? placeholders)
# - All column names are validated against a whitelist before SQL construction
# - All filter VALUES use parameterized queries (? placeholders)
# - This two-layer approach prevents SQL injection via both columns and values

require(rlang)
require(logger)

log_threshold(INFO)

# Load database helper functions for repository layer access (if not already loaded)
if (!exists("db_execute_query", mode = "function")) {
  if (file.exists("functions/db-helpers.R")) {
    source("functions/db-helpers.R", local = TRUE)
  }
}

#------------------------------------------------------------------------------
# Column Whitelists (LOG-02)
#------------------------------------------------------------------------------

#' Allowed columns for logging queries
#'
#' Whitelist of column names that can be used in filter and sort operations.
#' Any column not in this list will be rejected to prevent SQL injection.
#'
#' @section Security Notes:
#'
#' Column names in SQL cannot use parameterized queries (? placeholders) because
#' they are structural parts of the query, not values. This whitelist validation
#' is the security layer that prevents SQL injection via column names.
#'
#' The validation prevents SQL injection attacks that attempt to:
#' - Inject via sort column: `sort_column = "id; DROP TABLE logging; --"`
#' - Inject via filter column: `filters = list("status; DELETE FROM logging" = 1)`
#'
#' Example attack that would be blocked:
#' ```r
#' # This would throw invalid_filter_error, NOT execute the injection
#' validate_logging_column("id; DROP TABLE logging; --")
#' # Error: Invalid filter column: 'id; DROP TABLE logging; --'
#' ```
#'
#' Values are safe because they use parameterized queries (? placeholders)
#' which are handled by the database driver (DBI::dbBind) and never interpolated
#' into the SQL string.
#'
#' @export
LOGGING_ALLOWED_COLUMNS <- c(
  "id",
  "timestamp",
  "address",
  "agent",
  "host",
  "request_method",
  "path",
  "query",
  "post",
  "status",
  "duration",
  "file",
  "modified"
)

#' Allowed sort columns (subset that makes sense for sorting)
#'
#' Not all columns are practical to sort by. TEXT columns (agent, path, query, post)
#' are excluded because sorting them is expensive and rarely useful.
#'
#' @export
LOGGING_ALLOWED_SORT_COLUMNS <- c(
  "id",
  "timestamp",
  "status",
  "duration",
  "address",
  "request_method",
  "host",
  "file",
  "modified"
)

#------------------------------------------------------------------------------
# Validation Functions (LOG-02, LOG-04)
#------------------------------------------------------------------------------

#' Validate column name against whitelist
#'
#' Checks if a column name is in the allowed list. Throws invalid_filter_error
#' if column is not allowed, preventing SQL injection via column names.
#'
#' @param column Character, the column name to validate
#' @param allowed Character vector, the whitelist of allowed columns.
#'   Defaults to LOGGING_ALLOWED_COLUMNS.
#' @param context Character, description for error message (default: "filter").
#'   Use "sort" when validating sort columns.
#'
#' @return The validated column name (unchanged)
#'
#' @details
#' Column names cannot use parameterized queries (? placeholders) because they
#' are structural parts of SQL, not data values. This whitelist approach is the
#' security layer for dynamic SQL.
#'
#' On validation failure, throws rlang::abort with class "invalid_filter_error".
#' This error class allows the endpoint to catch it and return a 400 Bad Request
#' with a helpful error message instead of a 500 Internal Server Error.
#'
#' @examples
#' \dontrun{
#' # Valid column - returns the column name
#' validate_logging_column("status")
#' # [1] "status"
#'
#' # Invalid column - throws error
#' validate_logging_column("nonexistent_column")
#' # Error: Invalid filter column: 'nonexistent_column'
#'
#' # SQL injection attempt - blocked
#' validate_logging_column("id; DROP TABLE logging; --")
#' # Error: Invalid filter column: 'id; DROP TABLE logging; --'
#' }
#'
#' @export
validate_logging_column <- function(
  column,
  allowed = LOGGING_ALLOWED_COLUMNS,
  context = "filter"
) {
  if (!column %in% allowed) {
    rlang::abort(
      message = paste0(
        "Invalid ", context, " column: '", column, "'. ",
        "Allowed columns: ", paste(allowed, collapse = ", ")
      ),
      class = "invalid_filter_error"
    )
  }
  column
}

#' Validate sort direction
#'
#' Ensures sort direction is either ASC or DESC. This validation prevents
#' SQL injection via the sort direction parameter.
#'
#' @param direction Character, the sort direction
#'
#' @return The validated direction (uppercase)
#'
#' @details
#' Like column names, sort direction cannot use parameterized queries.
#' This validation ensures only the two valid SQL sort directions are accepted.
#'
#' On validation failure, throws rlang::abort with class "invalid_filter_error".
#'
#' @examples
#' \dontrun{
#' # Valid directions - normalized to uppercase
#' validate_sort_direction("asc")
#' # [1] "ASC"
#'
#' validate_sort_direction("DESC")
#' # [1] "DESC"
#'
#' # Invalid direction - throws error
#' validate_sort_direction("sideways")
#' # Error: Invalid sort direction: 'SIDEWAYS'. Must be ASC or DESC.
#'
#' # SQL injection attempt - blocked
#' validate_sort_direction("DESC; DROP TABLE logging; --")
#' # Error: Invalid sort direction: 'DESC; DROP TABLE LOGGING; --'. Must be ASC or DESC.
#' }
#'
#' @export
validate_sort_direction <- function(direction) {
  direction <- toupper(trimws(direction))
  if (!direction %in% c("ASC", "DESC")) {
    rlang::abort(
      message = paste0(
        "Invalid sort direction: '", direction, "'. Must be ASC or DESC."
      ),
      class = "invalid_filter_error"
    )
  }
  direction
}

#------------------------------------------------------------------------------
# Query Builders (LOG-03)
#------------------------------------------------------------------------------

#' Build WHERE clause with parameterized values
#'
#' Constructs a WHERE clause string and corresponding parameter list
#' for the logging table. All values use ? placeholders for parameterization.
#'
#' @param filters Named list of filter criteria:
#'   \describe{
#'     \item{status}{Integer, exact match on HTTP status code}
#'     \item{request_method}{Character, exact match on method (GET, POST, etc.)}
#'     \item{path_prefix}{Character, prefix match on path (uses LIKE 'prefix%')}
#'     \item{timestamp_from}{Character, minimum timestamp (>= comparison)}
#'     \item{timestamp_to}{Character, maximum timestamp (<= comparison)}
#'     \item{address}{Character, exact match on IP address}
#'   }
#'
#' @return List with:
#'   \describe{
#'     \item{clause}{Character, the WHERE clause (without "WHERE" keyword)}
#'     \item{params}{List, the parameter values in order}
#'   }
#'
#' @details
#' The function always starts with "1=1" to simplify AND concatenation.
#' This allows filters to be conditionally added without checking if it's
#' the first filter or not.
#'
#' All filter values use ? placeholders (parameterized queries). The database
#' driver (DBI::dbBind) handles proper escaping, preventing SQL injection.
#'
#' The path_prefix filter uses LIKE with % suffix for index-friendly prefix
#' search. The % is appended to the value, not interpolated into SQL.
#'
#' Empty or NULL filter values are ignored and not added to the clause.
#'
#' @examples
#' \dontrun{
#' # Single filter
#' result <- build_logging_where_clause(list(status = 200))
#' # result$clause: "1=1 AND status = ?"
#' # result$params: list(200)
#'
#' # Multiple filters
#' result <- build_logging_where_clause(list(
#'   status = 200,
#'   path_prefix = "/api/",
#'   request_method = "GET"
#' ))
#' # result$clause: "1=1 AND status = ? AND request_method = ? AND path LIKE ?"
#' # result$params: list(200, "GET", "/api/%")
#'
#' # Date range filter
#' result <- build_logging_where_clause(list(
#'   timestamp_from = "2026-01-01 00:00:00",
#'   timestamp_to = "2026-01-31 23:59:59"
#' ))
#' # result$clause: "1=1 AND timestamp >= ? AND timestamp <= ?"
#' # result$params: list("2026-01-01 00:00:00", "2026-01-31 23:59:59")
#'
#' # No filters
#' result <- build_logging_where_clause(list())
#' # result$clause: "1=1"
#' # result$params: list()
#' }
#'
#' @export
build_logging_where_clause <- function(filters = list()) {
  where_clause <- "1=1"
  params <- list()

  # Status filter (exact match on HTTP status code)
  if (!is.null(filters$status) && filters$status != "") {
    where_clause <- paste(where_clause, "AND status = ?")
    params <- append(params, as.integer(filters$status))
  }

  # Request method filter (exact match)
  if (!is.null(filters$request_method) && filters$request_method != "") {
    where_clause <- paste(where_clause, "AND request_method = ?")
    params <- append(params, filters$request_method)
  }

  # Path prefix filter (LIKE with prefix for index use)
  # Uses LIKE 'prefix%' which can use an index on the path column
  if (!is.null(filters$path_prefix) && filters$path_prefix != "") {
    where_clause <- paste(where_clause, "AND path LIKE ?")
    params <- append(params, paste0(filters$path_prefix, "%"))
  }

  # Timestamp range filters
  if (!is.null(filters$timestamp_from) && filters$timestamp_from != "") {
    where_clause <- paste(where_clause, "AND timestamp >= ?")
    params <- append(params, filters$timestamp_from)
  }

  if (!is.null(filters$timestamp_to) && filters$timestamp_to != "") {
    where_clause <- paste(where_clause, "AND timestamp <= ?")
    params <- append(params, filters$timestamp_to)
  }

  # Address filter (exact match on IP address)
  if (!is.null(filters$address) && filters$address != "") {
    where_clause <- paste(where_clause, "AND address = ?")
    params <- append(params, filters$address)
  }

  list(
    clause = where_clause,
    params = params
  )
}

#' Build ORDER BY clause
#'
#' Constructs an ORDER BY clause with validated column and direction.
#' Both the column name and direction are validated before inclusion in SQL.
#'
#' @param sort_column Character, column to sort by. Default: "id"
#' @param sort_direction Character, ASC or DESC. Default: "DESC"
#'
#' @return Character, the ORDER BY clause (e.g., "ORDER BY id DESC")
#'
#' @details
#' The function validates both the sort column (against LOGGING_ALLOWED_SORT_COLUMNS)
#' and the sort direction (must be ASC or DESC) before constructing the clause.
#'
#' If validation fails, throws rlang::abort with class "invalid_filter_error".
#'
#' @examples
#' \dontrun{
#' # Default sort (id DESC)
#' build_logging_order_clause()
#' # [1] "ORDER BY id DESC"
#'
#' # Custom sort
#' build_logging_order_clause("timestamp", "ASC")
#' # [1] "ORDER BY timestamp ASC"
#'
#' # Invalid column - throws error
#' build_logging_order_clause("agent", "DESC")
#' # Error: Invalid sort column: 'agent'. Allowed columns: id, timestamp, ...
#'
#' # Invalid direction - throws error
#' build_logging_order_clause("id", "RANDOM")
#' # Error: Invalid sort direction: 'RANDOM'. Must be ASC or DESC.
#' }
#'
#' @export
build_logging_order_clause <- function(
  sort_column = "id",
  sort_direction = "DESC"
) {
  # Validate column against sort-specific whitelist
  validate_logging_column(sort_column, LOGGING_ALLOWED_SORT_COLUMNS, "sort")

  # Validate direction
  direction <- validate_sort_direction(sort_direction)

  paste("ORDER BY", sort_column, direction)
}

#------------------------------------------------------------------------------
# Pagination Helpers (PAG-01, PAG-02)
#------------------------------------------------------------------------------

#' Build offset-based pagination response
#'
#' Constructs a standardized pagination response object with data and metadata.
#' Provides all fields needed for UI pagination controls.
#'
#' @param data Tibble or data.frame, the paginated data for current page
#' @param total Integer, total count of matching rows (from COUNT query)
#' @param page Integer, current page number (1-indexed)
#' @param per_page Integer, page size (rows per page)
#'
#' @return List with:
#'   \describe{
#'     \item{data}{The input data (unchanged)}
#'     \item{meta}{List with pagination metadata:
#'       \describe{
#'         \item{totalCount}{Total matching rows}
#'         \item{pageSize}{Rows per page}
#'         \item{offset}{Row offset for current page (0-indexed)}
#'         \item{currentPage}{Current page number (1-indexed)}
#'         \item{totalPages}{Total number of pages}
#'         \item{hasMore}{Boolean, TRUE if more pages exist}
#'       }
#'     }
#'   }
#'
#' @details
#' Handles edge case of total=0 (returns totalPages=0, hasMore=FALSE).
#'
#' The offset is 0-indexed: page 1 has offset 0, page 2 has offset per_page, etc.
#' This matches the SQL OFFSET clause convention.
#'
#' totalPages uses ceiling() to handle partial last pages. For example,
#' 25 rows with per_page=10 yields totalPages=3.
#'
#' hasMore is TRUE when (offset + nrow(data)) < total, indicating there are
#' more rows beyond the current page that can be fetched.
#'
#' @examples
#' \dontrun{
#' # Page 1 of 3, 10 items per page, 25 total
#' data <- tibble(id = 1:10)
#' response <- build_offset_pagination_response(data, total = 25, page = 1, per_page = 10)
#' # response$meta$totalPages = 3
#' # response$meta$hasMore = TRUE
#' # response$meta$offset = 0
#'
#' # Last page (page 3)
#' data <- tibble(id = 21:25)  # Only 5 rows
#' response <- build_offset_pagination_response(data, total = 25, page = 3, per_page = 10)
#' # response$meta$hasMore = FALSE
#' # response$meta$offset = 20
#'
#' # Empty result (total=0)
#' data <- tibble()
#' response <- build_offset_pagination_response(data, total = 0, page = 1, per_page = 10)
#' # response$meta$totalPages = 0
#' # response$meta$hasMore = FALSE
#' }
#'
#' @export
build_offset_pagination_response <- function(data, total, page, per_page) {
  # Coerce to integer for safety
  page <- as.integer(page)
  per_page <- as.integer(per_page)
  total <- as.integer(total)

  # Calculate offset (0-indexed)
  offset <- (page - 1L) * per_page

  # Calculate total pages (handle total=0 edge case)
  total_pages <- if (total == 0L) 0L else as.integer(ceiling(total / per_page))

  # Calculate hasMore: are there more rows beyond current page?
  rows_fetched <- if (is.data.frame(data)) nrow(data) else length(data)
  has_more <- (offset + rows_fetched) < total

  list(
    data = data,
    meta = list(
      totalCount = total,
      pageSize = per_page,
      offset = offset,
      currentPage = page,
      totalPages = total_pages,
      hasMore = has_more
    )
  )
}

#------------------------------------------------------------------------------
# Main Query Functions (LOG-01, LOG-05, LOG-06)
#------------------------------------------------------------------------------

#' Get paginated log entries with filtering
#'
#' Fetches log entries from database with filtering and offset-based pagination.
#' Uses database-side filtering (WHERE clause) instead of loading all rows.
#'
#' @param status Integer or NULL, filter by HTTP status code (exact match)
#' @param request_method Character or NULL, filter by method (GET, POST, etc.)
#' @param path_prefix Character or NULL, filter by path prefix (LIKE 'prefix%')
#' @param timestamp_from Character or NULL, filter by minimum timestamp
#' @param timestamp_to Character or NULL, filter by maximum timestamp
#' @param address Character or NULL, filter by IP address (exact match)
#' @param page Integer, page number (1-indexed). Default: 1
#' @param per_page Integer, rows per page. Default: 50
#' @param sort_column Character, column to sort by. Default: "id"
#' @param sort_direction Character, ASC or DESC. Default: "DESC"
#'
#' @return List with data and meta (from build_offset_pagination_response)
#'
#' @details
#' This function is the main entry point for fetching logs with pagination.
#' It orchestrates the query building process:
#'
#' 1. Validates sort column against LOGGING_ALLOWED_SORT_COLUMNS
#' 2. Validates sort direction (ASC/DESC only)
#' 3. Builds WHERE clause with parameterized values
#' 4. Executes COUNT query first for totalCount
#' 5. Executes data query with LIMIT/OFFSET
#' 6. Returns standardized pagination response
#'
#' All filtering happens at the database level (LOG-01). This is critical for
#' performance - the function never uses collect() to load all rows into memory.
#'
#' @examples
#' \dontrun{
#' # Get first page of all logs
#' result <- get_logs_paginated()
#' # result$data contains first 50 rows
#' # result$meta$totalCount contains total matching rows
#'
#' # Get first page of 200 OK responses
#' result <- get_logs_paginated(status = 200, page = 1, per_page = 50)
#'
#' # Get logs from specific path prefix
#' result <- get_logs_paginated(path_prefix = "/api/entity", page = 2)
#'
#' # Get logs sorted by timestamp ascending
#' result <- get_logs_paginated(sort_column = "timestamp", sort_direction = "ASC")
#'
#' # Get logs from a specific time range
#' result <- get_logs_paginated(
#'   timestamp_from = "2026-01-01 00:00:00",
#'   timestamp_to = "2026-01-31 23:59:59"
#' )
#'
#' # Get error logs (4xx and 5xx status codes need separate calls)
#' errors_4xx <- get_logs_paginated(status = 400)
#' errors_5xx <- get_logs_paginated(status = 500)
#' }
#'
#' @export
get_logs_paginated <- function(
  status = NULL,
  request_method = NULL,
  path_prefix = NULL,
  timestamp_from = NULL,
  timestamp_to = NULL,
  address = NULL,
  page = 1L,
  per_page = 50L,
  sort_column = "id",
  sort_direction = "DESC"
) {
  log_info("Fetching logs: page={page}, per_page={per_page}, sort={sort_column} {sort_direction}")

  # Coerce pagination params to integer
  page <- as.integer(page)
  per_page <- as.integer(per_page)

  # Validate sort parameters (throws invalid_filter_error if invalid)
  validate_logging_column(sort_column, LOGGING_ALLOWED_SORT_COLUMNS, "sort")
  sort_direction <- validate_sort_direction(sort_direction)

  # Build filters list from function parameters
  filters <- list(
    status = status,
    request_method = request_method,
    path_prefix = path_prefix,
    timestamp_from = timestamp_from,
    timestamp_to = timestamp_to,
    address = address
  )

  # Build WHERE clause with parameterized values
  where_result <- build_logging_where_clause(filters)
  where_clause <- where_result$clause
  params <- where_result$params

  # Execute COUNT query for totalCount (LOG-06)
  # This runs first so we know the total before fetching the page
  count_sql <- paste("SELECT COUNT(*) as total FROM logging WHERE", where_clause)
  count_result <- db_execute_query(count_sql, params)
  total <- count_result$total[1] %||% 0L

  # Calculate offset for the current page
  offset <- (page - 1L) * per_page

  # Build ORDER BY clause
  order_clause <- paste("ORDER BY", sort_column, sort_direction)

  # Execute data query with LIMIT/OFFSET (LOG-05)
  # Only fetches the rows needed for the current page
  data_sql <- paste(
    "SELECT id, timestamp, address, agent, host, request_method, path, query, post, status, duration, file, modified",
    "FROM logging WHERE", where_clause,
    order_clause,
    "LIMIT ? OFFSET ?"
  )
  data_params <- append(params, list(per_page, offset))
  data_result <- db_execute_query(data_sql, data_params)

  log_debug("Fetched {nrow(data_result)} rows, total={total}")

  # Return with pagination metadata (PAG-01, PAG-02)
  build_offset_pagination_response(data_result, total, page, per_page)
}
