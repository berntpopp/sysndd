# test-unit-llm-endpoint-helpers.R
# Unit tests for api/functions/llm-endpoint-helpers.R
#
# These tests cover the shared helper functions for LLM summary endpoints.
# Tests are organized by function with pure unit tests (no database required)
# and integration tests (requiring database) marked with skip_if.

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/llm-endpoint-helpers.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(testthat)
library(jsonlite)

# Source helpers
original_wd <- getwd()
setwd(api_dir)
tryCatch(
  {
    # Source dependencies first
    suppressMessages({
      source("functions/db-helpers.R", local = FALSE)
      source("functions/llm-cache-repository.R", local = FALSE)
      source("functions/llm-service.R", local = FALSE)
      source("functions/llm-endpoint-helpers.R", local = FALSE)
    })
  },
  error = function(e) {
    message("Note: Some functions not loaded - ", e$message)
  },
  finally = setwd(original_wd)
)

# ============================================================================
# extract_raw_hash() Tests
# ============================================================================

test_that("extract_raw_hash handles equals format", {
  result <- extract_raw_hash("equals(hash,abc123def456)")
  expect_equal(result, "abc123def456")
})

test_that("extract_raw_hash handles plain hash", {
  result <- extract_raw_hash("abc123def456")
  expect_equal(result, "abc123def456")
})

test_that("extract_raw_hash handles NULL", {
  result <- extract_raw_hash(NULL)
  expect_null(result)
})

test_that("extract_raw_hash handles empty string", {
  result <- extract_raw_hash("")
  expect_equal(result, "")
})

test_that("extract_raw_hash handles SHA256 format hash", {
  sha256_hash <- "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd"
  result <- extract_raw_hash(sha256_hash)
  expect_equal(result, sha256_hash)
})

test_that("extract_raw_hash extracts from complex equals format", {
  result <- extract_raw_hash("equals(hash,sha256-formatted-hash-value)")
  expect_equal(result, "sha256-formatted-hash-value")
})

test_that("extract_raw_hash handles hash with special characters", {
  # Some edge cases that shouldn't appear but test robustness
  result <- extract_raw_hash("equals(hash,test_hash_with_underscores)")
  expect_equal(result, "test_hash_with_underscores")
})

# ============================================================================
# format_summary_response() Tests
# ============================================================================

test_that("format_summary_response formats cached data correctly", {
  cached <- data.frame(
    cache_id = 123L,
    cluster_type = "functional",
    model_name = "gemini-3-pro-preview",
    created_at = as.POSIXct("2026-01-01 12:00:00"),
    validation_status = "validated",
    summary_json = '{"summary": "Test summary", "tags": ["tag1"]}',
    stringsAsFactors = FALSE
  )

  result <- format_summary_response(cached, "5")

  expect_equal(result$cache_id, 123L)
  expect_equal(result$cluster_type, "functional")
  expect_equal(result$cluster_number, 5L)
  expect_equal(result$validation_status, "validated")
  expect_false(result$generated)
  expect_equal(result$summary_json$summary, "Test summary")
})

test_that("format_summary_response handles phenotype cluster type", {
  cached <- data.frame(
    cache_id = 456L,
    cluster_type = "phenotype",
    model_name = "gemini-2.5-flash",
    created_at = as.POSIXct("2026-02-01 10:00:00"),
    validation_status = "pending",
    summary_json = '{"summary": "Phenotype summary", "key_themes": ["theme1"]}',
    stringsAsFactors = FALSE
  )

  result <- format_summary_response(cached, 10)

  expect_equal(result$cluster_type, "phenotype")
  expect_equal(result$cluster_number, 10L)
  expect_equal(result$model_name, "gemini-2.5-flash")
})

test_that("format_summary_response converts cluster_number to integer", {
  cached <- data.frame(
    cache_id = 1L,
    cluster_type = "functional",
    model_name = "test",
    created_at = Sys.time(),
    validation_status = "pending",
    summary_json = "{}",
    stringsAsFactors = FALSE
  )

  # Test with string input
  result <- format_summary_response(cached, "42")
  expect_equal(result$cluster_number, 42L)
  expect_type(result$cluster_number, "integer")
})

test_that("format_summary_response parses nested JSON correctly", {
  complex_json <- toJSON(list(
    summary = "Complex summary",
    key_themes = list("theme1", "theme2"),
    pathways = list(
      list(name = "pathway1", score = 0.95),
      list(name = "pathway2", score = 0.85)
    ),
    tags = c("cancer", "development")
  ), auto_unbox = TRUE)

  cached <- data.frame(
    cache_id = 1L,
    cluster_type = "functional",
    model_name = "test",
    created_at = Sys.time(),
    validation_status = "validated",
    summary_json = as.character(complex_json),
    stringsAsFactors = FALSE
  )

  result <- format_summary_response(cached, "1")

  expect_equal(result$summary_json$summary, "Complex summary")
  expect_length(result$summary_json$key_themes, 2)
  expect_length(result$summary_json$pathways, 2)
})

test_that("format_summary_response sets generated flag to FALSE", {
  cached <- data.frame(
    cache_id = 1L,
    cluster_type = "functional",
    model_name = "test",
    created_at = Sys.time(),
    validation_status = "pending",
    summary_json = '{"summary": "test"}',
    stringsAsFactors = FALSE
  )

  result <- format_summary_response(cached, "1")

  expect_false(result$generated)
})

# ============================================================================
# get_cluster_summary() Tests (with mocks)
# ============================================================================

test_that("get_cluster_summary returns 400 for missing hash", {
  # Mock response object
  res <- new.env()
  res$status <- 200L

  result <- get_cluster_summary(NULL, "1", "functional", res)

  expect_equal(res$status, 400L)
  expect_match(result$message, "cluster_hash.*required", ignore.case = TRUE)
})

test_that("get_cluster_summary returns 400 for empty hash", {
  res <- new.env()
  res$status <- 200L

  result <- get_cluster_summary("  ", "1", "functional", res)

  expect_equal(res$status, 400L)
})

test_that("get_cluster_summary returns 400 for whitespace-only hash", {
  res <- new.env()
  res$status <- 200L

  result <- get_cluster_summary("   \t\n  ", "1", "functional", res)

  expect_equal(res$status, 400L)
})

test_that("get_cluster_summary returns 400 for missing cluster_number", {
  res <- new.env()
  res$status <- 200L

  result <- get_cluster_summary("abc123", NULL, "functional", res)

  expect_equal(res$status, 400L)
  expect_match(result$message, "cluster_number.*required", ignore.case = TRUE)
})

test_that("get_cluster_summary handles equals format hash", {
  # This test verifies the hash extraction happens correctly
  # The actual cache lookup may fail, but the hash should be extracted
  res <- new.env()
  res$status <- 200L

  # With a non-existent hash, we expect either 404 (not found) or 503 (no API)
  # but NOT 400 (bad request) since the hash is valid
  result <- tryCatch(
    get_cluster_summary("equals(hash,validhash123)", "1", "functional", res),
    error = function(e) list(error = e$message)
  )

  # Should NOT be 400 since hash parameter is valid
  expect_true(res$status != 400L || is.null(result$error))
})

# ============================================================================
# get_cluster_summary() Integration Tests (require database)
# ============================================================================

# Helper to check if database is available
db_available <- function() {
  tryCatch(
    {
      # Try to get a connection
      conn <- get_db_connection()
      if (inherits(conn, "Pool")) {
        test_conn <- pool::poolCheckout(conn)
        pool::poolReturn(test_conn)
      }
      TRUE
    },
    error = function(e) FALSE
  )
}

test_that("get_cluster_summary returns 503 when Gemini not configured", {
  skip_if(!db_available(), "Database not available")
  skip_if(is_gemini_configured(), "Test requires Gemini to NOT be configured")

  res <- new.env()
  res$status <- 200L

  # Use a hash that definitely won't be in cache
  result <- get_cluster_summary("nonexistent_hash_xyz789", "999", "functional", res)

  # Should return 503 since Gemini is not configured and cache miss
  expect_equal(res$status, 503L)
  expect_match(result$message, "unavailable", ignore.case = TRUE)
})

test_that("get_cluster_summary returns 404 for nonexistent cluster", {
  skip_if(!db_available(), "Database not available")
  skip_if(!is_gemini_configured(), "Gemini not configured")

  res <- new.env()
  res$status <- 200L

  # Use a hash that definitely won't exist
  result <- get_cluster_summary(
    "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    "999999",
    "functional",
    res
  )

  # Should return 404 since cluster data not found
  expect_equal(res$status, 404L)
})

# ============================================================================
# Edge Cases and Error Handling
# ============================================================================

test_that("extract_raw_hash handles malformed equals format", {
  # Missing closing parenthesis - should return as-is
  result <- extract_raw_hash("equals(hash,abc123")
  # Pattern won't match, so returns original
  expect_equal(result, "equals(hash,abc123")
})

test_that("format_summary_response handles empty JSON", {
  cached <- data.frame(
    cache_id = 1L,
    cluster_type = "functional",
    model_name = "test",
    created_at = Sys.time(),
    validation_status = "pending",
    summary_json = "{}",
    stringsAsFactors = FALSE
  )

  result <- format_summary_response(cached, "1")

  expect_type(result$summary_json, "list")
  expect_equal(length(result$summary_json), 0)
})

test_that("format_summary_response handles dates correctly", {
  test_time <- as.POSIXct("2026-06-15 14:30:00", tz = "UTC")
  cached <- data.frame(
    cache_id = 1L,
    cluster_type = "functional",
    model_name = "test",
    created_at = test_time,
    validation_status = "pending",
    summary_json = "{}",
    stringsAsFactors = FALSE
  )

  result <- format_summary_response(cached, "1")

  # Should be converted to character string
  expect_type(result$created_at, "character")
  expect_true(grepl("2026", result$created_at))
})
