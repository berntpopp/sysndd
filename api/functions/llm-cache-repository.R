# functions/llm-cache-repository.R
#
# Database cache operations for LLM-generated cluster summaries.
# Provides hash generation, cache lookup, cache storage, and logging.
#
# Key features:
# - SHA256 hash generation for cache invalidation
# - Cache lookup with validation status awareness
# - Atomic cache updates (mark old as non-current, insert new)
# - Complete generation logging for all attempts (success + failure)

require(tidyverse)
require(jsonlite)
require(logger)
require(DBI)
require(digest)

log_threshold(INFO)

# Load database helper functions for repository layer access (if not already loaded)
if (!exists("db_execute_query", mode = "function")) {
  if (file.exists("functions/db-helpers.R")) {
    source("functions/db-helpers.R", local = TRUE)
  }
}

#' Generate cluster hash for cache invalidation
#'
#' Creates a SHA256 hash from sorted gene/entity identifiers.
#' When cluster composition changes, the hash changes, triggering cache invalidation.
#'
#' @param identifiers For functional clusters: tibble with hgnc_id column.
#'   For phenotype clusters: tibble with entity_id column.
#' @param cluster_type Character, either "functional" or "phenotype"
#'
#' @return Character string, 64-character SHA256 hash
#'
#' @details
#' - Functional clusters: sorts hgnc_ids, joins with comma, hashes
#' - Phenotype clusters: sorts entity_ids, joins with comma, hashes
#' - Uses digest::digest() with algo="sha256" and serialize=FALSE
#'
#' @examples
#' \dontrun{
#' # Functional cluster with gene IDs
#' ids <- tibble(hgnc_id = c(1234, 5678, 9012))
#' hash <- generate_cluster_hash(ids, "functional")
#'
#' # Phenotype cluster with entity IDs
#' ids <- tibble(entity_id = c("OMIM:123", "HP:001", "ORPHA:456"))
#' hash <- generate_cluster_hash(ids, "phenotype")
#' }
#'
#' @export
generate_cluster_hash <- function(identifiers, cluster_type = "functional") {
  if (cluster_type == "functional") {
    if (!"hgnc_id" %in% names(identifiers)) {
      log_error("Functional cluster requires hgnc_id column")
      rlang::abort(
        message = "Functional cluster identifiers must have hgnc_id column",
        class = "llm_cache_error"
      )
    }
    sorted_ids <- sort(identifiers$hgnc_id)
  } else if (cluster_type == "phenotype") {
    if (!"entity_id" %in% names(identifiers)) {
      log_error("Phenotype cluster requires entity_id column")
      rlang::abort(
        message = "Phenotype cluster identifiers must have entity_id column",
        class = "llm_cache_error"
      )
    }
    sorted_ids <- sort(identifiers$entity_id)
  } else {
    log_error("Invalid cluster_type: {cluster_type}")
    rlang::abort(
      message = paste("Invalid cluster_type:", cluster_type, "- must be 'functional' or 'phenotype'"),
      class = "llm_cache_error"
    )
  }

  id_string <- paste(sorted_ids, collapse = ",")
  hash <- digest::digest(id_string, algo = "sha256", serialize = FALSE)

  log_debug("Generated cluster hash: {substr(hash, 1, 16)}... for {length(sorted_ids)} identifiers")

  return(hash)
}


#' Get cached summary for a cluster
#'
#' Retrieves the current cached summary for a given cluster hash.
#' Returns NULL if no cached summary exists.
#'
#' @param cluster_hash Character, SHA256 hash of cluster composition
#' @param require_validated Logical, if TRUE only returns validated summaries (default: FALSE)
#'
#' @return Tibble with cached summary data, or NULL if not found.
#'   Includes: cache_id, cluster_type, cluster_number, cluster_hash,
#'   model_name, prompt_version, summary_json, tags, is_current,
#'   validation_status, created_at, validated_at, validated_by
#'
#' @details
#' - Only returns rows where is_current = TRUE
#' - If require_validated = TRUE, also requires validation_status = 'validated'
#' - summary_json is returned as-is (MySQL JSON column)
#'
#' @examples
#' \dontrun{
#' # Get any current summary (pending or validated)
#' cached <- get_cached_summary("abc123...")
#'
#' # Get only validated summaries
#' cached <- get_cached_summary("abc123...", require_validated = TRUE)
#' }
#'
#' @export
get_cached_summary <- function(cluster_hash, require_validated = FALSE) {
  log_debug("Looking up cached summary for hash: {substr(cluster_hash, 1, 16)}...")

  if (require_validated) {
    result <- db_execute_query(
      "SELECT * FROM llm_cluster_summary_cache
       WHERE cluster_hash = ? AND is_current = TRUE AND validation_status = 'validated'",
      list(cluster_hash)
    )
  } else {
    result <- db_execute_query(
      "SELECT * FROM llm_cluster_summary_cache
       WHERE cluster_hash = ? AND is_current = TRUE",
      list(cluster_hash)
    )
  }

  if (nrow(result) == 0) {
    log_debug("No cached summary found for hash: {substr(cluster_hash, 1, 16)}...")
    return(NULL)
  }

  log_info("Found cached summary (cache_id={result$cache_id[1]}, status={result$validation_status[1]})")
  return(result)
}


#' Save summary to cache
#'
#' Saves a new LLM-generated summary to the cache. Atomically marks any
#' existing current summaries for this cluster as non-current before inserting.
#'
#' @param cluster_type Character, "functional" or "phenotype"
#' @param cluster_number Integer, cluster number
#' @param cluster_hash Character, SHA256 hash of cluster composition
#' @param model_name Character, name of the LLM model used (e.g., "gemini-3-pro-preview")
#' @param prompt_version Character, version of the prompt template (default: "1.0")
#' @param summary_json Character or list, the structured LLM response (will be serialized to JSON)
#' @param tags Character vector or NULL, extracted tags for search/filtering
#'
#' @return Integer, the cache_id of the newly inserted row
#'
#' @details
#' - Uses db_with_transaction() for atomicity
#' - First marks existing current summaries for this cluster as is_current = FALSE
#' - Then inserts new row with is_current = TRUE, validation_status = 'pending'
#' - summary_json and tags are serialized to JSON if not already strings
#'
#' @examples
#' \dontrun{
#' cache_id <- save_summary_to_cache(
#'   cluster_type = "functional",
#'   cluster_number = 3,
#'   cluster_hash = "abc123...",
#'   model_name = "gemini-3-pro-preview",
#'   prompt_version = "1.0",
#'   summary_json = list(summary = "...", key_themes = c(...)),
#'   tags = c("mitochondrial", "metabolism")
#' )
#' }
#'
#' @export
save_summary_to_cache <- function(
  cluster_type,
  cluster_number,
  cluster_hash,
  model_name,
  prompt_version = "1.0",
  summary_json,
  tags = NULL,
  validation_status = "pending"
) {
  log_info("Saving summary to cache for cluster {cluster_type}/{cluster_number} (status={validation_status})")

  # Validate validation_status
  valid_statuses <- c("pending", "validated", "rejected")
  if (!validation_status %in% valid_statuses) {
    log_warn("Invalid validation_status '{validation_status}', defaulting to 'pending'")
    validation_status <- "pending"
  }

  # Serialize to JSON if needed - ensure plain character string for DBI binding
  summary_json_str <- if (is.character(summary_json) && length(summary_json) == 1) {
    summary_json
  } else {
    as.character(jsonlite::toJSON(summary_json, auto_unbox = TRUE))
  }

  # Convert NULL to NA_character_ for DBI binding (NULL has length 0, NA has length 1)
  tags_json_str <- if (is.null(tags)) {
    NA_character_
  } else if (is.character(tags) && length(tags) == 1 && startsWith(tags, "[")) {
    tags  # Already JSON
  } else {
    as.character(jsonlite::toJSON(tags, auto_unbox = FALSE))
  }

  result <- db_with_transaction({
    # Mark any existing current summaries as non-current
    affected <- db_execute_statement(
      "UPDATE llm_cluster_summary_cache
       SET is_current = FALSE
       WHERE cluster_type = ? AND cluster_number = ? AND is_current = TRUE",
      list(cluster_type, cluster_number)
    )

    if (affected > 0) {
      log_debug("Marked {affected} existing summary/summaries as non-current")
    }

    # Insert new summary with specified validation status
    db_execute_statement(
      "INSERT INTO llm_cluster_summary_cache
       (cluster_type, cluster_number, cluster_hash, model_name, prompt_version,
        summary_json, tags, is_current, validation_status)
       VALUES (?, ?, ?, ?, ?, ?, ?, TRUE, ?)",
      list(cluster_type, cluster_number, cluster_hash, model_name, prompt_version,
           summary_json_str, tags_json_str, validation_status)
    )

    # Get the inserted cache_id
    id_result <- db_execute_query("SELECT LAST_INSERT_ID() AS id")
    id_result$id[1]
  })

  log_info("Saved summary with cache_id={result}")
  return(result)
}


#' Log generation attempt
#'
#' Records an LLM generation attempt in the log table. Captures all attempts
#' including successful generations, validation failures, API errors, and timeouts.
#'
#' @param cluster_type Character, "functional" or "phenotype" (required)
#' @param cluster_number Integer, cluster number (required)
#' @param cluster_hash Character, SHA256 hash of cluster composition (required)
#' @param model_name Character, name of the LLM model used (required)
#' @param status Character, one of "success", "validation_failed", "api_error", "timeout" (required)
#' @param prompt_text Character, the prompt sent to the LLM (required)
#' @param response_json Character, list, or NULL, the raw LLM response
#' @param validation_errors Character or NULL, validation failure details
#' @param tokens_input Integer or NULL, input token count
#' @param tokens_output Integer or NULL, output token count
#' @param latency_ms Integer or NULL, API call latency in milliseconds
#' @param error_message Character or NULL, error message for failed attempts
#'
#' @return Integer, the log_id of the inserted row
#'
#' @details
#' - All generation attempts should be logged for debugging and prompt improvement
#' - response_json is serialized to JSON if not already a string
#' - Optional parameters (tokens, latency, errors) can be NULL
#'
#' @examples
#' \dontrun{
#' # Log successful generation
#' log_id <- log_generation_attempt(
#'   cluster_type = "functional",
#'   cluster_number = 3,
#'   cluster_hash = "abc123...",
#'   model_name = "gemini-3-pro-preview",
#'   status = "success",
#'   prompt_text = "Analyze this cluster...",
#'   response_json = result$summary,
#'   tokens_input = 1500,
#'   tokens_output = 300,
#'   latency_ms = 2500
#' )
#'
#' # Log failed attempt
#' log_id <- log_generation_attempt(
#'   cluster_type = "functional",
#'   cluster_number = 3,
#'   cluster_hash = "abc123...",
#'   model_name = "gemini-3-pro-preview",
#'   status = "api_error",
#'   prompt_text = "Analyze this cluster...",
#'   error_message = "429 Too Many Requests"
#' )
#' }
#'
#' @export
log_generation_attempt <- function(
  cluster_type,
  cluster_number,
  cluster_hash,
  model_name,
  status,
  prompt_text,
  response_json = NULL,
  validation_errors = NULL,
  tokens_input = NULL,
  tokens_output = NULL,
  latency_ms = NULL,
  error_message = NULL
) {
  log_debug("Logging generation attempt: status={status}, cluster={cluster_type}/{cluster_number}")

  # Serialize response_json if needed - ensure plain character string for DBI binding
  # Convert NULL to NA_character_ for DBI binding (NULL has length 0, NA has length 1)
  response_json_str <- if (is.null(response_json)) {
    NA_character_
  } else if (is.character(response_json) && length(response_json) == 1) {
    response_json
  } else {
    as.character(jsonlite::toJSON(response_json, auto_unbox = TRUE))
  }

  # Convert NULL to NA for DBI binding (NULL has length 0, NA has length 1)
  # DBI::dbBind requires all parameters to have length 1
  validation_errors_val <- if (is.null(validation_errors)) NA_character_ else validation_errors
  tokens_input_val <- if (is.null(tokens_input)) NA_integer_ else as.integer(tokens_input)
  tokens_output_val <- if (is.null(tokens_output)) NA_integer_ else as.integer(tokens_output)
  latency_ms_val <- if (is.null(latency_ms)) NA_integer_ else as.integer(latency_ms)
  error_message_val <- if (is.null(error_message)) NA_character_ else error_message

  db_execute_statement(
    "INSERT INTO llm_generation_log
     (cluster_type, cluster_number, cluster_hash, model_name, prompt_text,
      response_json, validation_errors, tokens_input, tokens_output,
      latency_ms, status, error_message)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    list(
      cluster_type, cluster_number, cluster_hash, model_name, prompt_text,
      response_json_str, validation_errors_val, tokens_input_val, tokens_output_val,
      latency_ms_val, status, error_message_val
    )
  )

  # Get the inserted log_id
  id_result <- db_execute_query("SELECT LAST_INSERT_ID() AS id")
  log_id <- id_result$id[1]

  if (status != "success") {
    log_warn("Generation attempt logged with status={status}, log_id={log_id}")
  } else {
    log_debug("Generation attempt logged: log_id={log_id}")
  }

  return(log_id)
}


#' Get generation history for a cluster
#'
#' Retrieves the generation attempt history for a specific cluster.
#' Useful for debugging and analyzing prompt improvements.
#'
#' @param cluster_type Character, "functional" or "phenotype"
#' @param cluster_number Integer, cluster number
#' @param limit Integer, maximum number of records to return (default: 50)
#'
#' @return Tibble with generation log entries, ordered by created_at DESC
#'
#' @export
get_generation_history <- function(cluster_type, cluster_number, limit = 50) {
  db_execute_query(
    "SELECT * FROM llm_generation_log
     WHERE cluster_type = ? AND cluster_number = ?
     ORDER BY created_at DESC
     LIMIT ?",
    list(cluster_type, cluster_number, as.integer(limit))
  )
}


#' Get generation statistics
#'
#' Retrieves aggregate statistics about generation attempts.
#' Useful for monitoring LLM usage and error rates.
#'
#' @return Tibble with status counts and average latency/tokens
#'
#' @export
get_generation_stats <- function() {
  db_execute_query(
    "SELECT
       status,
       COUNT(*) as count,
       AVG(latency_ms) as avg_latency_ms,
       AVG(tokens_input) as avg_tokens_input,
       AVG(tokens_output) as avg_tokens_output,
       SUM(tokens_input) as total_tokens_input,
       SUM(tokens_output) as total_tokens_output
     FROM llm_generation_log
     GROUP BY status"
  )
}


#' Update validation status of a cached summary
#'
#' Allows admins to manually update validation status.
#' Useful for correcting judge verdicts or manually validating summaries.
#'
#' @param cache_id Integer, the cache_id to update
#' @param validation_status Character, new status ("pending", "validated", "rejected")
#' @param validated_by Character or NULL, admin user who validated
#'
#' @return Logical, TRUE if update succeeded
#'
#' @examples
#' \dontrun{
#' # Manually validate a pending summary
#' update_validation_status(cache_id = 123, validation_status = "validated", validated_by = "admin")
#'
#' # Mark a summary as rejected
#' update_validation_status(cache_id = 456, validation_status = "rejected")
#' }
#'
#' @export
update_validation_status <- function(cache_id, validation_status, validated_by = NULL) {
  valid_statuses <- c("pending", "validated", "rejected")
  if (!validation_status %in% valid_statuses) {
    log_error("Invalid validation_status: {validation_status}")
    return(FALSE)
  }

  tryCatch(
    {
      db_execute_statement(
        "UPDATE llm_cluster_summary_cache
         SET validation_status = ?,
             validated_at = CASE WHEN ? = 'validated' THEN NOW() ELSE NULL END,
             validated_by = ?
         WHERE cache_id = ?",
        list(validation_status, validation_status, validated_by, as.integer(cache_id))
      )

      log_info("Updated cache_id={cache_id} to validation_status={validation_status}")
      return(TRUE)
    },
    error = function(e) {
      log_error("Failed to update validation status: {e$message}")
      return(FALSE)
    }
  )
}


#------------------------------------------------------------------------------
# Admin Query Functions
#------------------------------------------------------------------------------

#' Get cache statistics for admin dashboard
#'
#' Returns aggregate statistics about LLM cache entries and generation logs.
#' Used by admin dashboard to display system health and usage metrics.
#'
#' @return List with:
#'   - total_entries: Integer, total current cache entries
#'   - by_status: List with counts for pending, validated, rejected
#'   - by_type: List with counts for functional, phenotype
#'   - last_generation: POSIXct, timestamp of most recent generation
#'   - total_tokens_input: Integer, sum of input tokens (success only)
#'   - total_tokens_output: Integer, sum of output tokens (success only)
#'   - estimated_cost_usd: Numeric, estimated API cost
#'
#' @details
#' Cost calculation uses Gemini 2.0 Flash pricing:
#' - $0.075 per 1M input tokens
#' - $0.30 per 1M output tokens
#'
#' @examples
#' \dontrun{
#' stats <- get_cache_statistics()
#' print(stats$total_entries)
#' print(stats$estimated_cost_usd)
#' }
#'
#' @export
get_cache_statistics <- function() {
  log_info("Fetching cache statistics")

  # Get cache entry counts by status (current entries only)
  cache_stats <- db_execute_query(
    "SELECT
       COUNT(*) as total_entries,
       SUM(CASE WHEN validation_status = 'pending' THEN 1 ELSE 0 END) as pending,
       SUM(CASE WHEN validation_status = 'validated' THEN 1 ELSE 0 END) as validated,
       SUM(CASE WHEN validation_status = 'rejected' THEN 1 ELSE 0 END) as rejected,
       SUM(CASE WHEN cluster_type = 'functional' THEN 1 ELSE 0 END) as functional,
       SUM(CASE WHEN cluster_type = 'phenotype' THEN 1 ELSE 0 END) as phenotype,
       MAX(created_at) as last_generation
     FROM llm_cluster_summary_cache
     WHERE is_current = TRUE"
  )

  # Get token totals from generation logs (success only)
  token_stats <- db_execute_query(
    "SELECT
       COALESCE(SUM(tokens_input), 0) as total_tokens_input,
       COALESCE(SUM(tokens_output), 0) as total_tokens_output
     FROM llm_generation_log
     WHERE status = 'success'"
  )

  # Calculate estimated cost (Gemini 2.0 Flash pricing)
  # Input: $0.075 per 1M tokens, Output: $0.30 per 1M tokens
  input_cost <- (token_stats$total_tokens_input[1] %||% 0) * 0.075 / 1e6
  output_cost <- (token_stats$total_tokens_output[1] %||% 0) * 0.30 / 1e6
  estimated_cost_usd <- input_cost + output_cost

  list(
    total_entries = cache_stats$total_entries[1] %||% 0L,
    by_status = list(
      pending = cache_stats$pending[1] %||% 0L,
      validated = cache_stats$validated[1] %||% 0L,
      rejected = cache_stats$rejected[1] %||% 0L
    ),
    by_type = list(
      functional = cache_stats$functional[1] %||% 0L,
      phenotype = cache_stats$phenotype[1] %||% 0L
    ),
    last_generation = cache_stats$last_generation[1],
    total_tokens_input = token_stats$total_tokens_input[1] %||% 0L,
    total_tokens_output = token_stats$total_tokens_output[1] %||% 0L,
    estimated_cost_usd = round(estimated_cost_usd, 4)
  )
}


#' Get cached summaries with pagination and filtering
#'
#' Returns paginated cache entries for admin browser. Supports filtering
#' by cluster type and validation status.
#'
#' @param cluster_type Character or NULL, filter by "functional" or "phenotype"
#' @param validation_status Character or NULL, filter by "pending", "validated", "rejected"
#' @param page Integer, 1-indexed page number (default: 1)
#' @param per_page Integer, entries per page (default: 20)
#'
#' @return List with:
#'   - data: Tibble of cache entries
#'   - total: Integer, total matching entries
#'   - page: Integer, current page
#'   - per_page: Integer, entries per page
#'
#' @examples
#' \dontrun{
#' # Get all pending summaries
#' result <- get_cached_summaries_paginated(validation_status = "pending")
#'
#' # Get functional summaries, page 2
#' result <- get_cached_summaries_paginated(cluster_type = "functional", page = 2)
#' }
#'
#' @export
get_cached_summaries_paginated <- function(
  cluster_type = NULL,
  validation_status = NULL,
  page = 1L,
  per_page = 20L
) {
  log_info("Fetching summaries: type={cluster_type %||% 'all'}, status={validation_status %||% 'all'}, page={page}")

  # Coerce to integer
  page <- as.integer(page)
  per_page <- as.integer(per_page)

  # Build WHERE clause dynamically
  where_clauses <- "is_current = TRUE"
  params <- list()

  if (!is.null(cluster_type) && cluster_type != "") {
    where_clauses <- paste(where_clauses, "AND cluster_type = ?")
    params <- append(params, cluster_type)
  }

  if (!is.null(validation_status) && validation_status != "") {
    where_clauses <- paste(where_clauses, "AND validation_status = ?")
    params <- append(params, validation_status)
  }

  # Get total count
  count_sql <- paste("SELECT COUNT(*) as total FROM llm_cluster_summary_cache WHERE", where_clauses)
  count_result <- db_execute_query(count_sql, params)
  total <- count_result$total[1] %||% 0L

  # Get paginated data
  offset <- (page - 1L) * per_page
  data_sql <- paste(
    "SELECT cache_id, cluster_type, cluster_number, cluster_hash, model_name,
            prompt_version, summary_json, tags, is_current, validation_status,
            created_at, validated_at, validated_by
     FROM llm_cluster_summary_cache
     WHERE", where_clauses,
    "ORDER BY created_at DESC
     LIMIT ? OFFSET ?"
  )
  data_params <- append(params, list(per_page, offset))
  data_result <- db_execute_query(data_sql, data_params)

  list(
    data = data_result,
    total = total,
    page = page,
    per_page = per_page
  )
}


#' Clear LLM cache entries
#'
#' Deletes cache entries by cluster type. Uses transaction for atomicity.
#'
#' @param cluster_type Character, one of "all", "functional", "phenotype"
#'
#' @return List with:
#'   - count: Integer, number of entries deleted
#'
#' @examples
#' \dontrun{
#' # Clear all cache
#' result <- clear_llm_cache("all")
#'
#' # Clear only phenotype cache
#' result <- clear_llm_cache("phenotype")
#' }
#'
#' @export
clear_llm_cache <- function(cluster_type = "all") {
  log_info("Clearing LLM cache: type={cluster_type}")

  # Convert NULL to "all" for consistency
  cluster_type <- cluster_type %||% "all"

  result <- db_with_transaction({
    if (cluster_type == "all") {
      affected <- db_execute_statement("DELETE FROM llm_cluster_summary_cache")
    } else {
      affected <- db_execute_statement(
        "DELETE FROM llm_cluster_summary_cache WHERE cluster_type = ?",
        list(cluster_type)
      )
    }
    affected
  })

  log_info("Cleared {result} cache entries")
  list(count = result)
}


#' Get generation logs with pagination and filtering
#'
#' Returns paginated generation log entries for admin log viewer.
#' Supports filtering by cluster type, status, and date range.
#'
#' @param cluster_type Character or NULL, filter by "functional" or "phenotype"
#' @param status Character or NULL, filter by "success", "validation_failed", "api_error", "timeout"
#' @param from_date Character or NULL, filter logs >= this date (YYYY-MM-DD format)
#' @param to_date Character or NULL, filter logs <= this date (YYYY-MM-DD format)
#' @param page Integer, 1-indexed page number (default: 1)
#' @param per_page Integer, entries per page (default: 50)
#'
#' @return List with:
#'   - data: Tibble of log entries
#'   - total: Integer, total matching entries
#'   - page: Integer, current page
#'   - per_page: Integer, entries per page
#'
#' @examples
#' \dontrun{
#' # Get all error logs
#' result <- get_generation_logs_paginated(status = "api_error")
#'
#' # Get logs from last week
#' result <- get_generation_logs_paginated(
#'   from_date = "2026-01-25",
#'   to_date = "2026-02-01"
#' )
#' }
#'
#' @export
get_generation_logs_paginated <- function(
  cluster_type = NULL,
  status = NULL,
  from_date = NULL,
  to_date = NULL,
  page = 1L,
  per_page = 50L
) {
  log_info("Fetching generation logs: type={cluster_type %||% 'all'}, status={status %||% 'all'}, page={page}")

  # Coerce to integer
  page <- as.integer(page)
  per_page <- as.integer(per_page)

  # Build WHERE clause dynamically
  where_clauses <- "1=1"
  params <- list()

  if (!is.null(cluster_type) && cluster_type != "") {
    where_clauses <- paste(where_clauses, "AND cluster_type = ?")
    params <- append(params, cluster_type)
  }

  if (!is.null(status) && status != "") {
    where_clauses <- paste(where_clauses, "AND status = ?")
    params <- append(params, status)
  }

  if (!is.null(from_date) && from_date != "") {
    where_clauses <- paste(where_clauses, "AND created_at >= ?")
    params <- append(params, from_date)
  }

  if (!is.null(to_date) && to_date != "") {
    where_clauses <- paste(where_clauses, "AND created_at <= ?")
    params <- append(params, to_date)
  }

  # Get total count
  count_sql <- paste("SELECT COUNT(*) as total FROM llm_generation_log WHERE", where_clauses)
  count_result <- db_execute_query(count_sql, params)
  total <- count_result$total[1] %||% 0L

  # Get paginated data (exclude prompt_text and response_json for list view)
  offset <- (page - 1L) * per_page
  data_sql <- paste(
    "SELECT log_id, cluster_type, cluster_number, cluster_hash, model_name,
            status, tokens_input, tokens_output, latency_ms, error_message,
            validation_errors, created_at
     FROM llm_generation_log
     WHERE", where_clauses,
    "ORDER BY created_at DESC
     LIMIT ? OFFSET ?"
  )
  data_params <- append(params, list(per_page, offset))
  data_result <- db_execute_query(data_sql, data_params)

  list(
    data = data_result,
    total = total,
    page = page,
    per_page = per_page
  )
}
