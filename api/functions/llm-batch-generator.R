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

  message("[LLM-Batch] About to call create_job() with llm_batch_executor")

  # Build db_config from config.yml for daemon use
  # Daemons don't have access to the main process's pool object
  db_config <- tryCatch(
    {
      config_path <- if (file.exists("/app/config.yml")) "/app/config.yml" else "config.yml"
      cfg <- config::get(file = config_path)
      db_cfg <- cfg$sysndd_db %||% cfg
      list(
        db_host = db_cfg$host %||% "mysql",
        db_port = as.integer(db_cfg$port %||% 3306),
        db_name = db_cfg$dbname %||% "sysndd_db",
        db_user = db_cfg$user,
        db_password = db_cfg$password
      )
    },
    error = function(e) {
      message("[LLM-Batch] Failed to read config.yml: ", e$message)
      NULL
    }
  )

  if (is.null(db_config) || is.null(db_config$db_user)) {
    message("[LLM-Batch] ERROR: Could not read database config")
    return(list(skipped = TRUE, reason = "Database configuration not available"))
  }

  message("[LLM-Batch] db_config loaded: host=", db_config$db_host, ", db=", db_config$db_name)

  # Create job with llm_batch_executor
  tryCatch(
    {
      result <- create_job(
        operation = "llm_generation",
        params = list(
          db_config = db_config,
          clusters = clusters,
          cluster_type = cluster_type,
          parent_job_id = parent_job_id
        ),
        executor_fn = llm_batch_executor,
        timeout_ms = 3600000  # 1 hour for large batches
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
  db_config <- params$db_config

  message("[LLM-Executor] job_id=", job_id, " parent_job_id=", parent_job_id)

  # Create database connection for this daemon
  # Daemons don't have access to the main process's pool object
  if (is.null(db_config)) {
    log_debug("ERROR: db_config is NULL")
    message("[LLM-Executor] ERROR: db_config is NULL")
    return(list(total = 0L, succeeded = 0L, failed = 0L, skipped = 0L, error = "No database config"))
  }

  daemon_conn <- tryCatch(
    {
      log_debug("Creating database connection: host=", db_config$db_host, ", db=", db_config$db_name)
      DBI::dbConnect(
        RMariaDB::MariaDB(),
        host = db_config$db_host,
        port = db_config$db_port,
        dbname = db_config$db_name,
        user = db_config$db_user,
        password = db_config$db_password
      )
    },
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

  # Initialize counters
  total <- nrow(clusters)
  succeeded <- 0
  failed <- 0
  skipped <- 0

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
      message = sprintf("Cluster %d (%d/%d)", cluster_num, i, total),
      current = i,
      total = total
    )

    # Build cluster_data structure
    log_debug("Processing cluster ", cluster_num, " (", i, "/", total, ")")
    message("[LLM-Executor] Processing cluster ", cluster_num, " (", i, "/", total, ")")
    cluster_data <- list(
      cluster_number = cluster_num
    )

    # Extract identifiers - handle nested tibble structure from clustering functions
    if ("identifiers" %in% names(cluster_row)) {
      # identifiers is a nested tibble (list-column)
      identifiers_tbl <- cluster_row$identifiers[[1]]
      log_debug("Cluster ", cluster_num, " identifiers columns: ", paste(names(identifiers_tbl), collapse = ", "))
      message("[LLM-Executor] Cluster ", cluster_num, " identifiers columns: ", paste(names(identifiers_tbl), collapse = ", "))

      if (cluster_type == "functional") {
        # Functional clusters have symbol and hgnc_id columns
        if ("symbol" %in% names(identifiers_tbl) && "hgnc_id" %in% names(identifiers_tbl)) {
          cluster_data$identifiers <- identifiers_tbl
          message("[LLM-Executor] Cluster ", cluster_num, " has ", nrow(identifiers_tbl), " genes")
        } else {
          message("[LLM-Executor] ERROR: Cluster ", cluster_num, " missing symbol/hgnc_id columns")
          log_warn("Cluster {cluster_num} identifiers missing symbol/hgnc_id columns")
          failed <- failed + 1
          next
        }
      } else {
        # Phenotype clusters have entity_id column
        if ("entity_id" %in% names(identifiers_tbl)) {
          cluster_data$identifiers <- identifiers_tbl
        } else {
          message("[LLM-Executor] ERROR: Cluster ", cluster_num, " missing entity_id column")
          log_warn("Cluster {cluster_num} identifiers missing entity_id column")
          failed <- failed + 1
          next
        }
      }
    } else if ("symbols" %in% names(cluster_row)) {
      # Legacy format: comma-separated symbols string
      symbols <- strsplit(as.character(cluster_row$symbols), ",")[[1]]
      symbols <- trimws(symbols)
      cluster_data$identifiers <- tibble::tibble(
        symbol = symbols,
        hgnc_id = seq_along(symbols)
      )
    } else if ("entity_ids" %in% names(cluster_row)) {
      # Legacy format: comma-separated entity_ids string
      entity_ids <- strsplit(as.character(cluster_row$entity_ids), ",")[[1]]
      entity_ids <- trimws(entity_ids)
      cluster_data$identifiers <- tibble::tibble(
        entity_id = as.integer(entity_ids)
      )
    } else {
      log_warn("Cluster {cluster_num} has no identifiers data")
      failed <- failed + 1
      next
    }

    # Add term enrichment data if available
    if ("term_enrichment" %in% names(cluster_row)) {
      # Handle nested tibble (list-column) from clustering functions
      enrichment_data <- cluster_row$term_enrichment[[1]]
      if (is.character(enrichment_data)) {
        cluster_data$term_enrichment <- jsonlite::fromJSON(enrichment_data)
      } else if (is.data.frame(enrichment_data)) {
        cluster_data$term_enrichment <- enrichment_data
      } else {
        cluster_data$term_enrichment <- enrichment_data
      }
    } else {
      # No enrichment data - LLM can still generate but with lower quality
      cluster_data$term_enrichment <- tibble::tibble(
        category = character(0),
        term = character(0),
        fdr = numeric(0)
      )
    }

    # Extract cluster hash from clustering result's hash_filter column
    # The hash_filter is pre-computed during clustering in format: equals(hash,XXX)
    # Using this hash ensures consistency between what the API queries and what we store
    cluster_hash <- tryCatch({
      if ("hash_filter" %in% names(cluster_row)) {
        hash_str <- as.character(cluster_row$hash_filter)
        log_debug("Cluster ", cluster_num, " raw hash_filter: ", hash_str)
        message("[LLM-Executor] Cluster ", cluster_num, " raw hash_filter: ", hash_str)

        # Extract hash from equals(hash,XXX) format
        if (grepl("^equals\\(hash,", hash_str)) {
          extracted_hash <- sub("^equals\\(hash,(.*)\\)$", "\\1", hash_str)
          log_debug("Cluster ", cluster_num, " extracted hash: ", substr(extracted_hash, 1, 16), "...")
          message("[LLM-Executor] Cluster ", cluster_num, " extracted hash: ", substr(extracted_hash, 1, 16), "...")
          extracted_hash
        } else {
          # hash_filter is already a plain hash
          hash_str
        }
      } else {
        # Fallback: generate hash from identifiers (for backwards compatibility)
        log_debug("Cluster ", cluster_num, " has no hash_filter, generating from identifiers")
        message("[LLM-Executor] Cluster ", cluster_num, " has no hash_filter, generating from identifiers")
        generate_cluster_hash(cluster_data$identifiers, cluster_type)
      }
    }, error = function(e) {
      log_warn("Failed to extract/generate hash for cluster {cluster_row$cluster_number}: {e$message}")
      return(NULL)
    })

    if (is.null(cluster_hash)) {
      log_debug("ERROR: Cluster ", cluster_num, " hash generation returned NULL")
      message("[LLM-Executor] ERROR: Cluster ", cluster_num, " hash generation returned NULL")
      failed <- failed + 1
      next
    }
    log_debug("Cluster ", cluster_num, " hash: ", substr(cluster_hash, 1, 16), "...")
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

    if (!is.null(cached) && nrow(cached) > 0) {
      message("[LLM-Executor] Cluster ", cluster_num, " found in cache (cache_id=", cached$cache_id[1], ")")
      log_debug("Cluster {cluster_row$cluster_number} found in cache (cache_id={cached$cache_id[1]})")
      skipped <- skipped + 1
      next
    }

    message("[LLM-Executor] Cluster ", cluster_num, " not in cache, generating summary...")

    # Attempt generation with retry
    max_retries <- 3
    attempt <- 0
    generation_success <- FALSE

    while (attempt < max_retries && !generation_success) {
      attempt <- attempt + 1
      log_debug("Cluster ", cluster_num, " generation attempt ", attempt, "/", max_retries)
      message("[LLM-Executor] Cluster ", cluster_num, " generation attempt ", attempt, "/", max_retries)

      # Apply backoff for retries
      if (attempt > 1) {
        backoff_time <- (2^attempt) + runif(1, 0, 1)
        message("[LLM-Executor] Retry backoff: ", round(backoff_time, 1), "s")
        log_debug("Retry {attempt}/{max_retries} for cluster {cluster_row$cluster_number}, backing off {round(backoff_time, 1)}s")
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

      if (result$success) {
        # Success - already cached by generate_and_validate_with_judge
        log_debug("Cluster ", cluster_num, " SUCCESS: ", result$validation_status)
        message("[LLM-Executor] Cluster ", cluster_num, " SUCCESS: ", result$validation_status)
        log_info("Cluster {cluster_row$cluster_number}: {result$validation_status} (judge: {result$judge_result$verdict}, cache_id={result$cache_id})")
        succeeded <- succeeded + 1
        generation_success <- TRUE
      } else {
        log_debug("Cluster ", cluster_num, " attempt ", attempt, " failed: ", result$error %||% "unknown")
        message("[LLM-Executor] Cluster ", cluster_num, " attempt ", attempt, " failed: ", result$error %||% "unknown")
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
