#' Job Manager Module
#'
#' Provides job state management functions for async API operations.
#' Uses mirai daemon pool for background execution and in-memory
#' environment storage for job state tracking.
#'
#' @name job-manager
#' @author SysNDD Team

# Load required packages for this module
# Note: mirai, promises, uuid, digest loaded in start_sysndd_api.R

# NOTE: LLM batch generator loaded at END of file (after create_job is defined)

## -------------------------------------------------------------------##
# Global State
## -------------------------------------------------------------------##

#' Environment for storing job state
#'
#' Each job is stored as a list with keys:
#' - job_id: UUID string
#' - operation: String identifying the operation type
#' - status: "pending", "running", "completed", "failed"
#' - mirai_obj: The mirai object for status checking
#' - submitted_at: POSIXct timestamp
#' - params_hash: digest hash of parameters for deduplication
#' - result: Job result (NULL until completed)
#' - error: Error details (NULL unless failed)
#' - completed_at: POSIXct timestamp (NULL until done)
jobs_env <- new.env(parent = emptyenv())

#' Maximum number of concurrent jobs
#'
#' Matches the mirai daemon pool size (8 workers).
#' When reached, new job submissions return CAPACITY_EXCEEDED error.
MAX_CONCURRENT_JOBS <- 8

## -------------------------------------------------------------------##
# Core Functions
## -------------------------------------------------------------------##

#' Create a new async job
#'
#' Validates capacity, generates job ID, creates mirai task,
#' stores job state, and attaches completion callback.
#'
#' @param operation Character string identifying the operation type
#'   (e.g., "clustering", "phenotype_clustering", "ontology_update")
#' @param params List of parameters for the executor function
#' @param executor_fn Function to execute in background daemon
#' @param timeout_ms Timeout in milliseconds for the mirai task. Default 1800000 (30 min).
#'   Long-running jobs like HGNC update with gnomAD enrichment should set a higher value.
#'
#' @return List with either:
#'   - On success: job_id, status="accepted", estimated_seconds=30
#'   - On capacity exceeded: error="CAPACITY_EXCEEDED", message, retry_after=60
#'
#' @examples
#' \dontrun{
#' result <- create_job(
#'   operation = "clustering",
#'   params = list(genes = c("BRCA1", "TP53")),
#'   executor_fn = function(params) gen_string_clust_obj(params$genes)
#' )
#' }
create_job <- function(operation, params, executor_fn, timeout_ms = 1800000) {
  submitted <- async_job_service_submit(
    job_type = operation,
    request_payload = params
  )

  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL

  list(
    job_id = job_id,
    status = "accepted",
    estimated_seconds = 30
  )
}

#' Get the status of a job
#'
#' Checks if job exists, determines current status by checking
#' mirai resolution state, and returns appropriate response.
#'
#' @param job_id Character string - the UUID of the job
#'
#' @return List with either:
#'   - Not found: error="JOB_NOT_FOUND"
#'   - Running: status, step, estimated_seconds, retry_after=5
#'   - Completed: status, completed_at, result or error
#'
#' @examples
#' \dontrun{
#' status <- get_job_status("550e8400-e29b-41d4-a716-446655440000")
#' }
get_job_status <- function(job_id) {
  job <- async_job_service_status(job_id, include_result = TRUE)

  if (nrow(job) == 0) {
    return(list(
      error = "JOB_NOT_FOUND",
      message = "Job ID not found"
    ))
  }

  durable_status <- job$status[[1]]

  if (durable_status %in% c("queued", "running", "cancel_requested")) {
    submitted_at <- job$submitted_at[[1]]
    elapsed <- as.numeric(difftime(Sys.time(), submitted_at, units = "secs"))
    remaining <- max(0, 1800 - elapsed)
    progress_pct <- suppressWarnings(as.numeric(job$progress_pct[[1]]))

    progress_data <- NULL
    if (!is.na(progress_pct)) {
      progress_data <- list(
        current = as.integer(round(progress_pct)),
        total = 100L
      )
    }

    return(list(
      job_id = job_id,
      status = "running",
      step = job$progress_message[[1]] %||% get_progress_message(job$job_type[[1]]),
      progress = progress_data,
      estimated_seconds = round(remaining),
      retry_after = 5
    ))
  }

  if (durable_status == "completed") {
    return(list(
      job_id = job_id,
      status = "completed",
      completed_at = if (!is.na(job$completed_at[[1]])) {
        format(job$completed_at[[1]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      } else {
        NULL
      },
      result = if (!is.na(job$result_json[[1]])) {
        jsonlite::fromJSON(job$result_json[[1]], simplifyVector = TRUE)
      } else {
        NULL
      },
      error = NULL
    ))
  }

  list(
    job_id = job_id,
    status = "failed",
    completed_at = if (!is.na(job$completed_at[[1]])) {
      format(job$completed_at[[1]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else {
      NULL
    },
    result = NULL,
    error = list(
      code = job$last_error_code[[1]] %||% "EXECUTION_ERROR",
      message = job$last_error_message[[1]] %||% "Job execution failed"
    )
  )
}

#' Get operation-specific progress message
#'
#' Returns a user-friendly message describing what the job is doing.
#'
#' @param operation Character string identifying the operation type
#'
#' @return Character string with progress message
#'
#' @examples
#' \dontrun{
#' msg <- get_progress_message("clustering")
#' # Returns: "Fetching interaction data from STRING-db..."
#' }
get_progress_message <- function(operation) {
  messages <- list(
    clustering = "Fetching interaction data from STRING-db...",
    phenotype_clustering = "Running Multiple Correspondence Analysis...",
    ontology_update = "Downloading and processing ontology data from MONDO/OMIM...",
    omim_update = "Updating OMIM annotations from mim2gene.txt + JAX API...",
    hgnc_update = "Downloading HGNC data and enriching with gnomAD constraints...",
    backup_create = "Creating database backup...",
    backup_restore = "Restoring database from backup...",
    pubtator_update = "Fetching publications from PubTator API...",
    llm_generation = "Generating LLM summaries for clusters...",
    comparisons_update = "Refreshing comparisons data from external NDD databases..."
  )

  messages[[operation]] %||% "Processing request..."
}

#' Check for duplicate running jobs
#'
#' Scans active jobs for one with matching operation and parameters.
#' Prevents duplicate expensive computations.
#'
#' @param operation Character string identifying the operation type
#' @param params List of parameters to check against
#'
#' @return List with:
#'   - duplicate=TRUE, existing_job_id: if duplicate found
#'   - duplicate=FALSE: if no duplicate
#'
#' @examples
#' \dontrun{
#' dup <- check_duplicate_job("clustering", list(genes = c("BRCA1")))
#' if (dup$duplicate) {
#'   return_existing_job(dup$existing_job_id)
#' }
#' }
check_duplicate_job <- function(operation, params) {
  async_job_service_duplicate(operation, params)
}

#' Clean up old completed/failed jobs
#'
#' Removes jobs that completed more than 24 hours ago to prevent
#' memory leaks. Called periodically by schedule_cleanup().
#'
#' @return Integer count of removed jobs (invisible).
#'
#' @examples
#' \dontrun{
#' cleanup_old_jobs()
#' }
#' @export
cleanup_old_jobs <- function() {
  cutoff_time <- Sys.time() - (24 * 3600) # 24 hours ago
  removed <- 0

  job_ids <- ls(jobs_env)

  if (length(job_ids) == 0) {
    return(invisible(0))
  }

  for (job_id in job_ids) {
    tryCatch(
      {
        job <- jobs_env[[job_id]]

        if (is.null(job)) {
          # Orphaned entry, remove it
          rm(list = job_id, envir = jobs_env)
          removed <- removed + 1
          next
        }

        if (job$status %in% c("completed", "failed")) {
          end_time <- job$completed_at %||% job$submitted_at

          if (!is.null(end_time) && end_time < cutoff_time) {
            rm(list = job_id, envir = jobs_env)
            removed <- removed + 1
          }
        }
      },
      error = function(e) {
        message(sprintf("[%s] Error cleaning job %s: %s", Sys.time(), job_id, e$message))
      }
    )
  }

  if (removed > 0) {
    message(sprintf("[%s] Cleaned up %d old jobs", Sys.time(), removed))
  }

  invisible(removed)
}

#' Schedule Recurring Job Cleanup
#'
#' Schedules the cleanup_old_jobs function to run periodically.
#' Uses `later` package for non-blocking scheduling.
#' Default interval is 1 hour (3600 seconds).
#'
#' @param interval_seconds Interval between cleanup runs in seconds
#' @export
schedule_cleanup <- function(interval_seconds = 3600) {
  cleanup_and_reschedule <- function() {
    cleanup_old_jobs()
    # Reschedule
    later::later(cleanup_and_reschedule, interval_seconds)
  }

  # Start the first cleanup cycle
  later::later(cleanup_and_reschedule, interval_seconds)
  message(sprintf("[%s] Scheduled job cleanup every %d seconds", Sys.time(), interval_seconds))
}

#' Get Job History
#'
#' Returns a list of recent jobs from the jobs environment.
#' Includes both running and completed jobs, sorted by submission time (newest first).
#'
#' @param limit Integer maximum number of jobs to return (default 20)
#' @return Data frame of job records with: job_id, operation, status,
#'   submitted_at, completed_at, duration_seconds, error_message
#'
#' @examples
#' \dontrun{
#' history <- get_job_history(20)
#' }
#' @export
get_job_history <- function(limit = 20) {
  jobs <- async_job_service_history(limit)

  if (nrow(jobs) == 0) {
    return(data.frame(
      job_id = character(0),
      operation = character(0),
      status = character(0),
      submitted_at = character(0),
      completed_at = character(0),
      duration_seconds = integer(0),
      error_message = character(0),
      stringsAsFactors = FALSE
    ))
  }

  result <- data.frame(
    job_id = unname(as.character(jobs$job_id)),
    operation = unname(as.character(jobs$job_type)),
    status = unname(as.character(jobs$status)),
    submitted_at = vapply(
      jobs$submitted_at,
      function(value) unname(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
      character(1)
    ),
    completed_at = vapply(
      jobs$completed_at,
      function(value) {
        if (is.na(value)) {
          NA_character_
        } else {
          unname(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
        }
      },
      character(1)
    ),
    duration_seconds = vapply(
      seq_len(nrow(jobs)),
      function(i) {
        completed_at <- jobs$completed_at[[i]]
        if (is.na(completed_at)) {
          completed_at <- Sys.time()
        }
        as.integer(round(as.numeric(difftime(completed_at, jobs$submitted_at[[i]], units = "secs"))))
      },
      integer(1)
    ),
    error_message = vapply(
      jobs$last_error_message,
      function(value) {
        if (is.na(value)) {
          NA_character_
        } else {
          unname(as.character(value))
        }
      },
      character(1)
    ),
    stringsAsFactors = FALSE,
    row.names = NULL
  )

  rownames(result) <- NULL
  result
}

## -------------------------------------------------------------------##
# Load LLM Batch Generator (AFTER create_job is defined)
## -------------------------------------------------------------------##

# Load LLM batch generator - must be AFTER create_job definition
# because trigger_llm_batch_generation() calls create_job()
if (file.exists("functions/llm-batch-generator.R")) {
  message("[job-manager] Loading llm-batch-generator.R...")
  tryCatch(
    {
      source("functions/llm-batch-generator.R", local = FALSE)
      message("[job-manager] llm-batch-generator.R loaded successfully")
      message(
        "[job-manager] trigger_llm_batch_generation exists: ",
        exists("trigger_llm_batch_generation", mode = "function")
      )
      message("[job-manager] llm_batch_executor exists: ", exists("llm_batch_executor", mode = "function"))
    },
    error = function(e) {
      message("[job-manager] ERROR loading llm-batch-generator.R: ", conditionMessage(e))
    }
  )
} else {
  message("[job-manager] llm-batch-generator.R NOT FOUND")
}
