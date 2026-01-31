# test-llm-validation.R
# Unit tests for LLM entity validation functions
#
# These tests cover:
# - extract_gene_symbols() - HGNC-style symbol extraction from text
# - validate_gene_symbols() - Database validation against non_alt_loci_set
# - validate_pathways() - Pathway validation against enrichment terms
# - validate_summary_entities() - Comprehensive entity validation

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/llm-validation.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(dplyr)
library(tibble)

# Load test helpers (for database connection)
if (file.exists(file.path(api_dir, "tests", "testthat", "helper-db.R"))) {
  source(file.path(api_dir, "tests", "testthat", "helper-db.R"))
}

# Source validation functions
original_wd <- getwd()
setwd(api_dir)
tryCatch({
  library(tidyverse)
  library(stringr)
  library(logger)
  suppressWarnings({
    source("functions/llm-validation.R")
  })
}, error = function(e) {
  message("Note: llm-validation.R not loaded - ", e$message)
})
setwd(original_wd)

# ============================================================================
# extract_gene_symbols() Tests
# ============================================================================

test_that("extract_gene_symbols extracts HGNC-style symbols", {
  text <- "The BRCA1 and TP53 genes regulate DNA repair"
  symbols <- extract_gene_symbols(text)

  expect_true("BRCA1" %in% symbols)
  expect_true("TP53" %in% symbols)
  expect_false("DNA" %in% symbols)  # Common word excluded
  expect_false("The" %in% symbols)  # Lowercase excluded
})

test_that("extract_gene_symbols filters common abbreviations", {
  text <- "RNA and ATP are involved in DNA repair alongside MECP2 expression"
  symbols <- extract_gene_symbols(text)

  expect_true("MECP2" %in% symbols)
  expect_false("RNA" %in% symbols)  # Common word
  expect_false("ATP" %in% symbols)  # Common word
  expect_false("DNA" %in% symbols)  # Common word
})

test_that("extract_gene_symbols handles empty text", {
  expect_equal(extract_gene_symbols(""), character(0))
  expect_equal(extract_gene_symbols(NULL), character(0))
  expect_equal(extract_gene_symbols(character(0)), character(0))
})

test_that("extract_gene_symbols handles text with no gene symbols", {
  text <- "This is a sentence with no gene symbols, just lowercase words."
  symbols <- extract_gene_symbols(text)
  expect_equal(length(symbols), 0)
})

test_that("extract_gene_symbols extracts complex gene names", {
  # Test various HGNC symbol patterns
  text <- "C9orf72 and KCNQ2 are involved alongside SCN1A and ARID1B"
  symbols <- extract_gene_symbols(text)

  expect_true("C9orf72" %in% symbols)
  expect_true("KCNQ2" %in% symbols)
  expect_true("SCN1A" %in% symbols)
  expect_true("ARID1B" %in% symbols)
})

test_that("extract_gene_symbols returns unique symbols", {
  text <- "BRCA1 is important. BRCA1 is also involved in BRCA1 pathways."
  symbols <- extract_gene_symbols(text)

  expect_equal(sum(symbols == "BRCA1"), 1)  # Only one occurrence
})

test_that("extract_gene_symbols excludes database abbreviations", {
  text <- "Data from HPO, OMIM, KEGG and ORPHA databases alongside MECP2"
  symbols <- extract_gene_symbols(text)

  expect_true("MECP2" %in% symbols)
  expect_false("HPO" %in% symbols)
  expect_false("OMIM" %in% symbols)
  expect_false("KEGG" %in% symbols)
  expect_false("ORPHA" %in% symbols)
})

# ============================================================================
# validate_gene_symbols() Tests (require database)
# ============================================================================

test_that("validate_gene_symbols returns valid structure for empty input", {
  result <- validate_gene_symbols(character(0))

  expect_true(result$is_valid)
  expect_equal(length(result$valid), 0)
  expect_equal(length(result$invalid), 0)
})

test_that("validate_gene_symbols returns valid structure for NULL input", {
  result <- validate_gene_symbols(NULL)

  expect_true(result$is_valid)
  expect_equal(length(result$valid), 0)
  expect_equal(length(result$invalid), 0)
})

test_that("validate_gene_symbols validates real genes against database", {
  # Skip if database not available
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  # BRCA1 and TP53 should be in the HGNC database
  result <- validate_gene_symbols(c("BRCA1", "TP53"))

  expect_true("BRCA1" %in% result$valid)
  expect_true("TP53" %in% result$valid)
  expect_equal(length(result$invalid), 0)
  expect_true(result$is_valid)
})

test_that("validate_gene_symbols detects invalid gene symbols", {
  # Skip if database not available
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  # FAKEGENE123 should not exist in HGNC database
  result <- validate_gene_symbols(c("BRCA1", "FAKEGENE123", "NOTAREALGENE"))

  expect_true("BRCA1" %in% result$valid)
  expect_true("FAKEGENE123" %in% result$invalid)
  expect_true("NOTAREALGENE" %in% result$invalid)
  expect_false(result$is_valid)  # Strict validation
})

test_that("validate_gene_symbols is strict - any invalid causes failure", {
  # Skip if database not available
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  # Even one fake gene should cause is_valid = FALSE
  result <- validate_gene_symbols(c("BRCA1", "TP53", "HALLUCINATED1"))

  expect_false(result$is_valid)
  expect_true("HALLUCINATED1" %in% result$invalid)
})

# ============================================================================
# validate_pathways() Tests
# ============================================================================

test_that("validate_pathways returns valid structure for empty pathways", {
  result <- validate_pathways(character(0), c("Pathway A", "Pathway B"))

  expect_true(result$is_valid)
  expect_equal(length(result$valid), 0)
  expect_equal(length(result$invalid), 0)
})

test_that("validate_pathways returns valid structure for NULL pathways", {
  result <- validate_pathways(NULL, c("Pathway A", "Pathway B"))

  expect_true(result$is_valid)
})

test_that("validate_pathways validates pathways in enrichment terms", {
  enrichment_terms <- c("Oxidative phosphorylation", "DNA repair", "Cell cycle")
  pathways <- c("Oxidative phosphorylation", "DNA repair")

  result <- validate_pathways(pathways, enrichment_terms)

  expect_true(result$is_valid)
  expect_equal(length(result$valid), 2)
  expect_equal(length(result$invalid), 0)
})

test_that("validate_pathways detects invalid pathways", {
  enrichment_terms <- c("Oxidative phosphorylation", "DNA repair", "Cell cycle")
  pathways <- c("Oxidative phosphorylation", "Made up pathway")

  result <- validate_pathways(pathways, enrichment_terms)

  expect_false(result$is_valid)
  expect_true("Oxidative phosphorylation" %in% result$valid)
  expect_true("Made up pathway" %in% result$invalid)
})

test_that("validate_pathways uses case-insensitive matching", {
  enrichment_terms <- c("Oxidative Phosphorylation", "DNA Repair")
  pathways <- c("oxidative phosphorylation", "dna repair")

  result <- validate_pathways(pathways, enrichment_terms)

  expect_true(result$is_valid)
  expect_equal(length(result$valid), 2)
})

test_that("validate_pathways fails when enrichment_terms is empty", {
  pathways <- c("Oxidative phosphorylation")

  result <- validate_pathways(pathways, character(0))

  expect_false(result$is_valid)
  expect_true("Oxidative phosphorylation" %in% result$invalid)
})

test_that("validate_pathways fails when enrichment_terms is NULL", {
  pathways <- c("Oxidative phosphorylation")

  result <- validate_pathways(pathways, NULL)

  expect_false(result$is_valid)
})

# ============================================================================
# validate_summary_entities() Tests
# ============================================================================

test_that("validate_summary_entities validates valid summary content", {
  # Skip if database not available
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  summary_result <- list(
    summary = "The BRCA1 gene is involved in DNA repair mechanisms.",
    pathways = c("DNA repair"),
    tags = c("cancer", "repair")
  )

  cluster_data <- list(
    term_enrichment = tibble(
      term = c("DNA repair", "Cell cycle", "Apoptosis"),
      fdr = c(1e-10, 1e-8, 1e-6),
      category = c("GO:BP", "GO:BP", "GO:BP")
    )
  )

  result <- validate_summary_entities(summary_result, cluster_data)

  expect_true(result$is_valid)
  expect_true("BRCA1" %in% result$mentioned_genes)
  expect_true("DNA repair" %in% result$mentioned_pathways)
  expect_equal(length(result$errors), 0)
})

test_that("validate_summary_entities detects invalid gene symbols", {
  # Skip if database not available
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  summary_result <- list(
    summary = "The BRCA1 and HALLUCINATED1 genes are involved.",
    pathways = c("DNA repair"),
    tags = c("cancer")
  )

  cluster_data <- list(
    term_enrichment = tibble(
      term = c("DNA repair"),
      fdr = c(1e-10),
      category = c("GO:BP")
    )
  )

  result <- validate_summary_entities(summary_result, cluster_data)

  expect_false(result$is_valid)
  expect_true("HALLUCINATED1" %in% result$invalid_genes)
  expect_true(any(grepl("HALLUCINATED1", result$errors)))
})

test_that("validate_summary_entities detects invalid pathways", {
  # Skip if database not available
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  summary_result <- list(
    summary = "The BRCA1 gene is involved.",
    pathways = c("DNA repair", "Fictional pathway"),
    tags = c("cancer")
  )

  cluster_data <- list(
    term_enrichment = tibble(
      term = c("DNA repair", "Cell cycle"),
      fdr = c(1e-10, 1e-8),
      category = c("GO:BP", "GO:BP")
    )
  )

  result <- validate_summary_entities(summary_result, cluster_data)

  expect_false(result$is_valid)
  expect_true("Fictional pathway" %in% result$invalid_pathways)
  expect_true(any(grepl("Fictional pathway", result$errors)))
})

test_that("validate_summary_entities returns human-readable errors", {
  # Skip if database not available
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  summary_result <- list(
    summary = "The FAKEGENE1 and FAKEGENE2 genes are involved.",
    pathways = c("Made up pathway"),
    tags = c("fake")
  )

  cluster_data <- list(
    term_enrichment = tibble(
      term = c("Real pathway"),
      fdr = c(1e-10),
      category = c("GO:BP")
    )
  )

  result <- validate_summary_entities(summary_result, cluster_data)

  expect_false(result$is_valid)
  expect_true(length(result$errors) >= 1)

  # Errors should be human-readable
  all_errors <- paste(result$errors, collapse = " ")
  expect_true(grepl("gene|symbol", all_errors, ignore.case = TRUE) ||
              grepl("pathway", all_errors, ignore.case = TRUE))
})

test_that("validate_summary_entities handles missing term_enrichment", {
  # Skip if database not available
  skip_if(!exists("pool") || is.null(pool), "Database not available")

  summary_result <- list(
    summary = "The BRCA1 gene is involved.",
    pathways = character(0),  # No pathways
    tags = c("cancer")
  )

  cluster_data <- list()  # No term_enrichment

  result <- validate_summary_entities(summary_result, cluster_data)

  # Should still validate genes
  expect_true(result$is_valid)  # BRCA1 is valid, no pathways to validate
  expect_true("BRCA1" %in% result$mentioned_genes)
})

test_that("validate_summary_entities handles NULL summary", {
  summary_result <- list(
    summary = NULL,
    pathways = c("DNA repair"),
    tags = c("cancer")
  )

  cluster_data <- list(
    term_enrichment = tibble(
      term = c("DNA repair"),
      fdr = c(1e-10),
      category = c("GO:BP")
    )
  )

  result <- validate_summary_entities(summary_result, cluster_data)

  # No genes to validate, pathways are valid
  expect_true(result$is_valid)
  expect_equal(length(result$mentioned_genes), 0)
})
