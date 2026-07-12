#' Job Manager Module
#'
#' Legacy compatibility facade for async API operations.
#' Public job submission, status, and history now route through the
#' durable async job service instead of process-local state.
#'
#' @name job-manager
#' @author SysNDD Team

# Load required packages for this module
# Note: mirai, promises, uuid, digest loaded in start_sysndd_api.R

# NOTE: LLM batch generator loaded at END of file (after create_job is defined)

## -------------------------------------------------------------------##
# Core Functions
## -------------------------------------------------------------------##

#' Create a new async job
#'
#' Submits a durable job for execution by its registered worker handler.
#'
#' @param operation Character string identifying the operation type
#'   (e.g., "clustering", "phenotype_clustering", "ontology_update")
#' @param params List of payload parameters for the registered handler.
#'
#' @return List with either:
#'   - On success: job_id, status="accepted", estimated_seconds=30
#'   - On capacity exceeded: error="CAPACITY_EXCEEDED", message, retry_after=60
#'
#' @examples
#' \dontrun{
#' result <- create_job(
#'   operation = "clustering",
#'   params = list(genes = c("BRCA1", "TP53"))
#' )
#' }
create_job <- function(operation, params) {
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
#' @param result_mode Character string - "summary" omits stored result JSON,
#'   "full" includes and parses it.
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
get_job_status <- function(job_id, result_mode = "summary") {
  result_mode <- as.character(result_mode[[1]] %||% "summary")
  if (!result_mode %in% c("summary", "full")) {
    stop("result_mode must be one of: summary, full", call. = FALSE)
  }

  job <- async_job_service_status(
    job_id,
    include_result = identical(result_mode, "full")
  )

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
    result <- NULL
    error <- NULL
    if (identical(result_mode, "full") &&
        "result_json" %in% names(job) &&
        !is.na(job$result_json[[1]])) {
      result <- tryCatch(
        jsonlite::fromJSON(job$result_json[[1]], simplifyVector = TRUE),
        error = function(e) {
          error <<- list(
            code = "RESULT_PARSE_FAILED",
            message = conditionMessage(e)
          )
          NULL
        }
      )
    }

    return(list(
      job_id = job_id,
      status = "completed",
      completed_at = if (!is.na(job$completed_at[[1]])) {
        format(job$completed_at[[1]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      } else {
        NULL
      },
      result = result,
      result_mode = result_mode,
      error = error
    ))
  }

  if (durable_status == "cancelled") {
    return(list(
      job_id = job_id,
      status = "cancelled",
      completed_at = if (!is.na(job$completed_at[[1]])) {
        format(job$completed_at[[1]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      } else {
        NULL
      },
      result = NULL,
      error = list(
        code = "CANCELLED",
        message = job$last_error_message[[1]] %||% "Job was cancelled"
      )
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

#' Job-type single-flight duplicate check for destructive maintenance jobs.
#'
#' Same `(operation, params)` shape as [check_duplicate_job()] so it is a
#' drop-in `duplicate_check_fn` seam, but dedupes on job_type alone rather than
#' the payload hash (#535 S2b HIGH-4): a full-table-replace maintenance job must
#' never run concurrently, including across a deploy that changes its payload
#' schema. `params` is ignored.
#'
#' @param operation Character job type.
#' @param params Ignored (present for seam compatibility).
#' @return list(duplicate = FALSE) or list(duplicate = TRUE, existing_job_id).
#' @export
check_active_job_by_type <- function(operation, params = NULL) {
  async_job_service_duplicate_by_type(operation)
}

#' Compatibility no-op for the removed in-memory cleanup cycle
#'
#' @return Integer count of removed jobs (invisible).
#' @export
cleanup_old_jobs <- function() {
  invisible(0L)
}

#' Compatibility no-op for the removed in-memory cleanup scheduler
#'
#' @param interval_seconds Interval between cleanup runs in seconds
#' @export
schedule_cleanup <- function(interval_seconds = 3600) {
  invisible(interval_seconds)
}

#' Get Job History
#'
#' Returns recent durable jobs, sorted by submission time (newest first).
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

## -------------------------------------------------------------------##
# Job-Result Access Predicate
## -------------------------------------------------------------------##

# Job operations whose full result JSON is safe for anonymous retrieval
# (public, user-initiated analysis that returns the caller's own output).
PUBLIC_FULL_RESULT_JOB_TYPES <- c("clustering", "phenotype_clustering")

#' May this requester read the full result JSON for a job of `job_type`?
#'
#' Anonymous/Viewer callers may read full results only for public-operation
#' jobs; Reviewer and above may read any job's full result.
#'
#' @param job_type Character job operation/type.
#' @param user_role Character role from req$user_role, or NULL if anonymous.
#' @return Logical.
# Heavy/admin maintenance job results can carry operational detail (backup
# paths, import diagnostics, standing queries, corpus IDs, upstream errors), so
# their full result_json is Administrator-only even for otherwise-privileged
# Reviewer/Curator roles (LOW-1). This must mirror the canonical maintenance set
# ASYNC_MAINTENANCE_JOB_TYPES (async-job-service.R); the static list is the
# complete fallback for minimal/test envs where that constant is not sourced.
ADMIN_ONLY_RESULT_JOB_TYPES <- c(
  "publication_date_backfill", "publication_refresh", "pubtator_update",
  "pubtator_enrichment_refresh", "pubtatornidd_nightly", "omim_update",
  "hgnc_update", "comparisons_update", "ontology_update", "force_apply_ontology",
  "disease_ontology_mapping_refresh", "nddscore_import", "backup_create",
  "backup_restore"
)

# Reference the canonical maintenance set at CALL time so the two never drift
# (async-job-service.R is sourced before job-manager.R), unioned with the static
# fallback above for envs that source job-manager.R alone (tests).
admin_only_result_job_types <- function() {
  if (exists("ASYNC_MAINTENANCE_JOB_TYPES", mode = "character")) {
    return(base::union(ADMIN_ONLY_RESULT_JOB_TYPES, ASYNC_MAINTENANCE_JOB_TYPES))
  }
  ADMIN_ONLY_RESULT_JOB_TYPES
}

can_read_full_job_result <- function(job_type, user_role = NULL) {
  is_admin <- identical(user_role, "Administrator")
  if (!is.null(job_type) && job_type %in% admin_only_result_job_types()) {
    return(is_admin)
  }
  privileged <- !is.null(user_role) &&
    user_role %in% c("Reviewer", "Curator", "Administrator")
  if (privileged) {
    return(TRUE)
  }
  !is.null(job_type) && job_type %in% PUBLIC_FULL_RESULT_JOB_TYPES
}
