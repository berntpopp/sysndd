.async_job_null_coalesce <- function(value, default) {
  if (is.null(value) || length(value) == 0) {
    return(default)
  }

  value
}

.async_job_claim_field <- function(claimed_job, field) {
  value <- claimed_job[[field]]
  if (is.null(value) || length(value) == 0) {
    return(NULL)
  }

  if (is.list(value)) {
    return(value[[1]])
  }

  value[[1]]
}

async_job_worker_set_claim_context <- function(claimed_job, worker_config = NULL) {
  context <- list(
    job_id = .async_job_claim_field(claimed_job, "job_id"),
    claim_token = .async_job_claim_field(claimed_job, "claim_token"),
    worker_config = worker_config
  )

  options(async_job_worker_claim_context = context)
  invisible(context)
}

async_job_worker_get_claim_context <- function() {
  getOption("async_job_worker_claim_context", NULL)
}

async_job_worker_has_claim_context <- function() {
  context <- async_job_worker_get_claim_context()
  !is.null(context) &&
    !is.null(context$claim_token) &&
    nzchar(as.character(context$claim_token))
}

async_job_worker_clear_claim_context <- function() {
  options(async_job_worker_claim_context = NULL)
  invisible(NULL)
}

#' Create a durable progress reporter for a claimed async job
#'
#' @param job_id Character async job identifier.
#' @param throttle_seconds Numeric minimum interval between within-step writes.
#'
#' @return Function(step, message, current = NULL, total = NULL).
#' @export
create_async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
  last_write_time <- 0
  last_step <- ""

  function(step, message, current = NULL, total = NULL) {
    context <- async_job_worker_get_claim_context()
    claim_token <- .async_job_null_coalesce(context$claim_token, NULL)
    worker_config <- .async_job_null_coalesce(context$worker_config, list())

    if (is.null(claim_token) || !nzchar(as.character(claim_token))) {
      return(invisible(NULL))
    }

    now <- as.numeric(Sys.time())
    is_step_change <- !identical(step, last_step)
    is_complete <- !is.null(current) && !is.null(total) && total > 0 && current >= total

    if (!is_step_change && !is_complete && (now - last_write_time) < throttle_seconds) {
      return(invisible(NULL))
    }

    last_write_time <<- now
    last_step <<- step

    progress_pct <- NULL
    if (!is.null(current) && !is.null(total) && total > 0) {
      progress_pct <- round((as.numeric(current) / as.numeric(total)) * 100, 2)
    }

    async_job_repository_update_progress(
      job_id = job_id,
      progress_pct = progress_pct,
      progress_message = message,
      claim_token = claim_token
    )

    lease_seconds <- suppressWarnings(as.integer(worker_config$lease_seconds))
    if (length(lease_seconds) == 1L && !is.na(lease_seconds) && lease_seconds > 0L) {
      async_job_repository_heartbeat(
        job_id = job_id,
        lease_seconds = lease_seconds,
        claim_token = claim_token
      )
    }

    invisible(NULL)
  }
}
