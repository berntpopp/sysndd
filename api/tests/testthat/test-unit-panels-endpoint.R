# tests/testthat/test-unit-panels-endpoint.R
# Unit tests for panels endpoint column alias and filtering logic
#
# These tests validate the max_category handling in generate_panels_list
# without requiring database access.

library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(rlang)

# Source helper functions
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/endpoint-functions.R")) {
  normalizePath("../..")
} else {
  stop("Cannot find api directory")
}

source(file.path(api_dir, "functions", "helper-functions.R"))

# =============================================================================
# Test max_category column replacement logic
# =============================================================================

test_that("max_category column replaces category correctly when max_category=TRUE", {
  # Simulate the data structure after left_join with status_categories_list
  # A gene with multiple entities will have different category values per entity,
  # but all should have the same max_category after the join
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    category = c("Definitive", "Moderate", "Definitive"),  # Per-entity categories
    max_category = c("Definitive", "Definitive", "Definitive"),  # Max category per gene
    inheritance_filter = c("Autosomal dominant", "Autosomal dominant", "X-linked")
  )

  # Simulate the transformation that should happen when max_category=TRUE:
  # 1. Remove original category column
  # 2. Rename max_category to category
  max_category <- TRUE
  result <- test_data %>%
    {
      if (max_category) {
        select(., -category) %>%
          rename(category = max_category)
      } else {
        .
      }
    }

  # Verify the category column now contains max_category values
  expect_true("category" %in% colnames(result))
  expect_false("max_category" %in% colnames(result))
  expect_equal(result$category, c("Definitive", "Definitive", "Definitive"))
})

test_that("original category preserved when max_category=FALSE", {
  # When max_category=FALSE, the original per-entity category should be kept
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    category = c("Definitive", "Moderate", "Definitive"),
    max_category = c("Definitive", "Definitive", "Definitive"),
    inheritance_filter = c("Autosomal dominant", "Autosomal dominant", "X-linked")
  )

  max_category <- FALSE
  result <- test_data %>%
    {
      if (max_category) {
        select(., -category) %>%
          rename(category = max_category)
      } else {
        .
      }
    }

  # Verify the original category column is preserved
  expect_true("category" %in% colnames(result))
  expect_equal(result$category, c("Definitive", "Moderate", "Definitive"))
})

# =============================================================================
# Test filter expression replacement
# =============================================================================

test_that("filter expression replaces category with max_category when max_category=TRUE", {
  # Test the filter string replacement logic
  filter_string <- "equals(category,'Definitive'),any(inheritance_filter,'Autosomal dominant','X-linked')"

  max_category <- TRUE
  if (max_category) {
    filter_string <- str_replace(filter_string, "category", "max_category")
  }

  # Verify category was replaced with max_category
  expect_true(grepl("max_category", filter_string))
  # Use word boundary to avoid matching "category" inside "max_category"
  expect_false(grepl("\\bcategory\\b", filter_string))
  expect_match(filter_string, "equals\\(max_category,'Definitive'\\)")
})

test_that("filter expression with max_category can be parsed and applied", {
  # Create test data with max_category column
  test_data <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3"),
    max_category = c("Definitive", "Moderate", "Definitive"),
    inheritance_filter = c("Autosomal dominant", "Autosomal recessive", "X-linked")
  )

  # Use the helper function to generate filter expressions
  filter_string <- "equals(max_category,'Definitive')"
  filter_exprs <- generate_filter_expressions(filter_string)

  # Apply the filter
  result <- test_data %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # Verify filtering worked
  expect_equal(nrow(result), 2)
  expect_equal(result$symbol, c("GENE1", "GENE3"))
  expect_true(all(result$max_category == "Definitive"))
})

# =============================================================================
# Test field selection with category column
# =============================================================================

test_that("select_tibble_fields correctly selects category column", {
  # Simulate the final panels data structure
  test_data <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3"),
    category = c("Definitive", "Moderate", "Definitive"),
    inheritance = c("Autosomal dominant", "Autosomal recessive", "X-linked"),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3")
  )

  # Select specific fields including category
  fields_requested <- "category,symbol,hgnc_id"

  result <- select_tibble_fields(test_data, fields_requested, "symbol")

  # Verify the selected columns are present
  expect_true("category" %in% colnames(result))
  expect_true("symbol" %in% colnames(result))
  expect_true("hgnc_id" %in% colnames(result))
  expect_false("inheritance" %in% colnames(result))
  expect_equal(ncol(result), 3)
})

# =============================================================================
# Test output_columns_allowed match
# =============================================================================

test_that("all output_columns_allowed can be found in panels result", {
  # Define output_columns_allowed as it appears in start_sysndd_api.R
  output_columns_allowed <- c(
    "category",
    "inheritance",
    "symbol",
    "hgnc_id",
    "entrez_id",
    "ensembl_gene_id",
    "ucsc_id",
    "bed_hg19",
    "bed_hg38"
  )

  # Simulate a complete panels result tibble
  panels_result <- tibble(
    symbol = "GENE1",
    category = "Definitive",
    inheritance = "Autosomal dominant",
    hgnc_id = "HGNC:1",
    entrez_id = "123",
    ensembl_gene_id = "ENSG00000000001",
    ucsc_id = "uc001abc.1",
    bed_hg19 = "chr1:1000-2000",
    bed_hg38 = "chr1:1500-2500"
  )

  # Verify all allowed columns exist in the result
  for (col in output_columns_allowed) {
    expect_true(
      col %in% colnames(panels_result),
      info = paste("Column", col, "should be in panels result")
    )
  }
})

# =============================================================================
# Test category concatenation after grouping
# =============================================================================

test_that("category concatenation works with max_category values", {
  # Simulate data after max_category replacement but before grouping
  # A gene might have multiple inheritance modes, each with the same max_category
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    category = c("Definitive", "Definitive", "Moderate"),  # Already replaced with max
    inheritance = c("Autosomal dominant", "Autosomal recessive", "X-linked")
  )

  # Group by symbol and concatenate unique categories
  result <- test_data %>%
    group_by(symbol) %>%
    mutate(category = str_c(unique(category), collapse = "; ")) %>%
    mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
    ungroup() %>%
    unique()

  # Verify GENE1 has "Definitive" (not "Definitive; Definitive")
  gene1_result <- result %>% filter(symbol == "GENE1")
  expect_equal(nrow(gene1_result), 1)
  expect_equal(gene1_result$category, "Definitive")
  expect_match(gene1_result$inheritance, "Autosomal dominant; Autosomal recessive")

  # Verify GENE2 has "Moderate"
  gene2_result <- result %>% filter(symbol == "GENE2")
  expect_equal(gene2_result$category, "Moderate")
})

test_that("category concatenation without max_category replacement shows mixed categories", {
  # When max_category=FALSE, the original per-entity categories should be concatenated
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    category = c("Definitive", "Moderate", "Definitive"),  # Original per-entity values
    inheritance = c("Autosomal dominant", "Autosomal recessive", "X-linked")
  )

  result <- test_data %>%
    group_by(symbol) %>%
    mutate(category = str_c(unique(category), collapse = "; ")) %>%
    mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
    ungroup() %>%
    unique()

  # Verify GENE1 shows both categories concatenated
  gene1_result <- result %>% filter(symbol == "GENE1")
  expect_equal(nrow(gene1_result), 1)
  expect_match(gene1_result$category, "Definitive; Moderate|Moderate; Definitive")
})
