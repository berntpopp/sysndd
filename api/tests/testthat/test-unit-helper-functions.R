# tests/testthat/test-unit-helper-functions.R
# Unit tests for api/functions/helper-functions.R
#
# These tests cover pure functions that don't require database access.
# Run with: Rscript -e "testthat::test_file('tests/testthat/test-unit-helper-functions.R')"

# Load required libraries
library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(tidyr)

# Source the functions being tested
# Use here::here() approach - find api/ directory and go from there
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/helper-functions.R")) {
  normalizePath("../..")
} else {
  stop("Cannot find api directory")
}
source(file.path(api_dir, "functions", "helper-functions.R"))

# =============================================================================
# is_valid_email() tests
# =============================================================================

test_that("is_valid_email returns TRUE for valid email addresses", {
  expect_true(is_valid_email("test@example.com"))
  expect_true(is_valid_email("user.name@domain.org"))
  expect_true(is_valid_email("user+tag@example.co.uk"))
  expect_true(is_valid_email("USER@CAPS.COM"))
  expect_true(is_valid_email("john.doe123@university.edu"))
})

test_that("is_valid_email returns FALSE for invalid email addresses", {
  expect_false(is_valid_email("not-an-email"))
  expect_false(is_valid_email("missing@"))
  expect_false(is_valid_email("@nodomain.com"))
  expect_false(is_valid_email(""))
  expect_false(is_valid_email("no-at-sign.com"))
})

test_that("is_valid_email handles edge cases", {
  # Single character domain parts should fail (needs 2+ chars in TLD)
  expect_false(is_valid_email("test@example.c"))

  # Numbers in email are valid
  expect_true(is_valid_email("user123@domain456.com"))

  # Dots in local part are valid
  expect_true(is_valid_email("first.last@example.com"))

  # Underscores are valid
  expect_true(is_valid_email("user_name@example.com"))
})
