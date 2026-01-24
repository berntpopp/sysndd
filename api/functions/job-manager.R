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
create_job <- function(operation, params, executor_fn) {
  # Check capacity - count running/pending jobs
  running_count <- sum(vapply(ls(jobs_env), function(id) {
    job <- jobs_env[[id]]
    job$status %in% c("pending", "running")
  }, logical(1)))

  if (running_count >= MAX_CONCURRENT_JOBS) {
    return(list(
      error = "CAPACITY_EXCEEDED",
      message = sprintf(
        "Maximum %d concurrent jobs reached. Try again later.",
        MAX_CONCURRENT_JOBS
      ),
      retry_after = 60
    ))
  }

  # Generate unique job ID

job_id <- uuid::UUIDgenerate()

  # Create mirai task with 30-minute timeout (in milliseconds)
  m <- mirai::mirai(
    {
      executor_fn(params)
    },
    params = params,
    executor_fn = executor_fn,
    .timeout = 1800000  # 30 minutes in ms
  )

  # Store job state
  jobs_env[[job_id]] <- list(
    job_id = job_id,
    operation = operation,
    status = "pending",
    mirai_obj = m,
    submitted_at = Sys.time(),
    params_hash = digest::digest(params),
    result = NULL,
    error = NULL,
    completed_at = NULL
  )

  # Attach completion callback via promise pipe
  # This updates job state when mirai completes
  m %...>% (function(result) {
    if (mirai::is_mirai_error(result) || mirai::is_error_value(result)) {
      jobs_env[[job_id]]$status <- "failed"
      jobs_env[[job_id]]$error <- list(
        code = "EXECUTION_ERROR",
        message = result$message %||% "Job execution failed"
      )
    } else {
      jobs_env[[job_id]]$status <- "completed"
      jobs_env[[job_id]]$result <- result
    }
    jobs_env[[job_id]]$completed_at <- Sys.time()
  })

  return(list(
    job_id = job_id,
    status = "accepted",
    estimated_seconds = 30
  ))
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
  # Check if job exists
  if (!exists(job_id, envir = jobs_env)) {
    return(list(
      error = "JOB_NOT_FOUND",
      message = "Job ID not found"
    ))
  }

  job <- jobs_env[[job_id]]
  m <- job$mirai_obj

  # Check if still running via mirai's unresolved()
  if (mirai::unresolved(m)) {
    # Job still running - calculate estimated remaining time
    elapsed <- as.numeric(difftime(Sys.time(), job$submitted_at, units = "secs"))
    remaining <- max(0, 1800 - elapsed)  # 30 min = 1800 sec

    return(list(
      job_id = job_id,
      status = "running",
      step = get_progress_message(job$operation),
      estimated_seconds = round(remaining),
      retry_after = 5
    ))
  } else {
    # Job completed - return cached state
    return(list(
      job_id = job_id,
      status = job$status,
      completed_at = job$completed_at,
      result = job$result,
      error = job$error
    ))
  }
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
    ontology_update = "Fetching ontology data from external sources..."
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
  params_hash <- digest::digest(params)

  for (job_id in ls(jobs_env)) {
    job <- jobs_env[[job_id]]

    if (job$operation == operation &&
        job$params_hash == params_hash &&
        job$status %in% c("pending", "running")) {
      return(list(
        duplicate = TRUE,
        existing_job_id = job_id
      ))
    }
  }

  return(list(duplicate = FALSE))
}

#' Clean up old completed/failed jobs
#'
#' Removes jobs that completed more than 24 hours ago to prevent
#' memory leaks. Should be called periodically (e.g., hourly).
#'
#' @return NULL (invisible). Logs cleanup count via message().
#'
#' @examples
#' \dontrun{
#' # Schedule hourly cleanup
#' later::later(cleanup_old_jobs, 3600)
#' }
cleanup_old_jobs <- function() {
  cutoff_time <- Sys.time() - (24 * 3600)  # 24 hours ago
  removed_count <- 0

  for (job_id in ls(jobs_env)) {
    job <- jobs_env[[job_id]]

    # Only clean up completed or failed jobs
    if (job$status %in% c("completed", "failed")) {
      # Use completed_at if available, fall back to submitted_at
      end_time <- job$completed_at %||% job$submitted_at

      if (end_time < cutoff_time) {
        rm(list = job_id, envir = jobs_env)
        removed_count <- removed_count + 1
      }
    }
  }

  if (removed_count > 0) {
    message(sprintf("[%s] Cleaned up %d old jobs", Sys.time(), removed_count))
  }

  invisible(NULL)
}
