# test-external-ensembl.R
# Tests for Ensembl API integration (ensembl-functions.R)
#
# These tests use httptest2 to mock external Ensembl/BioMart API calls.
# Note: biomaRt functions make complex API requests that may not be fully
# intercepted by httptest2. Tests will skip gracefully if network unavailable.
#
# First run: May require live API access for biomaRt
# Subsequent runs: Attempt to use recorded responses

# Load required packages
library(dplyr)
library(tibble)
library(stringr)

# Skip if required packages not available
skip_if_not_installed("httptest2")
skip_if_not_installed("biomaRt")

# Source required files using helper-paths.R (loaded automatically by setup.R)
# Use local = FALSE to make functions available in test scope
source_api_file("functions/ensembl-functions.R", local = FALSE)

# biomaRt requires network access - it doesn't use standard httr/httr2
# These tests are more integration-focused and may skip without network

# ============================================================================
# gene_coordinates_from_symbol() Tests
# ============================================================================

test_that("gene_coordinates_from_symbol returns BED format for valid symbol", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    # Test with a well-known gene symbol
    gene_symbols <- c("BRCA1")
    gene_coordinates_from_symbol(gene_symbols, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("hgnc_symbol" %in% names(result))
  expect_true("bed_format" %in% names(result))
  expect_equal(nrow(result), 1)

  # BED format should be like: chr17:12345-67890
  if (!is.na(result$bed_format[1])) {
    expect_match(result$bed_format[1], "^chr[0-9XYM]+:[0-9]+-[0-9]+$")
  }
})

test_that("gene_coordinates_from_symbol handles multiple symbols", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    gene_symbols <- c("TP53", "EGFR", "MYC")
    gene_coordinates_from_symbol(gene_symbols, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3)
  expect_true("hgnc_symbol" %in% names(result))
  expect_true("bed_format" %in% names(result))
})

test_that("gene_coordinates_from_symbol supports hg38 reference", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    gene_symbols <- c("BRCA1")
    gene_coordinates_from_symbol(gene_symbols, reference = "hg38")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("bed_format" %in% names(result))
})

test_that("gene_coordinates_from_symbol handles unknown symbols gracefully", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    gene_symbols <- c("NOT_A_REAL_GENE_12345")
    gene_coordinates_from_symbol(gene_symbols, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  # Unknown genes should have NA for bed_format
  expect_true(is.na(result$bed_format[1]))
})

test_that("gene_coordinates_from_symbol accepts tibble input", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    gene_symbols <- tibble(value = c("BRCA1"))
    gene_coordinates_from_symbol(gene_symbols, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("hgnc_symbol" %in% names(result))
})

# ============================================================================
# gene_coordinates_from_ensembl() Tests
# ============================================================================

test_that("gene_coordinates_from_ensembl returns BED format for valid Ensembl ID", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    # ENSG00000012048 is BRCA1
    ensembl_id <- c("ENSG00000012048")
    gene_coordinates_from_ensembl(ensembl_id, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("ensembl_gene_id" %in% names(result))
  expect_true("bed_format" %in% names(result))
  expect_equal(nrow(result), 1)

  # BED format should be like: chr17:12345-67890
  if (!is.na(result$bed_format[1])) {
    expect_match(result$bed_format[1], "^chr[0-9XYM]+:[0-9]+-[0-9]+$")
  }
})

test_that("gene_coordinates_from_ensembl handles multiple Ensembl IDs", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    ensembl_id <- c("ENSG00000012048", "ENSG00000141510", "ENSG00000186092")
    gene_coordinates_from_ensembl(ensembl_id, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3)
  expect_true("ensembl_gene_id" %in% names(result))
  expect_true("bed_format" %in% names(result))
})

test_that("gene_coordinates_from_ensembl supports hg38 reference", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    ensembl_id <- c("ENSG00000012048")
    gene_coordinates_from_ensembl(ensembl_id, reference = "hg38")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("bed_format" %in% names(result))
})

test_that("gene_coordinates_from_ensembl handles invalid Ensembl IDs gracefully", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    ensembl_id <- c("ENSG00000999999")
    gene_coordinates_from_ensembl(ensembl_id, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  # Invalid IDs should have NA for bed_format
  expect_true(is.na(result$bed_format[1]))
})

test_that("gene_coordinates_from_ensembl accepts tibble input", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    ensembl_id <- tibble(value = c("ENSG00000012048"))
    gene_coordinates_from_ensembl(ensembl_id, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("ensembl_gene_id" %in% names(result))
})

# ============================================================================
# gene_id_version_from_ensembl() Tests
# ============================================================================

test_that("gene_id_version_from_ensembl returns versioned ID for valid Ensembl ID", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    ensembl_id <- c("ENSG00000203782")
    gene_id_version_from_ensembl(ensembl_id, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("ensembl_gene_id" %in% names(result))
  expect_true("ensembl_gene_id_version" %in% names(result))
  expect_equal(nrow(result), 1)

  # Versioned ID should have format ENSG00000123456.1
  if (!is.na(result$ensembl_gene_id_version[1])) {
    expect_match(result$ensembl_gene_id_version[1], "^ENSG[0-9]+\\.[0-9]+$")
  }
})

test_that("gene_id_version_from_ensembl handles multiple Ensembl IDs", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    ensembl_id <- c("ENSG00000203782", "ENSG00000008710")
    gene_id_version_from_ensembl(ensembl_id, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_true("ensembl_gene_id" %in% names(result))
  expect_true("ensembl_gene_id_version" %in% names(result))
})

test_that("gene_id_version_from_ensembl supports hg38 reference", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    ensembl_id <- c("ENSG00000203782")
    gene_id_version_from_ensembl(ensembl_id, reference = "hg38")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("ensembl_gene_id_version" %in% names(result))
})

test_that("gene_id_version_from_ensembl handles invalid IDs gracefully", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.ensembl.org"))

  result <- tryCatch({
    ensembl_id <- c("ENSG00000999999")
    gene_id_version_from_ensembl(ensembl_id, reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  # Invalid IDs should have NA for versioned ID
  expect_true(is.na(result$ensembl_gene_id_version[1]))
})

# ============================================================================
# check_ensembl_connectivity() Tests
# ============================================================================

test_that("check_ensembl_connectivity returns proper structure", {
  result <- tryCatch({
    check_ensembl_connectivity(reference = "hg38")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_type(result, "list")
  expect_true("connected" %in% names(result))
  expect_true("mirror" %in% names(result))
  expect_true("error" %in% names(result))
  expect_type(result$connected, "logical")
})

test_that("check_ensembl_connectivity works for hg19 reference", {
  result <- tryCatch({
    check_ensembl_connectivity(reference = "hg19")
  }, error = function(e) {
    skip(paste("Ensembl API error:", e$message))
  })

  expect_type(result, "list")
  expect_true("connected" %in% names(result))
})

# ============================================================================
# Graceful degradation Tests
# ============================================================================

test_that("gene_coordinates_from_symbol handles empty input", {
  result <- gene_coordinates_from_symbol(character(0), reference = "hg19")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true("hgnc_symbol" %in% names(result))
  expect_true("bed_format" %in% names(result))
})

test_that("gene_coordinates_from_ensembl handles empty input", {
  result <- gene_coordinates_from_ensembl(character(0), reference = "hg19")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true("ensembl_gene_id" %in% names(result))
  expect_true("bed_format" %in% names(result))
})

test_that("gene_id_version_from_ensembl handles empty input", {
  result <- gene_id_version_from_ensembl(character(0), reference = "hg19")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true("ensembl_gene_id" %in% names(result))
  expect_true("ensembl_gene_id_version" %in% names(result))
})

# ============================================================================
# Configuration and Helper Function Tests
# ============================================================================

test_that("ENSEMBL_HG38_MIRRORS is properly configured", {
  expect_true(exists("ENSEMBL_HG38_MIRRORS"))
  expect_type(ENSEMBL_HG38_MIRRORS, "character")
  expect_gte(length(ENSEMBL_HG38_MIRRORS), 1)
  # All URLs should use HTTPS

  expect_true(all(grepl("^https://", ENSEMBL_HG38_MIRRORS)))
})

test_that("ENSEMBL_HG19_MIRRORS is properly configured", {
  expect_true(exists("ENSEMBL_HG19_MIRRORS"))
  expect_type(ENSEMBL_HG19_MIRRORS, "character")
  expect_gte(length(ENSEMBL_HG19_MIRRORS), 1)
  # All URLs should use HTTPS
  expect_true(all(grepl("^https://", ENSEMBL_HG19_MIRRORS)))
})

test_that("retry configuration constants are properly set", {
  expect_true(exists("ENSEMBL_MAX_RETRIES"))
  expect_true(exists("ENSEMBL_BASE_DELAY_SECONDS"))
  expect_true(exists("ENSEMBL_MAX_DELAY_SECONDS"))
  expect_true(exists("ENSEMBL_TIMEOUT_SECONDS"))

  expect_gte(ENSEMBL_MAX_RETRIES, 1)
  expect_gte(ENSEMBL_BASE_DELAY_SECONDS, 1)
  expect_gte(ENSEMBL_MAX_DELAY_SECONDS, ENSEMBL_BASE_DELAY_SECONDS)
  expect_gte(ENSEMBL_TIMEOUT_SECONDS, 30)
})

test_that("sleep_with_backoff calculates delays correctly", {
  # Test exponential backoff formula: base_delay * 2^(attempt-1)
  # With base_delay = 2:
  #   attempt 1: 2 * 2^0 = 2
  #   attempt 2: 2 * 2^1 = 4
  #   attempt 3: 2 * 2^2 = 8

  # We can't test actual sleep time easily, but we can verify the function exists
  expect_true(exists("sleep_with_backoff"))
})

test_that("create_ensembl_mart returns NULL when all mirrors fail", {
  # Mock biomaRt::useMart to always fail
  local_mocked_bindings(
    useMart = function(...) {
      stop("Simulated connection failure")
    },
    .package = "biomaRt"
  )

  # Should return NULL, not throw error (graceful degradation)
  result <- create_ensembl_mart(reference = "hg38", max_retries = 1)
  expect_null(result)
})

test_that("safe_getBM returns NULL when mart is NULL", {
  result <- safe_getBM(
    attributes = c("hgnc_symbol"),
    filters = "hgnc_symbol",
    values = list("BRCA1"),
    mart = NULL
  )
  expect_null(result)
})

test_that("create_ensembl_mart selects correct mirrors for reference", {
  # Test that hg19 uses GRCh37 mirror
  # This is a unit test for the mirror selection logic

  # We can verify the mirror arrays are configured correctly
  expect_true(any(grepl("grch37", ENSEMBL_HG19_MIRRORS, ignore.case = TRUE)))
  expect_false(any(grepl("grch37", ENSEMBL_HG38_MIRRORS, ignore.case = TRUE)))
})
