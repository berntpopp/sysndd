# functions/job-progress.R
#
# File-based progress reporting for async jobs.
# Daemon processes write progress to a shared directory;
# the main process reads it during status polling.
#
# Uses atomic write (write to .tmp, rename) to avoid partial reads.
# Built-in throttling minimizes I/O overhead.

require(jsonlite)

#' Shared directory for job progress files
JOB_PROGRESS_DIR <- "/tmp/sysndd_jobs"

#' Create a file-based progress reporter for an async job
#'
#' Returns a closure that writes throttled progress updates to a JSON file.
#' The main process reads this file in get_job_status().
#'
#' @param job_id Character UUID of the job
#' @param throttle_seconds Minimum seconds between file writes (default: 2).
#'   Step changes and final items always write immediately.
#'
#' @return A function(step, message, current = NULL, total = NULL) that
#'   writes progress to the job's progress file.
#'
#' @examples
#' \dontrun{
#' reporter <- create_progress_reporter("abc-123")
#' reporter("download", "Downloading HGNC data...", current = 1, total = 9)
#' reporter("gnomad", "gnomAD enrichment (50/43000)", current = 50, total = 43000)
#' }
#'
#' @export
create_progress_reporter <- function(job_id, throttle_seconds = 2) {
  # Ensure directory exists
  if (!dir.exists(JOB_PROGRESS_DIR)) {
    dir.create(JOB_PROGRESS_DIR, recursive = TRUE, mode = "0755")
  }

  progress_file <- file.path(JOB_PROGRESS_DIR, paste0(job_id, ".json"))
  last_write_time <- 0
  last_step <- ""

  function(step, message, current = NULL, total = NULL) {
    now <- as.numeric(Sys.time())

    # Always write on step change or completion; throttle within-step updates
    is_step_change <- !identical(step, last_step)
    is_complete <- !is.null(current) && !is.null(total) && current == total

    if (!is_step_change && !is_complete && (now - last_write_time) < throttle_seconds) {
      return(invisible(NULL))
    }

    last_write_time <<- now
    last_step <<- step

    progress_data <- list(
      step = step,
      message = message
    )
    # Only include current/total when provided (avoids null in JSON)
    if (!is.null(current)) progress_data$current <- current
    if (!is.null(total)) progress_data$total <- total

    # Atomic write: temp file + rename prevents partial reads
    tmp_file <- paste0(progress_file, ".tmp")
    tryCatch({
      writeLines(toJSON(progress_data, auto_unbox = TRUE), tmp_file)
      file.rename(tmp_file, progress_file)
    }, error = function(e) {
      # Non-fatal: progress reporting failure shouldn't crash the job
      NULL
    })

    invisible(NULL)
  }
}


#' Read progress from a job's progress file
#'
#' Called by get_job_status() in the main process to include
#' daemon-reported progress in the status response.
#'
#' @param job_id Character UUID of the job
#'
#' @return Named list with step, message, current, total — or NULL if
#'   no progress file exists or it cannot be read.
#'
#' @export
read_job_progress <- function(job_id) {
  progress_file <- file.path(JOB_PROGRESS_DIR, paste0(job_id, ".json"))

  if (!file.exists(progress_file)) {
    return(NULL)
  }

  tryCatch(
    fromJSON(progress_file, simplifyVector = TRUE),
    error = function(e) NULL
  )
}


#' Clean up progress file for a completed/failed job
#'
#' Called from the promise callback in create_job() after
#' the mirai task resolves.
#'
#' @param job_id Character UUID of the job
#'
#' @export
cleanup_job_progress <- function(job_id) {
  progress_file <- file.path(JOB_PROGRESS_DIR, paste0(job_id, ".json"))
  tmp_file <- paste0(progress_file, ".tmp")

  suppressWarnings({
    if (file.exists(progress_file)) file.remove(progress_file)
    if (file.exists(tmp_file)) file.remove(tmp_file)
  })

  invisible(NULL)
}
