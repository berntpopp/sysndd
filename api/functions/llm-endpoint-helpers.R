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

  # Freshly generated summaries must have the SAME shape as cached ones, or a
  # curator gets one schema immediately after generating and a different one on
  # the next read. Reuse the cached formatter over a synthetic single row.
  fresh <- format_summary_response(
    data.frame(
      cache_id = result$cache_id %||% NA_integer_,
      cluster_type = cluster_type,
      cluster_hash = raw_hash,
      model_name = result$summary$model_name %||% get_default_gemini_model(),
      created_at = as.character(Sys.time()),
      validation_status = result$validation_status %||% "pending",
      summary_json = I(list(result$summary)),
      stringsAsFactors = FALSE
    ),
    cluster_number
  )
  fresh$generated <- TRUE # Flag indicating this was freshly generated
  fresh
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

  # #630: the model-generated syndromicity is retired. Strip it from historical
  # rows and serve the computed measure alongside instead.
  summary_json <- llm_summary_strip_llm_syndromicity(summary_json)
  summary_json$clinical_pattern <-
    llm_summary_normalize_clinical_pattern(summary_json$clinical_pattern)

  # Resolved by cluster_hash against the CURRENT public-ready snapshot; NULL
  # when the hash is not in it (e.g. a summary cached against a superseded
  # partition). tryCatch here is scoped to the snapshot lookup only -- a missing
  # snapshot must not turn a 200 into a 500 -- and never hides a
  # classification failure, which happens inside and is fail-closed.
  # Syndromicity is a PHENOTYPE-axis measure: functional clusters group genes by
  # molecular function, where "organ involvement" is not defined. They carry
  # `syndromicity: null` rather than a misleading zero.
  computed <- if (!identical(cached$cluster_type[1], "phenotype")) NULL else tryCatch(
    svc_cluster_syndromicity(cached$cluster_hash[1]),
    error = function(e) {
      log_error("Computed syndromicity lookup failed: {e$message}")
      NULL
    }
  )

  list(
    cache_id = cached$cache_id[1],
    cluster_type = cached$cluster_type[1],
    cluster_number = as.integer(cluster_number),
    model_name = cached$model_name[1],
    created_at = as.character(cached$created_at[1]),
    validation_status = cached$validation_status[1],
    validation_scope = LLM_VALIDATION_SCOPE,
    summary_json = summary_json,
    syndromicity = computed,
    pattern_conflicts_with_computed = llm_summary_pattern_conflicts(
      summary_json$clinical_pattern, computed
    ),
    generated = FALSE # Flag indicating this came from cache
  )
}


#------------------------------------------------------------------------------
# Retired model-generated syndromicity (#630)
#------------------------------------------------------------------------------

#' The enumerated `clinical_pattern` vocabulary.
#'
#' These are exactly the five values the generator prompt already named. Before
#' #630 the field was a free-text string, and it drifted in production: the same
#' cluster was labelled both "progressive metabolic disorders" and "progressive
#' metabolic/degenerative".
LLM_CLINICAL_PATTERN_VOCABULARY <- c(
  "syndromic malformation",
  "pure neurodevelopmental",
  "progressive metabolic/degenerative",
  "overgrowth syndrome",
  "other"
)

#' Legacy free-text values observed in the cache, mapped into the vocabulary.
#'
#' Without this, every pre-#630 cached summary would degrade to "other" and lose
#' its gestalt. These are the exact drifted strings present in
#' `llm_cluster_summary_cache`; anything else still degrades to "other".
LLM_CLINICAL_PATTERN_ALIASES <- c(
  "progressive metabolic disorders" = "progressive metabolic/degenerative",
  "syndromic malformations"         = "syndromic malformation",
  "overgrowth syndromes"            = "overgrowth syndrome"
)

#' Drop the retired model-generated `syndromicity` key (#630).
#'
#' Historical cache rows still carry it. Serving it would present a
#' non-reproducible model label as a clinical finding -- the same cluster hash,
#' the same model, 39 seconds apart, produced three different values. Removing
#' it on READ is what lets this change ship without forcing regeneration of
#' every cached summary (`LLM_SUMMARY_PROMPT_VERSION` is deliberately NOT
#' bumped: `get_cached_summary()` binds the version into every lookup, so a bump
#' would 404 every existing summary, and `mcp_public_llm_cluster_summary` pins
#' the version in SQL as well).
#'
#' @export
llm_summary_strip_llm_syndromicity <- function(summary_json) {
  if (!is.list(summary_json)) {
    return(summary_json)
  }
  summary_json[["syndromicity"]] <- NULL
  summary_json
}

#' Constrain `clinical_pattern` to the enumerated vocabulary.
#'
#' @export
llm_summary_normalize_clinical_pattern <- function(value) {
  if (is.null(value) || length(value) == 0L) {
    return(NULL)
  }
  v <- as.character(value)[1]
  if (is.na(v) || !nzchar(v)) {
    return(NULL)
  }
  if (v %in% LLM_CLINICAL_PATTERN_VOCABULARY) {
    return(v)
  }
  # Membership test first: `[[` on a named character vector RAISES for a missing
  # name ("subscript out of bounds"), it does not return NULL, so indexing
  # directly would turn an unrecognised pattern into a 500.
  if (v %in% names(LLM_CLINICAL_PATTERN_ALIASES)) {
    return(unname(LLM_CLINICAL_PATTERN_ALIASES[[v]]))
  }
  log_warn("clinical_pattern outside vocabulary, degrading to 'other': {v}")
  "other"
}

#' Does the model's `clinical_pattern` contradict the computed measure?
#'
#' `clinical_pattern` retains two syndromicity-bearing values, so the LLM can
#' still assert "pure neurodevelopmental" for a cluster whose entities largely
#' DO have recorded extra-neurological involvement -- the original defect under
#' another name. Rather than hide that, the response says so.
#'
#' Compared against the FRACTION, not the categorical `cluster_call`. Observed
#' live: a cluster where 74.6% of entities have recorded involvement is called
#' `mixed` (it sits just under the 0.75 cutoff) while the model labelled it
#' "pure neurodevelopmental". Gating on `cluster_call == predominantly_syndromic`
#' would let exactly that case through unflagged.
#'
#' @export
llm_summary_pattern_conflicts <- function(clinical_pattern, syndromicity) {
  if (is.null(clinical_pattern) || is.null(syndromicity)) {
    return(FALSE)
  }
  fraction <- syndromicity$fraction_syndromic
  if (is.null(fraction) || length(fraction) == 0L || is.na(fraction[[1]])) {
    return(FALSE)
  }
  fraction <- as.numeric(fraction[[1]])

  # A majority either way is the honest boundary for "does this word
  # contradict the data", independent of where the reporting cutoffs sit.
  if (identical(clinical_pattern, "pure neurodevelopmental")) {
    return(fraction > 0.5)
  }
  if (identical(clinical_pattern, "syndromic malformation")) {
    return(fraction < 0.5)
  }
  FALSE
}

#' What `validation_status` actually covers.
#'
#' The issue's third concern: consumers read `validation_status: "validated"` as
#' covering every field. It never covered syndromicity -- no reference existed
#' to validate against -- so the scope is now stated in the response.
LLM_VALIDATION_SCOPE <- paste(
  "LLM judge verdict on the generated prose: phenotype grounding, enrichment",
  "direction, and inheritance claims. Does NOT cover syndromicity, which is",
  "computed from curated HPO annotations and served separately in the",
  "`syndromicity` field."
)
