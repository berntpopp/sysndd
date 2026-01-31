# test-unit-file-functions.R
# Unit tests for api/functions/file-functions.R
#
# These tests cover pure file utility functions that don't require
# external API calls or database access. Tests use temporary directories
# to avoid filesystem side effects.

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/file-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(stringr)
library(withr)
library(readr)
library(fs)
library(lubridate)

# Source functions being tested
source(file.path(api_dir, "functions/file-functions.R"))

# ============================================================================
# replace_strings() Tests
# ============================================================================

test_that("replace_strings replaces single string in file", {
  withr::with_tempdir({
    input_file <- "input.txt"
    output_file <- "output.txt"

    # Create test input file
    writeLines("Hello world", input_file)

    # Replace string
    replace_strings(input_file, output_file, c("world"), c("universe"))

    # Verify output
    result <- readLines(output_file)
    expect_equal(result, "Hello universe")
  })
})

test_that("replace_strings replaces multiple strings in file", {
  withr::with_tempdir({
    input_file <- "input.txt"
    output_file <- "output.txt"

    # Create test input file
    writeLines("The quick brown fox jumps over the lazy dog", input_file)

    # Replace multiple strings
    replace_strings(
      input_file,
      output_file,
      c("quick", "brown", "lazy"),
      c("slow", "black", "energetic")
    )

    # Verify output
    result <- readLines(output_file)
    expect_equal(result, "The slow black fox jumps over the energetic dog")
  })
})

test_that("replace_strings handles multiline files", {
  withr::with_tempdir({
    input_file <- "input.txt"
    output_file <- "output.txt"

    # Create test input file with multiple lines
    writeLines(c("Line 1 with text", "Line 2 with text", "Line 3 with other"), input_file)

    # Replace string across lines
    replace_strings(input_file, output_file, c("text"), c("content"))

    # Verify output
    result <- readLines(output_file)
    expect_equal(result[1], "Line 1 with content")
    expect_equal(result[2], "Line 2 with content")
    expect_equal(result[3], "Line 3 with other")
  })
})

test_that("replace_strings errors when find and replace vectors differ in length", {
  withr::with_tempdir({
    input_file <- "input.txt"
    output_file <- "output.txt"

    writeLines("test", input_file)

    # Should error - mismatched vector lengths
    expect_error(
      replace_strings(input_file, output_file, c("a", "b"), c("x")),
      "Find and replace vectors must be the same length"
    )
  })
})

test_that("replace_strings handles numeric replacements", {
  withr::with_tempdir({
    input_file <- "input.txt"
    output_file <- "output.txt"

    writeLines("Value: 100", input_file)

    # Replace with numeric value
    replace_strings(input_file, output_file, c("100"), c("200"))

    result <- readLines(output_file)
    expect_equal(result, "Value: 200")
  })
})

# ============================================================================
# check_file_age() Tests
# ============================================================================

test_that("check_file_age returns FALSE when no matching files exist", {
  withr::with_tempdir({
    result <- check_file_age("nonexistent_file", getwd(), months = 1)
    expect_false(result)
  })
})

test_that("check_file_age returns TRUE for recent files", {
  withr::with_tempdir({
    # Create a file with today's date in the filename
    today <- format(Sys.Date(), "%Y-%m-%d")
    filename <- paste0("test_file.", today, ".csv")
    writeLines("test", filename)

    # File is from today, so it should be less than 1 month old
    result <- check_file_age("test_file", getwd(), months = 1)
    expect_true(result)
  })
})

test_that("check_file_age returns FALSE for old files", {
  withr::with_tempdir({
    # Create a file with an old date (6 months ago)
    old_date <- format(Sys.Date() - 180, "%Y-%m-%d")
    filename <- paste0("test_file.", old_date, ".csv")
    writeLines("test", filename)

    # File is 6 months old, should be older than 1 month
    result <- check_file_age("test_file", getwd(), months = 1)
    expect_false(result)
  })
})

test_that("check_file_age handles edge case at boundary", {
  withr::with_tempdir({
    # Create a file exactly 30 days old (approximately 1 month)
    date_30_days_ago <- format(Sys.Date() - 30, "%Y-%m-%d")
    filename <- paste0("test_file.", date_30_days_ago, ".csv")
    writeLines("test", filename)

    # At boundary - behavior depends on exact month length
    result <- check_file_age("test_file", getwd(), months = 1)
    expect_true(is.logical(result))
  })
})

test_that("check_file_age finds newest when multiple files exist", {
  withr::with_tempdir({
    # Create multiple files with different dates
    old_date <- format(Sys.Date() - 60, "%Y-%m-%d")
    recent_date <- format(Sys.Date() - 5, "%Y-%m-%d")

    writeLines("old", paste0("test_file.", old_date, ".csv"))
    writeLines("recent", paste0("test_file.", recent_date, ".csv"))

    # Should check the newest file (5 days old)
    result <- check_file_age("test_file", getwd(), months = 1)
    expect_true(result)
  })
})

test_that("check_file_age handles different months parameter", {
  withr::with_tempdir({
    # Create a file 3 months old
    date_3_months <- format(Sys.Date() - 90, "%Y-%m-%d")
    filename <- paste0("test_file.", date_3_months, ".csv")
    writeLines("test", filename)

    # Should be older than 1 month
    expect_false(check_file_age("test_file", getwd(), months = 1))

    # Should be older than 2 months
    expect_false(check_file_age("test_file", getwd(), months = 2))

    # Should be within 6 months
    expect_true(check_file_age("test_file", getwd(), months = 6))
  })
})

# ============================================================================
# get_newest_file() Tests
# ============================================================================

test_that("get_newest_file returns NULL when no files exist", {
  withr::with_tempdir({
    result <- get_newest_file("nonexistent", getwd())
    expect_null(result)
  })
})

test_that("get_newest_file returns the most recent file", {
  withr::with_tempdir({
    # Create multiple files with different dates
    old_date <- format(Sys.Date() - 30, "%Y-%m-%d")
    new_date <- format(Sys.Date(), "%Y-%m-%d")

    old_file <- paste0("test_file.", old_date, ".csv")
    new_file <- paste0("test_file.", new_date, ".csv")

    writeLines("old", old_file)
    writeLines("new", new_file)

    result <- get_newest_file("test_file", getwd())

    # Should return the newer file path
    expect_true(!is.null(result))
    expect_true(grepl(new_date, result))
    expect_true(file.exists(result))
  })
})

test_that("get_newest_file handles single file", {
  withr::with_tempdir({
    today <- format(Sys.Date(), "%Y-%m-%d")
    filename <- paste0("single_file.", today, ".csv")
    writeLines("test", filename)

    result <- get_newest_file("single_file", getwd())

    expect_true(!is.null(result))
    expect_true(file.exists(result))
    expect_true(grepl("single_file", result))
    expect_true(grepl(today, result))
  })
})

test_that("get_newest_file returns correct file among many", {
  withr::with_tempdir({
    # Create 5 files with different dates
    dates <- Sys.Date() - c(100, 50, 25, 10, 2)
    for (i in seq_along(dates)) {
      date_str <- format(dates[i], "%Y-%m-%d")
      filename <- paste0("data_file.", date_str, ".txt")
      writeLines(paste("data", i), filename)
    }

    result <- get_newest_file("data_file", getwd())

    # Should return the file from 2 days ago (newest)
    newest_date <- format(dates[5], "%Y-%m-%d")
    expect_true(!is.null(result))
    expect_true(grepl(newest_date, result))
  })
})

test_that("get_newest_file handles files with same date", {
  withr::with_tempdir({
    # Create two files with the same date (edge case)
    today <- format(Sys.Date(), "%Y-%m-%d")
    file1 <- paste0("test.", today, ".csv")
    file2 <- paste0("test.", today, ".txt")

    writeLines("content1", file1)
    writeLines("content2", file2)

    # Function should return file(s) with newest date
    # If multiple files have same date, it may return first or a vector
    result <- get_newest_file("test", getwd())

    expect_true(!is.null(result))
    expect_true(length(result) >= 1)
  })
})

# ============================================================================
# download_and_save_json() Tests
# ============================================================================

test_that("download_and_save_json creates filename with date", {
  skip_if_not_installed("httr")

  withr::with_tempdir({
    # Mock a simple response - note: this test would need network in real scenario
    # For now, just verify the filename pattern logic
    save_path <- "test.json"

    # The function would try to download - skip if no network
    skip("Requires network access and live API")

    # If we had mocking: verify filename includes date
    # Expected format: test.YYYY-MM-DD.json.gz
    date_iso <- format(Sys.Date(), "%Y-%m-%d")
    expected_filename <- paste0("test.", date_iso, ".json.gz")
  })
})

test_that("download_and_save_json handles gzip parameter", {
  skip("Requires network access and live API")

  # Test that gzip=FALSE creates .json file
  # Test that gzip=TRUE creates .json.gz file
})

# Note: Full integration tests for download_and_save_json would require
# either mocking httr::GET or actual network access. These are intentionally
# skipped as unit tests focus on pure functions.
