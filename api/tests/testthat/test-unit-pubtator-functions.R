# test-unit-pubtator-functions.R
# Unit tests for PubTator function fixes (Phase 82)
#
# Tests verify:
# - LEFT JOIN filtering returns only unannotated PMIDs
# - INSERT IGNORE used for annotation cache writes
# - Rate limit delay is 0.35s (350ms)

library(testthat)
library(dplyr)
library(tidyverse)

# Source the file under test
source_api_file("functions/pubtator-functions.R", local = FALSE)

# Test 1: Rate limit constant value
test_that("PUBTATOR_RATE_LIMIT_DELAY is 0.35 seconds", {
  expect_equal(PUBTATOR_RATE_LIMIT_DELAY, 0.35)
})

# Test 2: Rate limit constant is under NCBI limit
test_that("Rate limit delay yields under 3 requests per second", {
  requests_per_second <- 1 / PUBTATOR_RATE_LIMIT_DELAY
  expect_lt(requests_per_second, 3.0)
})

# Test 3: Verify LEFT JOIN query appears in sync function source
test_that("pubtator_db_update contains LEFT JOIN for unannotated PMIDs", {
  src <- readLines(file.path(get_api_dir(), "functions", "pubtator-functions.R"))
  src_text <- paste(src, collapse = "\n")
  # Check LEFT JOIN pattern exists
  expect_true(grepl("LEFT JOIN pubtator_annotation_cache", src_text, fixed = TRUE))
  # Check IS NULL filter exists
  expect_true(grepl("annotation_id IS NULL", src_text, fixed = TRUE))
})

# Test 4: Verify INSERT IGNORE in annotation cache inserts
test_that("Annotation cache inserts use INSERT IGNORE", {
  src <- readLines(file.path(get_api_dir(), "functions", "pubtator-functions.R"))
  src_text <- paste(src, collapse = "\n")
  # No plain INSERT INTO pubtator_annotation_cache should exist
  plain_inserts <- grepl("INSERT INTO pubtator_annotation_cache", src_text, fixed = TRUE)
  ignore_inserts <- grepl("INSERT IGNORE INTO pubtator_annotation_cache", src_text, fixed = TRUE)
  expect_false(plain_inserts && !ignore_inserts)
  expect_true(ignore_inserts)
})

# Test 5: Verify no INSERT IGNORE on search_cache (only annotation_cache)
test_that("Search cache inserts do NOT use INSERT IGNORE", {
  src <- readLines(file.path(get_api_dir(), "functions", "pubtator-functions.R"))
  src_text <- paste(src, collapse = "\n")
  expect_false(grepl("INSERT IGNORE INTO pubtator_search_cache", src_text, fixed = TRUE))
})

# Test 6: PMID query SQL includes LEFT JOIN and IS NULL filter
test_that("PMID query SQL includes LEFT JOIN and IS NULL filter", {
  # Extract the SQL from the source code between the PMID query markers
  src <- readLines(file.path(get_api_dir(), "functions", "pubtator-functions.R"))

  # Find lines containing the PMID query for annotation fetch
  # Look for the distinctive LEFT JOIN pattern
  left_join_lines <- grep("LEFT JOIN pubtator_annotation_cache a ON s\\.pmid = a\\.pmid", src)
  expect_gte(length(left_join_lines), 2,
    label = "LEFT JOIN should appear in both sync and async functions"
  )

  # For each LEFT JOIN occurrence, verify IS NULL follows within 3 lines
  for (line_num in left_join_lines) {
    context_lines <- src[line_num:min(line_num + 3, length(src))]
    context_text <- paste(context_lines, collapse = " ")
    expect_true(
      grepl("annotation_id IS NULL", context_text),
      label = paste("IS NULL filter should follow LEFT JOIN near line", line_num)
    )
  }
})

# Test 7: Count of INSERT IGNORE occurrences
test_that("INSERT IGNORE appears exactly twice (sync + async)", {
  src <- readLines(file.path(get_api_dir(), "functions", "pubtator-functions.R"))
  ignore_lines <- grep("INSERT IGNORE INTO pubtator_annotation_cache", src)
  expect_equal(length(ignore_lines), 2)
})

# Test 8: pubtator_rate_limited_call uses PUBTATOR_RATE_LIMIT_DELAY
test_that("pubtator_rate_limited_call sleeps for PUBTATOR_RATE_LIMIT_DELAY", {
  sleep_calls <- c()
  local_mocked_bindings(
    Sys.sleep = function(time) { sleep_calls <<- c(sleep_calls, time) },
    .package = "base"
  )
  # Call with a simple function that succeeds immediately
  result <- pubtator_rate_limited_call(function() "ok")
  expect_equal(result, "ok")
  # Should have slept once for the rate limit delay
  expect_true(any(abs(sleep_calls - 0.35) < 0.001))
})

# Test 9: pubtator_db_update sync transaction uses function(txn_conn)
test_that("pubtator_db_update sync transaction uses function-based pattern", {
  src <- readLines(file.path(get_api_dir(), "functions", "pubtator-functions.R"))

  # Find the sync db_with_transaction call (not the async one)
  txn_lines <- grep("db_with_transaction\\(function\\(txn_conn\\)", src)
  expect_gte(length(txn_lines), 1,
    label = "At least one db_with_transaction(function(txn_conn)) in sync path"
  )
})

# Test 10: All db_execute_* calls inside sync transaction pass conn = txn_conn
test_that("pubtator sync transaction passes conn = txn_conn to all DB calls", {
  src <- readLines(file.path(get_api_dir(), "functions", "pubtator-functions.R"))
  src_text <- paste(src, collapse = "\n")

  # Extract the sync function body (pubtator_db_update, not async)
  # Find function start and end
  func_start <- grep("^pubtator_db_update <- function", src)
  expect_equal(length(func_start), 1)

  # Find the transaction block
  txn_start <- grep("db_with_transaction\\(function\\(txn_conn\\)", src)
  # Use the first one (sync function)
  sync_txn_start <- txn_start[txn_start > func_start][1]
  expect_false(is.na(sync_txn_start))

  # Count db_execute_query and db_execute_statement calls within the transaction block
  # Transaction extends to the matching closing }, pool_obj = pool)
  # Look for all db_execute_* calls between txn_start and end of function
  async_start <- grep("^pubtator_db_update_async <- function", src)
  sync_end <- if (length(async_start) > 0) async_start[1] - 1 else length(src)

  sync_body <- src[sync_txn_start:sync_end]
  db_calls <- grep("db_execute_(query|statement)\\(", sync_body, value = TRUE)
  conn_calls <- grep("conn = txn_conn", sync_body, value = TRUE)

  # Every db_execute_* call should have a corresponding conn = txn_conn
  expect_equal(length(db_calls), length(conn_calls),
    label = paste("DB calls:", length(db_calls), "conn= args:", length(conn_calls))
  )
})
