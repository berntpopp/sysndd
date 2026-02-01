# api/functions/comparisons-sources.R
#
# Source configuration and metadata management for comparisons data refresh.
# Provides functions to read/update source URLs from database config table.
#
# Usage:
#   source("functions/comparisons-sources.R", local = FALSE)
#
# Functions:
#   - get_active_sources(conn): Fetch active sources from comparisons_config
#   - update_source_last_updated(conn, source_name): Update timestamp after download
#   - get_comparisons_metadata(conn): Get last refresh info for UI display
#   - update_comparisons_metadata(conn, status, sources_count, rows_imported, error): Update metadata

library(DBI)
library(dplyr)
library(dbplyr)

#' Get Active Comparison Sources
#'
#' Fetches all active sources from the comparisons_config table.
#' These are the external databases to download during a refresh.
#'
#' @param conn Database connection (DBI connection, not pool)
#'
#' @return Tibble with columns: source_name, source_url, file_format, last_updated
#'
#' @examples
#' \dontrun{
#' sources <- get_active_sources(conn)
#' for (i in seq_len(nrow(sources))) {
#'   download_source_data(sources[i, ], temp_dir)
#' }
#' }
#'
#' @export
get_active_sources <- function(conn) {
  query <- "
    SELECT source_name, source_url, file_format, last_updated
    FROM comparisons_config
    WHERE is_active = TRUE
    ORDER BY id
  "

  result <- DBI::dbGetQuery(conn, query)
  tibble::as_tibble(result)
}

#' Update Source Last Updated Timestamp
#'
#' Updates the last_updated timestamp for a specific source after successful download.
#'
#' @param conn Database connection (DBI connection, not pool)
#' @param source_name Character string identifying the source
#'
#' @return Invisible NULL (side effect: database updated)
#'
#' @export
update_source_last_updated <- function(conn, source_name) {
  query <- "UPDATE comparisons_config SET last_updated = NOW() WHERE source_name = ?"
  stmt <- DBI::dbSendStatement(conn, query)
  DBI::dbBind(stmt, list(source_name))
  DBI::dbClearResult(stmt)
  invisible(NULL)
}

#' Get Comparisons Metadata
#'
#' Fetches the comparisons metadata for UI display (last refresh info).
#'
#' @param conn Database connection (DBI connection, not pool). Can also be a pool.
#'
#' @return Tibble with single row containing refresh metadata
#'
#' @export
get_comparisons_metadata <- function(conn) {
  query <- "
    SELECT
      last_full_refresh,
      last_refresh_status,
      last_refresh_error,
      sources_count,
      rows_imported,
      updated_at
    FROM comparisons_metadata
    LIMIT 1
  "

  result <- DBI::dbGetQuery(conn, query)
  tibble::as_tibble(result)
}

#' Update Comparisons Metadata
#'
#' Updates the comparisons_metadata table with refresh status and statistics.
#' Called at the end of a refresh job (success or failure).
#'
#' @param conn Database connection (DBI connection, not pool)
#' @param status Character: "success", "failed", "running", "never"
#' @param sources_count Integer: number of sources processed
#' @param rows_imported Integer: total rows imported
#' @param error_message Character or NULL: error message if failed
#'
#' @return Invisible NULL (side effect: database updated)
#'
#' @export
update_comparisons_metadata <- function(conn,
                                        status,
                                        sources_count = 0,
                                        rows_imported = 0,
                                        error_message = NULL) {
  if (status == "success") {
    # Update with success, set last_full_refresh to NOW()
    query <- "
      UPDATE comparisons_metadata
      SET last_full_refresh = NOW(),
          last_refresh_status = ?,
          last_refresh_error = NULL,
          sources_count = ?,
          rows_imported = ?
      WHERE id = 1
    "
    stmt <- DBI::dbSendStatement(conn, query)
    DBI::dbBind(stmt, list(status, sources_count, rows_imported))
    DBI::dbClearResult(stmt)
  } else {
    # Update with failure or other status
    query <- "
      UPDATE comparisons_metadata
      SET last_refresh_status = ?,
          last_refresh_error = ?,
          sources_count = ?,
          rows_imported = ?
      WHERE id = 1
    "
    stmt <- DBI::dbSendStatement(conn, query)
    DBI::dbBind(stmt, list(status, error_message, sources_count, rows_imported))
    DBI::dbClearResult(stmt)
  }

  invisible(NULL)
}

#' Get All Source Names
#'
#' Returns a vector of all source names (active and inactive) for reference.
#'
#' @param conn Database connection
#'
#' @return Character vector of source names
#'
#' @export
get_all_source_names <- function(conn) {
  query <- "SELECT source_name FROM comparisons_config ORDER BY id"
  result <- DBI::dbGetQuery(conn, query)
  result$source_name
}
