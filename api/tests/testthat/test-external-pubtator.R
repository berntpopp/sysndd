# test-external-pubtator.R
# Tests for PubTator API integration (pubtator-functions.R)
#
# These tests use httptest2 to mock external API calls where possible.
# Pure function tests work without network; integration tests
# may skip if no network and no fixtures.
#
# First run: Records live API responses to fixtures/pubtator/
# Subsequent runs: Replays recorded responses

# Load required packages (individual packages, not tidyverse meta-package)
library(dplyr)
library(tibble)
library(stringr)
library(purrr)
library(jsonlite)
library(digest)
library(logger)

# Source required files using helper-paths.R (loaded automatically by setup.R)
# Use local = FALSE to make functions available in test scope
# Note: pubtator-functions.R depends on db-helpers.R
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/pubtator-functions.R", local = FALSE)

# Skip tests if required packages not available
skip_if_not_installed("httptest2")
skip_if_not_installed("jsonlite")

# ============================================================================
# Pure Function Tests (no network required)
# ============================================================================

test_that("generate_query_hash produces consistent hash", {
  # This tests the hash function without network calls
  hash1 <- generate_query_hash("test query")
  hash2 <- generate_query_hash("test query")
  hash3 <- generate_query_hash("different query")

  expect_equal(hash1, hash2)
  expect_false(hash1 == hash3)
  expect_equal(nchar(hash1), 64)
})

test_that("generate_query_hash handles whitespace normalization", {
  # The function uses str_squish to normalize whitespace
  hash1 <- generate_query_hash("test query")
  hash2 <- generate_query_hash("  test   query  ")
  hash3 <- generate_query_hash("test\tquery")

  expect_equal(hash1, hash2)
  expect_equal(hash1, hash3)
})

test_that("generate_query_hash handles empty string", {
  hash <- generate_query_hash("")
  expect_equal(nchar(hash), 64)
})

test_that("pubtator_parse_biocjson returns NULL for invalid URL", {
  # Non-existent URL should return NULL (error handled internally)
  result <- pubtator_parse_biocjson("https://httpbin.org/status/404")
  expect_null(result)
})

test_that("pubtator_v3_data_from_pmids handles NULL input", {
  result <- pubtator_v3_data_from_pmids(NULL)
  expect_null(result)
})

test_that("pubtator_v3_data_from_pmids handles empty vector input", {
  result <- pubtator_v3_data_from_pmids(character(0))
  expect_null(result)
})

test_that("safe_as_json handles NULL", {
  result <- safe_as_json(NULL)
  expect_equal(result, "")
})

test_that("safe_as_json handles atomic values", {
  result <- safe_as_json("test")
  expect_equal(result, "test")

  result <- safe_as_json(123)
  expect_equal(result, "123")
})

test_that("safe_as_json handles lists", {
  result <- safe_as_json(list(a = 1, b = 2))
  expect_true(is.character(result))
  # Should be valid JSON
  parsed <- tryCatch(fromJSON(result), error = function(e) NULL)
  expect_true(!is.null(parsed))
})

test_that("build_pmid_annotations_table handles non-list input", {
  result <- build_pmid_annotations_table("not a list")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true("pmid" %in% names(result))
  expect_true("annotations" %in% names(result))
})

test_that("build_pmid_annotations_table handles missing required fields", {
  # Missing 'id' and 'passages'
  result <- build_pmid_annotations_table(list(other = "data"))

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

# ============================================================================
# Integration Tests (network required if no fixtures)
# ============================================================================

test_that("pubtator_v3_total_pages_from_query returns page count", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "pubtator"))

  with_pubtator_mock({
    result <- tryCatch({
      # Simple query that should return results
      pubtator_v3_total_pages_from_query("BRCA1")
    }, error = function(e) {
      skip(paste("PubTator API error:", e$message))
    })

    # Should return a number (total pages) or NULL on error
    expect_true(is.numeric(result) || is.null(result))
    if (!is.null(result)) {
      expect_gt(result, 0)
    }
  })
})

test_that("pubtator_v3_total_pages_from_query handles empty results", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "pubtator"))

  with_pubtator_mock({
    result <- tryCatch({
      # Nonsense query that should return no results
      pubtator_v3_total_pages_from_query("xyzzy12345nonexistent98765")
    }, error = function(e) {
      skip(paste("PubTator API error:", e$message))
    })

    # Should return NULL or 0 for no results
    expect_true(is.null(result) || result == 0)
  })
})

test_that("pubtator_v3_pmids_from_request returns tibble", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "pubtator"))

  with_pubtator_mock({
    result <- tryCatch({
      pubtator_v3_pmids_from_request(
        query = "BRCA1",
        start_page = 1,
        max_pages = 1
      )
    }, error = function(e) {
      skip(paste("PubTator API error:", e$message))
    })

    # Should return tibble or NULL
    if (!is.null(result)) {
      expect_s3_class(result, "tbl_df")
      expect_true("pmid" %in% names(result))
    }
  })
})
