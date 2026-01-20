# tests/testthat/setup.R
# Global test setup - runs before any test file

# Load testing libraries
library(testthat)
library(dittodb)
library(withr)
library(httr2)

# Load tidyverse for data manipulation (used in assertions)
library(dplyr)
library(tibble)
library(stringr)

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
