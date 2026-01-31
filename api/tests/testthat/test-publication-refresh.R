# test-publication-refresh.R
# Unit tests for publication refresh functionality
#
# These tests cover:
# - Publication stats endpoint field validation
# - PMID input validation for refresh endpoint

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/publication-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(dplyr)
library(tibble)
library(DBI)

# Load test helpers (for database connection)
if (file.exists(file.path(api_dir, "tests", "testthat", "helper-db.R"))) {
  source(file.path(api_dir, "tests", "testthat", "helper-db.R"))
}

# Source db-helpers.R for db_execute_query
original_wd <- getwd()
setwd(api_dir)
tryCatch({
  # These are required by db-helpers.R
  library(pool)
  library(logger)
  library(rlang)
  source("functions/db-helpers.R")
}, error = function(e) {
  # db-helpers.R may fail if pool is not set up, that's okay
  message("Note: db-helpers.R not loaded - ", e$message)
})
setwd(original_wd)

# ============================================================================
# Helper function to validate PMID input (extracted from endpoint logic)
# ============================================================================

validate_refresh_pmids <- function(pmids) {
  if (is.null(pmids) || length(pmids) == 0) {
    return(list(error = "No PMIDs provided", valid = FALSE))
  }

  # Check PMID format (should be PMID:XXXXXXXX or just numbers)
  invalid_pmids <- c()
  for (pmid in pmids) {
    # Accept both "PMID:12345678" and "12345678" formats
    clean_pmid <- gsub("^PMID:", "", pmid)
    if (!grepl("^[0-9]+$", clean_pmid)) {
      invalid_pmids <- c(invalid_pmids, pmid)
    }
  }

  if (length(invalid_pmids) > 0) {
    return(list(
      error = paste("Invalid PMID format:", paste(invalid_pmids, collapse = ", ")),
      valid = FALSE
    ))
  }

  return(list(error = NULL, valid = TRUE, count = length(pmids)))
}

# ============================================================================
# PMID Validation Tests
# ============================================================================

test_that("validate_refresh_pmids rejects empty array", {
  result <- validate_refresh_pmids(c())
  expect_equal(result$error, "No PMIDs provided")
  expect_false(result$valid)
})

test_that("validate_refresh_pmids rejects NULL input", {
  result <- validate_refresh_pmids(NULL)
  expect_equal(result$error, "No PMIDs provided")
  expect_false(result$valid)
})

test_that("validate_refresh_pmids accepts valid PMID array", {
  result <- validate_refresh_pmids(c("PMID:12345678"))
  expect_null(result$error)
  expect_true(result$valid)
  expect_equal(result$count, 1)
})

test_that("validate_refresh_pmids accepts multiple PMIDs", {
  result <- validate_refresh_pmids(c("PMID:12345678", "PMID:87654321"))
  expect_null(result$error)
  expect_true(result$valid)
  expect_equal(result$count, 2)
})

test_that("validate_refresh_pmids accepts numeric-only PMID format", {
  result <- validate_refresh_pmids(c("12345678", "87654321"))
  expect_null(result$error)
  expect_true(result$valid)
})

test_that("validate_refresh_pmids rejects invalid PMID format", {
  result <- validate_refresh_pmids(c("PMID:abc123"))
  expect_false(result$valid)
  expect_true(grepl("Invalid PMID format", result$error))
})

test_that("validate_refresh_pmids rejects mixed valid/invalid PMIDs", {
  result <- validate_refresh_pmids(c("PMID:12345678", "invalid"))
  expect_false(result$valid)
  expect_true(grepl("invalid", result$error))
})

# ============================================================================
# Publication Stats Tests (require database)
# ============================================================================

test_that("publications/stats returns expected fields", {
  # Skip if helper-db.R didn't set up a pool
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  # Call the stats query logic directly
  total_result <- db_execute_query(
    "SELECT COUNT(*) as total FROM publication"
  )
  oldest_result <- db_execute_query(
    "SELECT MIN(update_date) as oldest_update FROM publication"
  )
  outdated_result <- db_execute_query(
    "SELECT COUNT(*) as outdated_count FROM publication WHERE update_date < DATE_SUB(NOW(), INTERVAL 1 YEAR)"
  )

  # Verify results have expected structure

expect_true("total" %in% names(total_result))
  expect_true("oldest_update" %in% names(oldest_result))
  expect_true("outdated_count" %in% names(outdated_result))

  # Verify types
  expect_type(as.integer(total_result$total[1]), "integer")
  expect_type(as.integer(outdated_result$outdated_count[1]), "integer")
})

test_that("publications stats queries return non-negative counts", {
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  total_result <- db_execute_query(
    "SELECT COUNT(*) as total FROM publication"
  )
  outdated_result <- db_execute_query(
    "SELECT COUNT(*) as outdated_count FROM publication WHERE update_date < DATE_SUB(NOW(), INTERVAL 1 YEAR)"
  )

  expect_gte(as.integer(total_result$total[1]), 0)
  expect_gte(as.integer(outdated_result$outdated_count[1]), 0)
})

# ============================================================================
# Rate Limiting Logic Tests (design verification)
# ============================================================================

test_that("refresh uses 350ms delay for NCBI rate limiting", {
  # This is a design verification test
  # The actual Sys.sleep(0.35) is in the executor_fn in admin_endpoints.R
  # We verify the code includes proper rate limiting by checking the file

  admin_code <- readLines(file.path(api_dir, "endpoints", "admin_endpoints.R"))
  rate_limit_line <- grep("Sys\\.sleep\\(0\\.35\\)", admin_code, value = TRUE)

  expect_true(
    length(rate_limit_line) > 0,
    info = "Executor should include Sys.sleep(0.35) for rate limiting"
  )
})

test_that("refresh sources required functions in daemon", {
  # Verify that executor_fn sources required files
  admin_code <- readLines(file.path(api_dir, "endpoints", "admin_endpoints.R"))

  expect_true(
    any(grepl('source\\("functions/publication-functions\\.R"\\)', admin_code)),
    info = "Executor should source publication-functions.R"
  )
  expect_true(
    any(grepl('source\\("functions/job-progress\\.R"\\)', admin_code)),
    info = "Executor should source job-progress.R"
  )
  expect_true(
    any(grepl('source\\("functions/db-helpers\\.R"\\)', admin_code)),
    info = "Executor should source db-helpers.R"
  )
})

test_that("refresh creates database connection in daemon", {
  # Verify that executor_fn creates its own database connection
  admin_code <- readLines(file.path(api_dir, "endpoints", "admin_endpoints.R"))

  expect_true(
    any(grepl("DBI::dbConnect", admin_code)),
    info = "Executor should create database connection"
  )
  expect_true(
    any(grepl("DBI::dbDisconnect", admin_code)),
    info = "Executor should disconnect database on exit"
  )
})

test_that("refresh uses create_progress_reporter", {
  # Verify progress reporting is implemented
  admin_code <- readLines(file.path(api_dir, "endpoints", "admin_endpoints.R"))

  expect_true(
    any(grepl("create_progress_reporter", admin_code)),
    info = "Executor should use create_progress_reporter"
  )
})
