# api/functions/llm-endpoint-helpers.R
#
# Shared helper functions for LLM summary endpoints.
# Follows DRY principle - both functional and phenotype endpoints use these.
#
# This module extracts common endpoint logic to avoid duplication between
# functional_cluster_summary and phenotype_cluster_summary endpoints.
#
# Key functions:
#   - get_cluster_summary(): Main entry point for summary retrieval/generation
#   - extract_raw_hash(): Normalize hash format from request parameters
#   - format_summary_response(): Transform cache data to API response
#
# Dependencies:
#   - llm-cache-repository.R: get_cached_summary()
#   - llm-service.R: get_or_generate_summary(), fetch_cluster_data_for_generation()
#   - db-helpers.R: Database connection utilities

library(logger)
library(jsonlite)

#' Get Cluster Summary (Cache or Generate)
#'
#' Retrieves a cached LLM summary or generates a new one if not found.
#' This is the main entry point for summary endpoint logic.
#'
#' @param cluster_hash Cluster hash (may be in "equals(hash,...)" format)
#' @param cluster_number Cluster number as string
#' @param cluster_type Either "functional" or "phenotype"
#' @param res Plumber response object for setting status codes
#'
#' @return List with summary data or error message
#'
#' @export
get_cluster_summary <- function(cluster_hash, cluster_number, cluster_type, res) {
  # Extract raw hash from equals(hash,...) format if present
  raw_hash <- extract_raw_hash(cluster_hash)

  # Parameter validation
  if (is.null(raw_hash) || nchar(trimws(raw_hash)) == 0) {
    res$status <- 400L
    return(list(message = "cluster_hash parameter is required"))
  }

  if (is.null(cluster_number)) {
    res$status <- 400L
    return(list(message = "cluster_number parameter is required"))
  }

  # Fast path: check cache first
  cached <- tryCatch(
    get_cached_summary(raw_hash, require_validated = FALSE),
    error = function(e) {
      log_error("Cache lookup failed: {e$message}")
      NULL
    }
  )

  if (!is.null(cached) && nrow(cached) > 0) {
    # Filter rejected summaries (per CONTEXT.md - hide rejected from users)
    if (cached$validation_status[1] == "rejected") {
      res$status <- 404L
      return(list(message = "Summary not found for this cluster"))
    }
    return(format_summary_response(cached, cluster_number))
  }

  # Cache miss - attempt generation
  log_info("Cache miss for {cluster_type} cluster hash: {substr(raw_hash, 1, 16)}...")

  # Check if generation is possible
  if (!is_gemini_configured()) {
    log_warn("Gemini API not configured - cannot generate summary")
    res$status <- 503L
    return(list(
      message = "Summary generation temporarily unavailable",
      retry_after = 3600L
    ))
  }

  # Fetch cluster data for generation
  cluster_data <- tryCatch(
    fetch_cluster_data_for_generation(raw_hash, cluster_type),
    error = function(e) {
      log_error("Failed to fetch cluster data: {e$message}")
      NULL
    }
  )

  if (is.null(cluster_data)) {
    res$status <- 404L
    return(list(message = "Cluster data not found for hash"))
  }

  # Generate summary
  result <- tryCatch(
    get_or_generate_summary(
      cluster_data = cluster_data,
      cluster_type = cluster_type
    ),
    error = function(e) {
      log_error("Summary generation failed: {e$message}")
      list(success = FALSE, error = e$message)
    }
  )

  if (!result$success) {
    res$status <- 500L
    return(list(
      message = "Failed to generate summary",
      error = result$error %||% "Unknown error"
    ))
  }

  # Return generated summary
  list(
    cache_id = result$cache_id,
    cluster_type = cluster_type,
    cluster_number = as.integer(cluster_number),
    model_name = result$summary$model_name %||% "gemini-3-pro-preview",
    created_at = as.character(Sys.time()),
    validation_status = result$validation_status %||% "pending",
    summary_json = result$summary,
    generated = TRUE # Flag indicating this was freshly generated
  )
}

#' Extract Raw Hash from Filter Format
#'
#' Converts "equals(hash,abc123)" format to raw "abc123" hash.
#' Also handles plain hash strings by returning them unchanged.
#'
#' @param cluster_hash Hash string, possibly in filter format
#'
#' @return Raw hash string, or NULL if input is NULL
#'
#' @export
extract_raw_hash <- function(cluster_hash) {
  if (is.null(cluster_hash)) {
    return(NULL)
  }

  if (grepl("^equals\\(hash,", cluster_hash)) {
    sub("^equals\\(hash,(.*)\\)$", "\\1", cluster_hash)
  } else {
    cluster_hash
  }
}

#' Format Summary Response
#'
#' Converts cached summary row to API response format.
#' Parses JSON if stored as string and structures response consistently.
#'
#' @param cached Single-row data frame from cache
#' @param cluster_number Cluster number (as string or integer)
#'
#' @return Formatted list for JSON response
#'
#' @export
format_summary_response <- function(cached, cluster_number) {
  # Parse JSON if it's a string (MySQL JSON column behavior)
  summary_json <- if (is.character(cached$summary_json[1])) {
    jsonlite::fromJSON(cached$summary_json[1])
  } else {
    cached$summary_json[[1]]
  }

  list(
    cache_id = cached$cache_id[1],
    cluster_type = cached$cluster_type[1],
    cluster_number = as.integer(cluster_number),
    model_name = cached$model_name[1],
    created_at = as.character(cached$created_at[1]),
    validation_status = cached$validation_status[1],
    summary_json = summary_json,
    generated = FALSE # Flag indicating this came from cache
  )
}
