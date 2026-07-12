# ---------------------------------------------------------------------------
# Queue-depth capacity cap
# ---------------------------------------------------------------------------

# Max simultaneously queued+running jobs allowed on the public submit queue.
# Read once at source/startup time; changing the env var requires an API
# restart to take effect.
ASYNC_PUBLIC_JOB_CAP <- as.integer(Sys.getenv("ASYNC_PUBLIC_JOB_CAP", "8"))

#' TRUE when the active (queued+running) job count is at or over the cap.
#'
#' Soft cap: the check-then-submit sequence in the endpoints is not atomic, so
#' two concurrent requests may both pass and transiently push the queue one or
#' two over the cap. That is acceptable for a back-pressure guard.
#'
#' @param active_count Integer count of currently in-flight jobs.
#' @param cap Integer maximum allowed. Defaults to ASYNC_PUBLIC_JOB_CAP.
#' @return Logical.
#' @export
async_job_capacity_exceeded <- function(active_count, cap = ASYNC_PUBLIC_JOB_CAP) {
  isTRUE(as.integer(active_count) >= as.integer(cap))
}

#' Count queued+running jobs for a given queue.
#'
#' @param queue_name Character queue name to inspect.
#' @param conn Optional DB connection or pool. NULL uses global pool.
#' @return Integer count of active (queued / running / cancel_requested) jobs.
#' @export
async_job_active_count <- function(queue_name = "default", conn = NULL) {
  sql <- paste(
    "SELECT COUNT(*) AS n FROM async_jobs",
    "WHERE queue_name = ? AND status IN ('queued', 'running', 'cancel_requested')"
  )
  row <- db_execute_query(sql, params = list(queue_name), conn = conn)
  if (nrow(row) == 0) 0L else as.integer(row$n[[1]])
}

# ---------------------------------------------------------------------------
# Queue routing + priority by job type (#486)
#
# One serial worker draining one shared "default" queue lets a long-running,
# non-interruptible maintenance job (e.g. publication_date_backfill) head-of-line
# block latency-sensitive interactive jobs (clustering / phenotype_clustering /
# llm_generation and the snapshot -> LLM deploy chain). These helpers are the
# single source of truth for which lane and priority a job type defaults to; the
# `worker-maintenance` container drains the "maintenance" lane so heavy jobs run
# in parallel with the interactive worker instead of blocking it.
# ---------------------------------------------------------------------------

# Heavy / bulk / external maintenance job types, routed to the "maintenance" lane.
ASYNC_MAINTENANCE_JOB_TYPES <- c(
  "publication_date_backfill",
  "publication_refresh",
  "pubtator_update",
  "pubtator_enrichment_refresh",
  "pubtatornidd_nightly",
  "omim_update",
  "hgnc_update",
  "comparisons_update",
  "ontology_update",
  "force_apply_ontology",
  "disease_ontology_mapping_refresh",
  "nddscore_import",
  "backup_create",
  "backup_restore"
)

# Latency-sensitive / user-visible interactive job types. They stay on the
# "default" lane but get the LOWEST priority number so a worker claims them ahead
# of any maintenance job that happens to share the queue.
ASYNC_INTERACTIVE_JOB_TYPES <- c(
  "clustering",
  "phenotype_clustering",
  "llm_generation",
  "analysis_snapshot_refresh",
  "network_layout_prewarm"
)

# Priority tiers (lower number = claimed first; the claim query orders
# `priority ASC`). interactive < maintenance < everything-else default.
ASYNC_PRIORITY_INTERACTIVE <- 10L
ASYNC_PRIORITY_MAINTENANCE <- 50L
ASYNC_PRIORITY_DEFAULT <- 100L

#' Resolve the durable queue lane for a job type.
#'
#' @param job_type Character durable job type.
#' @return "maintenance" for heavy/bulk/external maintenance job types, else
#'   "default".
#' @export
async_job_queue_for_type <- function(job_type) {
  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
  if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) "maintenance" else "default"
}

#' Resolve the default claim priority for a job type.
#'
#' @param job_type Character durable job type.
#' @return Integer priority: interactive (10) < maintenance (50) < default (100).
#' @export
async_job_priority_for_type <- function(job_type) {
  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
  if (jt %in% ASYNC_INTERACTIVE_JOB_TYPES) {
    ASYNC_PRIORITY_INTERACTIVE
  } else if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) {
    ASYNC_PRIORITY_MAINTENANCE
  } else {
    ASYNC_PRIORITY_DEFAULT
  }
}

# ---------------------------------------------------------------------------

.async_job_service_scalar <- function(value, default = NULL) {
  if (is.null(value) || length(value) == 0) {
    return(default)
  }

  if (is.list(value)) {
    return(value[[1]])
  }

  value[[1]]
}

.async_job_service_abort <- function(message, class = "async_job_service_validation_error", ...) {
  rlang::abort(message = message, class = class, ...)
}

.async_job_service_non_empty_string <- function(value, field) {
  scalar <- .async_job_service_scalar(value, NULL)

  if (is.null(scalar)) {
    .async_job_service_abort(sprintf("%s is required", field))
  }

  scalar <- as.character(scalar)
  if (!nzchar(trimws(scalar))) {
    .async_job_service_abort(sprintf("%s is required", field))
  }

  scalar
}

async_job_service_payload_json <- function(request_payload) {
  if (is.character(request_payload) && length(request_payload) == 1L) {
    return(request_payload[[1]])
  }

  as.character(
    jsonlite::toJSON(
      request_payload,
      auto_unbox = TRUE,
      null = "null",
      dataframe = "rows",
      POSIXt = "ISO8601"
    )
  )
}

async_job_service_request_hash <- function(job_type, request_payload_json) {
  digest::digest(
    paste0(
      .async_job_service_non_empty_string(job_type, "job_type"),
      ":",
      as.character(.async_job_service_scalar(request_payload_json, ""))
    ),
    algo = "sha256",
    serialize = FALSE
  )
}

.async_job_service_duplicate_row <- function(error, conn = NULL) {
  duplicate_job <- error$duplicate_job
  if (is.null(duplicate_job)) {
    duplicate_job <- tibble::tibble()
  }

  if (nrow(duplicate_job) > 0) {
    return(duplicate_job)
  }

  job_id <- error$job_id
  if (is.null(job_id)) {
    return(tibble::tibble())
  }

  async_job_repository_get(job_id, conn = conn)
}

#' Submit a durable async job and return its stored row
#'
#' @param job_type Character durable job type.
#' @param request_payload Named list or JSON payload string.
#' @param submitted_by Optional user id.
#' @param queue_name Character queue name. `NULL` (default) routes by job type via
#'   `async_job_queue_for_type()` (maintenance lane for heavy jobs, else default);
#'   an explicit value is honored as-is.
#' @param priority Integer queue priority. `NULL` (default) resolves by job type
#'   via `async_job_priority_for_type()` (interactive < maintenance < default); an
#'   explicit value is honored as-is.
#' @param max_attempts Integer maximum attempts.
#' @param scheduled_at Optional schedule time.
#' @param job_id Optional explicit job id for tests.
#' @param conn Optional DB connection or pool.
#'
#' @return List containing the stored job row and duplicate/create flags.
#' @export
async_job_service_submit <- function(
  job_type,
  request_payload,
  submitted_by = NULL,
  queue_name = NULL,
  priority = NULL,
  max_attempts = 1L,
  scheduled_at = Sys.time(),
  job_id = uuid::UUIDgenerate(),
  conn = NULL
) {
  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
  # Default the lane + priority from the job type so heavy maintenance jobs never
  # head-of-line block interactive jobs (#486). Explicit overrides are honored.
  if (is.null(queue_name)) {
    queue_name <- async_job_queue_for_type(job_type)
  }
  if (is.null(priority)) {
    priority <- async_job_priority_for_type(job_type)
  }
  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
  payload_json <- async_job_service_payload_json(request_payload)
  request_hash <- async_job_service_request_hash(job_type, payload_json)
  submitted_at <- Sys.time()

  stored_job <- tryCatch(
    {
      async_job_repository_create(
        list(
          job_id = job_id,
          job_type = job_type,
          queue_name = queue_name,
          priority = as.integer(priority),
          request_hash = request_hash,
          request_payload_json = payload_json,
          submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
          submitted_at = submitted_at,
          scheduled_at = scheduled_at,
          max_attempts = as.integer(max_attempts)
        ),
        conn = conn
      )

      async_job_repository_get(job_id, conn = conn)
    },
    async_job_duplicate_error = function(error) {
      .async_job_service_duplicate_row(error, conn = conn)
    }
  )

  is_duplicate <- nrow(stored_job) > 0 && !identical(stored_job$job_id[[1]], job_id)

  list(
    job = stored_job,
    duplicate = is_duplicate,
    created = !is_duplicate
  )
}

#' Persist an already-completed durable async job row
#'
#' Used for cache-hit fast paths that should still return a normal durable
#' job id without enqueueing worker execution.
#'
#' @param job_type Character durable job type.
#' @param request_payload Named list or JSON payload string.
#' @param result Completed handler result payload.
#' @param submitted_by Optional user id.
#' @param queue_name Character queue name.
#' @param priority Integer queue priority.
#' @param job_id Optional explicit job id.
#' @param submitted_at Optional submission timestamp.
#' @param completed_at Optional completion timestamp.
#' @param conn Optional DB connection or pool.
#'
#' @return Tibble with the stored completed job row.
#' @export
async_job_service_store_completed <- function(
  job_type,
  request_payload,
  result,
  submitted_by = NULL,
  queue_name = "default",
  priority = 100L,
  job_id = uuid::UUIDgenerate(),
  submitted_at = Sys.time(),
  completed_at = submitted_at,
  conn = NULL
) {
  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
  payload_json <- async_job_service_payload_json(request_payload)
  result_json <- async_job_service_payload_json(result)

  async_job_repository_create(
    list(
      job_id = job_id,
      job_type = job_type,
      queue_name = queue_name,
      priority = as.integer(priority),
      status = "completed",
      request_hash = async_job_service_request_hash(job_type, payload_json),
      request_payload_json = payload_json,
      submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
      submitted_at = submitted_at,
      scheduled_at = submitted_at,
      started_at = submitted_at,
      completed_at = completed_at,
      progress_pct = 100,
      result_json = result_json
    ),
    conn = conn
  )

  async_job_repository_get(job_id, include_result = TRUE, conn = conn)
}

#' Find an active duplicate for a durable async job request
#'
#' @param job_type Character durable job type.
#' @param request_payload Named list or JSON payload string.
#' @param conn Optional DB connection or pool.
#'
#' @return Tibble with zero or one active duplicate row.
#' @export
async_job_service_find_duplicate <- function(job_type, request_payload, conn = NULL) {
  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
  payload_json <- async_job_service_payload_json(request_payload)

  async_job_repository_find_active_duplicate(
    job_type = job_type,
    request_hash = async_job_service_request_hash(job_type, payload_json),
    conn = conn
  )
}

#' Read current durable async job status
#'
#' @param job_id Character job id.
#' @param include_result Logical; include result_json when TRUE.
#' @param conn Optional DB connection or pool.
#'
#' @return Tibble with zero or one durable job row.
#' @export
async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
  async_job_repository_get(
    job_id = .async_job_service_non_empty_string(job_id, "job_id"),
    include_result = isTRUE(include_result),
    conn = conn
  )
}

#' Return durable async job history
#'
#' @param limit Integer history limit.
#' @param include_result Logical; include result_json in history rows.
#' @param conn Optional DB connection or pool.
#'
#' @return Tibble of recent durable jobs.
#' @export
async_job_service_history <- function(limit = 20L, include_result = FALSE, conn = NULL) {
  args <- list(
    limit = max(1L, as.integer(.async_job_service_scalar(limit, 20L))),
    conn = conn
  )
  if (isTRUE(include_result)) {
    args$include_result <- TRUE
  }
  do.call(async_job_repository_history, args)
}

#' Request durable async job cancellation and return the refreshed row
#'
#' @param job_id Character job id.
#' @param cancelled_by Optional user id.
#' @param conn Optional DB connection or pool.
#'
#' @return Tibble with zero or one durable job row after cancellation.
#' @export
async_job_service_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
  job_id <- .async_job_service_non_empty_string(job_id, "job_id")

  async_job_repository_cancel(
    job_id = job_id,
    cancelled_by = if (is.null(cancelled_by)) NULL else as.integer(cancelled_by),
    conn = conn
  )

  async_job_repository_get(job_id, conn = conn)
}

#' Legacy duplicate response wrapper for endpoints not migrated yet
#'
#' @inheritParams async_job_service_find_duplicate
#'
#' @return List shaped like the previous duplicate helper.
#' @export
async_job_service_duplicate <- function(job_type, request_payload, conn = NULL) {
  duplicate <- async_job_service_find_duplicate(
    job_type = job_type,
    request_payload = request_payload,
    conn = conn
  )

  if (nrow(duplicate) == 0) {
    return(list(duplicate = FALSE))
  }

  list(
    duplicate = TRUE,
    existing_job_id = duplicate$job_id[[1]]
  )
}

#' Find an active job of a given type (job-type single-flight).
#'
#' @param job_type Character job type.
#' @param conn Optional DB connection or pool.
#' @return Tibble with zero or one active duplicate row of that job_type.
#' @export
async_job_service_find_active_by_type <- function(job_type, conn = NULL) {
  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
  async_job_repository_find_active_by_type(job_type = job_type, conn = conn)
}

#' Job-type single-flight duplicate check (#535 S2b HIGH-4).
#'
#' Unlike `async_job_service_duplicate()` (which keys on the payload hash and so
#' cannot dedupe across a payload-schema change), this dedupes on job_type alone,
#' so a destructive full-table-replace maintenance job (hgnc/comparisons/omim/
#' force_apply) resubmitted while one is in flight gets a clean 409 even across
#' the deploy that drops db_config from its payload.
#'
#' NOTE (scope): this is a **best-effort, submit-time** guard — the check and the
#' subsequent insert are NOT atomic, so a rare concurrent double-submit can still
#' enqueue two jobs. That is acceptable because the durable **maintenance lane
#' runs on a single worker** (`async_job_worker_main` claims+runs jobs
#' sequentially; Compose runs one `worker-maintenance` container), so two
#' destructive jobs never execute concurrently regardless of dedup. A hard,
#' atomic **cross-type conflict-group mutex** (e.g. an advisory lock covering
#' check+insert, or a generated conflict-key unique index grouping
#' omim_update/force_apply_ontology and pubtator_enrichment_refresh/
#' pubtatornidd_nightly) is defense-in-depth needed only if the maintenance lane
#' is ever scaled beyond one worker — tracked as a follow-up, not part of this
#' credential fix.
#'
#' @param job_type Character job type.
#' @param conn Optional DB connection or pool.
#' @return list(duplicate = FALSE) or list(duplicate = TRUE, existing_job_id = ...).
#' @export
async_job_service_duplicate_by_type <- function(job_type, conn = NULL) {
  active <- async_job_service_find_active_by_type(job_type, conn = conn)
  if (nrow(active) == 0) {
    return(list(duplicate = FALSE))
  }
  list(duplicate = TRUE, existing_job_id = active$job_id[[1]])
}

#' Legacy cancellation wrapper for endpoints not migrated yet
#'
#' @inheritParams async_job_service_cancel
#'
#' @return List describing cancellation outcome.
#' @export
async_job_service_request_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
  cancelled <- async_job_service_cancel(
    job_id = job_id,
    cancelled_by = cancelled_by,
    conn = conn
  )

  if (nrow(cancelled) == 0) {
    return(list(
      error = "JOB_NOT_FOUND",
      message = "Job ID not found"
    ))
  }

  list(job_id = job_id, status = cancelled$status[[1]])
}
