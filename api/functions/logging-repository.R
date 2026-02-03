# functions/logging-repository.R
#
# Database repository for logging table operations.
# Provides query building and column validation for database-side filtering.
#
# Key features:
# - Column whitelist validation to prevent SQL injection
# - Parameterized queries via db_execute_query()
# - Database-side filtering (fixes #152 memory issue)
# - Compatible with existing cursor-based pagination (generate_cursor_pag_inf)
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
# Database Query Functions (LOG-01, LOG-05, LOG-06)
#------------------------------------------------------------------------------
#
# NOTE: This API uses CURSOR-BASED PAGINATION (page_after, page_size) not
# offset-based pagination (page, per_page). The existing generate_cursor_pag_inf()
# function handles pagination formatting. These repository functions provide
# database-side filtering to avoid loading all rows into memory.

#' Get filtered log entries for cursor pagination
#'
#' Fetches log entries from database with filtering. The result is a tibble
#' that can be passed to generate_cursor_pag_inf() for cursor-based pagination.
#'
#' This function performs database-side filtering (WHERE clause) instead of
#' loading all rows with collect(). This is the key fix for issue #152.
#'
#' @param filters Named list of filter criteria (from parse_filter_to_list)
#' @param sort_column Character, column to sort by. Default: "id"
#' @param sort_direction Character, ASC or DESC. Default: "DESC"
#' @param max_rows Integer, maximum rows to return. Default: 100000 (safety limit)
#'
#' @return Tibble with filtered log entries, ready for generate_cursor_pag_inf()
#'
#' @details
#' The function:
#' 1. Validates sort column against LOGGING_ALLOWED_SORT_COLUMNS
#' 2. Validates sort direction (ASC/DESC only)
#' 3. Builds WHERE clause with parameterized values
#' 4. Executes query with ORDER BY for consistent pagination
#' 5. Returns tibble compatible with generate_cursor_pag_inf()
#'
#' Unlike the old collect() approach, this filters at the database level.
#' The max_rows parameter provides a safety limit to prevent memory issues
#' even with very broad filters.
#'
#' @examples
#' \dontrun{
#' # Get all logs (up to max_rows)
#' logs <- get_logs_filtered()
#'
#' # Get logs with status filter
#' logs <- get_logs_filtered(list(status = 200))
#'
#' # Get logs with path prefix
#' logs <- get_logs_filtered(list(path_prefix = "/api/entity"))
#'
#' # Then use with cursor pagination:
#' result <- generate_cursor_pag_inf(logs, page_size = 50, page_after = 0, "id")
#' }
#'
#' @export
get_logs_filtered <- function(
  filters = list(),
  sort_column = "id",
  sort_direction = "DESC",
  max_rows = 100000L
) {
  log_info("Fetching filtered logs: sort={sort_column} {sort_direction}")

  # Validate sort parameters (throws invalid_filter_error if invalid)
  validate_logging_column(sort_column, LOGGING_ALLOWED_SORT_COLUMNS, "sort")
  sort_direction <- validate_sort_direction(sort_direction)

  # Build WHERE clause with parameterized values
  where_result <- build_logging_where_clause(filters)
  where_clause <- where_result$clause
  params <- where_result$params

  # Build ORDER BY clause
  order_clause <- paste("ORDER BY", sort_column, sort_direction)

  # Execute query with LIMIT for safety (LOG-01)
  # The LIMIT prevents memory issues even with very broad filters
  data_sql <- paste(
    "SELECT id, timestamp, address, agent, host, request_method, path,",
    "query, post, status, duration, file, modified",
    "FROM logging WHERE", where_clause,
    order_clause,
    "LIMIT ?"
  )
  data_params <- append(params, list(as.integer(max_rows)))
  data_result <- db_execute_query(data_sql, data_params)

  log_info("Fetched {nrow(data_result)} rows from database")

  # Return as tibble for compatibility with generate_cursor_pag_inf
  tibble::as_tibble(data_result)
}

#' Parse filter string to filter list
#'
#' Converts the comma-separated filter string from the endpoint into a list
#' that can be passed to get_logs_filtered().
#'
#' Supported filter formats:
#' - status==200 (exact match on status)
#' - request_method==GET (exact match on method)
#' - path=^/api/ (prefix match on path, converted to path_prefix)
#' - timestamp>2026-01-01 (converted to timestamp_from)
#' - timestamp<2026-01-31 (converted to timestamp_to)
#' - address==127.0.0.1 (exact match on address)
#'
#' @param filter_string Character, comma-separated filter expressions
#'
#' @return Named list of filters for get_logs_filtered()
#'
#' @examples
#' \dontrun{
#' # Single filter
#' parse_logging_filter("status==200")
#' # list(status = 200)
#'
#' # Multiple filters
#' parse_logging_filter("status==200,request_method==GET")
#' # list(status = 200, request_method = "GET")
#'
#' # Path prefix (special handling)
#' parse_logging_filter("path=^/api/")
#' # list(path_prefix = "/api/")
#' }
#'
#' @export
parse_logging_filter <- function(filter_string) {
  if (is.null(filter_string) || filter_string == "") {
    return(list())
  }

  filters <- list()
  parts <- strsplit(filter_string, ",")[[1]]

  for (part in parts) {
    part <- trimws(part)
    if (part == "") next

    # Handle different operators
    if (grepl("==", part)) {
      # Exact match: column==value
      split <- strsplit(part, "==")[[1]]
      if (length(split) == 2) {
        col <- trimws(split[1])
        val <- trimws(split[2])

        # Map to filter list keys
        if (col == "status") {
          filters$status <- as.integer(val)
        } else if (col == "request_method") {
          filters$request_method <- val
        } else if (col == "address") {
          filters$address <- val
        }
      }
    } else if (grepl("=\\^", part)) {
      # Prefix match: column=^prefix (path=^/api/)
      split <- strsplit(part, "=\\^")[[1]]
      if (length(split) == 2) {
        col <- trimws(split[1])
        val <- trimws(split[2])

        if (col == "path") {
          filters$path_prefix <- val
        }
      }
    } else if (grepl(">=", part)) {
      # Greater than or equal: column>=value
      split <- strsplit(part, ">=")[[1]]
      if (length(split) == 2) {
        col <- trimws(split[1])
        val <- trimws(split[2])

        if (col == "timestamp") {
          filters$timestamp_from <- val
        }
      }
    } else if (grepl("<=", part)) {
      # Less than or equal: column<=value
      split <- strsplit(part, "<=")[[1]]
      if (length(split) == 2) {
        col <- trimws(split[1])
        val <- trimws(split[2])

        if (col == "timestamp") {
          filters$timestamp_to <- val
        }
      }
    } else if (grepl(">", part)) {
      # Greater than: column>value
      split <- strsplit(part, ">")[[1]]
      if (length(split) == 2) {
        col <- trimws(split[1])
        val <- trimws(split[2])

        if (col == "timestamp") {
          filters$timestamp_from <- val
        }
      }
    } else if (grepl("<", part)) {
      # Less than: column<value
      split <- strsplit(part, "<")[[1]]
      if (length(split) == 2) {
        col <- trimws(split[1])
        val <- trimws(split[2])

        if (col == "timestamp") {
          filters$timestamp_to <- val
        }
      }
    }
  }

  filters
}
