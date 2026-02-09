# test-unit-pubtator-parse.R
# Behavior tests for PubTator parsing functions (M-9, M-10)
#
# Tests verify actual function behavior with mocked data,
# NOT source code patterns.

library(testthat)
library(jsonlite)

# Source the file under test
source_api_file("functions/pubtator-functions.R", local = FALSE)

# Helper: create a temporary file with BioCJSON content
write_biocjson_file <- function(docs, dir = tempdir()) {
  content <- list(PubTator3 = docs)
  path <- tempfile(fileext = ".json", tmpdir = dir)
  writeLines(toJSON(content, auto_unbox = TRUE), path)
  path
}

# --- pubtator_parse_biocjson tests ---

test_that("pubtator_parse_biocjson parses single document", {
  doc <- data.frame(
    id = "12345678",
    pmid = "12345678",
    stringsAsFactors = FALSE
  )
  doc$passages <- list(data.frame(
    text = "Sample passage text",
    stringsAsFactors = FALSE
  ))

  path <- write_biocjson_file(doc)
  on.exit(unlink(path))

  result <- pubtator_parse_biocjson(paste0("file://", path))
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_true("id" %in% names(result))
  expect_equal(as.character(result$id), "12345678")
})

test_that("pubtator_parse_biocjson handles multiple documents", {
  docs <- data.frame(
    id = c("11111111", "22222222", "33333333"),
    pmid = c("11111111", "22222222", "33333333"),
    stringsAsFactors = FALSE
  )
  docs$passages <- list(
    data.frame(text = "Text 1", stringsAsFactors = FALSE),
    data.frame(text = "Text 2", stringsAsFactors = FALSE),
    data.frame(text = "Text 3", stringsAsFactors = FALSE)
  )

  path <- write_biocjson_file(docs)
  on.exit(unlink(path))

  result <- pubtator_parse_biocjson(paste0("file://", path))
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
})

test_that("pubtator_parse_biocjson returns NULL for empty PubTator3 array", {
  path <- tempfile(fileext = ".json")
  writeLines('{"PubTator3": []}', path)
  on.exit(unlink(path))

  result <- pubtator_parse_biocjson(paste0("file://", path))
  expect_null(result)
})

test_that("pubtator_parse_biocjson returns NULL for missing PubTator3 key", {
  path <- tempfile(fileext = ".json")
  writeLines('{"other_key": []}', path)
  on.exit(unlink(path))

  result <- pubtator_parse_biocjson(paste0("file://", path))
  expect_null(result)
})

test_that("pubtator_parse_biocjson returns NULL on invalid URL", {
  result <- pubtator_parse_biocjson("file:///nonexistent/path.json")
  expect_null(result)
})

test_that("pubtator_parse_biocjson copies _id to id when id is missing", {
  path <- tempfile(fileext = ".json")
  # Manually write JSON with _id instead of id
  json_content <- '{"PubTator3": [{"_id": "99999999", "pmid": "99999999", "passages": []}]}'
  writeLines(json_content, path)
  on.exit(unlink(path))

  result <- pubtator_parse_biocjson(paste0("file://", path))
  expect_s3_class(result, "data.frame")
  expect_true("id" %in% names(result))
  expect_equal(as.character(result$id), "99999999")
})

# --- Rate limit configuration tests ---

test_that("PUBTATOR_RATE_LIMIT_DELAY is under NCBI 3 req/s limit", {
  expect_equal(PUBTATOR_RATE_LIMIT_DELAY, 0.35)
  requests_per_second <- 1 / PUBTATOR_RATE_LIMIT_DELAY
  expect_lt(requests_per_second, 3.0)
})

test_that("PUBTATOR_MAX_PMIDS_PER_REQUEST batch size is 100", {
  expect_equal(PUBTATOR_MAX_PMIDS_PER_REQUEST, 100)
})

# --- pubtator_rate_limited_call behavior tests ---

test_that("pubtator_rate_limited_call returns result on success", {
  sleep_calls <- c()
  local_mocked_bindings(
    Sys.sleep = function(time) { sleep_calls <<- c(sleep_calls, time) },
    .package = "base"
  )
  result <- pubtator_rate_limited_call(function() "ok")
  expect_equal(result, "ok")
  # Should have slept once for rate limit delay
  expect_true(any(abs(sleep_calls - PUBTATOR_RATE_LIMIT_DELAY) < 0.001))
})

test_that("pubtator_rate_limited_call retries on failure", {
  sleep_calls <- c()
  call_count <- 0
  local_mocked_bindings(
    Sys.sleep = function(time) { sleep_calls <<- c(sleep_calls, time) },
    .package = "base"
  )

  # Function that fails once then succeeds
  flaky_fn <- function() {
    call_count <<- call_count + 1
    if (call_count < 2) stop("transient error")
    "recovered"
  }

  result <- pubtator_rate_limited_call(flaky_fn)
  expect_equal(result, "recovered")
  expect_equal(call_count, 2)
})

test_that("pubtator_rate_limited_call returns NULL after max retries", {
  local_mocked_bindings(
    Sys.sleep = function(time) {},
    .package = "base"
  )

  result <- pubtator_rate_limited_call(
    function() stop("permanent error"),
    max_retries = 1
  )
  expect_null(result)
})

# --- generate_query_hash tests ---

test_that("generate_query_hash produces consistent SHA-256", {
  hash1 <- generate_query_hash("BRCA1")
  hash2 <- generate_query_hash("BRCA1")
  expect_equal(hash1, hash2)
  expect_equal(nchar(hash1), 64) # SHA-256 produces 64 hex chars
})

test_that("generate_query_hash normalizes whitespace", {
  hash1 <- generate_query_hash("BRCA1  AND  cancer")
  hash2 <- generate_query_hash("BRCA1 AND cancer")
  expect_equal(hash1, hash2)
})

test_that("generate_query_hash differs for different queries", {
  hash1 <- generate_query_hash("BRCA1")
  hash2 <- generate_query_hash("BRCA2")
  expect_false(hash1 == hash2)
})
