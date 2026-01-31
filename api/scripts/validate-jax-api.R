#!/usr/bin/env Rscript
#' JAX Ontology API Validation Script
#'
#' Purpose: Empirically test JAX Ontology API rate limits and data completeness
#' before implementing the full OMIM migration.
#'
#' Output:
#' - Console summary statistics
#' - CSV file: api/data/jax-api-validation-results.csv
#' - Recommendations for retry parameters, request delays, and data thresholds
#'
#' Usage: Rscript api/scripts/validate-jax-api.R
#'
#' Author: SysNDD Team
#' Date: 2026-01-24

# =============================================================================
# Setup
# =============================================================================

suppressPackageStartupMessages({
  library(httr2)
  library(readr)
  library(dplyr)
  library(purrr)
  library(tidyr)
})

# Configuration
JAX_API_BASE_URL <- "https://ontology.jax.org/api/network/annotation/OMIM:"
MIM2GENE_URL <- "https://omim.org/static/omim/data/mim2gene.txt"
SAMPLE_SIZE <- 100
OUTPUT_DIR <- file.path(dirname(dirname(getwd())), "api", "data")

# Detect script location for output directory
script_dir <- tryCatch({
  # When run via Rscript
  dirname(commandArgs(trailingOnly = FALSE)[grep("--file=", commandArgs(trailingOnly = FALSE))])
}, error = function(e) {
  getwd()
})

# Set output directory relative to script location or use api/data
if (grepl("scripts$", script_dir)) {
  OUTPUT_DIR <- file.path(dirname(script_dir), "data")
} else if (dir.exists("api/data")) {
  OUTPUT_DIR <- "api/data"
} else {
  OUTPUT_DIR <- "."
}

cat("\n")
cat("=============================================================================\n")
cat("JAX Ontology API Validation Script\n")
cat("=============================================================================\n")
cat(sprintf("Start time: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat(sprintf("Output directory: %s\n", OUTPUT_DIR))
cat("\n")

# =============================================================================
# Download and Parse mim2gene.txt
# =============================================================================

cat("Step 1: Downloading mim2gene.txt from OMIM...\n")

mim2gene_temp <- tempfile(fileext = ".txt")

tryCatch({
  download_result <- request(MIM2GENE_URL) |>
    req_timeout(60) |>
    req_retry(max_tries = 3, backoff = ~ 2^.x) |>
    req_perform(path = mim2gene_temp)

  cat(sprintf("  Downloaded: %s bytes\n", file.size(mim2gene_temp)))
}, error = function(e) {
  stop(sprintf("Failed to download mim2gene.txt: %s", e$message))
})

# Parse mim2gene.txt (tab-delimited, skip comment lines)
cat("Step 2: Parsing mim2gene.txt...\n")

mim2gene <- read_tsv(
  mim2gene_temp,
  comment = "#",
  col_names = c(
    "MIM_Number",
    "MIM_Entry_Type",
    "Entrez_Gene_ID",
    "Approved_Gene_Symbol_HGNC",
    "Ensembl_Gene_ID"
  ),
  col_types = cols(
    MIM_Number = col_character(),
    MIM_Entry_Type = col_character(),
    Entrez_Gene_ID = col_character(),
    Approved_Gene_Symbol_HGNC = col_character(),
    Ensembl_Gene_ID = col_character()
  ),
  na = c("", "NA", "-")
)

# Filter for phenotype entries
phenotype_mims <- mim2gene |>
  filter(MIM_Entry_Type == "phenotype") |>
  pull(MIM_Number)

cat(sprintf("  Total entries: %d\n", nrow(mim2gene)))
cat(sprintf("  Phenotype entries: %d\n", length(phenotype_mims)))

# Sample random phenotype MIM numbers for testing
set.seed(42) # Reproducibility
sample_mims <- sample(phenotype_mims, min(SAMPLE_SIZE, length(phenotype_mims)))
cat(sprintf("  Sampled for testing: %d\n", length(sample_mims)))
cat("\n")

# =============================================================================
# Helper Function: Fetch with Timing
# =============================================================================

fetch_with_timing <- function(mim_number, delay_ms = 0) {
  url <- paste0(JAX_API_BASE_URL, mim_number)
  start <- Sys.time()

  response <- tryCatch({
    request(url) |>
      req_timeout(30) |>
      req_error(is_error = ~ FALSE) |>
      req_perform()
  }, error = function(e) {
    NULL
  })

  elapsed_ms <- as.numeric(difftime(Sys.time(), start, units = "secs")) * 1000

  if (is.null(response)) {
    return(tibble(
      mim_number = mim_number,
      status_code = NA_integer_,
      response_time_ms = elapsed_ms,
      disease_name = NA_character_,
      success = FALSE,
      error_type = "connection_error"
    ))
  }

  status <- resp_status(response)

  if (status == 429) {
    return(tibble(
      mim_number = mim_number,
      status_code = 429L,
      response_time_ms = elapsed_ms,
      disease_name = NA_character_,
      success = FALSE,
      error_type = "rate_limited"
    ))
  }

  if (status == 404) {
    return(tibble(
      mim_number = mim_number,
      status_code = 404L,
      response_time_ms = elapsed_ms,
      disease_name = NA_character_,
      success = FALSE,
      error_type = "not_found"
    ))
  }

  if (status != 200) {
    return(tibble(
      mim_number = mim_number,
      status_code = as.integer(status),
      response_time_ms = elapsed_ms,
      disease_name = NA_character_,
      success = FALSE,
      error_type = paste0("http_", status)
    ))
  }

  # Parse JSON response
  data <- tryCatch({
    resp_body_json(response)
  }, error = function(e) {
    NULL
  })

  if (is.null(data)) {
    return(tibble(
      mim_number = mim_number,
      status_code = 200L,
      response_time_ms = elapsed_ms,
      disease_name = NA_character_,
      success = FALSE,
      error_type = "json_parse_error"
    ))
  }

  # Extract disease name using safe navigation

disease_name <- pluck(data, "disease", "name", .default = NA_character_)

  if (is.null(disease_name) || is.na(disease_name) || disease_name == "") {
    return(tibble(
      mim_number = mim_number,
      status_code = 200L,
      response_time_ms = elapsed_ms,
      disease_name = NA_character_,
      success = FALSE,
      error_type = "missing_disease_name"
    ))
  }

  tibble(
    mim_number = mim_number,
    status_code = 200L,
    response_time_ms = elapsed_ms,
    disease_name = disease_name,
    success = TRUE,
    error_type = NA_character_
  )
}

# =============================================================================
# Rate Limit Testing
# =============================================================================

cat("Step 3: Testing rate limits with different delay settings...\n")

# Test with different delays: 0ms, 25ms, 50ms, 100ms
delays_to_test <- c(0, 25, 50, 100)
batch_sizes <- c(10, 25)

rate_limit_results <- list()

for (delay in delays_to_test) {
  cat(sprintf("\n  Testing with %dms delay between requests:\n", delay))

  for (batch_size in batch_sizes) {
    test_mims <- sample_mims[1:min(batch_size, length(sample_mims))]
    cat(sprintf("    Batch size %d: ", batch_size))

    batch_results <- list()
    rate_limited_count <- 0

    for (i in seq_along(test_mims)) {
      result <- fetch_with_timing(test_mims[i], delay)
      batch_results[[i]] <- result

      if (!is.na(result$status_code) && result$status_code == 429) {
        rate_limited_count <- rate_limited_count + 1
      }

      if (delay > 0 && i < length(test_mims)) {
        Sys.sleep(delay / 1000)
      }
    }

    batch_df <- bind_rows(batch_results)
    avg_response_time <- mean(batch_df$response_time_ms, na.rm = TRUE)
    success_rate <- sum(batch_df$success) / nrow(batch_df) * 100

    cat(sprintf(
      "avg %.0fms, success %.1f%%, rate_limited %d\n",
      avg_response_time,
      success_rate,
      rate_limited_count
    ))

    rate_limit_results[[paste0("delay_", delay, "_batch_", batch_size)]] <- list(
      delay_ms = delay,
      batch_size = batch_size,
      avg_response_time_ms = avg_response_time,
      success_rate = success_rate,
      rate_limited_count = rate_limited_count,
      results = batch_df
    )
  }
}

cat("\n")

# =============================================================================
# Data Completeness Testing
# =============================================================================

cat("Step 4: Testing data completeness (full sample with optimal delay)...\n")

# Use 50ms delay as conservative approach
optimal_delay <- 50

all_results <- list()
for (i in seq_along(sample_mims)) {
  if (i %% 20 == 0 || i == 1) {
    cat(sprintf("  Progress: %d/%d (%.0f%%)\n", i, length(sample_mims), i / length(sample_mims) * 100))
  }

  result <- fetch_with_timing(sample_mims[i], optimal_delay)
  all_results[[i]] <- result

  if (i < length(sample_mims)) {
    Sys.sleep(optimal_delay / 1000)
  }
}

completeness_df <- bind_rows(all_results)

cat("\n")

# =============================================================================
# Analysis and Summary
# =============================================================================

cat("=============================================================================\n")
cat("RESULTS SUMMARY\n")
cat("=============================================================================\n\n")

# Rate Limit Analysis
cat("RATE LIMIT ANALYSIS:\n")
cat("-------------------\n")

rate_limit_summary <- map_dfr(rate_limit_results, function(x) {
  tibble(
    delay_ms = x$delay_ms,
    batch_size = x$batch_size,
    avg_response_ms = x$avg_response_time_ms,
    success_pct = x$success_rate,
    rate_limited = x$rate_limited_count
  )
})

print(rate_limit_summary)

# Determine if any rate limiting occurred
total_rate_limited <- sum(rate_limit_summary$rate_limited)
if (total_rate_limited == 0) {
  cat("\nNo rate limiting (429) responses detected in any test configuration.\n")
  cat("JAX API appears tolerant of rapid sequential requests.\n")
} else {
  cat(sprintf("\nWARNING: %d rate limit responses detected.\n", total_rate_limited))
  cat("Recommend using longer delays between requests.\n")
}

cat("\n")

# Data Completeness Analysis
cat("DATA COMPLETENESS ANALYSIS:\n")
cat("---------------------------\n")

success_count <- sum(completeness_df$success)
total_count <- nrow(completeness_df)
success_rate <- success_count / total_count * 100

cat(sprintf("Total phenotype MIM numbers in mim2gene.txt: %d\n", length(phenotype_mims)))
cat(sprintf("Number tested in validation: %d\n", total_count))
cat(sprintf("Successful retrievals: %d (%.1f%%)\n", success_count, success_rate))
cat(sprintf("Failures: %d (%.1f%%)\n", total_count - success_count, 100 - success_rate))

cat("\n")

# Failure breakdown
failure_breakdown <- completeness_df |>
  filter(!success) |>
  count(error_type, name = "count") |>
  arrange(desc(count))

if (nrow(failure_breakdown) > 0) {
  cat("Failure breakdown:\n")
  for (i in seq_len(nrow(failure_breakdown))) {
    cat(sprintf("  %s: %d\n", failure_breakdown$error_type[i], failure_breakdown$count[i]))
  }
} else {
  cat("No failures detected.\n")
}

cat("\n")

# Response time statistics
cat("RESPONSE TIME STATISTICS:\n")
cat("-------------------------\n")
response_times <- completeness_df$response_time_ms
cat(sprintf("Min: %.0f ms\n", min(response_times, na.rm = TRUE)))
cat(sprintf("Median: %.0f ms\n", median(response_times, na.rm = TRUE)))
cat(sprintf("Mean: %.0f ms\n", mean(response_times, na.rm = TRUE)))
cat(sprintf("Max: %.0f ms\n", max(response_times, na.rm = TRUE)))
cat(sprintf("95th percentile: %.0f ms\n", quantile(response_times, 0.95, na.rm = TRUE)))

cat("\n")

# =============================================================================
# Recommendations
# =============================================================================

cat("=============================================================================\n")
cat("RECOMMENDATIONS\n")
cat("=============================================================================\n\n")

# Determine optimal delay
if (total_rate_limited == 0) {
  recommended_delay <- 50
  cat(sprintf("1. OPTIMAL DELAY: %d ms between requests\n", recommended_delay))
  cat("   Rationale: No rate limiting detected, but 50ms provides safety margin\n")
  cat("   and allows ~20 requests/second which is respectful to the API.\n")
} else {
  recommended_delay <- 100
  cat(sprintf("1. OPTIMAL DELAY: %d ms between requests\n", recommended_delay))
  cat("   Rationale: Rate limiting detected, use conservative delay.\n")
}

cat("\n")

cat("2. RETRY PARAMETERS:\n")
cat("   max_tries = 5\n")
cat("   backoff = ~ 2^.x (exponential: 2, 4, 8, 16, 32 seconds)\n")
cat("   max_seconds = 120\n")
cat("   is_transient = ~ resp_status(.x) %in% c(429, 503, 504)\n")

cat("\n")

if (success_rate >= 95) {
  cat("3. DATA COMPLETENESS THRESHOLD: PASSED\n")
  cat(sprintf("   %.1f%% success rate exceeds 95%% threshold.\n", success_rate))
  cat("   Proceed with implementation.\n")
} else if (success_rate >= 90) {
  cat("3. DATA COMPLETENESS THRESHOLD: MARGINAL\n")
  cat(sprintf("   %.1f%% success rate is below 95%% threshold.\n", success_rate))
  cat("   Consider allowing partial failures with warning.\n")
} else {
  cat("3. DATA COMPLETENESS THRESHOLD: FAILED\n")
  cat(sprintf("   %.1f%% success rate is significantly below 95%% threshold.\n", success_rate))
  cat("   Investigate failures before implementation.\n")
}

cat("\n")

cat("4. VALIDATION STRICTNESS:\n")
if (success_rate >= 95) {
  cat("   Recommendation: ABORT on missing disease names\n")
  cat("   High success rate means failures indicate real problems.\n")
} else {
  cat("   Recommendation: WARN on missing disease names, allow partial failures\n")
  cat("   Some phenotype MIM numbers may not have JAX API records.\n")
}

cat("\n")

# =============================================================================
# Save Results
# =============================================================================

cat("Step 5: Saving results to CSV...\n")

# Ensure output directory exists
if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

output_file <- file.path(OUTPUT_DIR, "jax-api-validation-results.csv")

completeness_df |>
  write_csv(output_file)

cat(sprintf("  Results saved to: %s\n", output_file))

# Save summary statistics
summary_file <- file.path(OUTPUT_DIR, "jax-api-validation-summary.txt")

summary_text <- sprintf(
  "JAX API Validation Summary
==========================
Date: %s

RATE LIMITS:
- Rate limited responses: %d
- Recommended delay: %d ms

DATA COMPLETENESS:
- Total phenotype MIMs: %d
- Tested: %d
- Success rate: %.1f%%

RESPONSE TIMES:
- Median: %.0f ms
- Mean: %.0f ms
- 95th percentile: %.0f ms

RECOMMENDATIONS:
- Delay: %d ms between requests
- Retry: max_tries=5, backoff=2^x, max_seconds=120
- Validation: %s
",
  format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  total_rate_limited,
  recommended_delay,
  length(phenotype_mims),
  total_count,
  success_rate,
  median(response_times, na.rm = TRUE),
  mean(response_times, na.rm = TRUE),
  quantile(response_times, 0.95, na.rm = TRUE),
  recommended_delay,
  ifelse(success_rate >= 95, "ABORT on missing names", "WARN on missing names")
)

writeLines(summary_text, summary_file)
cat(sprintf("  Summary saved to: %s\n", summary_file))

cat("\n")
cat("=============================================================================\n")
cat(sprintf("Validation complete at %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("=============================================================================\n")
