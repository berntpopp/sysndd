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
  tags = NULL
) {
  log_info("Saving summary to cache for cluster {cluster_type}/{cluster_number}")

  # Serialize to JSON if needed
  summary_json_str <- if (is.character(summary_json)) {
    summary_json
  } else {
    jsonlite::toJSON(summary_json, auto_unbox = TRUE)
  }

  tags_json_str <- if (is.null(tags)) {
    NULL
  } else if (is.character(tags) && length(tags) == 1 && startsWith(tags, "[")) {
    tags  # Already JSON
  } else {
    jsonlite::toJSON(tags, auto_unbox = FALSE)
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

    # Insert new summary
    db_execute_statement(
      "INSERT INTO llm_cluster_summary_cache
       (cluster_type, cluster_number, cluster_hash, model_name, prompt_version,
        summary_json, tags, is_current, validation_status)
       VALUES (?, ?, ?, ?, ?, ?, ?, TRUE, 'pending')",
      list(cluster_type, cluster_number, cluster_hash, model_name, prompt_version,
           summary_json_str, tags_json_str)
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

  # Serialize response_json if needed
  response_json_str <- if (is.null(response_json)) {
    NULL
  } else if (is.character(response_json)) {
    response_json
  } else {
    jsonlite::toJSON(response_json, auto_unbox = TRUE)
  }

  db_execute_statement(
    "INSERT INTO llm_generation_log
     (cluster_type, cluster_number, cluster_hash, model_name, prompt_text,
      response_json, validation_errors, tokens_input, tokens_output,
      latency_ms, status, error_message)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    list(
      cluster_type, cluster_number, cluster_hash, model_name, prompt_text,
      response_json_str, validation_errors, tokens_input, tokens_output,
      latency_ms, status, error_message
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
