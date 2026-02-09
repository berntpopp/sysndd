# test-unit-category-normalization.R
# Unit tests for api/functions/category-normalization.R
#
# These tests verify that category normalization correctly maps source-specific
# category values to standard SysNDD categories, and that per-source categories
# are preserved without cross-database aggregation (bug #173 regression test).

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/category-normalization.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(testthat)
library(tibble)
library(dplyr)

# Source function being tested
source(file.path(api_dir, "functions/category-normalization.R"))

# ============================================================================
# gene2phenotype Category Mapping Tests
# ============================================================================

test_that("normalize_comparison_categories maps gene2phenotype categories correctly", {
  fixture <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3", "GENE4", "GENE5", "GENE6", "GENE7"),
    list = rep("gene2phenotype", 7),
    category = c("strong", "Definitive", "limited", "Moderate", "refuted", "disputed", "both rd and if")
  )

  result <- normalize_comparison_categories(fixture)

  expect_equal(result$category[1], "Definitive")  # strong
  expect_equal(result$category[2], "Definitive")  # Definitive
  expect_equal(result$category[3], "Limited")     # limited
  expect_equal(result$category[4], "Moderate")    # Moderate (unchanged)
  expect_equal(result$category[5], "Refuted")     # refuted
  expect_equal(result$category[6], "Refuted")     # disputed
  expect_equal(result$category[7], "Definitive")  # both rd and if
})

test_that("normalize_comparison_categories handles case-insensitive gene2phenotype", {
  fixture <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3"),
    list = rep("gene2phenotype", 3),
    category = c("Strong", "STRONG", "strong")
  )

  result <- normalize_comparison_categories(fixture)

  # All should map to "Definitive"
  expect_equal(result$category, c("Definitive", "Definitive", "Definitive"))
})

# ============================================================================
# panelapp Category Mapping Tests
# ============================================================================

test_that("normalize_comparison_categories maps panelapp confidence levels", {
  fixture <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3"),
    list = rep("panelapp", 3),
    category = c("3", "2", "1")
  )

  result <- normalize_comparison_categories(fixture)

  expect_equal(result$category[1], "Definitive")  # 3
  expect_equal(result$category[2], "Limited")     # 2
  expect_equal(result$category[3], "Refuted")     # 1
})

# ============================================================================
# sfari Category Mapping Tests
# ============================================================================

test_that("normalize_comparison_categories maps sfari gene scores", {
  fixture <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3", "GENE4"),
    list = rep("sfari", 4),
    category = c("1", "2", "3", NA)
  )

  result <- normalize_comparison_categories(fixture)

  expect_equal(result$category[1], "Definitive")  # 1
  expect_equal(result$category[2], "Moderate")    # 2
  expect_equal(result$category[3], "Limited")     # 3
  expect_equal(result$category[4], "Definitive")  # NA
})

# ============================================================================
# geisinger_DBD and radboudumc_ID Category Mapping Tests
# ============================================================================

test_that("normalize_comparison_categories maps geisinger_DBD and radboudumc_ID to Definitive", {
  fixture <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3", "GENE4"),
    list = c("geisinger_DBD", "geisinger_DBD", "radboudumc_ID", "radboudumc_ID"),
    category = c("high", "low", "strong", "unknown")
  )

  result <- normalize_comparison_categories(fixture)

  # All should map to "Definitive" regardless of original category value
  expect_equal(result$category, c("Definitive", "Definitive", "Definitive", "Definitive"))
})

# ============================================================================
# SysNDD and Other Sources Category Preservation Tests
# ============================================================================

test_that("normalize_comparison_categories preserves SysNDD and omim_ndd categories", {
  fixture <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3", "GENE4", "GENE5", "GENE6"),
    list = c("SysNDD", "SysNDD", "SysNDD", "omim_ndd", "orphanet_id", "orphanet_id"),
    category = c("Definitive", "Limited", "Moderate", "Definitive", "Definitive", "Limited")
  )

  result <- normalize_comparison_categories(fixture)

  # Categories should be unchanged
  expect_equal(result$category, c("Definitive", "Limited", "Moderate", "Definitive", "Definitive", "Limited"))
})

# ============================================================================
# KEY REGRESSION TEST: Per-Source Category Preservation (Bug #173)
# ============================================================================

test_that("per-source categories are preserved, not collapsed to cross-database max", {
  # This is the KEY regression test for bug #173
  # Before fix: Cross-database max aggregation caused all sources to show
  #             the same category (the "best" category across all sources)
  # After fix:  Each source keeps its own category rating

  fixture <- tibble::tribble(
    ~symbol, ~hgnc_id, ~list, ~category,
    # GENE1 is Definitive in SysNDD but Limited in other sources
    "GENE1", "HGNC:1", "SysNDD", "Definitive",
    "GENE1", "HGNC:1", "gene2phenotype", "limited",
    "GENE1", "HGNC:1", "panelapp", "2",
    # GENE2 is Limited in SysNDD but Definitive in sfari
    "GENE2", "HGNC:2", "SysNDD", "Limited",
    "GENE2", "HGNC:2", "sfari", "1"
  )

  result <- normalize_comparison_categories(fixture)

  # GENE1: Each source should keep its own category
  gene1_results <- result %>% filter(symbol == "GENE1")
  expect_equal(gene1_results$category[gene1_results$list == "SysNDD"], "Definitive")
  expect_equal(gene1_results$category[gene1_results$list == "gene2phenotype"], "Limited")
  expect_equal(gene1_results$category[gene1_results$list == "panelapp"], "Limited")

  # GENE2: SysNDD should keep "Limited" (NOT "Definitive" from sfari)
  gene2_results <- result %>% filter(symbol == "GENE2")
  expect_equal(gene2_results$category[gene2_results$list == "SysNDD"], "Limited")
  expect_equal(gene2_results$category[gene2_results$list == "sfari"], "Definitive")

  # Critical assertion: GENE2's SysNDD row should NOT be "Definitive"
  # (that would indicate cross-database max aggregation bug)
  expect_false(gene2_results$category[gene2_results$list == "SysNDD"] == "Definitive")
})

# ============================================================================
# Edge Cases and Error Handling
# ============================================================================

test_that("normalize_comparison_categories handles empty input", {
  fixture <- tibble(
    symbol = character(0),
    list = character(0),
    category = character(0)
  )

  result <- normalize_comparison_categories(fixture)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true("symbol" %in% colnames(result))
  expect_true("list" %in% colnames(result))
  expect_true("category" %in% colnames(result))
})

test_that("normalize_comparison_categories result is not grouped", {
  # Pitfall 1 defense: Ensure result is ungrouped
  fixture <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    list = c("SysNDD", "gene2phenotype", "panelapp"),
    category = c("Definitive", "strong", "3")
  )

  result <- normalize_comparison_categories(fixture)

  expect_false(dplyr::is_grouped_df(result))
})

test_that("normalize_comparison_categories preserves all input columns", {
  fixture <- tibble(
    symbol = c("GENE1", "GENE2"),
    hgnc_id = c("HGNC:1", "HGNC:2"),
    list = c("SysNDD", "gene2phenotype"),
    category = c("Definitive", "strong"),
    extra_column = c("value1", "value2")
  )

  result <- normalize_comparison_categories(fixture)

  # Should preserve all columns except category (which gets normalized)
  expect_true("symbol" %in% colnames(result))
  expect_true("hgnc_id" %in% colnames(result))
  expect_true("list" %in% colnames(result))
  expect_true("category" %in% colnames(result))
  expect_true("extra_column" %in% colnames(result))

  # Extra column should be unchanged
  expect_equal(result$extra_column, c("value1", "value2"))
})

test_that("normalize_comparison_categories handles NA in category column", {
  fixture <- tibble(
    symbol = c("GENE1", "GENE2"),
    list = c("SysNDD", "omim_ndd"),
    category = c(NA, "Definitive")
  )

  result <- normalize_comparison_categories(fixture)

  # NA should remain NA (unless it's sfari source, which maps NA to Definitive)
  expect_true(is.na(result$category[1]))
  expect_equal(result$category[2], "Definitive")
})
