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
#### LOCK-SAFE BATCHING: each batch first does a NON-LOCKING snapshot read to pick
#### up to `batch_size` candidate PKs (oldest-first), then DELETEs by PRIMARY KEY
#### (`job_id IN (...)`) while RE-CHECKING the full terminal predicate. A single
#### `DELETE ... WHERE <pred> LIMIT n` would lock every index record it SCANS (not
#### just the n it deletes), so a large tail of old-but-nonqualifying rows (e.g.
#### terminal rows whose `updated_at` was just bumped by the S2b payload scrub)
#### could block workers; deleting by PK locks only the targeted rows. The DELETE's
#### predicate re-check also makes it a same-partition proof that a row did not
#### become active/retryable between the read and the delete.
####
#### SQL SAFETY: every WHERE clause is a FIXED literal template; the retention
#### window, batch size, and candidate PKs are all passed as BOUND parameters, so
#### no value is ever interpolated into a statement. The window is also
#### independently range/type-validated via validate_retention_days() (defense in
#### depth: 0 / negative / unset fails closed to the default, never "delete all").
#### Verified end-to-end against a live MySQL/RMariaDB DB.
####
#### Depends on validate_retention_days() from functions/log-cleanup.R (sourced
#### before this file by the entrypoint script and the tests).

#' Default retention window for terminal async jobs (days). Longer than the
#' request-log window because job history is more operationally useful.
ASYNC_JOB_RETENTION_DEFAULT_DAYS <- 90L

#' Default candidate batch size — keeps a first-run backlog from becoming one
#' giant transaction (row locks / undo / replication lag). The run loop commits
#' between batches until fewer than a full batch remain.
ASYNC_JOB_RETENTION_BATCH_SIZE <- 1000L

#' Hard upper bound on batches per invocation so a single daily run can never
#' monopolize the sidecar (huge first-run backlog, or a table that keeps
#' producing qualifying terminal rows). 1000 batches * 1000 rows = up to 1M rows
#' pruned per run; any remainder is left for the next daily run.
ASYNC_JOB_RETENTION_MAX_BATCHES <- 1000L

#' Wall-clock ceiling (seconds) for one invocation's batch loop. Complements the
#' batch cap: whichever bound trips first stops the run and leaves the remainder
#' for the next daily run, so the destructive loop can never run unbounded.
ASYNC_JOB_RETENTION_MAX_SECONDS <- 600L

#' The terminal + non-retryable + aged WHERE clause shared by the count, select,
#' and delete builders, as a PARAMETERIZED template. Age is gated on BOTH
#' submitted_at (indexed, prunes the bulk) AND updated_at (the last state change —
#' i.e. when the row became/stayed terminal), so a job submitted long ago but only
#' just completed is not deleted immediately after its terminal write. The two `?`
#' placeholders bind the (negative) retention-day offset for TIMESTAMPADD.
.async_job_retention_where <- paste(
  "status IN ('completed', 'failed', 'cancelled')",
  "AND active_request_hash IS NULL",
  "AND submitted_at < TIMESTAMPADD(DAY, ?, CURRENT_TIMESTAMP(6))",
  "AND updated_at < TIMESTAMPADD(DAY, ?, CURRENT_TIMESTAMP(6))"
)

#' Build the parameterized COUNT(*) query for prunable terminal jobs.
#'
#' @param retention_days Validated positive integer day count.
#' @return A list `{sql, params}` for `db_execute_query()`.
#' @export
build_async_job_retention_count_sql <- function(retention_days = ASYNC_JOB_RETENTION_DEFAULT_DAYS) {
  retention_days <- validate_retention_days(retention_days, ASYNC_JOB_RETENTION_DEFAULT_DAYS)
  offset <- -retention_days
  list(
    sql = paste("SELECT COUNT(*) AS n FROM async_jobs WHERE", .async_job_retention_where),
    params = list(offset, offset)
  )
}

#' Build the parameterized SELECT that reads up to `batch_size` candidate PKs
#' (oldest-first) for one delete batch. A plain snapshot read: it takes no row
#' locks, so scanning old-but-nonqualifying rows never blocks workers.
#'
#' @param retention_days Validated positive integer day count.
#' @param batch_size Validated positive integer LIMIT for one batch.
#' @return A list `{sql, params}` for `db_execute_query()`.
#' @export
build_async_job_retention_select_ids_sql <- function(retention_days = ASYNC_JOB_RETENTION_DEFAULT_DAYS,
                                                     batch_size = ASYNC_JOB_RETENTION_BATCH_SIZE) {
  retention_days <- validate_retention_days(retention_days, ASYNC_JOB_RETENTION_DEFAULT_DAYS)
  batch_size <- validate_retention_days(batch_size, ASYNC_JOB_RETENTION_BATCH_SIZE)
  offset <- -retention_days
  list(
    sql = paste(
      "SELECT job_id FROM async_jobs WHERE", .async_job_retention_where,
      "ORDER BY submitted_at, job_id LIMIT ?"
    ),
    params = list(offset, offset, batch_size)
  )
}

#' Build the parameterized DELETE that removes the given candidate PKs, RE-checking
#' the full terminal predicate so a row that became active/retryable (or was
#' touched, bumping updated_at) between the read and the delete is left untouched.
#' Locking is confined to the named PRIMARY KEYs.
#'
#' @param job_ids Non-empty character vector of candidate job_id PKs.
#' @param retention_days Validated positive integer day count.
#' @return A list `{sql, params}` for `db_execute_statement()`.
#' @export
build_async_job_retention_delete_by_ids_sql <- function(job_ids,
                                                        retention_days = ASYNC_JOB_RETENTION_DEFAULT_DAYS) {
  job_ids <- as.character(job_ids)
  job_ids <- job_ids[!is.na(job_ids) & nzchar(job_ids)]
  if (length(job_ids) < 1L) {
    stop("build_async_job_retention_delete_by_ids_sql(): at least one job_id required", call. = FALSE)
  }
  retention_days <- validate_retention_days(retention_days, ASYNC_JOB_RETENTION_DEFAULT_DAYS)
  offset <- -retention_days
  placeholders <- paste(rep("?", length(job_ids)), collapse = ", ")
  list(
    sql = paste0(
      "DELETE FROM async_jobs WHERE job_id IN (", placeholders, ") AND ",
      .async_job_retention_where
    ),
    params = c(as.list(job_ids), list(offset, offset))
  )
}

#' Resolve the dry-run flag with a fail-safe bias for this DESTRUCTIVE prune.
#'
#' This is stricter than the shared `log_cleanup_env_is_true()` on purpose: an
#' unrecognized non-empty value (e.g. a typo'd `treu`) is treated as dry-run so
#' an operator who *intended* verification mode never triggers a delete by a typo.
#'
#' - unset / empty / NULL / NA -> FALSE (normal prune; matches the compose default)
#' - recognized truthy (1/true/yes/on) -> TRUE
#' - recognized falsy (0/false/no/off) -> FALSE
#' - any other non-empty value -> TRUE + a warning (fail-safe: never delete)
#'
#' @param value Raw env value.
#' @param warn Function used to surface the ambiguity (injectable for tests).
#' @return TRUE (dry-run, no deletion) or FALSE (prune).
#' @export
async_job_retention_resolve_dry_run <- function(value, warn = warning) {
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    return(FALSE)
  }
  tok <- tolower(trimws(as.character(value)))
  if (!nzchar(tok)) {
    return(FALSE)
  }
  if (tok %in% c("1", "true", "yes", "on")) {
    return(TRUE)
  }
  if (tok %in% c("0", "false", "no", "off")) {
    return(FALSE)
  }
  warn(sprintf(
    paste0("[job-retention] unrecognized ASYNC_JOB_RETENTION_DRY_RUN value '%s'; ",
           "treating as dry-run (no deletion). Set it to true/false explicitly."),
    value
  ))
  TRUE
}

#' Resolve the async-job retention configuration from environment variables.
#'
#' Env vars (defaults): `ASYNC_JOB_RETENTION_DAYS` (90),
#' `ASYNC_JOB_RETENTION_DRY_RUN` (false; unrecognized -> fail-safe dry-run).
#'
#' @param getenv Function used to read env vars (injectable for tests).
#' @return A validated list: retention_days, dry_run.
#' @export
async_job_retention_config_from_env <- function(getenv = Sys.getenv) {
  list(
    retention_days = validate_retention_days(
      getenv("ASYNC_JOB_RETENTION_DAYS", ""), ASYNC_JOB_RETENTION_DEFAULT_DAYS
    ),
    # Operator lever: a smaller batch proportionally shrinks each statement's
    # work AND the FK cascade into async_job_events (useful if a job family emits
    # unusually many lifecycle events).
    batch_size = validate_retention_days(
      getenv("ASYNC_JOB_RETENTION_BATCH_SIZE", ""), ASYNC_JOB_RETENTION_BATCH_SIZE
    ),
    dry_run = async_job_retention_resolve_dry_run(getenv("ASYNC_JOB_RETENTION_DRY_RUN", ""))
  )
}

#' Run the async-job retention prune.
#'
#' In dry-run mode, counts the prunable terminal rows and deletes nothing. In a
#' destructive run it skips the (unnecessary, extra-scan) pre-count and deletes in
#' bounded, lock-safe batches: read candidate PKs (non-locking) then delete by PK
#' with a full-predicate re-check. Both the batch count and the wall-clock time are
#' bounded so one invocation can never run unbounded. The DB layer is injected so
#' the routine is fully testable without a live database.
#'
#' @param config A config list (see `async_job_retention_config_from_env()`).
#' @param count_fn Function(sql, params) -> integer count.
#' @param select_ids_fn Function(sql, params) -> character vector of job_id PKs.
#' @param execute_fn Function(sql, params) -> integer rows affected.
#' @param logger Function(msg) for human-readable progress.
#' @param max_batches Hard cap on batches per invocation (see
#'   `ASYNC_JOB_RETENTION_MAX_BATCHES`); the remainder is left for the next run.
#' @param max_seconds Wall-clock ceiling (seconds) for the batch loop.
#' @param now_fn Clock function (injectable for tests).
#' @return Invisibly, a summary list (retention_days, dry_run, candidate_rows,
#'   deleted_rows, batch_cap_reached, time_cap_reached).
#' @export
run_async_job_retention <- function(config, count_fn, select_ids_fn, execute_fn,
                                    logger = message,
                                    max_batches = ASYNC_JOB_RETENTION_MAX_BATCHES,
                                    max_seconds = ASYNC_JOB_RETENTION_MAX_SECONDS,
                                    now_fn = Sys.time) {
  stopifnot(
    is.list(config), is.function(count_fn),
    is.function(select_ids_fn), is.function(execute_fn)
  )
  max_batches <- validate_retention_days(max_batches, ASYNC_JOB_RETENTION_MAX_BATCHES)

  if (isTRUE(config$dry_run)) {
    count_spec <- build_async_job_retention_count_sql(config$retention_days)
    candidate_rows <- as.integer(count_fn(count_spec$sql, count_spec$params))
    if (length(candidate_rows) != 1L || is.na(candidate_rows)) {
      candidate_rows <- 0L
    }
    logger(sprintf(
      "[job-retention] table=async_jobs retention_days=%d candidates=%d dry_run=true",
      config$retention_days, candidate_rows
    ))
    logger(sprintf(
      "[job-retention] DRY RUN: would delete %d terminal job row(s); no rows removed",
      candidate_rows
    ))
    return(invisible(list(
      retention_days = config$retention_days, dry_run = TRUE,
      candidate_rows = candidate_rows, deleted_rows = 0L,
      batch_cap_reached = FALSE, time_cap_reached = FALSE
    )))
  }

  # Destructive run: skip the extra pre-count scan and delete in bounded, lock-safe
  # batches. A hard `max_batches` cap AND a `max_seconds` wall-clock cap each
  # guarantee the loop terminates within one invocation even if qualifying rows
  # keep appearing; the remainder is pruned on the next run.
  logger(sprintf(
    "[job-retention] table=async_jobs retention_days=%d dry_run=false",
    config$retention_days
  ))
  batch_size <- validate_retention_days(
    if (is.null(config$batch_size)) ASYNC_JOB_RETENTION_BATCH_SIZE else config$batch_size,
    ASYNC_JOB_RETENTION_BATCH_SIZE
  )
  deleted_rows <- 0L
  batches <- 0L
  batch_cap_reached <- FALSE
  time_cap_reached <- FALSE
  started_at <- now_fn()
  repeat {
    select_spec <- build_async_job_retention_select_ids_sql(config$retention_days, batch_size)
    job_ids <- as.character(select_ids_fn(select_spec$sql, select_spec$params))
    job_ids <- job_ids[!is.na(job_ids) & nzchar(job_ids)]
    n_candidates <- length(job_ids)
    if (n_candidates == 0L) {
      break
    }
    delete_spec <- build_async_job_retention_delete_by_ids_sql(job_ids, config$retention_days)
    n <- as.integer(execute_fn(delete_spec$sql, delete_spec$params))
    if (length(n) != 1L || is.na(n)) {
      n <- 0L
    }
    deleted_rows <- deleted_rows + n
    batches <- batches + 1L
    if (n_candidates < batch_size) {
      break
    }
    if (batches >= max_batches) {
      batch_cap_reached <- TRUE
      break
    }
    if (as.numeric(difftime(now_fn(), started_at, units = "secs")) >= max_seconds) {
      time_cap_reached <- TRUE
      break
    }
  }

  logger(sprintf(
    "[job-retention] deleted %d terminal job row(s) in %d batch(es) of %d (retention %d day(s))",
    deleted_rows, batches, batch_size, config$retention_days
  ))
  if (batch_cap_reached) {
    logger(sprintf(
      "[job-retention] batch cap reached (%d batches); remaining eligible rows will be pruned on the next run",
      max_batches
    ))
  }
  if (time_cap_reached) {
    logger(sprintf(
      "[job-retention] time cap reached (%.0fs); remaining eligible rows will be pruned on the next run",
      max_seconds
    ))
  }

  invisible(list(
    retention_days = config$retention_days, dry_run = FALSE,
    candidate_rows = NA_integer_, deleted_rows = deleted_rows,
    batch_cap_reached = batch_cap_reached, time_cap_reached = time_cap_reached
  ))
}
