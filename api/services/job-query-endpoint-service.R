# api/services/job-query-endpoint-service.R
#
# Bodies of the two read-only job query handlers, extracted from
# endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5):
#   GET /api/jobs/history            (Administrator only)
#   GET /api/jobs/<job_id>/status    (public summary; full requires access)
#
# The `require_role(req, res, "Administrator")` gate for /history stays in the
# endpoint shell (byte-identical). /status has no `require_role()` call in the
# original handler — its access control is the inline `result_mode`/
# `can_read_full_job_result()` branching below, preserved verbatim.

#' Build the Administrator job-history response.
#'
#' @param limit Requested page size; clamped to [1, 100], defaults to 20 on
#'   invalid input (matches the original inline handler).
#' @return List payload for the `json` serializer.
#' @export
svc_job_get_history <- function(limit = 20) {
  # Validate and constrain limit parameter
  limit <- as.integer(limit)
  if (is.na(limit) || limit < 1) {
    limit <- 20
  }
  if (limit > 100) {
    limit <- 100
  }

  # Get job history from job-manager
  jobs <- get_job_history(limit)

  # Return with metadata
  list(
    data = if (nrow(jobs) > 0) {
      # Convert data frame to list of lists for JSON serialization
      lapply(seq_len(nrow(jobs)), function(i) {
        list(
          job_id = jobs$job_id[i],
          operation = jobs$operation[i],
          status = jobs$status[i],
          submitted_at = jobs$submitted_at[i],
          completed_at = jobs$completed_at[i],
          duration_seconds = jobs$duration_seconds[i],
          error_message = jobs$error_message[i]
        )
      })
    } else {
      list()
    },
    meta = list(
      count = nrow(jobs),
      limit = limit
    )
  )
}

#' Poll job status and retrieve results when complete.
#'
#' `result_mode = "full"` additionally gates on `can_read_full_job_result()`
#' using the durable job row's `job_type` and the caller's `req$user_role`;
#' only jobs that exist are gated (unknown ids still fall through to the
#' unauthenticated JOB_NOT_FOUND 404 path, so this never discloses more or
#' less than the summary path would).
#'
#' @param job_id Character job id.
#' @param result_mode "summary" (default) or "full".
#' @param req Plumber request (reads `req$user_role`).
#' @param res Plumber response, mutated in place (status + headers).
#' @return List payload for the `json` serializer.
#' @export
svc_job_get_status <- function(job_id, result_mode = "summary", req, res) {
  result_mode <- as.character(result_mode[[1]] %||% "summary")
  if (!result_mode %in% c("summary", "full")) {
    res$status <- 400
    return(list(
      error = "INVALID_RESULT_MODE",
      message = "result_mode must be one of: summary, full"
    ))
  }

  if (identical(result_mode, "full")) {
    job_row <- tryCatch(
      async_job_repository_get(job_id),
      error = function(e) NULL
    )
    if (is.null(job_row)) {
      res$status <- 503
      return(list(
        error = "SERVICE_UNAVAILABLE",
        message = "Unable to verify job access at this time."
      ))
    }
    # Only gate jobs that exist; unknown ids fall through to JOB_NOT_FOUND (404)
    # so we never disclose more (or less) than the unauthenticated summary path.
    if (nrow(job_row) > 0 &&
          !can_read_full_job_result(job_row$job_type[[1]], req$user_role)) {
      res$status <- 403
      return(list(
        error = "FORBIDDEN",
        message = "Full job results for this operation are not available at your access level."
      ))
    }
  }

  status <- get_job_status(job_id, result_mode = result_mode)

  if (identical(status$error, "JOB_NOT_FOUND")) {
    res$status <- 404
    return(list(
      error = "JOB_NOT_FOUND",
      message = paste0("Job '", job_id, "' not found or expired")
    ))
  }

  # Set Retry-After for running jobs
  if (status$status %in% c("pending", "running")) {
    res$setHeader("Retry-After", as.character(status$retry_after %||% 5))
  }

  res$status <- 200
  return(status)
}
