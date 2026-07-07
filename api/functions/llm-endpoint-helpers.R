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
get_cluster_summary <- function(cluster_hash, cluster_number, cluster_type, res, allow_generation = FALSE) {
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

  # Fast path (SECURITY #7): the public / cache-hit path serves ONLY validated
  # summaries. A `pending` (not-yet-judged) row must read as "being prepared",
  # never as a served summary, matching the MCP default (require_validated).
  cached <- tryCatch(
    get_cached_summary(raw_hash, require_validated = TRUE),
    error = function(e) {
      log_error("Cache lookup failed: {e$message}")
      NULL
    }
  )

  if (!is.null(cached) && nrow(cached) > 0) {
    return(format_summary_response(cached, cluster_number))
  }

  # A current REJECTED row is a TERMINAL serving state (#490): the judge
  # deterministically rejected this cluster's summary, so it will never validate
  # no matter how many times it is regenerated. Return HTTP 200 with an explicit
  # "not available + why" payload instead of a bare 404, which the frontend could
  # not distinguish from "still generating". The validated-only lookup above does
  # not return it, so fetch it explicitly by status. We do NOT auto-promote
  # rejected -> validated; MCP / public analysis stay validated-only.
  rejected <- tryCatch(
    get_cached_summary(raw_hash, require_validated = FALSE, status = "rejected"),
    error = function(e) NULL
  )
  if (!is.null(rejected) && nrow(rejected) > 0) {
    return(list(
      cluster_type = rejected$cluster_type[1],
      cluster_number = as.integer(cluster_number),
      validation_status = "rejected",
      summary_available = FALSE,
      reason = llm_summary_rejection_reason(rejected),
      generated = FALSE
    ))
  }

  # Cache miss - attempt generation
  log_info("Cache miss for {cluster_type} cluster hash: {substr(raw_hash, 1, 16)}...")

  # Public path is cache-hit-only: never run Gemini synchronously for an
  # unauthenticated request. Generation is opt-in for Curator+ callers.
  if (!isTRUE(allow_generation)) {
    log_info("Cache miss on cache-only path for {cluster_type} cluster - generation not permitted")
    res$status <- 404L
    return(list(message = "Summary not yet available for this cluster"))
  }

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
    model_name = result$summary$model_name %||% get_default_gemini_model(),
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

#' Extract the LLM-judge rejection reason from a cached summary row (#490)
#'
#' Reads the judge reasoning persisted in `summary_json`, tolerating both the
#' flat `llm_judge_reasoning` key (batch + unified on-demand path) and the older
#' nested `validation$reasoning` shape. Returns `NA_character_` when no reason is
#' present or the JSON cannot be parsed.
#'
#' @param cached Single-row cache data frame (with a `summary_json` column).
#' @return Character scalar reason, or `NA_character_`.
#' @export
llm_summary_rejection_reason <- function(cached) {
  summary_json <- tryCatch(
    if (is.character(cached$summary_json[1])) {
      jsonlite::fromJSON(cached$summary_json[1])
    } else {
      cached$summary_json[[1]]
    },
    error = function(e) NULL
  )
  if (is.null(summary_json)) {
    return(NA_character_)
  }

  reason <- summary_json$llm_judge_reasoning
  if (is.null(reason) || length(reason) == 0 || (length(reason) == 1 && is.na(reason))) {
    validation <- summary_json$validation
    reason <- if (!is.null(validation)) validation$reasoning else NULL
  }
  if (is.null(reason) || length(reason) == 0) {
    return(NA_character_)
  }
  as.character(reason[[1]])
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
