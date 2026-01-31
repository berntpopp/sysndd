# test-unit-logging-functions.R
# Unit tests for api/functions/logging-functions.R
#
# These tests cover pure functions in logging-functions.R that don't require
# database access. Tests use temporary directories for file operations.
#
# Functions tested:
# - convert_empty(): String to placeholder conversion
# - read_log_files(): Log file reading with validation
#
# NOT tested (requires database):
# - log_message_to_db(): Database logging

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/logging-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(dplyr)
library(purrr)
library(readr)
library(fs)
library(withr)

# Source functions being tested
source(file.path(api_dir, "functions/logging-functions.R"))

# ============================================================================
# convert_empty() Tests
# ============================================================================

test_that("convert_empty returns dash for empty string", {
  result <- convert_empty("")
  expect_equal(result, "-")
})

test_that("convert_empty returns original string for non-empty input", {
  result <- convert_empty("example")
  expect_equal(result, "example")
})

test_that("convert_empty preserves spaces in non-empty strings", {
  result <- convert_empty("hello world")
  expect_equal(result, "hello world")
})

test_that("convert_empty handles single character strings", {
  expect_equal(convert_empty("a"), "a")
  expect_equal(convert_empty(" "), " ")  # Single space is NOT empty
})

test_that("convert_empty handles special characters", {
  expect_equal(convert_empty("-"), "-")
  expect_equal(convert_empty("/api/test"), "/api/test")
  expect_equal(convert_empty("user@example.com"), "user@example.com")
})

test_that("convert_empty handles numeric-like strings", {
  expect_equal(convert_empty("0"), "0")
  expect_equal(convert_empty("123"), "123")
  expect_equal(convert_empty("3.14"), "3.14")
})

# ============================================================================
# read_log_files() Input Validation Tests
# ============================================================================

test_that("read_log_files throws error for non-existent folder", {
  expect_error(
    read_log_files("/nonexistent/path/to/logs"),
    "The specified folder does not exist"
  )
})

test_that("read_log_files throws error for empty column names", {
  withr::with_tempdir({
    # Create a valid log file
    writeLines("127.0.0.1;user_agent;localhost", "plumber_test.log")

    expect_error(
      read_log_files(getwd(), col_names = ""),
      "Column names must be a non-empty, comma-separated string"
    )
  })
})

test_that("read_log_files throws error for duplicate column names", {
  withr::with_tempdir({
    # Create a valid log file
    writeLines("127.0.0.1;user_agent;localhost", "plumber_test.log")

    expect_error(
      read_log_files(getwd(), col_names = "col1,col2,col1"),
      "Duplicate column names are not allowed"
    )
  })
})

test_that("read_log_files throws error when no files match pattern", {
  withr::with_tempdir({
    # Create files that don't match the default pattern
    writeLines("test", "other_file.txt")

    expect_error(
      read_log_files(getwd(), regexp = "plumber_*"),
      "No files found matching the specified pattern"
    )
  })
})

test_that("read_log_files throws error for column names with empty segments", {
  withr::with_tempdir({
    writeLines("127.0.0.1;user_agent;localhost", "plumber_test.log")

    expect_error(
      read_log_files(getwd(), col_names = "col1,,col3"),
      "Column names must be a non-empty, comma-separated string"
    )
  })
})

# ============================================================================
# read_log_files() Successful Execution Tests
# ============================================================================

test_that("read_log_files reads single log file correctly", {
  withr::with_tempdir({
    # Create a mock log file with 3 columns
    log_content <- "127.0.0.1;Mozilla/5.0;localhost"
    writeLines(log_content, "plumber_test.log")

    result <- read_log_files(
      getwd(),
      regexp = "plumber_",
      col_names = "ip,agent,host"
    )

    # Check result is a tibble
    expect_s3_class(result, "tbl_df")

    # Check columns exist
    expect_true("ip" %in% names(result))
    expect_true("agent" %in% names(result))
    expect_true("host" %in% names(result))
    expect_true("filename" %in% names(result))
    expect_true("last_modified" %in% names(result))
    expect_true("row_id" %in% names(result))

    # Check values
    expect_equal(result$ip[1], "127.0.0.1")
    expect_equal(result$agent[1], "Mozilla/5.0")
    expect_equal(result$host[1], "localhost")
    expect_equal(result$filename[1], "plumber_test.log")
  })
})

test_that("read_log_files combines multiple log files", {
  withr::with_tempdir({
    # Create two mock log files
    writeLines("192.168.1.1;Chrome;host1", "plumber_1.log")
    Sys.sleep(0.1)  # Small delay to ensure different timestamps
    writeLines("192.168.1.2;Firefox;host2", "plumber_2.log")

    result <- read_log_files(
      getwd(),
      regexp = "plumber_",
      col_names = "ip,agent,host"
    )

    # Should have 2 rows
    expect_equal(nrow(result), 2)

    # Both files should be represented
    expect_true("plumber_1.log" %in% result$filename)
    expect_true("plumber_2.log" %in% result$filename)
  })
})

test_that("read_log_files sorts by modification time descending", {
  withr::with_tempdir({
    # Create older file first
    writeLines("old_data;old_agent;old_host", "plumber_old.log")
    Sys.sleep(0.5)  # Ensure different modification times

    # Create newer file second
    writeLines("new_data;new_agent;new_host", "plumber_new.log")

    result <- read_log_files(
      getwd(),
      regexp = "plumber_",
      col_names = "data,agent,host"
    )

    # Newest file should be first (sorted by last_modified descending)
    expect_equal(result$filename[1], "plumber_new.log")
    expect_equal(result$data[1], "new_data")
  })
})

test_that("read_log_files assigns row_id as first column", {
  withr::with_tempdir({
    writeLines("data1;agent1;host1", "plumber_1.log")
    writeLines("data2;agent2;host2", "plumber_2.log")

    result <- read_log_files(
      getwd(),
      regexp = "plumber_",
      col_names = "data,agent,host"
    )

    # row_id should be the first column
    expect_equal(names(result)[1], "row_id")

    # row_id should be sequential starting from 1
    expect_equal(result$row_id, 1:nrow(result))
  })
})

test_that("read_log_files respects custom delimiter", {
  withr::with_tempdir({
    # Create log file with comma delimiter
    writeLines("127.0.0.1,Mozilla/5.0,localhost", "plumber_test.log")

    result <- read_log_files(
      getwd(),
      regexp = "plumber_",
      delim = ",",
      col_names = "ip,agent,host"
    )

    expect_equal(result$ip[1], "127.0.0.1")
    expect_equal(result$agent[1], "Mozilla/5.0")
  })
})

test_that("read_log_files handles multiline log files", {
  withr::with_tempdir({
    # Create log file with multiple entries
    log_content <- c(
      "192.168.1.1;Chrome;host1",
      "192.168.1.2;Firefox;host2",
      "192.168.1.3;Safari;host3"
    )
    writeLines(log_content, "plumber_multi.log")

    result <- read_log_files(
      getwd(),
      regexp = "plumber_",
      col_names = "ip,agent,host"
    )

    # Should have 3 rows
    expect_equal(nrow(result), 3)

    # All rows should have same filename
    expect_true(all(result$filename == "plumber_multi.log"))

    # Check all IPs are present
    expect_true("192.168.1.1" %in% result$ip)
    expect_true("192.168.1.2" %in% result$ip)
    expect_true("192.168.1.3" %in% result$ip)
  })
})

test_that("read_log_files handles custom regexp pattern", {
  withr::with_tempdir({
    # Create files with different naming patterns
    writeLines("data1;agent1;host1", "api_access.log")
    writeLines("data2;agent2;host2", "api_error.log")
    writeLines("data3;agent3;host3", "system.log")

    # Only match api_* logs
    result <- read_log_files(
      getwd(),
      regexp = "api_",
      col_names = "data,agent,host"
    )

    # Should only have 2 rows (api_access.log and api_error.log)
    expect_equal(nrow(result), 2)
    expect_false("system.log" %in% result$filename)
  })
})

test_that("read_log_files warns on column count mismatch but continues", {
  withr::with_tempdir({
    # Create a file with correct column count
    writeLines("data1;agent1;host1", "plumber_good.log")

    # Create a file with wrong column count
    writeLines("data2;agent2", "plumber_bad.log")

    # Should warn but still process the good file
    expect_warning(
      result <- read_log_files(
        getwd(),
        regexp = "plumber_",
        col_names = "data,agent,host"
      ),
      "Column count mismatch"
    )

    # Should have 1 row from the good file
    expect_equal(nrow(result), 1)
    expect_equal(result$filename[1], "plumber_good.log")
  })
})
