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
require(ellmer)

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

# Load progress reporter (if not already loaded)
if (!exists("create_progress_reporter", mode = "function")) {
  if (file.exists("functions/job-progress.R")) {
    source("functions/job-progress.R", local = TRUE)
  }
}

# Load job manager for create_job (if not already loaded)
if (!exists("create_job", mode = "function")) {
  if (file.exists("functions/job-manager.R")) {
    source("functions/job-manager.R", local = TRUE)
  }
}


#' Trigger LLM batch generation after clustering completion
#'
#' Entry point for chaining LLM generation after clustering jobs.
#' Checks Gemini configuration and creates a batch generation job.
#'
#' @param clusters Tibble of cluster data from clustering result
#' @param cluster_type Character, "functional" or "phenotype"
#' @param parent_job_id Character, UUID of the clustering job that triggered this
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
#' - Passes clusters, cluster_type, and parent_job_id to executor
#' - Timeout set to 1 hour for large batches
#'
#' @examples
#' \dontrun{
#' # Called from job-manager.R promise callback
#' result <- trigger_llm_batch_generation(
#'   clusters = clustering_result$clusters,
#'   cluster_type = "functional",
#'   parent_job_id = "abc-123"
#' )
#' }
#'
#' @export
trigger_llm_batch_generation <- function(clusters, cluster_type, parent_job_id) {
  # Check if Gemini is configured
  if (!is_gemini_configured()) {
    log_warn("Skipping LLM generation: GEMINI_API_KEY not set")
    return(list(
      skipped = TRUE,
      reason = "GEMINI_API_KEY environment variable not set"
    ))
  }

  log_info("Triggering LLM batch generation for {nrow(clusters)} {cluster_type} clusters (parent={parent_job_id})")

  # Create job with llm_batch_executor
  result <- create_job(
    operation = "llm_generation",
    params = list(
      clusters = clusters,
      cluster_type = cluster_type,
      parent_job_id = parent_job_id
    ),
    executor_fn = llm_batch_executor,
    timeout_ms = 3600000  # 1 hour for large batches
  )

  return(result)
}


#' LLM batch executor for processing clusters
#'
#' Processes each cluster with cache-first lookup, retry logic, and progress reporting.
#' Executed in mirai daemon as part of async job.
#'
#' @param params List containing:
#'   - clusters: Tibble of cluster data
#'   - cluster_type: Character, "functional" or "phenotype"
#'   - parent_job_id: Character, UUID of parent clustering job
#'   - .__job_id__: Character, UUID of this job (injected by create_job)
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
  # Extract parameters
  clusters <- params$clusters
  cluster_type <- params$cluster_type
  job_id <- params$.__job_id__
  parent_job_id <- params$parent_job_id %||% "unknown"

  log_info("LLM batch executor started: {nrow(clusters)} clusters, type={cluster_type}, job_id={job_id}")

  # Create progress reporter
  reporter <- create_progress_reporter(job_id)

  # Initialize counters
  total <- nrow(clusters)
  succeeded <- 0
  failed <- 0
  skipped <- 0

  # Process each cluster
  for (i in seq_len(total)) {
    cluster_row <- clusters[i, ]

    # Update progress
    reporter(
      step = "generation",
      message = sprintf("Cluster %d (%d/%d)", cluster_row$cluster_number, i, total),
      current = i,
      total = total
    )

    # Build cluster_data structure
    # The structure depends on cluster_type
    cluster_data <- list(
      cluster_number = cluster_row$cluster_number
    )

    # For functional clusters: identifiers have hgnc_id and symbol columns
    # For phenotype clusters: identifiers have entity_id column
    if (cluster_type == "functional") {
      # Extract genes from cluster row (assume symbols column contains comma-separated genes)
      if ("symbols" %in% names(cluster_row)) {
        symbols <- strsplit(cluster_row$symbols, ",")[[1]]
        symbols <- trimws(symbols)
        # We need hgnc_id for hashing - if not available, use placeholder
        cluster_data$identifiers <- tibble::tibble(
          symbol = symbols,
          hgnc_id = seq_along(symbols)  # Placeholder if not available
        )
      } else {
        log_warn("Cluster {cluster_row$cluster_number} missing 'symbols' column")
        failed <- failed + 1
        next
      }
    } else {
      # Phenotype clusters - structure may vary
      # Assume entity_ids column or similar
      if ("entity_ids" %in% names(cluster_row)) {
        entity_ids <- strsplit(cluster_row$entity_ids, ",")[[1]]
        entity_ids <- trimws(entity_ids)
        cluster_data$identifiers <- tibble::tibble(
          entity_id = entity_ids
        )
      } else {
        log_warn("Cluster {cluster_row$cluster_number} missing 'entity_ids' column")
        failed <- failed + 1
        next
      }
    }

    # Add term enrichment data if available
    # This may be stored in a JSON column or separate structure
    if ("term_enrichment" %in% names(cluster_row)) {
      # Parse JSON if needed
      cluster_data$term_enrichment <- if (is.character(cluster_row$term_enrichment)) {
        jsonlite::fromJSON(cluster_row$term_enrichment)
      } else {
        cluster_row$term_enrichment
      }
    } else {
      # No enrichment data - LLM can still generate but with lower quality
      cluster_data$term_enrichment <- tibble::tibble(
        category = character(0),
        term = character(0),
        fdr = numeric(0)
      )
    }

    # Generate cluster hash
    cluster_hash <- tryCatch(
      generate_cluster_hash(cluster_data$identifiers, cluster_type),
      error = function(e) {
        log_warn("Failed to generate hash for cluster {cluster_row$cluster_number}: {e$message}")
        return(NULL)
      }
    )

    if (is.null(cluster_hash)) {
      failed <- failed + 1
      next
    }

    # Check cache
    cached <- tryCatch(
      get_cached_summary(cluster_hash),
      error = function(e) {
        log_warn("Cache lookup failed for cluster {cluster_row$cluster_number}: {e$message}")
        return(NULL)
      }
    )

    if (!is.null(cached) && nrow(cached) > 0) {
      log_debug("Cluster {cluster_row$cluster_number} found in cache (cache_id={cached$cache_id[1]})")
      skipped <- skipped + 1
      next
    }

    # Attempt generation with retry
    max_retries <- 3
    attempt <- 0
    generation_success <- FALSE

    while (attempt < max_retries && !generation_success) {
      attempt <- attempt + 1

      # Apply backoff for retries
      if (attempt > 1) {
        backoff_time <- (2^attempt) + runif(1, 0, 1)
        log_debug("Retry {attempt}/{max_retries} for cluster {cluster_row$cluster_number}, backing off {round(backoff_time, 1)}s")
        Sys.sleep(backoff_time)
      }

      # Attempt generation
      result <- tryCatch(
        generate_cluster_summary(
          cluster_data = cluster_data,
          cluster_type = cluster_type
        ),
        error = function(e) {
          log_warn("Generation error for cluster {cluster_row$cluster_number} (attempt {attempt}): {e$message}")
          return(list(success = FALSE, error = e$message))
        }
      )

      if (result$success) {
        # Success - save to cache
        cache_id <- tryCatch(
          save_summary_to_cache(
            cluster_type = cluster_type,
            cluster_number = as.integer(cluster_row$cluster_number),
            cluster_hash = cluster_hash,
            model_name = "gemini-2.0-flash",
            prompt_version = "1.0",
            summary_json = result$summary,
            tags = result$summary$tags
          ),
          error = function(e) {
            log_error("Failed to save to cache for cluster {cluster_row$cluster_number}: {e$message}")
            return(NULL)
          }
        )

        if (!is.null(cache_id)) {
          log_info("Generated summary for cluster {cluster_row$cluster_number} (cache_id={cache_id})")
          succeeded <- succeeded + 1
          generation_success <- TRUE
        } else {
          # Cache save failed but generation succeeded - count as failure
          log_warn("Generation succeeded but cache save failed for cluster {cluster_row$cluster_number}")
        }
      }
    }

    # If still not successful after retries, count as failed
    if (!generation_success) {
      log_warn("Failed to generate summary for cluster {cluster_row$cluster_number} after {max_retries} attempts")
      failed <- failed + 1
    }
  }

  # Final progress update
  reporter(
    step = "complete",
    message = sprintf("Done: %d succeeded, %d failed, %d cached", succeeded, failed, skipped),
    current = total,
    total = total
  )

  log_info("LLM batch generation complete: {succeeded} succeeded, {failed} failed, {skipped} cached (total={total})")

  return(list(
    total = as.integer(total),
    succeeded = as.integer(succeeded),
    failed = as.integer(failed),
    skipped = as.integer(skipped)
  ))
}
