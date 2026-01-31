# tests/testthat/setup.R
# Global test setup - runs before any test file

# Load testing libraries
library(testthat)
library(dittodb)
library(withr)
library(httr2)
library(jose)  # For JWT token testing

# Load tidyverse for data manipulation (used in assertions)
library(dplyr)
library(tibble)
library(stringr)

# Resolve dplyr/AnnotationDbi select() conflict
# AnnotationDbi (via biomaRt) masks dplyr::select, causing test failures
# See: https://conflicted.r-lib.org/ and https://tidyverse.tidyverse.org/reference/tidyverse_conflicts.html
if (requireNamespace("conflicted", quietly = TRUE)) {
  conflicted::conflicts_prefer(dplyr::select)
  conflicted::conflicts_prefer(dplyr::filter)
} else {
  # Fallback: ensure dplyr methods are accessible
  # This helps when source()'d files use bare select()
  select <- dplyr::select
  filter <- dplyr::filter
}

# Source helper files (will be created in subsequent plans)
# These use test_path() for portable path resolution
helper_files <- list.files(
  test_path(),
  pattern = "^helper-.*\\.R$",
  full.names = TRUE
)
for (helper in helper_files) {
  source(helper, local = TRUE)
}

# Configure testthat options
withr::local_options(
  list(
    testthat.progress.max_fails = 50,  # Don't stop early
    testthat.progress.show_status = TRUE
  ),
  .local_envir = teardown_env()
)

# Log test initialization
message("SysNDD API test environment initialized")
