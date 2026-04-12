# functions/llm-rate-limiter.R
#
# Throttling, quota management, and data-driven confidence scoring
# for LLM API calls. Contains rate limit configuration and the
# objective confidence calculation independent of LLM self-assessment.
#
# Split from llm-service.R as part of v11.0 Phase D (D1).

require(logger)

#------------------------------------------------------------------------------
# Rate limit configuration for Gemini API
# Based on Paid Tier 1: 60 RPM for gemini-2.0-flash
# Using conservative limit to avoid rate limiting issues
#------------------------------------------------------------------------------
GEMINI_RATE_LIMIT <- list(
  capacity = 30, # Conservative: 30 RPM (half of Paid Tier 1)
  fill_time_s = 60, # 1 minute window
  backoff_base = 2, # Exponential backoff base (seconds)
  max_retries = 3 # Maximum retry attempts
)


#' Calculate derived confidence from cluster data
#'
#' Computes a confidence score based on data strength.
#' Provides an objective measure independent of LLM self-assessment.
#' Handles both functional (enrichment/FDR) and phenotype (v.test/p.value) clusters.
#'
#' @param data Tibble with either:
#'   - term_enrichment: containing 'fdr' column (for functional clusters)
#'   - quali_inp_var: containing 'p.value' and 'v.test' columns (for phenotype clusters)
#' @param cluster_type Character, "functional" or "phenotype" (default: auto-detect)
#'
#' @return List with:
#'   - avg_fdr: Average FDR/p-value across top terms (numeric)
#'   - term_count: Number of significant terms (integer)
#'   - score: Derived confidence score ("high", "medium", or "low")
#'
#' @details
#' For functional clusters (FDR-based):
#' - high: avg_fdr < 1e-10 AND term_count > 20
#' - medium: avg_fdr < 1e-5 AND term_count > 10
#' - low: otherwise
#'
#' For phenotype clusters (v.test-based):
#' - high: many terms with |v.test| > 5 AND p.value < 1e-10
#' - medium: some terms with |v.test| > 3 AND p.value < 1e-5
#' - low: otherwise
#'
#' @examples
#' \dontrun{
#' enrichment <- tibble(term = c("GO:001", "GO:002"), fdr = c(1e-12, 1e-15))
#' conf <- calculate_derived_confidence(enrichment)
#' # conf$score = "high"
#' }
#'
#' @export
calculate_derived_confidence <- function(data, cluster_type = NULL) {
  # Handle NULL or empty data
  if (is.null(data)) {
    return(list(
      avg_fdr = NA_real_,
      term_count = 0L,
      score = "low"
    ))
  }

  # Convert list to data frame if needed
  if (is.list(data) && !is.data.frame(data)) {
    data <- tryCatch(
      dplyr::bind_rows(data),
      error = function(e) NULL
    )
  }

  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    return(list(
      avg_fdr = NA_real_,
      term_count = 0L,
      score = "low"
    ))
  }

  # Auto-detect cluster type based on column presence
  if (is.null(cluster_type)) {
    cluster_type <- if ("fdr" %in% names(data)) {
      "functional"
    } else if (all(c("p.value", "v.test") %in% names(data))) {
      "phenotype"
    } else {
      "unknown"
    }
  }

  if (cluster_type == "phenotype") {
    # Phenotype cluster: use p.value and v.test
    if (!all(c("p.value", "v.test") %in% names(data))) {
      log_warn("Phenotype data missing required columns, returning low confidence")
      return(list(
        avg_fdr = NA_real_,
        term_count = nrow(data),
        score = "low"
      ))
    }

    # Count significant terms (p.value < 0.05 AND |v.test| > 2)
    significant_terms <- data %>%
      dplyr::filter(`p.value` < 0.05 & abs(`v.test`) > 2)

    term_count <- nrow(significant_terms)

    # Use p.value as the equivalent of FDR for display
    avg_pvalue <- if (term_count > 0) {
      mean(significant_terms$`p.value`, na.rm = TRUE)
    } else {
      NA_real_
    }

    # Count strong effects
    strong_effects <- sum(abs(significant_terms$`v.test`) > 5, na.rm = TRUE)
    very_strong <- sum(abs(significant_terms$`v.test`) > 10, na.rm = TRUE)

    # Determine confidence score based on v.test magnitudes and p-values
    score <- if (!is.na(avg_pvalue) && avg_pvalue < 1e-10 && strong_effects > 10) {
      "high"
    } else if (!is.na(avg_pvalue) && avg_pvalue < 1e-5 && term_count > 5) {
      "medium"
    } else {
      "low"
    }

    log_debug(
      "Derived confidence (phenotype): avg_pvalue={signif(avg_pvalue, 3)}, ",
      "term_count={term_count}, strong_effects={strong_effects}, score={score}"
    )

    return(list(
      avg_fdr = avg_pvalue, # Use p.value for consistency with frontend
      term_count = as.integer(term_count),
      score = score
    ))
  } else {
    # Functional cluster: use FDR
    if (!"fdr" %in% names(data)) {
      log_warn("Enrichment data missing 'fdr' column, returning low confidence")
      return(list(
        avg_fdr = NA_real_,
        term_count = nrow(data),
        score = "low"
      ))
    }

    # Count significant terms (FDR < 0.05)
    significant_terms <- data %>%
      dplyr::filter(fdr < 0.05)

    term_count <- nrow(significant_terms)

    # Calculate average FDR across significant terms
    avg_fdr <- if (term_count > 0) {
      mean(significant_terms$fdr, na.rm = TRUE)
    } else {
      NA_real_
    }

    # Determine confidence score
    score <- if (!is.na(avg_fdr) && avg_fdr < 1e-10 && term_count > 20) {
      "high"
    } else if (!is.na(avg_fdr) && avg_fdr < 1e-5 && term_count > 10) {
      "medium"
    } else {
      "low"
    }

    log_debug("Derived confidence (functional): avg_fdr={signif(avg_fdr, 3)}, term_count={term_count}, score={score}")

    return(list(
      avg_fdr = avg_fdr,
      term_count = as.integer(term_count),
      score = score
    ))
  }
}
