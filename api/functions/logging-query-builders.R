# functions/logging-query-builders.R
#
# Pure SQL-construction layer for logging table queries.
# Split from logging-repository.R in WP8 (#401, part of #346).
#
# Provides column whitelist validation, WHERE/ORDER clause builders, and the
# filter-string parser used by the logging endpoints and by the database
# repository functions in logging-repository.R.
#
# Security model (see logging-repository.R for full notes):
# - Column names are validated against a whitelist (cannot be parameterized).
# - All filter VALUES use parameterized queries (? placeholders) in the
#   repository layer that consumes build_logging_where_clause().
#
# Lazy-loaded by endpoints/logging_endpoints.R, which sources this file BEFORE
# logging-repository.R because the repository query functions (get_logs_filtered,
# get_logs_first_page) call these builders. logging-repository.R itself is not
# registered in bootstrap/load_modules.R; both files are sourced on demand from
# the logging endpoint.

require(rlang)

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

  # Path contains filter (LIKE with wildcards for substring match)
  if (!is.null(filters$path_contains) && filters$path_contains != "") {
    where_clause <- paste(where_clause, "AND path LIKE ?")
    params <- append(params, paste0("%", filters$path_contains, "%"))
  }

  # Host filter (exact match)
  if (!is.null(filters$host) && filters$host != "") {
    where_clause <- paste(where_clause, "AND host = ?")
    params <- append(params, filters$host)
  }

  # Agent contains filter (LIKE with wildcards for substring match)
  if (!is.null(filters$agent_contains) && filters$agent_contains != "") {
    where_clause <- paste(where_clause, "AND agent LIKE ?")
    params <- append(params, paste0("%", filters$agent_contains, "%"))
  }

  # Any contains filter - search across multiple text columns
  if (!is.null(filters$any_contains) && filters$any_contains != "") {
    search_val <- paste0("%", filters$any_contains, "%")
    where_clause <- paste(
      where_clause,
      "AND (path LIKE ? OR agent LIKE ? OR query LIKE ? OR host LIKE ?)"
    )
    params <- append(params, list(search_val, search_val, search_val, search_val))
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

  if (sort_column == "id") {
    paste("ORDER BY id", direction)
  } else {
    paste0("ORDER BY ", sort_column, " ", direction, ", id ", direction)
  }
}

#' Parse filter string to filter list
#'
#' Converts the filter string from the endpoint into a list
#' that can be passed to get_logs_filtered().
#'
#' Supported filter formats (matching frontend conventions):
#' - contains(status,500) - exact match on status
#' - contains(request_method,GET) - exact match on method
#' - contains(path,/api/) - LIKE match on path
#' - contains(address,127.0.0.1) - exact match on address
#' - equals(column,value) - exact match
#' - greaterThan(timestamp,2026-01-01) - timestamp_from
#' - greaterThanOrEqual(timestamp,2026-01-01) - timestamp_from
#' - lessThan(timestamp,2026-01-31) - timestamp_to
#' - lessThanOrEqual(timestamp,2026-01-31) - timestamp_to
#' - and(expr1,expr2) - multiple filters combined
#'
#' @param filter_string Character, filter expression string
#'
#' @return Named list of filters for get_logs_filtered()
#'
#' @examples
#' \dontrun{
#' # Single filter
#' parse_logging_filter("contains(status,500)")
#' # list(status = 500)
#'
#' # Multiple filters with and()
#' parse_logging_filter("and(contains(status,200),contains(request_method,GET))")
#' # list(status = 200, request_method = "GET")
#'
#' # Path search
#' parse_logging_filter("contains(path,/api/)")
#' # list(path_contains = "/api/")
#' }
#'
#' @export
parse_logging_filter <- function(filter_string) {
  if (is.null(filter_string) || filter_string == "" || filter_string == "null") {
    return(list())
  }

  # URL decode the filter string
  filter_string <- URLdecode(filter_string)
  filter_string <- trimws(filter_string)

  filters <- list()

  # Helper function to parse a single expression like contains(column,value)
  parse_single_expr <- function(expr) {
    expr <- trimws(expr)
    if (expr == "") return(NULL)

    # Match pattern: operation(column,value)
    # Handle potential quotes around value
    match <- regmatches(
      expr,
      regexec("^(\\w+)\\(([^,]+),(.+)\\)$", expr)
    )[[1]]

    if (length(match) == 4) {
      operation <- match[2]
      column <- trimws(match[3])
      value <- trimws(match[4])
      # Remove surrounding quotes if present
      value <- gsub("^['\"]|['\"]$", "", value)

      return(list(operation = operation, column = column, value = value))
    }

    NULL
  }

  # Helper function to add a parsed expression to filters
  add_to_filters <- function(parsed_expr) {
    if (is.null(parsed_expr)) return()

    op <- parsed_expr$operation
    col <- parsed_expr$column
    val <- parsed_expr$value

    # Map operations to filter list keys
    if (op %in% c("contains", "equals")) {
      if (col == "status") {
        filters$status <<- as.integer(val)
      } else if (col == "request_method") {
        filters$request_method <<- val
      } else if (col == "address") {
        filters$address <<- val
      } else if (col == "path") {
        # For path, use LIKE matching
        filters$path_contains <<- val
      } else if (col == "host") {
        filters$host <<- val
      } else if (col == "agent") {
        filters$agent_contains <<- val
      } else if (col == "any") {
        # Search across all text columns
        filters$any_contains <<- val
      }
    } else if (op %in% c("greaterThan", "greaterThanOrEqual")) {
      if (col == "timestamp") {
        filters$timestamp_from <<- val
      }
    } else if (op %in% c("lessThan", "lessThanOrEqual")) {
      if (col == "timestamp") {
        filters$timestamp_to <<- val
      }
    }
  }

  # Check if wrapped in and() or or()
  if (grepl("^and\\(", filter_string) || grepl("^or\\(", filter_string)) {
    # Extract content inside and() or or()
    inner <- sub("^(and|or)\\((.*)\\)$", "\\2", filter_string)

    # Split by ),contains or ),equals etc. (careful parsing)
    # Use a regex that splits on ),operation(
    # Split carefully - find top-level commas between expressions
    exprs <- c()
    depth <- 0
    current <- ""
    for (char in strsplit(inner, "")[[1]]) {
      if (char == "(") depth <- depth + 1
      if (char == ")") depth <- depth - 1
      if (char == "," && depth == 0) {
        exprs <- c(exprs, current)
        current <- ""
      } else {
        current <- paste0(current, char)
      }
    }
    if (current != "") exprs <- c(exprs, current)

    # Parse each expression
    for (expr in exprs) {
      parsed <- parse_single_expr(expr)
      add_to_filters(parsed)
    }
  } else {
    # Single expression
    parsed <- parse_single_expr(filter_string)
    add_to_filters(parsed)
  }

  filters
}
