# functions/llm-batch-generator.R
#
# Batch LLM generation orchestrator for cluster summaries.
# Chains after clustering job completion and processes clusters with cache-first lookup.
#
# Key features:
# - Cache-first lookup for each cluster (skips cached summaries)
# - Retry logic with exponential backoff and jitter
# - Per-cluster progress reporting
# - Graceful failure (failed clusters don't stop batch)
# - Integration with job-manager via create_job()

require(logger)
# Make ellmer optional - LLM features require it but basic API functions don't
if (!requireNamespace("ellmer", quietly = TRUE)) {
  log_warn("ellmer package not available - LLM batch generation disabled")
}

log_threshold(INFO)

# Load LLM service functions (if not already loaded)
if (!exists("generate_cluster_summary", mode = "function")) {
  if (file.exists("functions/llm-service.R")) {
    source("functions/llm-service.R", local = TRUE)
  }
}

# Load cache repository functions (if not already loaded)
if (!exists("get_cached_summary", mode = "function")) {
  if (file.exists("functions/llm-cache-repository.R")) {
    source("functions/llm-cache-repository.R", local = TRUE)
  }
}

# Load the cluster-row -> cluster_data builder (extracted helper) if not present
if (!exists("llm_batch_build_cluster_data", mode = "function")) {
  if (file.exists("functions/llm-batch-cluster-data.R")) {
    source("functions/llm-batch-cluster-data.R", local = TRUE)
  }
}

# Load progress reporter (if not already loaded)
if (!exists("create_progress_reporter", mode = "function")) {
  if (file.exists("functions/job-progress.R")) {
    source("functions/job-progress.R", local = TRUE)
  }
}

# Note: create_job is provided by job-manager.R which sources this file
# Do NOT source job-manager.R from here - it creates a circular dependency

# Load LLM judge module (if not already loaded)
if (!exists("generate_and_validate_with_judge", mode = "function")) {
  if (file.exists("functions/llm-judge.R")) {
    source("functions/llm-judge.R", local = TRUE)
  }
}

llm_cluster_progress_message <- function(cluster_num, current, total) {
  sprintf(
    "Cluster %s (%d/%d)",
    as.character(cluster_num[[1]]),
    as.integer(current),
    as.integer(total)
  )
}


#' Decide whether a cluster's cache-first lookup should short-circuit (#488)
#'
#' The batch executor is cache-first: if a current summary already exists for a
#' cluster's hash, it normally skips generation. A forced regeneration must
#' bypass that short-circuit so it actually re-generates. Extracted as a pure
#' function so the truth table is unit-testable without a database.
#'
#' @param cached The `get_cached_summary()` result (NULL / 0-row => cache miss).
#' @param force Logical, TRUE to force regeneration regardless of cache hit.
#' @return TRUE to skip generation (use the cached summary); FALSE to (re)generate.
#' @export
llm_should_skip_cached <- function(cached, force = FALSE) {
  if (isTRUE(force)) {
    return(FALSE)
  }
  !is.null(cached) && is.data.frame(cached) && nrow(cached) > 0
}


#' Trigger LLM batch generation after clustering completion
#'
#' Entry point for chaining LLM generation after clustering jobs.
#' Checks Gemini configuration and creates a batch generation job.
#'
#' @param clusters Tibble of cluster data from clustering result
#' @param cluster_type Character, "functional" or "phenotype"
#' @param parent_job_id Character, UUID of the clustering job that triggered this
#' @param force Logical, if TRUE regenerate even for clusters already cached
#'   (bypasses the executor's cache-first short-circuit). Default FALSE.
#'
#' @return List with:
#'   - skipped: Logical, TRUE if Gemini not configured
#'   - reason: Character, reason for skipping (if skipped)
#'   - job_id: Character, UUID of created job (if not skipped)
#'   - status: Character, job status (if not skipped)
#'
#' @details
#' - Checks is_gemini_configured() before proceeding
#' - Creates job with operation="llm_generation"
#' - Passes clusters, cluster_type, parent_job_id, and force to executor
#' - Timeout set to 1 hour for large batches
#'
#' @examples
#' \dontrun{
#' # Called after durable clustering jobs complete
#' result <- trigger_llm_batch_generation(
#'   clusters = clustering_result$clusters,
#'   cluster_type = "functional",
#'   parent_job_id = "abc-123"
#' )
#' }
#'
#' @export
trigger_llm_batch_generation <- function(clusters, cluster_type, parent_job_id, force = FALSE) {
  # Debug: Confirm function entry with message() for Docker logs visibility
  message("[LLM-Batch] ENTERED trigger_llm_batch_generation function")

  # Ensure is_gemini_configured is available (load llm-service.R if needed)
  if (!exists("is_gemini_configured", mode = "function")) {
    message("[LLM-Batch] Loading llm-service.R for is_gemini_configured")
    if (file.exists("functions/llm-service.R")) {
      source("functions/llm-service.R", local = FALSE)
    } else {
      message("[LLM-Batch] ERROR: llm-service.R not found")
      return(list(skipped = TRUE, reason = "llm-service.R not found"))
    }
  }

  # Check if Gemini is configured
  gemini_configured <- is_gemini_configured()
  message("[LLM-Batch] is_gemini_configured() = ", gemini_configured)

  if (!gemini_configured) {
    message("[LLM-Batch] Skipping: GEMINI_API_KEY not set")
    log_warn("[LLM-Batch] Skipping: GEMINI_API_KEY not set")
    return(list(
      skipped = TRUE,
      reason = "GEMINI_API_KEY environment variable not set"
    ))
  }

  # Validate inputs
  if (is.null(clusters) || !is.data.frame(clusters)) {
    message("[LLM-Batch] Invalid clusters: not a data.frame")
    log_error("[LLM-Batch] Invalid clusters: not a data.frame")
    return(list(skipped = TRUE, reason = "Invalid clusters input"))
  }

  if (nrow(clusters) == 0) {
    message("[LLM-Batch] No clusters to process")
    log_warn("[LLM-Batch] No clusters to process")
    return(list(skipped = TRUE, reason = "No clusters to process"))
  }

  message("[LLM-Batch] Triggering for ", nrow(clusters), " ", cluster_type, " clusters (parent=", parent_job_id, ")")
  message("[LLM-Batch] Cluster columns: ", paste(names(clusters), collapse = ", "))
  log_info("[LLM-Batch] Triggering for {nrow(clusters)} {cluster_type} clusters (parent={parent_job_id})")
  log_debug("[LLM-Batch] Cluster columns: {paste(names(clusters), collapse=', ')}")

  # Check if create_job function is available
  if (!exists("create_job", mode = "function")) {
    message("[LLM-Batch] ERROR: create_job function not available!")
    return(list(skipped = TRUE, reason = "create_job function not available"))
  }

  message("[LLM-Batch] About to submit llm_generation job")

  # The registered durable handler resolves DB creds at run time via
  # async_job_db_connect() (#535 S2b) — no db_config in the payload.
  tryCatch(
    {
      result <- create_job(
        operation = "llm_generation",
        params = list(
          clusters = clusters,
          cluster_type = cluster_type,
          parent_job_id = parent_job_id,
          force = isTRUE(force)
        )
      )
      message("[LLM-Batch] Job created successfully: ", result$job_id %||% "unknown")
      log_info("[LLM-Batch] Job created: {result$job_id %||% 'unknown'}")
      return(result)
    },
    error = function(e) {
      message("[LLM-Batch] FAILED to create job: ", conditionMessage(e))
      log_error("[LLM-Batch] Failed to create job: {conditionMessage(e)}")
      return(list(
        skipped = TRUE,
        reason = paste("Job creation failed:", conditionMessage(e))
      ))
    }
  )
}


#' LLM batch executor for processing clusters
#'
#' Processes each cluster with cache-first lookup, retry logic, and progress reporting.
#' Executed by the durable async worker; opens its DB connection via
#' async_job_db_connect() (#535 S2b).
#'
#' @param params List containing:
#'   - clusters: Tibble of cluster data
#'   - cluster_type: Character, "functional" or "phenotype"
#'   - parent_job_id: Character, UUID of parent clustering job
#'   - .__job_id__: Character, UUID injected by the durable handler
#'
#' @return List with summary statistics:
#'   - total: Integer, total clusters processed
#'   - succeeded: Integer, successfully generated summaries
#'   - failed: Integer, failed after retries
#'   - skipped: Integer, found in cache
#'
#' @details
#' Processing flow for each cluster:
#' 1. Build cluster_data structure from cluster row
#' 2. Generate cluster_hash
#' 3. Check cache via get_cached_summary()
#' 4. If cache hit: increment skipped, continue
#' 5. If cache miss: attempt generation with retry (max 3 attempts)
#' 6. On success: save to cache, increment succeeded
#' 7. On failure: exponential backoff with jitter, retry
#' 8. After 3 failures: log warning, increment failed, continue
#'
#' Retry backoff: 2^attempts + runif(1, 0, 1) seconds
#'
#' @export
llm_batch_executor <- function(params) {
  # File-based debug logging for mirai daemon visibility
  debug_log_file <- "/tmp/llm_executor_debug.log"
  log_debug <- function(...) {
    cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " ", ..., "\n", file = debug_log_file, append = TRUE)
  }
  log_debug("ENTERED llm_batch_executor function")

  # Debug: Confirm executor entry with message() for visibility
  message("[LLM-Executor] ENTERED llm_batch_executor function")
  log_info("[LLM-Executor] Starting batch executor")

  # Extract parameters with validation
  clusters <- params$clusters
  cluster_type <- params$cluster_type
  job_id <- params$.__job_id__ %||% "unknown"
  parent_job_id <- params$parent_job_id %||% "unknown"
  force <- isTRUE(params$force)

  message("[LLM-Executor] job_id=", job_id, " parent_job_id=", parent_job_id, " force=", force)

  # Resolve the DB connection at run time from the worker runtime config (#535
  # S2b); no db_config is carried in the job payload.
  daemon_conn <- tryCatch(
    async_job_db_connect(),
    error = function(e) {
      log_debug("ERROR: Database connection failed: ", e$message)
      message("[LLM-Executor] ERROR: Database connection failed: ", e$message)
      NULL
    }
  )

  if (is.null(daemon_conn)) {
    return(list(total = 0L, succeeded = 0L, failed = 0L, skipped = 0L, error = "Database connection failed"))
  }

  # Ensure connection is closed when executor exits
  on.exit(DBI::dbDisconnect(daemon_conn), add = TRUE)

  # Make connection available to db-helpers via global environment
  # This allows LLM functions to use db_execute_query without modifications
  base::assign("daemon_db_conn", daemon_conn, envir = .GlobalEnv)
  on.exit(base::rm("daemon_db_conn", envir = .GlobalEnv), add = TRUE)

  log_debug("Database connection established")
  message("[LLM-Executor] Database connection established")

  # Validate inputs
  if (is.null(clusters) || !is.data.frame(clusters)) {
    message("[LLM-Executor] ERROR: Invalid clusters data")
    log_error("[LLM-Executor] Invalid clusters data")
    return(list(total = 0L, succeeded = 0L, failed = 0L, skipped = 0L, error = "Invalid clusters"))
  }

  message("[LLM-Executor] Processing ", nrow(clusters), " ", cluster_type, " clusters")
  message("[LLM-Executor] Cluster columns: ", paste(names(clusters), collapse = ", "))
  log_info("[LLM-Executor] Processing {nrow(clusters)} {cluster_type} clusters (job={job_id}, parent={parent_job_id})")
  log_debug("[LLM-Executor] Cluster columns: {paste(names(clusters), collapse=', ')}")

  # Create progress reporter with error handling
  reporter <- tryCatch(
    create_progress_reporter(job_id),
    error = function(e) {
      log_warn("[LLM-Executor] Progress reporter failed: {e$message}")
      function(...) invisible(NULL)  # Fallback no-op reporter
    }
  )

  # Initialize counters. `rejected` is reported as a distinct bucket (#490): a
  # cluster the judge deterministically rejects is neither a generation
  # `failed` (API/parse error) nor `skipped` (cache hit); conflating it with
  # `failed` hid the judge rejection from the job result_json.
  total <- nrow(clusters)
  succeeded <- 0
  failed <- 0
  skipped <- 0
  rejected <- 0

  # Process each cluster
  for (i in seq_len(total)) {
    cluster_row <- clusters[i, ]

    # Get cluster number (handle both 'cluster' and 'cluster_number' column names)
    cluster_num <- if ("cluster_number" %in% names(cluster_row)) {
      cluster_row$cluster_number
    } else if ("cluster" %in% names(cluster_row)) {
      cluster_row$cluster
    } else {
      i  # Fallback to index
    }

    # Update progress
    reporter(
      step = "generation",
      message = llm_cluster_progress_message(cluster_num, i, total),
      current = i,
      total = total
    )

    # Build the cluster_data structure + resolve the authoritative cluster hash
    # (extracted to llm-batch-cluster-data.R to keep the executor under the
    # file-size ratchet, and to make the row-shaping unit-testable).
    message("[LLM-Executor] Processing cluster ", cluster_num, " (", i, "/", total, ")")
    built <- llm_batch_build_cluster_data(cluster_row, cluster_type, cluster_num)
    if (!isTRUE(built$ok)) {
      log_warn("Cluster {cluster_num} skipped: {built$reason}")
      message("[LLM-Executor] Cluster ", cluster_num, " skipped: ", built$reason)
      failed <- failed + 1
      next
    }
    cluster_data <- built$cluster_data
    cluster_hash <- built$cluster_hash
    message("[LLM-Executor] Cluster ", cluster_num, " hash: ", substr(cluster_hash, 1, 16), "...")

    # Check cache
    cached <- tryCatch(
      get_cached_summary(cluster_hash),
      error = function(e) {
        message("[LLM-Executor] Cache lookup error for cluster ", cluster_num, ": ", e$message)
        log_warn("Cache lookup failed for cluster {cluster_row$cluster_number}: {e$message}")
        return(NULL)
      }
    )

    # Cache-first short-circuit, unless a forced regeneration was requested
    # (#488). `llm_should_skip_cached` centralizes the decision so it is
    # unit-testable and `force` actually bypasses the cache instead of being a
    # dead query param.
    if (llm_should_skip_cached(cached, force)) {
      message("[LLM-Executor] Cluster ", cluster_num, " found in cache (cache_id=", cached$cache_id[1], ")")
      log_debug("Cluster {cluster_row$cluster_number} found in cache (cache_id={cached$cache_id[1]})")
      skipped <- skipped + 1
      next
    }

    if (force && !is.null(cached) && nrow(cached) > 0) {
      message("[LLM-Executor] Cluster ", cluster_num, " cached but force=TRUE, regenerating...")
    } else {
      message("[LLM-Executor] Cluster ", cluster_num, " not in cache, generating summary...")
    }

    # Attempt generation with retry. `judge_attempts` counts judge verdicts so
    # the batch does not re-generate a cluster the judge deterministically
    # rejects more than `max_judge_attempts` times per run (#490): a repeat
    # rejection of the same content wastes API calls and never validates.
    max_retries <- 3
    max_judge_attempts <- 2
    attempt <- 0
    judge_attempts <- 0
    generation_success <- FALSE
    last_validation_status <- NA_character_

    while (attempt < max_retries && !generation_success) {
      attempt <- attempt + 1
      log_debug("Cluster ", cluster_num, " generation attempt ", attempt, "/", max_retries)
      message("[LLM-Executor] Cluster ", cluster_num, " generation attempt ", attempt, "/", max_retries)

      # Apply backoff for retries
      if (attempt > 1) {
        backoff_time <- (2^attempt) + runif(1, 0, 1)
        message("[LLM-Executor] Retry backoff: ", round(backoff_time, 1), "s")
        log_debug(
          "Retry {attempt}/{max_retries} for cluster {cluster_row$cluster_number}, ",
          "backing off {round(backoff_time, 1)}s"
        )
        Sys.sleep(backoff_time)
      }

      # Attempt generation and validation
      # Pass the pre-computed cluster_hash (extracted from hash_filter) to ensure
      # the cached summary uses the same hash that the API will query
      result <- tryCatch(
        generate_and_validate_with_judge(
          cluster_data = cluster_data,
          cluster_type = cluster_type,
          cluster_hash = cluster_hash
        ),
        error = function(e) {
          log_debug("Cluster ", cluster_num, " attempt ", attempt, " ERROR: ", conditionMessage(e))
          message("[LLM-Executor] Cluster ", cluster_num, " attempt ", attempt, " ERROR: ", conditionMessage(e))
          log_warn("Cluster {cluster_row$cluster_number} attempt {attempt}: {e$message}")
          return(list(success = FALSE, error = conditionMessage(e)))
        }
      )

      last_validation_status <- result$validation_status %||% last_validation_status

      if (result$success) {
        # Success - already cached by generate_and_validate_with_judge
        log_debug("Cluster ", cluster_num, " SUCCESS: ", result$validation_status)
        message("[LLM-Executor] Cluster ", cluster_num, " SUCCESS: ", result$validation_status)
        log_info(
          "Cluster {cluster_row$cluster_number}: {result$validation_status} ",
          "(judge: {result$judge_result$verdict}, cache_id={result$cache_id})"
        )
        succeeded <- succeeded + 1
        generation_success <- TRUE
      } else if (identical(result$validation_status, "rejected")) {
        # Judge REJECTION (not an API/parse failure). The row is cached
        # is_current with the snapshot hash so serving can surface a terminal
        # "could not be validated" state (#490). Bound the judge re-tries so we
        # don't burn API calls re-rejecting the same content.
        judge_attempts <- judge_attempts + 1
        log_warn(
          "Cluster {cluster_row$cluster_number} rejected by judge ",
          "(judge_attempt {judge_attempts}/{max_judge_attempts})"
        )
        message("[LLM-Executor] Cluster ", cluster_num, " rejected by judge (attempt ", judge_attempts, ")")
        if (judge_attempts >= max_judge_attempts) {
          message("[LLM-Executor] Cluster ", cluster_num, " judge-rejection cap reached; stopping retries")
          break
        }
      } else {
        log_debug("Cluster ", cluster_num, " attempt ", attempt, " failed: ", result$error %||% "unknown")
        message("[LLM-Executor] Cluster ", cluster_num, " attempt ", attempt, " failed: ", result$error %||% "unknown")
      }
    }

    # Classify the outcome (#490): a judge rejection is reported in the distinct
    # `rejected` bucket, a generation/API error in `failed`.
    if (!generation_success) {
      if (identical(last_validation_status, "rejected")) {
        log_warn("Cluster {cluster_row$cluster_number} not validated: judge rejected after {judge_attempts} attempt(s)")
        rejected <- rejected + 1
      } else {
        log_warn("Failed to generate summary for cluster {cluster_row$cluster_number} after {max_retries} attempts")
        failed <- failed + 1
      }
    }

    # Periodic memory cleanup every 10 clusters
    # Helps return memory to OS during long batch runs in daemon context
    # ~100ms overhead per call, acceptable for memory benefits
    if (i %% 10 == 0) {
      gc(verbose = FALSE)
      log_debug("gc() called after cluster ", i)
    }
  }

  # Final memory cleanup after batch processing
  gc(verbose = FALSE)
  log_debug("Final gc() called after batch completion")

  # Final progress update
  reporter(
    step = "complete",
    message = sprintf(
      "Done: %d succeeded, %d rejected, %d failed, %d cached",
      succeeded, rejected, failed, skipped
    ),
    current = total,
    total = total
  )

  log_info(
    "LLM batch generation complete: {succeeded} succeeded, {rejected} rejected, ",
    "{failed} failed, {skipped} cached (total={total})"
  )

  return(list(
    total = as.integer(total),
    succeeded = as.integer(succeeded),
    rejected = as.integer(rejected),
    failed = as.integer(failed),
    skipped = as.integer(skipped)
  ))
}
