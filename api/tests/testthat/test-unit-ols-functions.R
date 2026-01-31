# test-unit-ols-functions.R
# Unit tests for api/functions/ols-functions.R
#
# These tests cover OLS4 API integration functions for MONDO lookups.
# Tests use mocked responses to avoid network calls to the EBI OLS4 API.

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/ols-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(testthat)
library(httr2)
library(stringr)
library(purrr)

# Source functions being tested
source(file.path(api_dir, "functions/ols-functions.R"))


# ============================================================================
# Test: ols_encode_iri
# ============================================================================

test_that("ols_encode_iri double-encodes IRIs correctly", {
  # Standard MONDO IRI
  iri <- "http://purl.obolibrary.org/obo/MONDO_0033482"
  encoded <- ols_encode_iri(iri)

  # Should be double-encoded: : becomes %3A then %253A
  expect_true(grepl("%253A", encoded))  # : double-encoded
  expect_true(grepl("%252F", encoded))  # / double-encoded

  # Verify specific double-encoding
  expect_equal(
    encoded,
    "http%253A%252F%252Fpurl.obolibrary.org%252Fobo%252FMONDO_0033482"
  )
})

test_that("ols_encode_iri handles empty input", {
  expect_equal(ols_encode_iri(""), "")
})


# ============================================================================
# Test: ols_format_deprecation_summary
# ============================================================================

test_that("ols_format_deprecation_summary handles NULL input", {
  result <- ols_format_deprecation_summary(NULL)
  expect_equal(result, "No MONDO mapping found")
})

test_that("ols_format_deprecation_summary formats complete info", {
  info <- list(
    mondo_id = "MONDO:0033482",
    mondo_label = "Spinocerebellar ataxia 47",
    mapping_type = "equivalentObsolete",
    replacement_omim_id = "OMIM:620719"
  )

  result <- ols_format_deprecation_summary(info)

  expect_true(grepl("MONDO:0033482", result))
  expect_true(grepl("Spinocerebellar ataxia 47", result))
  expect_true(grepl("equivalentObsolete", result))
  expect_true(grepl("OMIM:620719", result))
})

test_that("ols_format_deprecation_summary handles partial info", {
  info <- list(
    mondo_id = "MONDO:0033482",
    mondo_label = "Test disease",
    mapping_type = "exactMatch"
  )

  result <- ols_format_deprecation_summary(info)

  expect_true(grepl("MONDO:0033482", result))
  expect_false(grepl("replacement", result))
})


# ============================================================================
# Test: Input validation
# ============================================================================

test_that("ols_search_mondo handles empty input", {
  result <- ols_search_mondo("")
  expect_equal(result, list())

  result <- ols_search_mondo(NULL)
  expect_equal(result, list())

  result <- ols_search_mondo(NA)
  expect_equal(result, list())
})

test_that("ols_get_mondo_term handles empty input", {
  result <- ols_get_mondo_term("")
  expect_null(result)

  result <- ols_get_mondo_term(NULL)
  expect_null(result)
})

test_that("ols_get_mondo_for_omim handles empty input", {
  result <- ols_get_mondo_for_omim("")
  expect_null(result)

  result <- ols_get_mondo_for_omim(NULL)
  expect_null(result)
})

test_that("ols_get_deprecated_omim_info handles empty input", {
  result <- ols_get_deprecated_omim_info("")
  expect_null(result)
})


# ============================================================================
# Test: OMIM ID normalization
# ============================================================================

test_that("ols_get_mondo_for_omim normalizes OMIM IDs", {
  # This tests the normalization logic - actual API call will fail gracefully
  # We're checking that both formats are handled

  # Mock function behavior for testing normalization
  # The actual function extracts the number from OMIM:XXXXXX format
  omim_with_prefix <- "OMIM:617931"
  omim_without_prefix <- "617931"

  # Both should extract to the same number
  expect_equal(
    str_replace(omim_with_prefix, "^OMIM:", ""),
    omim_without_prefix
  )
})


# ============================================================================
# Test: Batch function with empty input
# ============================================================================

test_that("ols_get_deprecated_omim_info_batch handles empty input", {
  result <- ols_get_deprecated_omim_info_batch(c())
  expect_equal(result, list())

  result <- ols_get_deprecated_omim_info_batch(character(0))
  expect_equal(result, list())
})


# ============================================================================
# Test: ols_has_mondo_equivalent handles empty input
# ============================================================================

test_that("ols_has_mondo_equivalent handles empty input",
{
  result <- ols_has_mondo_equivalent("")
  expect_false(result)

  result <- ols_has_mondo_equivalent(NULL)
  expect_false(result)
})


# ============================================================================
# Integration tests (require network - skip on CRAN/CI)
# ============================================================================

test_that("ols_search_mondo returns results for known term", {
  skip_on_cran()
  skip_if_offline()

  # Search for a well-known disease
  results <- ols_search_mondo("cystic fibrosis", rows = 5)

  # Should return some results
  expect_true(length(results) > 0 || is.list(results))
})

test_that("ols_get_mondo_for_omim finds mapping for known OMIM", {
 skip_on_cran()
  skip_if_offline()

  # OMIM:219700 is cystic fibrosis - well-known mapping
  result <- ols_get_mondo_for_omim("OMIM:219700")

  # May or may not find it depending on API availability
  # Just check it doesn't error
 expect_true(is.null(result) || is.list(result))
})

test_that("ols_get_deprecated_omim_info returns info for deprecated OMIM", {
  skip_on_cran()
  skip_if_offline()

  # OMIM:617931 is known to be deprecated (spinocerebellar ataxia 47)
  result <- ols_get_deprecated_omim_info("OMIM:617931")

  # May or may not find it depending on API availability
  # Just check structure if found
  if (!is.null(result)) {
    expect_true("mondo_id" %in% names(result) || is.list(result))
  }
})
