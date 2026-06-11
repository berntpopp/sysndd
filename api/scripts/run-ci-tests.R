#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) >= 1) args[[1]] else "full"

source("scripts/test-selection.R")
source("scripts/ci-test-summary.R")

selected_files <- list_ci_test_files(mode)

if (!length(selected_files)) {
  stop("No test files selected for mode: ", mode, call. = FALSE)
}

cat(
  "Running", length(selected_files), "test files in", mode, "mode\n",
  sep = " "
)

# Run with stop_on_failure = FALSE so we can append a classified skip summary
# (issue #360) *after* the per-test reporter output. We re-create the
# fail-on-failure contract ourselves below, so verification strength is
# unchanged: any failure or error still exits non-zero and fails CI.
results <- testthat::test_dir(
  "tests/testthat",
  filter = build_test_file_filter(selected_files),
  stop_on_failure = FALSE
)

# Presentation-only: separate expected local-profile skips from anything that
# warrants a look. Does not change the pass/fail decision below.
print_ci_test_summary(results, mode = mode)

# Re-assert the testthat fail-on-failure contract that stop_on_failure = TRUE
# would normally provide. `as.data.frame()` on testthat_results yields one row
# per test with logical `failed`/`error` counts.
results_df <- as.data.frame(results)
n_failed <- sum(results_df$failed)
n_errors <- sum(results_df$error)

if (n_failed > 0 || n_errors > 0) {
  stop(
    sprintf(
      "Test failures detected: %d failed, %d errored. See output above.",
      n_failed, n_errors
    ),
    call. = FALSE
  )
}
