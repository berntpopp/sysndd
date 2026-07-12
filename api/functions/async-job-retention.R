# functions/async-job-retention.R
#### Retention-based cleanup of terminal `async_jobs` rows (#535 S7).
####
#### The `async_jobs` table (and its `result_json`/`request_payload_json` JSON
#### columns, plus the cascading `async_job_events`) grows monotonically: nothing
#### prunes it today (log-cleanup.R deliberately scopes itself to `logging`). This
#### module prunes only TERMINAL, non-retryable rows older than a retention window,
#### mirroring log-cleanup.R's injection-safe, DB-injected, unit-testable shape and
#### reusing its `validate_retention_days()` guard.
####
#### Terminal + non-retryable = status IN ('completed','failed','cancelled') AND
#### active_request_hash IS NULL. `active_request_hash` is the generated column S2
#### uses to define "not currently active and not pending a retry" (a failed row
#### still awaiting a retry keeps a non-NULL active_request_hash), so this predicate
#### never deletes a job that is queued, running, cancel-requested, or retry-pending.
#### Deleting parent rows cascades to `async_job_events`.
####
#### Depends on validate_retention_days() from functions/log-cleanup.R (sourced
#### before this file by the entrypoint script and the tests).

#' Default retention window for terminal async jobs (days). Longer than the
#' request-log window because job history is more operationally useful.
ASYNC_JOB_RETENTION_DEFAULT_DAYS <- 90L

#' Default DELETE batch size — keeps a first-run backlog from becoming one giant
#' transaction (row locks / undo / replication lag). The run loop commits between
#' batches until fewer than a full batch remain.
ASYNC_JOB_RETENTION_BATCH_SIZE <- 1000L

#' The terminal + non-retryable predicate shared by the count and delete builders.
#' Age is gated on BOTH submitted_at (indexed, prunes the bulk) AND updated_at (the
#' last state change — i.e. when the row became/stayed terminal), so a job that was
#' submitted long ago but only just completed is not deleted immediately after its
#' terminal write. `%1$d` interpolates the one validated retention-day integer.
.async_job_retention_predicate <- paste(
  "status IN ('completed', 'failed', 'cancelled')",
  "AND active_request_hash IS NULL",
  "AND submitted_at < (NOW() - INTERVAL %1$d DAY)",
  "AND updated_at < (NOW() - INTERVAL %1$d DAY)"
)

#' Build the COUNT(*) query for prunable terminal jobs.
#'
#' @param retention_days Validated positive integer day count.
#' @return A single SQL string.
#' @export
build_async_job_retention_count_sql <- function(retention_days = ASYNC_JOB_RETENTION_DEFAULT_DAYS) {
  retention_days <- validate_retention_days(retention_days, ASYNC_JOB_RETENTION_DEFAULT_DAYS)
  sprintf(
    paste("SELECT COUNT(*) AS n FROM async_jobs WHERE", .async_job_retention_predicate),
    retention_days
  )
}

#' Build the DELETE statement that prunes terminal jobs older than the window.
#'
#' The retention day count is interpolated only as a validated integer; every
#' other token is a fixed literal. No untrusted value reaches the SQL.
#'
#' @param retention_days Validated positive integer day count.
#' @return A single SQL string.
#' @export
build_async_job_retention_delete_sql <- function(retention_days = ASYNC_JOB_RETENTION_DEFAULT_DAYS,
                                                 batch_size = NULL) {
  retention_days <- validate_retention_days(retention_days, ASYNC_JOB_RETENTION_DEFAULT_DAYS)
  sql <- sprintf(
    paste("DELETE FROM async_jobs WHERE", .async_job_retention_predicate),
    retention_days
  )
  if (!is.null(batch_size)) {
    batch_size <- validate_retention_days(batch_size, ASYNC_JOB_RETENTION_BATCH_SIZE)
    sql <- sprintf("%s LIMIT %d", sql, batch_size)
  }
  sql
}

#' Resolve the async-job retention configuration from environment variables.
#'
#' Env vars (defaults): `ASYNC_JOB_RETENTION_DAYS` (90),
#' `ASYNC_JOB_RETENTION_DRY_RUN` (false).
#'
#' @param getenv Function used to read env vars (injectable for tests).
#' @return A validated list: retention_days, dry_run.
#' @export
async_job_retention_config_from_env <- function(getenv = Sys.getenv) {
  list(
    retention_days = validate_retention_days(
      getenv("ASYNC_JOB_RETENTION_DAYS", ""), ASYNC_JOB_RETENTION_DEFAULT_DAYS
    ),
    dry_run = log_cleanup_env_is_true(getenv("ASYNC_JOB_RETENTION_DRY_RUN", ""))
  )
}

#' Run the async-job retention prune.
#'
#' Counts prunable terminal rows, then (unless dry-run) deletes them, returning a
#' structured summary. The DB layer is injected so the routine is fully testable
#' without a live database.
#'
#' @param config A config list (see `async_job_retention_config_from_env()`).
#' @param count_fn Function(sql) -> integer count.
#' @param execute_fn Function(sql) -> integer rows affected.
#' @param logger Function(msg) for human-readable progress.
#' @return Invisibly, a summary list (retention_days, dry_run, candidate_rows,
#'   deleted_rows).
#' @export
run_async_job_retention <- function(config, count_fn, execute_fn, logger = message) {
  stopifnot(is.list(config), is.function(count_fn), is.function(execute_fn))

  count_sql <- build_async_job_retention_count_sql(config$retention_days)
  candidate_rows <- as.integer(count_fn(count_sql))
  if (length(candidate_rows) != 1L || is.na(candidate_rows)) {
    candidate_rows <- 0L
  }

  logger(sprintf(
    "[job-retention] table=async_jobs retention_days=%d candidates=%d dry_run=%s",
    config$retention_days, candidate_rows, tolower(as.character(config$dry_run))
  ))

  if (isTRUE(config$dry_run)) {
    logger(sprintf(
      "[job-retention] DRY RUN: would delete %d terminal job row(s); no rows removed",
      candidate_rows
    ))
    return(invisible(list(
      retention_days = config$retention_days, dry_run = TRUE,
      candidate_rows = candidate_rows, deleted_rows = 0L
    )))
  }

  # Delete in bounded batches, each its own auto-committed statement, so a large
  # first-run backlog never becomes one giant transaction / lock set.
  batch_size <- ASYNC_JOB_RETENTION_BATCH_SIZE
  deleted_rows <- 0L
  repeat {
    n <- as.integer(execute_fn(
      build_async_job_retention_delete_sql(config$retention_days, batch_size)
    ))
    if (length(n) != 1L || is.na(n)) {
      n <- 0L
    }
    deleted_rows <- deleted_rows + n
    if (n < batch_size) {
      break
    }
  }

  logger(sprintf(
    "[job-retention] deleted %d terminal job row(s) in batches of %d (retention %d day(s))",
    deleted_rows, batch_size, config$retention_days
  ))

  invisible(list(
    retention_days = config$retention_days, dry_run = FALSE,
    candidate_rows = candidate_rows, deleted_rows = deleted_rows
  ))
}
