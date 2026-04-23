#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) >= 1) args[[1]] else "full"

source("scripts/test-selection.R")

selected_files <- list_ci_test_files(mode)

if (!length(selected_files)) {
  stop("No test files selected for mode: ", mode, call. = FALSE)
}

cat(
  "Running", length(selected_files), "test files in", mode, "mode\n",
  sep = " "
)

testthat::test_dir(
  "tests/testthat",
  filter = build_test_file_filter(selected_files)
)
