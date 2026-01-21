#!/usr/bin/env Rscript
# scripts/coverage.R
# Generate test coverage report using covr
#
# For non-package projects, we use a simplified approach:
# 1. Trace specific source files
# 2. Run tests via testthat
# 3. Report coverage

# Load covr quietly
suppressPackageStartupMessages(library(covr))

# Change to api directory
if (basename(getwd()) != "api") {
  setwd("api")
}

# Get source files to measure
source_files <- list.files("functions", pattern = "\\.R$", full.names = TRUE)

cat("Measuring coverage for", length(source_files), "source files...\n")

# Use file_coverage with explicit source and test paths
# We filter to just test-unit-* files to avoid DB/network dependencies for now
test_files <- list.files(
  "tests/testthat",
  pattern = "^test-unit-.*\\.R$",
  full.names = TRUE
)

cat("Using", length(test_files), "unit test files\n\n")

# Calculate coverage
cov <- file_coverage(
  source_files = source_files,
  test_files = test_files,
  parent_env = globalenv()
)

# Calculate percentage
pct <- percent_coverage(cov)

# Print summary
cat("\n========================================\n")
cat("Overall coverage: ", round(pct, 1), "%\n")
cat("========================================\n\n")

# Print file-by-file coverage
cat("Coverage by file:\n")
cov_summary <- tally_coverage(cov)
if (nrow(cov_summary) > 0) {
  # Round percent column if it exists and is numeric
  if ("percent" %in% names(cov_summary) && is.numeric(cov_summary$percent)) {
    cov_summary$percent <- round(cov_summary$percent, 1)
  }
  print(cov_summary, row.names = FALSE)
}

# Warning if below threshold
if (pct < 70) {
  cat("\nWARNING: Coverage ", round(pct, 1), "% below 70% threshold\n")
}

# Generate HTML report
cat("\nGenerating HTML report...\n")
dir.create("../coverage", showWarnings = FALSE)
report(cov, file = "../coverage/coverage-report.html", browse = FALSE)
cat("HTML report: coverage/coverage-report.html\n")
