# functions/async-job-repository.R
#
# Durable repository for async job state and lifecycle events.
# This layer performs DB access only; higher-level services own request
# validation, handler dispatch, and event policy.
#
# Shared primitives (library loads, db-helpers fallback, captured base::get
# bindings, ASYNC_JOB_BASE_COLUMNS, SELECT builders, and the validation/
# scalar/empty/queue/param-normalization helpers) live in the sibling
# async-job-repository-helpers.R (#346 ceiling extraction). It is not
# separately listed in the bootstrap loaders; this guard loads it, right
# before this file's own functions, on first source of this file.
if (!exists("db_execute_query", mode = "function") ||
    !exists(".async_job_build_select", mode = "function")) {
  # Resolve this file's own directory from the active source() frame so the
  # sibling loads regardless of cwd (testthat runs from tests/testthat/, where
  # the bare cwd-relative candidates below do not resolve).
  .self_dir <- NULL
  for (.i in seq_len(sys.nframe())) {
    .of <- sys.frame(.i)$ofile
    if (!is.null(.of)) {
      .self_dir <- dirname(.of)
      break
    }
  }
  .candidates <- c(
    if (!is.null(.self_dir)) file.path(.self_dir, "async-job-repository-helpers.R"),
    "functions/async-job-repository-helpers.R",
    "/app/functions/async-job-repository-helpers.R"
  )
  for (.p in .candidates) {
    if (file.exists(.p)) {
      source(.p, local = TRUE)
      break
    }
  }
}

#' Create a durable async job row
#'
#' @param job Named list with job metadata and payload.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Character job_id.
#' @export
async_job_repository_create <- function(job, conn = NULL) {
  .async_job_require_fields(
    job,
    c("job_id", "job_type", "request_payload_json", "request_hash")
  )

  submitted_at <- .async_job_scalar(job$submitted_at, Sys.time())
  scheduled_at <- .async_job_scalar(job$scheduled_at, submitted_at)

  insert_values <- list(
    job_id = .async_job_scalar(job$job_id),
    job_type = .async_job_scalar(job$job_type),
    queue_name = .async_job_scalar(job$queue_name, "default"),
    priority = as.integer(.async_job_scalar(job$priority, 100L)),
    status = .async_job_scalar(job$status, "queued"),
    request_hash = .async_job_scalar(job$request_hash),
    request_payload_json = .async_job_scalar(job$request_payload_json),
    submitted_at = submitted_at,
    scheduled_at = scheduled_at,
    attempt_count = as.integer(.async_job_scalar(job$attempt_count, 0L)),
    max_attempts = as.integer(.async_job_scalar(job$max_attempts, 1L))
  )

  optional_fields <- c(
    "submitted_by",
    "started_at",
    "completed_at",
    "claimed_by_worker",
    "claim_token",
    "worker_hostname",
    "worker_pid",
    "last_heartbeat_at",
    "claim_expires_at",
    "next_attempt_at",
    "progress_pct",
    "progress_message",
    "last_error_code",
    "last_error_message",
    "cancelled_by",
    "result_json"
  )

  for (field in optional_fields) {
    if (field %in% names(job)) {
      value <- .async_job_scalar(job[[field]], NULL)
      if (!is.null(value) && !(length(value) == 1 && is.na(value))) {
        if (field %in% c("submitted_by", "worker_pid", "cancelled_by")) {
          value <- as.integer(value)
        } else if (field == "progress_pct") {
          value <- as.numeric(value)
        }
        insert_values[[field]] <- value
      }
    }
  }

  sql <- paste0(
    "INSERT INTO async_jobs (",
    paste(names(insert_values), collapse = ", "),
    ") VALUES (",
    paste(rep("?", length(insert_values)), collapse = ", "),
    ")"
  )

  params <- .async_job_normalize_params(insert_values)

  tryCatch(
    {
      db_execute_statement(sql, params, conn = conn)
    },
    db_statement_error = function(e) {
      is_duplicate <- grepl(
        "idx_async_jobs_active_request_hash",
        e$message,
        fixed = TRUE
      )
      if (!is_duplicate) {
        stop(e)
      }

      duplicate <- async_job_repository_find_active_duplicate(
        job_type = .async_job_scalar(job$job_type),
        request_hash = .async_job_scalar(job$request_hash),
        conn = conn
      )

      abort(
        message = "Active async job with matching request hash already exists",
        class = "async_job_duplicate_error",
        job_id = if (nrow(duplicate) > 0) duplicate$job_id[[1]] else NULL,
        duplicate_job = duplicate
      )
    }
  )

  .async_job_scalar(job$job_id)
}

#' Get a durable async job row
#'
#' @param job_id Character job identifier.
#' @param include_result Logical; include result_json on polling reads.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Tibble with zero or one row.
#' @export
async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
  sql <- paste(
    .async_job_build_select(include_result),
    "FROM async_jobs WHERE job_id = ? LIMIT 1"
  )

  db_execute_query(sql, list(job_id), conn = conn)
}

#' Find an active duplicate by job_type and durable request hash
#'
#' @param job_type Character job type.
#' @param request_hash Character durable request hash.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Tibble with zero or one active duplicate row.
#' @export
# "Active" = in-flight OR retryable-failed. Shared by the hash-keyed duplicate
# lookup and the job-type single-flight lookup so they stay identical.
.async_job_active_status_sql <- paste(
  "(status IN ('queued', 'running', 'cancel_requested')",
  "OR (status = 'failed' AND attempt_count < max_attempts AND next_attempt_at IS NOT NULL))"
)

async_job_repository_find_active_duplicate <- function(job_type, request_hash, conn = NULL) {
  sql <- paste(
    .async_job_build_select(FALSE),
    "FROM async_jobs WHERE job_type = ? AND request_hash = ?",
    "AND", .async_job_active_status_sql,
    "ORDER BY submitted_at DESC LIMIT 1"
  )

  db_execute_query(sql, list(job_type, request_hash), conn = conn)
}

#' Find an active job of a given type, independent of request payload/hash.
#'
#' Job-type single-flight for destructive maintenance families (#535 S2b): a
#' new submission must dedupe against ANY in-flight (or retryable-failed) job of
#' the same type, even across a payload-schema change (e.g. dropping db_config),
#' which the hash-based `find_active_duplicate` cannot do because the hash
#' changes with the payload.
#'
#' @param job_type Character job type.
#' @param conn Optional connection or pool for dependency injection.
#' @return Tibble with zero or one active row of that job_type.
#' @export
async_job_repository_find_active_by_type <- function(job_type, conn = NULL) {
  sql <- paste(
    .async_job_build_select(FALSE),
    "FROM async_jobs WHERE job_type = ?",
    "AND", .async_job_active_status_sql,
    "ORDER BY submitted_at DESC LIMIT 1"
  )

  db_execute_query(sql, list(job_type), conn = conn)
}

#' Claim the next eligible queued or scheduled-retry job
#'
#' @param worker_id Character worker identifier.
#' @param worker_hostname Character hostname.
#' @param worker_pid Integer PID.
#' @param lease_seconds Integer lease duration.
#' @param queues Character vector of eligible queues.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Tibble with zero or one claimed job row.
#' @export
async_job_repository_claim_next <- function(
  worker_id,
  worker_hostname,
  worker_pid,
  lease_seconds,
  queues = "default",
  conn = NULL
) {
  queue_values <- .async_job_normalize_queues(queues)

  placeholders <- paste(rep("?", length(queue_values)), collapse = ", ")

  db_with_transaction(function(txn_conn) {
    select_sql <- paste0(
      "SELECT job_id FROM async_jobs ",
      "WHERE queue_name IN (", placeholders, ") ",
      "AND (",
      "(status = 'queued' AND scheduled_at <= CURRENT_TIMESTAMP(6)) ",
      "OR ",
      "(status = 'failed' AND attempt_count < max_attempts ",
      "AND next_attempt_at IS NOT NULL AND next_attempt_at <= CURRENT_TIMESTAMP(6))",
      ") ",
      "ORDER BY priority ASC, ",
      "CASE ",
      "  WHEN status = 'failed' AND next_attempt_at IS NOT NULL THEN next_attempt_at ",
      "  ELSE scheduled_at ",
      "END ASC, ",
      "submitted_at ASC ",
      "LIMIT 1 FOR UPDATE SKIP LOCKED"
    )

    candidate <- db_execute_query(select_sql, as.list(queue_values), conn = txn_conn)
    if (nrow(candidate) == 0) {
      return(.async_job_empty_result())
    }

    job_id <- candidate$job_id[[1]]
    claim_token <- uuid::UUIDgenerate()

    update_sql <- paste(
      "UPDATE async_jobs",
      "SET status = 'running',",
      "started_at = CURRENT_TIMESTAMP(6),",
      "completed_at = NULL,",
      "claimed_by_worker = ?,",
      "claim_token = ?,",
      "worker_hostname = ?,",
      "worker_pid = ?,",
      "last_heartbeat_at = CURRENT_TIMESTAMP(6),",
      "claim_expires_at = DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL ? SECOND),",
      "attempt_count = attempt_count + 1,",
      "next_attempt_at = NULL",
      "WHERE job_id = ?"
    )

    db_execute_statement(
      update_sql,
      list(
        worker_id,
        claim_token,
        worker_hostname,
        as.integer(worker_pid),
        as.integer(lease_seconds),
        job_id
      ),
      conn = txn_conn
    )

    async_job_repository_get(job_id, conn = txn_conn)
  }, pool_obj = conn)
}

#' Update durable progress fields for a running job
#'
#' @param job_id Character job identifier.
#' @param progress_pct Numeric percentage or NULL.
#' @param progress_message Character progress message or NULL.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Integer affected rows.
#' @export
async_job_repository_update_progress <- function(
  job_id,
  progress_pct = NULL,
  progress_message = NULL,
  claim_token,
  conn = NULL
) {
  clauses <- character(0)
  params <- list()

  if (!is.null(progress_pct)) {
    clauses <- c(clauses, "progress_pct = ?")
    params <- c(params, list(as.numeric(progress_pct)))
  }

  if (!is.null(progress_message)) {
    clauses <- c(clauses, "progress_message = ?")
    params <- c(params, list(progress_message))
  }

  if (length(clauses) == 0) {
    return(0L)
  }

  sql <- paste0(
    "UPDATE async_jobs SET ",
    paste(clauses, collapse = ", "),
    " WHERE job_id = ? AND claim_token = ? AND status = 'running'"
  )

  db_execute_statement(sql, c(params, list(job_id, claim_token)), conn = conn)
}

#' Append a lifecycle event for a durable async job
#'
#' @param job_id Character job identifier.
#' @param event_type Character event type.
#' @param event_message Optional message.
#' @param event_payload Optional JSON payload string.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Integer event_id.
#' @export
async_job_repository_append_event <- function(
  job_id,
  event_type,
  event_message = NULL,
  event_payload = NULL,
  conn = NULL
) {
  db_with_transaction(function(txn_conn) {
    db_execute_statement(
      paste(
        "INSERT INTO async_job_events",
        "(job_id, event_type, event_message, event_payload_json)",
        "VALUES (?, ?, ?, ?)"
      ),
      list(
        job_id,
        event_type,
        .async_job_scalar(event_message, NA_character_),
        .async_job_scalar(event_payload, NA_character_)
      ),
      conn = txn_conn
    )

    result <- db_execute_query("SELECT LAST_INSERT_ID() AS event_id", conn = txn_conn)
    as.integer(result$event_id[[1]])
  }, pool_obj = conn)
}

#' Mark a job completed and persist its result payload
#'
#' @param job_id Character job identifier.
#' @param result_json Character JSON result payload.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Integer affected rows.
#' @export
async_job_repository_complete <- function(job_id, result_json, claim_token, conn = NULL) {
  db_execute_statement(
    paste(
      "UPDATE async_jobs",
      "SET status = 'completed',",
      "completed_at = CURRENT_TIMESTAMP(6),",
      "claimed_by_worker = NULL,",
      "claim_token = NULL,",
      "worker_hostname = NULL,",
      "worker_pid = NULL,",
      "last_heartbeat_at = NULL,",
      "claim_expires_at = NULL,",
      "last_error_code = NULL,",
      "last_error_message = NULL,",
      "result_json = ?",
      "WHERE job_id = ? AND claim_token = ? AND status IN ('running', 'cancel_requested')"
    ),
    list(result_json, job_id, claim_token),
    conn = conn
  )
}

#' Mark a job attempt failed and optionally schedule a retry
#'
#' @param job_id Character job identifier.
#' @param error_code Character error code.
#' @param error_message Character error message.
#' @param next_attempt_at Optional retry time.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Integer affected rows.
#' @export
async_job_repository_fail <- function(
  job_id,
  error_code,
  error_message,
  claim_token,
  next_attempt_at = NULL,
  conn = NULL
) {
  db_execute_statement(
    paste(
      "UPDATE async_jobs",
      "SET status = 'failed',",
      "completed_at = CURRENT_TIMESTAMP(6),",
      "claimed_by_worker = NULL,",
      "claim_token = NULL,",
      "worker_hostname = NULL,",
      "worker_pid = NULL,",
      "last_heartbeat_at = NULL,",
      "claim_expires_at = NULL,",
      "last_error_code = ?,",
      "last_error_message = ?,",
      "next_attempt_at = ?",
      "WHERE job_id = ? AND claim_token = ? AND status IN ('running', 'cancel_requested')"
    ),
    list(
      error_code,
      error_message,
      .async_job_scalar(next_attempt_at, as.POSIXct(NA)),
      job_id,
      claim_token
    ),
    conn = conn
  )
}

#' Request cancellation or finalize a queued job as cancelled
#'
#' @param job_id Character job identifier.
#' @param cancelled_by Optional user_id.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Integer affected rows.
#' @export
async_job_repository_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
  db_execute_statement(
    paste(
      "UPDATE async_jobs",
      "SET cancelled_by = CASE",
      "  WHEN status IN ('running', 'queued', 'failed') THEN ?",
      "  ELSE cancelled_by",
      "END,",
      "completed_at = CASE",
      "  WHEN status IN ('queued', 'failed') THEN CURRENT_TIMESTAMP(6)",
      "  ELSE completed_at",
      "END,",
      "claimed_by_worker = CASE",
      "  WHEN status IN ('queued', 'failed') THEN NULL",
      "  ELSE claimed_by_worker",
      "END,",
      "worker_hostname = CASE",
      "  WHEN status IN ('queued', 'failed') THEN NULL",
      "  ELSE worker_hostname",
      "END,",
      "worker_pid = CASE",
      "  WHEN status IN ('queued', 'failed') THEN NULL",
      "  ELSE worker_pid",
      "END,",
      "last_heartbeat_at = CASE",
      "  WHEN status IN ('queued', 'failed') THEN NULL",
      "  ELSE last_heartbeat_at",
      "END,",
      "claim_expires_at = CASE",
      "  WHEN status IN ('queued', 'failed') THEN NULL",
      "  ELSE claim_expires_at",
      "END,",
      "next_attempt_at = CASE",
      "  WHEN status IN ('queued', 'failed') THEN NULL",
      "  ELSE next_attempt_at",
      "END,",
      "status = CASE",
      "  WHEN status = 'running' THEN 'cancel_requested'",
      "  WHEN status IN ('queued', 'failed') THEN 'cancelled'",
      "  ELSE status",
      "END",
      "WHERE job_id = ?"
    ),
    list(as.integer(.async_job_scalar(cancelled_by, NA_integer_)), job_id),
    conn = conn
  )
}

#' Extend the lease for a running job
#'
#' @param job_id Character job identifier.
#' @param lease_seconds Integer lease duration.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Integer affected rows.
#' @export
async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
  db_execute_statement(
    paste(
      "UPDATE async_jobs",
      "SET last_heartbeat_at = CURRENT_TIMESTAMP(6),",
      "claim_expires_at = DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL ? SECOND)",
      "WHERE job_id = ? AND claim_token = ? AND status IN ('running', 'cancel_requested')"
    ),
    list(as.integer(lease_seconds), job_id, claim_token),
    conn = conn
  )
}

#' Recover stale leases for jobs whose worker heartbeat expired
#'
#' @param now POSIXct time used for stale detection.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Tibble with jobs_recovered count.
#' @export
async_job_repository_recover_stale <- function(now = Sys.time(), conn = NULL) {
  recovered <- db_with_transaction(function(txn_conn) {
    db_execute_statement(
      paste(
        "UPDATE async_jobs",
        "SET completed_at = CASE",
        "  WHEN status = 'cancel_requested' THEN CURRENT_TIMESTAMP(6)",
        "  WHEN attempt_count < max_attempts THEN NULL",
        "  ELSE CURRENT_TIMESTAMP(6)",
        "END,",
        "claimed_by_worker = NULL,",
        "claim_token = NULL,",
        "worker_hostname = NULL,",
        "worker_pid = NULL,",
        "last_heartbeat_at = NULL,",
        "claim_expires_at = NULL,",
        "scheduled_at = CASE",
        "  WHEN status = 'cancel_requested' THEN scheduled_at",
        "  WHEN attempt_count < max_attempts THEN ?",
        "  ELSE scheduled_at",
        "END,",
        "next_attempt_at = NULL,",
        "last_error_code = CASE",
        "  WHEN status = 'cancel_requested' THEN last_error_code",
        "  ELSE 'LEASE_EXPIRED'",
        "END,",
        "last_error_message = CASE",
        "  WHEN status = 'cancel_requested' THEN last_error_message",
        "  ELSE 'Job lease expired before completion'",
        "END,",
        "status = CASE",
        "  WHEN status = 'cancel_requested' THEN 'cancelled'",
        "  WHEN attempt_count < max_attempts THEN 'queued'",
        "  ELSE 'failed'",
        "END",
        "WHERE status IN ('running', 'cancel_requested')",
        "AND claim_expires_at IS NOT NULL",
        "AND claim_expires_at <= ?"
      ),
      list(now, now),
      conn = txn_conn
    )
  }, pool_obj = conn)

  tibble::tibble(jobs_recovered = as.integer(recovered %||% 0L))
}

#' Return recent durable async jobs for operator history views
#'
#' @param limit Integer row limit.
#' @param include_result Logical; include result_json in history rows.
#' @param conn Optional connection or pool for dependency injection.
#'
#' @return Tibble of recent jobs ordered newest first.
#' @export
async_job_repository_history <- function(limit = 20L, include_result = FALSE, conn = NULL) {
  limit <- max(1L, as.integer(limit))
  sql <- paste(
    .async_job_build_select(include_result),
    "FROM async_jobs ORDER BY submitted_at DESC LIMIT",
    limit
  )

  db_execute_query(sql, conn = conn)
}
