# functions/logging-repository.R
#
# Database repository for logging table operations.
# Provides the database-side query functions (get_logs_filtered,
# get_logs_first_page) for filtered, cursor-paginated log retrieval.
#
# The pure SQL-construction layer (column whitelists, validate_logging_column,
# validate_sort_direction, build_logging_where_clause, build_logging_order_clause,
# parse_logging_filter) was extracted into logging-query-builders.R in WP8
# (#401, part of #346). endpoints/logging_endpoints.R sources that builders file
# BEFORE this one because the query functions below call those builders.
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

  # Build ORDER BY clause. Non-unique sort columns need id as a stable
  # tiebreaker so cursor IDs point to the same row across page requests.
  order_clause <- build_logging_order_clause(sort_column, sort_direction)

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

#' Get the first logs page using SQL count and limit
#'
#' Fetches only the requested first page plus one lookahead row. This avoids
#' loading the repository safety cap into R before pagination.
#'
#' @param filters Named list of filter criteria
#' @param sort_column Character, column to sort by. Default: "id"
#' @param sort_direction Character, ASC or DESC. Default: "DESC"
#' @param page_size Integer, number of rows to return
#'
#' @return Cursor pagination list with links, meta, and data
#' @export
get_logs_first_page <- function(
  filters = list(),
  sort_column = "id",
  sort_direction = "DESC",
  page_size = 10L
) {
  log_info("Fetching first logs page: sort={sort_column} {sort_direction}, page_size={page_size}")

  validate_logging_column(sort_column, LOGGING_ALLOWED_SORT_COLUMNS, "sort")
  sort_direction <- validate_sort_direction(sort_direction)
  page_size_all <- identical(tolower(as.character(page_size)), "all")
  requested_page_size <- suppressWarnings(as.integer(page_size))

  where_result <- build_logging_where_clause(filters)
  where_clause <- where_result$clause
  params <- where_result$params
  order_clause <- build_logging_order_clause(sort_column, sort_direction)

  count_sql <- paste(
    "SELECT COUNT(*) AS total",
    "FROM logging WHERE", where_clause
  )
  count_result <- db_execute_query(count_sql, params)
  total_items <- as.integer(count_result$total[[1]] %||% 0L)
  page_size <- if (page_size_all) {
    total_items
  } else if (is.na(requested_page_size) || requested_page_size < 1L) {
    10L
  } else {
    min(requested_page_size, 500L)
  }
  total_pages <- if (total_items == 0L) 0L else ceiling(total_items / page_size)

  data_sql <- paste(
    "SELECT id, timestamp, address, agent, host, request_method, path,",
    "query, post, status, duration, file, modified",
    "FROM logging WHERE", where_clause,
    order_clause,
    "LIMIT ?"
  )
  lookahead_limit <- if (page_size_all) page_size else page_size + 1L
  data_result <- tibble::as_tibble(db_execute_query(data_sql, append(params, list(lookahead_limit))))
  has_next <- !page_size_all && nrow(data_result) > page_size
  page_data <- utils::head(data_result, page_size)

  current_page_last_id <- if (nrow(page_data) > 0L) {
    page_data$id[[nrow(page_data)]]
  } else {
    "null"
  }

  last_cursor_id <- "null"
  if (!page_size_all && total_pages > 1L) {
    last_cursor_offset <- as.integer(page_size * (total_pages - 1L) - 1L)
    last_cursor_sql <- paste(
      "SELECT id",
      "FROM logging WHERE", where_clause,
      order_clause,
      "LIMIT 1 OFFSET ?"
    )
    last_cursor_result <- db_execute_query(
      last_cursor_sql,
      append(params, list(last_cursor_offset))
    )
    if (nrow(last_cursor_result) > 0L) {
      last_cursor_id <- last_cursor_result$id[[1]]
    }
  }

  links <- tibble::as_tibble(list(
    "prev" = "null",
    "self" = paste0("&page_after=0&page_size=", page_size),
    "next" = if (has_next) {
      paste0("&page_after=", current_page_last_id, "&page_size=", page_size)
    } else {
      "null"
    },
    "last" = if (identical(last_cursor_id, "null")) {
      "null"
    } else {
      paste0("&page_after=", last_cursor_id, "&page_size=", page_size)
    }
  ))

  meta <- tibble::as_tibble(list(
    "perPage" = page_size,
    "currentPage" = 1L,
    "totalPages" = total_pages,
    "prevItemID" = "null",
    "currentItemID" = 0L,
    "nextItemID" = if (has_next) current_page_last_id else "null",
    "lastItemID" = last_cursor_id,
    "totalItems" = total_items
  ))

  list(links = links, meta = meta, data = page_data)
}
