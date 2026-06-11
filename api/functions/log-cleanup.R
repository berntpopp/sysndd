# functions/log-cleanup.R
#### Reusable, testable helpers for retention-based cleanup of operational log
#### rows in the database. The thin entrypoint `scripts/delete_old_logs.R`
#### bootstraps config + the connection pool and delegates to `run_log_cleanup()`.
####
#### Scope: the high-volume operational request log table `logging`
#### (DATETIME `timestamp` column, indexed by `idx_logging_timestamp`). This is
#### the table the Plumber `postroute` hook writes one row per request to via
#### `log_message_to_db()`. Other low-volume audit tables (e.g.
#### `llm_generation_log`, `async_job_events`) are intentionally NOT pruned here;
#### they are operationally useful history and `async_job_events` already cascades
#### from `async_jobs`.

#' Default operational log table pruned by the cleanup job.
LOG_CLEANUP_DEFAULT_TABLE <- "logging"

#' Default timestamp column used for the retention predicate.
LOG_CLEANUP_DEFAULT_TIMESTAMP_COLUMN <- "timestamp"

#' Default retention window in days when none is configured.
LOG_CLEANUP_DEFAULT_RETENTION_DAYS <- 30L

#' Validate and coerce a log-retention value to a positive integer day count.
#'
#' The retention window is the only value that flows into the SQL predicate as a
#' literal (MySQL `INTERVAL` does not accept a bound placeholder for the unit
#' count in a portable way), so it must be strictly validated to an integer
#' before it is ever interpolated. String interpolation of an unvalidated value
#' would be an injection vector; coercing to a bounded integer removes it.
#'
#' @param value Raw retention value (character from env, or numeric).
#' @param default Fallback used when `value` is empty/NULL.
#' @return A single positive integer number of days.
#' @export
validate_retention_days <- function(value, default = LOG_CLEANUP_DEFAULT_RETENTION_DAYS) {
  if (is.null(value) || length(value) != 1L) {
    if (is.null(value)) {
      return(as.integer(default))
    }
    stop("retention days must be a single value", call. = FALSE)
  }

  if (is.character(value)) {
    value <- trimws(value)
    if (!nzchar(value)) {
      return(as.integer(default))
    }
    # Reject anything that is not a bare non-negative integer literal. This is
    # the guard that makes literal interpolation into the DELETE safe.
    if (!grepl("^[0-9]+$", value)) {
      stop(sprintf("invalid retention days: '%s' (expected a positive integer)", value), call. = FALSE)
    }
  }

  num <- suppressWarnings(as.numeric(value))
  if (is.na(num) || num != as.integer(num) || num < 1L) {
    stop(sprintf("invalid retention days: '%s' (expected a positive integer >= 1)", as.character(value)), call. = FALSE)
  }

  as.integer(num)
}

#' Validate a SQL identifier (table or column name) against a strict allowlist.
#'
#' Only bare ASCII identifiers (letters, digits, underscore; not starting with a
#' digit) are accepted. Identifiers are never user-supplied here, but validating
#' them keeps the SQL builders injection-proof by construction.
#'
#' @param identifier The identifier to validate.
#' @param what Human-readable label used in error messages.
#' @return The identifier, unchanged, when valid.
#' @export
validate_sql_identifier <- function(identifier, what = "identifier") {
  if (is.null(identifier) || length(identifier) != 1L || !is.character(identifier) ||
        is.na(identifier) || !nzchar(identifier)) {
    stop(sprintf("invalid %s: must be a non-empty string", what), call. = FALSE)
  }
  if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", identifier)) {
    stop(sprintf("invalid %s: '%s' is not a bare SQL identifier", what, identifier), call. = FALSE)
  }
  identifier
}

#' Build the COUNT(*) query used to report how many rows would be deleted.
#'
#' @param table Validated table name.
#' @param timestamp_column Validated timestamp column name.
#' @param retention_days Validated positive integer day count.
#' @return A single SQL string.
#' @export
build_log_cleanup_count_sql <- function(table = LOG_CLEANUP_DEFAULT_TABLE,
                                        timestamp_column = LOG_CLEANUP_DEFAULT_TIMESTAMP_COLUMN,
                                        retention_days = LOG_CLEANUP_DEFAULT_RETENTION_DAYS) {
  table <- validate_sql_identifier(table, "table name")
  timestamp_column <- validate_sql_identifier(timestamp_column, "timestamp column")
  retention_days <- validate_retention_days(retention_days)

  sprintf(
    "SELECT COUNT(*) AS n FROM %s WHERE %s < (NOW() - INTERVAL %d DAY)",
    table, timestamp_column, retention_days
  )
}

#' Build the DELETE statement that prunes rows older than the retention window.
#'
#' The retention day count is interpolated as a validated integer; the table and
#' column are validated bare identifiers. No untrusted value reaches the SQL.
#'
#' @param table Validated table name.
#' @param timestamp_column Validated timestamp column name.
#' @param retention_days Validated positive integer day count.
#' @return A single SQL string.
#' @export
build_log_cleanup_delete_sql <- function(table = LOG_CLEANUP_DEFAULT_TABLE,
                                         timestamp_column = LOG_CLEANUP_DEFAULT_TIMESTAMP_COLUMN,
                                         retention_days = LOG_CLEANUP_DEFAULT_RETENTION_DAYS) {
  table <- validate_sql_identifier(table, "table name")
  timestamp_column <- validate_sql_identifier(timestamp_column, "timestamp column")
  retention_days <- validate_retention_days(retention_days)

  sprintf(
    "DELETE FROM %s WHERE %s < (NOW() - INTERVAL %d DAY)",
    table, timestamp_column, retention_days
  )
}

#' Resolve the cleanup configuration from environment variables.
#'
#' Env vars (with defaults):
#' - `LOG_RETENTION_DAYS`  -> retention window in days (default 30)
#' - `LOG_CLEANUP_DRY_RUN` -> when truthy, count only, do not delete
#' - `LOG_CLEANUP_TABLE`   -> override table name (default `logging`)
#' - `LOG_CLEANUP_TIMESTAMP_COLUMN` -> override timestamp column (default `timestamp`)
#'
#' @param getenv Function used to read env vars (injectable for tests).
#' @return A validated list: table, timestamp_column, retention_days, dry_run.
#' @export
log_cleanup_config_from_env <- function(getenv = Sys.getenv) {
  retention_days <- validate_retention_days(getenv("LOG_RETENTION_DAYS", ""))
  table <- getenv("LOG_CLEANUP_TABLE", LOG_CLEANUP_DEFAULT_TABLE)
  timestamp_column <- getenv("LOG_CLEANUP_TIMESTAMP_COLUMN", LOG_CLEANUP_DEFAULT_TIMESTAMP_COLUMN)
  dry_run <- log_cleanup_env_is_true(getenv("LOG_CLEANUP_DRY_RUN", ""))

  list(
    table = validate_sql_identifier(table, "table name"),
    timestamp_column = validate_sql_identifier(timestamp_column, "timestamp column"),
    retention_days = retention_days,
    dry_run = dry_run
  )
}

#' Interpret a truthy environment-variable string.
#'
#' @param value Raw env value.
#' @return TRUE when the value is one of 1/true/yes/on (case-insensitive).
#' @export
log_cleanup_env_is_true <- function(value) {
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    return(FALSE)
  }
  tolower(trimws(as.character(value))) %in% c("1", "true", "yes", "on")
}

#' Run the log-cleanup routine.
#'
#' Counts the candidate rows, then (unless dry-run) deletes them, returning a
#' structured summary. The DB layer is injected so the routine is fully testable
#' without a live database.
#'
#' @param config A config list (see `log_cleanup_config_from_env()`).
#' @param count_fn Function(sql) -> integer count of matching rows.
#' @param execute_fn Function(sql) -> integer rows affected by the DELETE.
#' @param logger Function(msg) used for human-readable progress output.
#' @return Invisibly, a summary list (table, retention_days, dry_run,
#'   candidate_rows, deleted_rows).
#' @export
run_log_cleanup <- function(config,
                            count_fn,
                            execute_fn,
                            logger = message) {
  stopifnot(is.list(config), is.function(count_fn), is.function(execute_fn))

  count_sql <- build_log_cleanup_count_sql(
    config$table, config$timestamp_column, config$retention_days
  )
  candidate_rows <- as.integer(count_fn(count_sql))
  if (length(candidate_rows) != 1L || is.na(candidate_rows)) {
    candidate_rows <- 0L
  }

  logger(sprintf(
    "[log-cleanup] table=%s column=%s retention_days=%d candidates=%d dry_run=%s",
    config$table, config$timestamp_column, config$retention_days,
    candidate_rows, tolower(as.character(config$dry_run))
  ))

  if (isTRUE(config$dry_run)) {
    logger(sprintf(
      "[log-cleanup] DRY RUN: would delete %d row(s) from %s; no rows removed",
      candidate_rows, config$table
    ))
    return(invisible(list(
      table = config$table,
      retention_days = config$retention_days,
      dry_run = TRUE,
      candidate_rows = candidate_rows,
      deleted_rows = 0L
    )))
  }

  delete_sql <- build_log_cleanup_delete_sql(
    config$table, config$timestamp_column, config$retention_days
  )
  deleted_rows <- as.integer(execute_fn(delete_sql))
  if (length(deleted_rows) != 1L || is.na(deleted_rows)) {
    deleted_rows <- 0L
  }

  logger(sprintf(
    "[log-cleanup] deleted %d row(s) from %s (retention %d day(s))",
    deleted_rows, config$table, config$retention_days
  ))

  invisible(list(
    table = config$table,
    retention_days = config$retention_days,
    dry_run = FALSE,
    candidate_rows = candidate_rows,
    deleted_rows = deleted_rows
  ))
}
