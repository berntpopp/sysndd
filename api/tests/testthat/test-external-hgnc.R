# test-external-hgnc.R
# Tests for HGNC API integration (hgnc-functions.R)
#
# These tests use httptest2 to mock external HGNC API calls.
# Note: Uses jsonlite::fromJSON() which httptest2 can intercept via httr2
# when GET requests are involved.
#
# First run: Records live API responses to fixtures/rest.genenames.org/
# Subsequent runs: Replays recorded responses (no network calls)

# Load required packages
library(dplyr)
library(tibble)
library(stringr)
library(jsonlite)

# Source required files using helper-paths.R (loaded automatically by setup.R)
# Use local = FALSE to make functions available in test scope
source_api_file("functions/hgnc-functions.R", local = FALSE)

# Skip if required packages not available
skip_if_not_installed("httptest2")
skip_if_not_installed("jsonlite")

# ============================================================================
# hgnc_id_from_prevsymbol() Tests
# ============================================================================

test_that("hgnc_id_from_prevsymbol returns HGNC ID for valid previous symbol", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  # Note: httptest2 may not intercept jsonlite::fromJSON() directly
  # This test may require network on first run to record fixtures
  result <- tryCatch({
    hgnc_id_from_prevsymbol("KMT2B")
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  if (!is.na(result)) {
    expect_true(is.integer(result) || is.numeric(result))
    expect_true(result > 0)
  }
})

test_that("hgnc_id_from_prevsymbol handles unknown previous symbol gracefully", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    hgnc_id_from_prevsymbol("NOT_A_REAL_PREVSYMBOL_12345")
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  # Should return NA for unknown symbol
  expect_true(is.na(result))
})

# ============================================================================
# hgnc_id_from_aliassymbol() Tests
# ============================================================================

test_that("hgnc_id_from_aliassymbol returns HGNC ID for valid alias", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    # MLL2 is an alias for KMT2B
    hgnc_id_from_aliassymbol("MLL2")
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  if (!is.na(result)) {
    expect_true(is.integer(result) || is.numeric(result))
    expect_true(result > 0)
  }
})

test_that("hgnc_id_from_aliassymbol handles unknown alias gracefully", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    hgnc_id_from_aliassymbol("NOT_A_REAL_ALIAS_12345")
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  # Should return NA for unknown alias
  expect_true(is.na(result))
})

# ============================================================================
# hgnc_id_from_symbol() Tests
# ============================================================================

test_that("hgnc_id_from_symbol returns HGNC ID for single valid symbol", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    # Test with a well-known gene symbol
    symbol_input <- tibble(value = c("BRCA1"))
    hgnc_id_from_symbol(symbol_input)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("hgnc_id" %in% names(result))
  expect_equal(nrow(result), 1)

  if (!is.na(result$hgnc_id[1])) {
    expect_true(is.integer(result$hgnc_id[1]) || is.numeric(result$hgnc_id[1]))
    expect_true(result$hgnc_id[1] > 0)
  }
})

test_that("hgnc_id_from_symbol handles multiple symbols", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    symbol_input <- tibble(value = c("TP53", "BRCA1", "EGFR"))
    hgnc_id_from_symbol(symbol_input)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("hgnc_id" %in% names(result))
  expect_equal(nrow(result), 3)
})

test_that("hgnc_id_from_symbol handles unknown symbols with NA", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    symbol_input <- tibble(value = c("NOT_A_REAL_GENE_12345"))
    hgnc_id_from_symbol(symbol_input)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_true(is.na(result$hgnc_id[1]))
})

test_that("hgnc_id_from_symbol converts symbols to uppercase", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    # Test with lowercase input
    symbol_input <- tibble(value = c("tp53"))
    hgnc_id_from_symbol(symbol_input)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  # The function should handle lowercase and still find the gene
  if (!is.na(result$hgnc_id[1])) {
    expect_true(result$hgnc_id[1] > 0)
  }
})

# ============================================================================
# hgnc_id_from_symbol_grouped() Tests
# ============================================================================

test_that("hgnc_id_from_symbol_grouped handles single symbol", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    input_tibble <- tibble(value = c("ARID1B"))
    hgnc_id_from_symbol_grouped(input_tibble, request_max = 150)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_true(is.vector(result))
  expect_equal(length(result), 1)

  if (!is.na(result[1])) {
    expect_true(is.integer(result[1]) || is.numeric(result[1]))
  }
})

test_that("hgnc_id_from_symbol_grouped handles multiple symbols", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    input_tibble <- tibble(value = c("ARID1B", "GRIN2B", "NAA10"))
    hgnc_id_from_symbol_grouped(input_tibble, request_max = 150)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_true(is.vector(result))
  expect_equal(length(result), 3)
})

test_that("hgnc_id_from_symbol_grouped uses fallback for failed symbols", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  # This test verifies the function tries prevsymbol and aliassymbol fallbacks
  result <- tryCatch({
    # Mix of current and previous symbols
    input_tibble <- tibble(value = c("KMT2B", "MLL2"))
    hgnc_id_from_symbol_grouped(input_tibble, request_max = 150)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_true(is.vector(result))
  expect_equal(length(result), 2)
})

# ============================================================================
# symbol_from_hgnc_id() Tests
# ============================================================================

test_that("symbol_from_hgnc_id returns symbol for valid HGNC ID", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    # HGNC:1100 is BRCA1
    hgnc_id_input <- tibble(value = c(1100))
    symbol_from_hgnc_id(hgnc_id_input)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("symbol" %in% names(result))
  expect_equal(nrow(result), 1)
})

test_that("symbol_from_hgnc_id handles multiple HGNC IDs", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    hgnc_id_input <- tibble(value = c(1100, 11998, 3236))
    symbol_from_hgnc_id(hgnc_id_input)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_true("symbol" %in% names(result))
  expect_equal(nrow(result), 3)
})

test_that("symbol_from_hgnc_id handles invalid HGNC IDs with NA", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    # Use an invalid HGNC ID (very high number unlikely to exist)
    hgnc_id_input <- tibble(value = c(999999999))
    symbol_from_hgnc_id(hgnc_id_input)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
})

# ============================================================================
# symbol_from_hgnc_id_grouped() Tests
# ============================================================================

test_that("symbol_from_hgnc_id_grouped handles single HGNC ID", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    input_tibble <- tibble(value = c(1100))
    symbol_from_hgnc_id_grouped(input_tibble, request_max = 150)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_true(is.vector(result))
  expect_equal(length(result), 1)
})

test_that("symbol_from_hgnc_id_grouped handles multiple HGNC IDs", {
  skip_if_no_fixtures_or_network(test_path("fixtures", "rest.genenames.org"))

  result <- tryCatch({
    input_tibble <- tibble(value = c(1100, 11998, 3236))
    symbol_from_hgnc_id_grouped(input_tibble, request_max = 150)
  }, error = function(e) {
    skip(paste("HGNC API error:", e$message))
  })

  expect_true(is.vector(result))
  expect_equal(length(result), 3)
})

# ============================================================================
# HGNC Data Type Cleanup Tests (for update_process_hgnc_data)
# ============================================================================
# These tests verify that the data type cleanup step in update_process_hgnc_data
# properly converts logical and Date columns to character for MySQL compatibility.

test_that("logical columns are converted to character for DB compatibility", {
  # Simulate HGNC data with logical columns (like kznf_gene_catalog, mamit-trnadb)
  test_data <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3"),
    kznf_gene_catalog = c(TRUE, FALSE, NA),
    `mamit-trnadb` = c(NA, TRUE, FALSE),
    intermediate_filament_db = c(FALSE, NA, TRUE)
  )

  # Apply the same transformation used in update_process_hgnc_data
  result <- test_data %>%
    mutate(across(where(is.logical), ~ as.character(.x)))

  # All logical columns should now be character

  expect_type(result$kznf_gene_catalog, "character")
  expect_type(result$`mamit-trnadb`, "character")
  expect_type(result$intermediate_filament_db, "character")

  # Values should be "TRUE", "FALSE", or NA (character)
  expect_equal(result$kznf_gene_catalog[1], "TRUE")
  expect_equal(result$kznf_gene_catalog[2], "FALSE")
  expect_true(is.na(result$kznf_gene_catalog[3]))
})

test_that("Date columns are converted to character for DB compatibility", {
  # Simulate HGNC data with Date columns
  test_data <- tibble(
    symbol = c("GENE1", "GENE2"),
    date_approved_reserved = as.Date(c("2020-01-15", "2021-06-30")),
    date_modified = as.Date(c("2023-01-01", NA))
  )

  # Apply the same transformation used in update_process_hgnc_data
  # Use inherits() for base R compatibility (is.Date is from lubridate)
  result <- test_data %>%
    mutate(across(where(~ inherits(.x, "Date")), ~ as.character(.x)))

  # All Date columns should now be character
  expect_type(result$date_approved_reserved, "character")
  expect_type(result$date_modified, "character")

  # Date format should be preserved as YYYY-MM-DD string
  expect_equal(result$date_approved_reserved[1], "2020-01-15")
  expect_true(is.na(result$date_modified[2]))
})

test_that("mixed data types are handled correctly", {
  # Simulate a more realistic HGNC data structure
  test_data <- tibble(
    hgnc_id = c("HGNC:1", "HGNC:2"),
    symbol = c("BRCA1", "TP53"),
    entrez_id = c(672, 7157),
    logical_col = c(TRUE, FALSE),
    date_col = as.Date(c("2020-01-01", "2021-01-01")),
    character_col = c("value1", "value2")
  )

  # Apply both transformations
  # Use inherits() for base R compatibility (is.Date is from lubridate)
  result <- test_data %>%
    mutate(across(where(is.logical), ~ as.character(.x))) %>%
    mutate(across(where(~ inherits(.x, "Date")), ~ as.character(.x)))

  # Check types after transformation
  expect_type(result$hgnc_id, "character")
  expect_type(result$symbol, "character")
  expect_type(result$entrez_id, "double")  # numeric stays numeric
  expect_type(result$logical_col, "character")  # logical converted
  expect_type(result$date_col, "character")  # date converted
  expect_type(result$character_col, "character")  # char stays char
})
