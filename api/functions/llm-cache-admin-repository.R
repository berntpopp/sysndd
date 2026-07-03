# functions/llm-cache-admin-repository.R
#
# Admin dashboard read queries for the LLM cluster-summary cache + generation
# log: cache statistics, paginated summaries, cache clearing, and paginated
# generation logs. Extracted from functions/llm-cache-repository.R to keep that
# core cache file under the code-quality file-size ratchet. These are read-only
# admin-surface helpers consumed by endpoints/llm_admin_endpoints.R; they are
# NOT needed by the async worker. Sourced right after llm-cache-repository.R in
# bootstrap/load_modules.R.

require(logger)
require(DBI)


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
#' The cost estimate is keyed off the active Gemini model
#' (get_default_gemini_model()) using approximate per-1M-token rates from the
#' central catalog (llm_model_pricing()), not a hardcoded rate.
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
       SUM(CASE WHEN cluster_type = 'functional'
                AND validation_status = 'validated' THEN 1 ELSE 0 END) as functional_validated,
       SUM(CASE WHEN cluster_type = 'functional'
                AND validation_status = 'pending' THEN 1 ELSE 0 END) as functional_pending,
       SUM(CASE WHEN cluster_type = 'functional'
                AND validation_status = 'rejected' THEN 1 ELSE 0 END) as functional_rejected,
       SUM(CASE WHEN cluster_type = 'phenotype' THEN 1 ELSE 0 END) as phenotype,
       SUM(CASE WHEN cluster_type = 'phenotype'
                AND validation_status = 'validated' THEN 1 ELSE 0 END) as phenotype_validated,
       SUM(CASE WHEN cluster_type = 'phenotype'
                AND validation_status = 'pending' THEN 1 ELSE 0 END) as phenotype_pending,
       SUM(CASE WHEN cluster_type = 'phenotype'
                AND validation_status = 'rejected' THEN 1 ELSE 0 END) as phenotype_rejected,
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

  # Estimate cost via the active model's catalog pricing (not a hardcoded rate).
  pricing <- llm_model_pricing(get_default_gemini_model())
  input_cost <- (token_stats$total_tokens_input[1] %||% 0) * pricing$input_per_million / 1e6
  output_cost <- (token_stats$total_tokens_output[1] %||% 0) * pricing$output_per_million / 1e6
  estimated_cost_usd <- input_cost + output_cost

  list(
    total_entries = cache_stats$total_entries[1] %||% 0L,
    by_status = list(
      pending = cache_stats$pending[1] %||% 0L,
      validated = cache_stats$validated[1] %||% 0L,
      rejected = cache_stats$rejected[1] %||% 0L
    ),
    # Nested per-type breakdown ({count, validated, pending, rejected}) to match
    # the frontend contract (app/src/types/llm.ts CacheTypeStats); the previous
    # scalar shape made the per-type cache cards always render 0.
    by_type = list(
      functional = list(
        count = cache_stats$functional[1] %||% 0L,
        validated = cache_stats$functional_validated[1] %||% 0L,
        pending = cache_stats$functional_pending[1] %||% 0L,
        rejected = cache_stats$functional_rejected[1] %||% 0L
      ),
      phenotype = list(
        count = cache_stats$phenotype[1] %||% 0L,
        validated = cache_stats$phenotype_validated[1] %||% 0L,
        pending = cache_stats$phenotype_pending[1] %||% 0L,
        rejected = cache_stats$phenotype_rejected[1] %||% 0L
      )
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

  result <- db_with_transaction(function(txn_conn) {
    if (cluster_type == "all") {
      affected <- db_execute_statement("DELETE FROM llm_cluster_summary_cache", conn = txn_conn)
    } else {
      affected <- db_execute_statement(
        "DELETE FROM llm_cluster_summary_cache WHERE cluster_type = ?",
        list(cluster_type),
        conn = txn_conn
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
