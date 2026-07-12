# api/functions/async-job-payload-scrub.R
#
# Redacts the DB password that older code persisted into
# async_jobs.request_payload_json (native JSON column) for the BACKUP job
# family, and recomputes the row's request_hash so it no longer encodes the
# password (a SHA-256 over job_type + payload would otherwise remain a
# password-derived verifier for offline guessing; #535 P1-1 H6).
#
# Scope is deliberately narrow (#535 H1/B1):
#   - job_type IN ('backup_create','backup_restore') only -> other durable
#     families still READ payload$db_config$password until S2b migrates them, so
#     scrubbing their rows would break queued/retryable jobs.
#   - status IN ('completed','failed','cancelled') AND active_request_hash IS
#     NULL (TERMINAL, non-retryable) only. active_request_hash is a generated
#     column that stays non-NULL for retryable-failed rows; two such rows
#     differing only by password would redact to the same recomputed hash and
#     violate UNIQUE (job_type, active_request_hash), rolling back the scrub.
#     Requiring it NULL scrubs only rows that cannot interact with that index.
# Idempotent: rows already carrying the sentinel are skipped.
#
# Runs best-effort at API startup, after a successful restore (old dumps
# re-import credential-bearing rows; #535 H5), and via the operator script
# api/scripts/scrub-job-payload-credentials.R. Operator credential ROTATION
# remains the primary mitigation.

ASYNC_JOB_PAYLOAD_SCRUB_SENTINEL <- "***REDACTED***"

#' Single idempotent UPDATE that redacts $.db_config.password and recomputes
#' request_hash for terminal backup rows.
#' @export
async_job_payload_scrub_statement <- function(sentinel = ASYNC_JOB_PAYLOAD_SCRUB_SENTINEL) {
  sprintf(
    paste0(
      "UPDATE async_jobs\n",
      "SET request_hash = SHA2(CONCAT(job_type, ':', ",
      "JSON_SET(request_payload_json, '$.db_config.password', '%s')), 256),\n",
      "    request_payload_json = JSON_SET(request_payload_json, '$.db_config.password', '%s')\n",
      "WHERE job_type IN ('backup_create','backup_restore')\n",
      "  AND status IN ('completed','failed','cancelled')\n",
      "  AND active_request_hash IS NULL\n",
      "  AND JSON_EXTRACT(request_payload_json, '$.db_config.password') IS NOT NULL\n",
      "  AND JSON_UNQUOTE(JSON_EXTRACT(request_payload_json, '$.db_config.password')) <> '%s'"
    ),
    sentinel, sentinel, sentinel
  )
}

#' Execute the scrub. Returns the number of (distinct) rows redacted.
#' @export
async_job_scrub_payload_credentials <- function(conn = NULL) {
  as.integer(db_execute_statement(async_job_payload_scrub_statement(), list(), conn = conn))
}

#' Best-effort startup hook (env-gated, never throws).
#' @export
async_job_scrub_payload_credentials_on_startup <- function() {
  if (!identical(tolower(Sys.getenv("ASYNC_JOB_PAYLOAD_SCRUB_ON_STARTUP", "true")), "true")) {
    return(invisible(FALSE))
  }
  tryCatch(
    {
      n <- async_job_scrub_payload_credentials()
      if (isTRUE(n > 0)) {
        logger::log_info("Scrubbed credentials from {n} terminal backup payload row(s)")
      }
      invisible(TRUE)
    },
    error = function(e) {
      logger::log_warn("async_jobs backup payload credential scrub skipped: {conditionMessage(e)}")
      invisible(FALSE)
    }
  )
}

#' Remove stale mode-0600 MySQL option files a crashed worker may have left
#' behind (#535 P1-1 L1). Best-effort; never throws.
#' @export
async_job_backup_cleanup_stale_option_files <- function(dir = tempdir()) {
  tryCatch(
    unlink(Sys.glob(file.path(dir, "mysql_opt_*.cnf"))),
    error = function(e) invisible(NULL)
  )
  invisible(TRUE)
}
