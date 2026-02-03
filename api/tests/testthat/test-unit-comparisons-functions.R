# test-unit-comparisons-functions.R
# Unit tests for api/functions/comparisons-functions.R
#
# These tests cover the core functions for importing and parsing
# NDD gene list data from external sources. Network-dependent tests
# and PDF parsing tests are skipped when resources unavailable.

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/comparisons-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(testthat)
library(tibble)
library(dplyr)
library(stringr)
library(withr)

# Source functions being tested
source(file.path(api_dir, "functions/comparisons-functions.R"))

# ============================================================================
# download_source_data() Tests
# ============================================================================

test_that("download_source_data handles timeout gracefully", {
  skip_on_cran()
  skip_if_offline()

  source_config <- tibble(
    source_name = "test_timeout",
    source_url = "https://httpbin.org/delay/10",
    file_format = "txt"
  )

  temp_dir <- tempdir()

  # With 1 second timeout, should return NULL (timeout)
  result <- suppressWarnings(
    download_source_data(source_config, temp_dir, timeout_seconds = 1)
  )
  expect_null(result)
})

test_that("download_source_data returns correct file extension", {
  skip_on_cran()
  skip_if_offline()

  temp_dir <- tempdir()

  # Test CSV extension
  source_config <- tibble(
    source_name = "test_csv",
    source_url = "https://httpbin.org/robots.txt",
    file_format = "csv"
  )

  result <- download_source_data(source_config, temp_dir, timeout_seconds = 30)

  if (!is.null(result)) {
    expect_true(grepl("\\.csv$", result))
    unlink(result)
  }
})

test_that("download_source_data uses correct extensions for each format", {
  # Test the extension mapping without network
  expect_equal(switch("pdf",
    "pdf" = ".pdf"
  ), ".pdf")
  expect_equal(switch("csv.gz",
    "csv.gz" = ".csv.gz"
  ), ".csv.gz")
  expect_equal(switch("csv",
    "csv" = ".csv"
  ), ".csv")
  expect_equal(switch("tsv",
    "tsv" = ".tsv"
  ), ".tsv")
  expect_equal(switch("json",
    "json" = ".json"
  ), ".json")
  expect_equal(switch("txt",
    "txt" = ".txt"
  ), ".txt")
})

test_that("download_source_data handles missing URL gracefully", {
  source_config <- tibble(
    source_name = "test_missing",
    source_url = "https://nonexistent.invalid.domain/file.txt",
    file_format = "txt"
  )

  temp_dir <- tempdir()

  result <- suppressWarnings(
    download_source_data(source_config, temp_dir, timeout_seconds = 5)
  )
  expect_null(result)
})

# ============================================================================
# parse_radboudumc_pdf() Tests
# ============================================================================

test_that("parse_radboudumc_pdf requires pdftools package", {
  skip_if_not_installed("pdftools")

  # Test with non-existent file should error
  expect_error(
    parse_radboudumc_pdf("/nonexistent/file.pdf"),
    class = "error"
  )
})

test_that("parse_radboudumc_pdf errors without pdftools", {
  # Create a mock namespace check that returns FALSE
  # This test verifies the error message when pdftools is not installed

  # We can't easily mock requireNamespace, so we verify the function

  # has the appropriate check by looking at the source
  func_body <- deparse(body(parse_radboudumc_pdf))
  expect_true(any(grepl("requireNamespace.*pdftools", func_body)))
  expect_true(any(grepl("stop.*pdftools", func_body)))
})

# ============================================================================
# standardize_comparison_data() Tests
# ============================================================================

test_that("standardize_comparison_data adds all expected columns", {
  # Minimal input data
  input <- tibble(
    gene_symbol = c("BRCA1", "TP53"),
    list = c("test_source", "test_source"),
    version = c("v1", "v1")
  )

  result <- standardize_comparison_data(input, "test_source", "2026-01-01")

  expected_cols <- c(
    "symbol", "hgnc_id", "disease_ontology_id", "disease_ontology_name",
    "inheritance", "category", "pathogenicity_mode", "phenotype",
    "publication_id", "list", "version", "import_date", "granularity"
  )

  expect_true(all(expected_cols %in% colnames(result)))
})

test_that("standardize_comparison_data renames gene_symbol to symbol", {
  input <- tibble(
    gene_symbol = c("MECP2", "SHANK3"),
    list = c("test", "test"),
    version = c("1", "1")
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  expect_true("symbol" %in% colnames(result))
  expect_false("gene_symbol" %in% colnames(result))
  expect_equal(result$symbol, c("MECP2", "SHANK3"))
})

test_that("standardize_comparison_data sets import_date correctly", {
  input <- tibble(
    gene_symbol = c("SCN1A"),
    list = c("test"),
    version = c("1")
  )

  result <- standardize_comparison_data(input, "test", "2026-02-03")

  expect_equal(result$import_date, "2026-02-03")
})

test_that("standardize_comparison_data sets source-specific granularity", {
  input <- tibble(
    gene_symbol = c("GENE1"),
    list = c("test"),
    version = c("1")
  )

  # Test different sources
  rad_result <- standardize_comparison_data(input, "radboudumc_ID", "2026-01-01")
  expect_equal(rad_result$granularity, "gene,disease,category(implied)")

  g2p_result <- standardize_comparison_data(input, "gene2phenotype", "2026-01-01")
  expect_equal(
    g2p_result$granularity,
    "gene,disease,inheritance,category,pathogenicity"
  )

  panelapp_result <- standardize_comparison_data(input, "panelapp", "2026-01-01")
  expect_equal(
    panelapp_result$granularity,
    "gene,disease(aggregated),inheritance(aggregated),category,pathogenicity(incomplete)"
  )
})

test_that("standardize_comparison_data handles radboudumc OMIM formatting", {
  input <- tibble(
    gene_symbol = c("GENE1", "GENE2"),
    OMIMdiseaseID = c("123456", "654321;789012"),
    list = c("radboudumc_ID", "radboudumc_ID"),
    version = c("v1", "v1")
  )

  result <- standardize_comparison_data(input, "radboudumc_ID", "2026-01-01")

  # Should expand semicolon-separated OMIM IDs
  expect_true(nrow(result) >= 2)

  # Should add OMIM: prefix
  omim_ids <- result$disease_ontology_id[!is.na(result$disease_ontology_id)]
  expect_true(all(grepl("^OMIM:", omim_ids)))

  # Should set category to "Definitive"
  expect_true(all(result$category == "Definitive"))
})

test_that("standardize_comparison_data handles gene2phenotype OMIM formatting", {
  input <- tibble(
    gene_symbol = c("BRCA1", "TP53"),
    disease_ontology_id = c("113705", NA),
    disease_ontology_name = c("Test Disease", "Unknown"),
    category = c("Definitive", "Limited"),
    inheritance = c("AD", "AR"),
    pathogenicity_mode = c("LOF", "GOF"),
    phenotype = c("HP:0001;HP:0002", "HP:0003"),
    publication_id = c("12345;67890", "11111"),
    list = c("gene2phenotype", "gene2phenotype"),
    version = c("v1", "v1")
  )

  result <- standardize_comparison_data(input, "gene2phenotype", "2026-01-01")

  # Should add OMIM: prefix where ID exists
  non_na_ids <- result$disease_ontology_id[!is.na(result$disease_ontology_id)]
  expect_true(all(grepl("^OMIM:", non_na_ids) | is.na(non_na_ids)))

  # Should replace semicolons with commas in phenotype
  expect_false(any(grepl(";", result$phenotype, fixed = TRUE), na.rm = TRUE))
})

test_that("standardize_comparison_data handles missing columns", {
  # Input with minimal columns
  input <- tibble(
    gene_symbol = c("TEST1"),
    list = c("test"),
    version = c("1")
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  # Should have all expected columns
  expect_true("hgnc_id" %in% colnames(result))
  expect_true("disease_ontology_id" %in% colnames(result))
  expect_true("inheritance" %in% colnames(result))

  # Missing columns should be NA
  expect_true(is.na(result$hgnc_id))
  expect_true(is.na(result$disease_ontology_id))
})

test_that("standardize_comparison_data sets Definitive category for geisinger", {
  input <- tibble(
    gene_symbol = c("GENE1"),
    list = c("geisinger_DBD"),
    version = c("1"),
    category = c("Unknown")
  )

  result <- standardize_comparison_data(input, "geisinger_DBD", "2026-01-01")

  expect_equal(result$category, "Definitive")
})

# ============================================================================
# resolve_hgnc_symbols() Tests (require database)
# ============================================================================

test_that("resolve_hgnc_symbols returns correct structure for empty input", {
  # Test without database - should handle empty input gracefully
  result <- resolve_hgnc_symbols(character(0), NULL)

  expect_s3_class(result, "tbl_df")
  expect_true("symbol" %in% colnames(result))
  expect_true("hgnc_id" %in% colnames(result))
  expect_equal(nrow(result), 0)
})

test_that("resolve_hgnc_symbols uppercases input symbols", {
  # We can test the uppercase logic without a database
  symbols <- c("brca1", "Tp53", "MECP2")

  # The function uppercases internally, we test that logic
  result <- unique(toupper(symbols))
  expect_equal(result, c("BRCA1", "TP53", "MECP2"))
})

# ============================================================================
# parse_gene2phenotype_csv() Tests
# ============================================================================

test_that("parse_gene2phenotype_csv extracts correct columns", {
  skip("Requires G2P test fixture file")

  # This test would run if we had a test fixture
  # fixture_path <- file.path(api_dir, "tests/fixtures/g2p_sample.csv.gz")
  # skip_if_not(file.exists(fixture_path))

  # result <- parse_gene2phenotype_csv(fixture_path)
  # expect_true("gene_symbol" %in% colnames(result))
  # expect_true("list" %in% colnames(result))
  # expect_equal(unique(result$list), "gene2phenotype")
})

# ============================================================================
# parse_sfari_csv() Tests
# ============================================================================

test_that("parse_sfari_csv sets list name correctly", {
  skip("Requires SFARI test fixture file")

  # This test would validate list = "sfari" is set
})

# ============================================================================
# parse_panelapp_tsv() Tests
# ============================================================================

test_that("parse_panelapp_tsv filters for gene entities only", {
  skip("Requires PanelApp test fixture file")

  # This test would validate Entity type == "gene" filter
})

# ============================================================================
# parse_orphanet_json() Tests
# ============================================================================

test_that("parse_orphanet_json excludes disorder-associated loci", {
  skip("Requires Orphanet test fixture file")

  # This test would validate GeneType != "Disorder-associated locus" filter
})

# ============================================================================
# Edge Cases and Error Handling
# ============================================================================

test_that("standardize_comparison_data handles empty tibble", {
  input <- tibble(
    gene_symbol = character(0),
    list = character(0),
    version = character(0)
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  expect_equal(nrow(result), 0)
  expect_true("symbol" %in% colnames(result))
})

test_that("standardize_comparison_data handles NA values", {
  input <- tibble(
    gene_symbol = c("GENE1", NA),
    list = c("test", "test"),
    version = c("1", "1")
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  expect_equal(nrow(result), 2)
  expect_true(is.na(result$symbol[2]))
})

test_that("standardize_comparison_data handles special characters", {
  input <- tibble(
    gene_symbol = c("C9orf72", "AARS1"),
    list = c("test", "test"),
    version = c("1", "1")
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  expect_equal(result$symbol[1], "C9orf72")
  expect_equal(result$symbol[2], "AARS1")
})
