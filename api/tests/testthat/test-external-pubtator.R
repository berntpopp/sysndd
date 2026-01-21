# test-external-pubtator.R
# Tests for PubTator API integration (pubtator-functions.R)
#
# These tests use httptest2 to mock external API calls where possible.
# Pure function tests work without network; integration tests
# may skip if no network and no fixtures.
#
# First run: Records live API responses to fixtures/pubtator/
# Subsequent runs: Replays recorded responses

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/pubtator-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages (individual packages, not tidyverse meta-package)
library(dplyr)
library(tibble)
library(stringr)
library(purrr)
library(jsonlite)
library(digest)
library(logger)

# Source required files
source(file.path(api_dir, "functions/pubtator-functions.R"))

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

test_that("pubtator_v3_parse_nonstandard_json handles NULL input", {
  # This tests the JSON parser without network calls
  result <- pubtator_v3_parse_nonstandard_json(NULL)
  expect_null(result)
})

test_that("pubtator_v3_parse_nonstandard_json handles empty input", {
  result <- pubtator_v3_parse_nonstandard_json(character(0))
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

test_that("fix_doc_id adds id from _id when missing", {
  # Test the document ID fixing function
  doc_with_underscore_id <- list(`_id` = "12345", passages = list())
  result <- fix_doc_id(doc_with_underscore_id)

  expect_equal(result$id, "12345")
  expect_equal(result$`_id`, "12345")
})

test_that("fix_doc_id preserves existing id", {
  doc_with_id <- list(id = "existing_id", `_id` = "12345", passages = list())
  result <- fix_doc_id(doc_with_id)

  expect_equal(result$id, "existing_id")
})

test_that("fix_doc_id handles NULL input", {
  result <- fix_doc_id(NULL)
  expect_true(is.list(result))
  expect_length(result, 0)
})

test_that("reassemble_pubtator_docs handles NULL input", {
  result <- reassemble_pubtator_docs(NULL)
  expect_true(is.list(result))
  expect_length(result, 0)
})

test_that("reassemble_pubtator_docs handles empty list", {
  result <- reassemble_pubtator_docs(list())
  expect_true(is.list(result))
  expect_length(result, 0)
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
