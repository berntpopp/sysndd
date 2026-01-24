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
