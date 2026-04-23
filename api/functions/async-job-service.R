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
#' @param queue_name Character queue name.
#' @param priority Integer queue priority.
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
  queue_name = "default",
  priority = 100L,
  max_attempts = 1L,
  scheduled_at = Sys.time(),
  job_id = uuid::UUIDgenerate(),
  conn = NULL
) {
  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
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
#' @param conn Optional DB connection or pool.
#'
#' @return Tibble of recent durable jobs.
#' @export
async_job_service_history <- function(limit = 20L, conn = NULL) {
  async_job_repository_history(
    limit = max(1L, as.integer(.async_job_service_scalar(limit, 20L))),
    conn = conn
  )
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
