# tests/testthat/test-unit-endpoint-functions.R
# Tests for pure aspects of api/functions/endpoint-functions.R
#
# These functions rely heavily on database access, so we test:
# 1. Input parameter handling through helper function integration
# 2. Return structure validation patterns
# 3. Helper function dependencies (already tested in test-unit-helper-functions.R)

library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(tidyr)

# Source helper functions first (they are dependencies)
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/endpoint-functions.R")) {
  normalizePath("../..")
} else {
  stop("Cannot find api directory")
}

# Source helper functions which endpoint-functions.R depends on
source(file.path(api_dir, "functions", "helper-functions.R"))

# Note: endpoint-functions.R has global dependencies (pool, dw)
# We test it by examining structure and testing through helper integration

# =============================================================================
# Return structure validation tests
# =============================================================================

test_that("endpoint return structure follows expected pattern", {
  # All endpoint functions should return a list with: links, meta, data
  # We verify this by examining the function code structure

  # Read the function file and check return patterns
  endpoint_code <- readLines(file.path(api_dir, "functions", "endpoint-functions.R"))

  # Check for expected return structure
  return_patterns <- grep("return_list\\s*<-\\s*list\\(", endpoint_code, value = TRUE)

  expect_true(length(return_patterns) > 0)

  # Verify common pattern across all code: links, meta, data
  # Pattern may be split across lines, so check the whole file
  endpoint_text <- paste(endpoint_code, collapse = " ")

  has_links <- any(grepl("links\\s*=\\s*links", endpoint_code))
  has_meta <- any(grepl("meta\\s*=\\s*meta", endpoint_code))
  has_data <- any(grepl("data\\s*=", endpoint_code))

  expect_true(has_links, "Endpoint functions should return 'links'")
  expect_true(has_meta, "Endpoint functions should return 'meta'")
  expect_true(has_data, "Endpoint functions should return 'data'")
})

test_that("endpoint functions use consistent unique identifiers", {
  # Check that endpoints use appropriate unique identifiers for pagination
  endpoint_code <- readLines(file.path(api_dir, "functions", "endpoint-functions.R"))

  # Look for unique_id parameter in sort expressions
  unique_id_patterns <- grep("unique_id\\s*=\\s*\"", endpoint_code, value = TRUE)

  # Should find unique identifiers in code
  expect_true(length(unique_id_patterns) > 0)

  # Check for expected identifiers
  has_symbol <- any(grepl("\"symbol\"", unique_id_patterns))
  has_entity_id <- any(grepl("\"entity_id\"", unique_id_patterns))

  expect_true(has_symbol || has_entity_id,
              "Endpoints should use symbol or entity_id as unique identifier")
})

# =============================================================================
# Parameter validation tests
# =============================================================================

test_that("sort expression parsing works for endpoint default sorts", {
  # Test the sort parameters used by endpoint functions
  sort_exprs <- generate_sort_expressions("symbol", unique_id = "symbol")
  expect_true("symbol" %in% sort_exprs)

  sort_exprs2 <- generate_sort_expressions("entity_id", unique_id = "entity_id")
  expect_true("entity_id" %in% sort_exprs2)

  sort_exprs3 <- generate_sort_expressions("category_id,-n", unique_id = "category_id")
  expect_true("category_id" %in% sort_exprs3)
  expect_true("desc(n)" %in% sort_exprs3)
})

test_that("filter expressions handle empty/null correctly", {
  # Endpoint functions pass various filter states
  expect_equal(generate_filter_expressions(""), "")
  expect_equal(generate_filter_expressions("null"), "")
})

test_that("URLdecoded filters are handled", {
  # Some endpoints URLdecode filters before processing
  # Test that our helper still works with decoded strings
  filter_decoded <- "equals(category,'Definitive')"
  filter_exprs <- generate_filter_expressions(filter_decoded)

  expect_true(length(filter_exprs) > 0)
  expect_true(any(grepl("Definitive", filter_exprs)))
})

# =============================================================================
# generate_tibble_fspec() integration
# =============================================================================

test_that("fspec generation works with endpoint-like data", {
  # Create tibble similar to endpoint output
  endpoint_like_data <- tibble(
    entity_id = 1:5,
    symbol = c("BRCA1", "TP53", "EGFR", "KRAS", "PTEN"),
    category = c("Definitive", "Definitive", "Moderate", "Limited", "Definitive"),
    ndd_phenotype_word = c("Yes", "Yes", "No", "Yes", "No")
  )

  fspec_result <- generate_tibble_fspec(
    endpoint_like_data,
    "entity_id,symbol,category,ndd_phenotype_word"
  )

  expect_true("fspec" %in% names(fspec_result))
  expect_true("key" %in% names(fspec_result$fspec))
  expect_true("filterable" %in% names(fspec_result$fspec))
  expect_true("sortable" %in% names(fspec_result$fspec))
})

test_that("fspec generation handles comparison-table-like data", {
  # Test data similar to generate_comparisons_list output
  comparison_data <- tibble(
    symbol = c("BRCA1", "TP53", "EGFR"),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    SysNDD = c("Definitive", "Definitive", "Moderate"),
    gene2phenotype = c("Definitive", "not listed", "Moderate"),
    panelapp = c("Definitive", "Definitive", "not listed")
  )

  fspec_result <- generate_tibble_fspec(
    comparison_data,
    "symbol,SysNDD,gene2phenotype,panelapp"
  )

  expect_true("fspec" %in% names(fspec_result))
  # fspec is a tibble with a count column showing counts for each field
  expect_true("count" %in% names(fspec_result$fspec))
  expect_equal(nrow(fspec_result$fspec), 4)  # 4 fields specified
})

# =============================================================================
# Cursor pagination integration
# =============================================================================

test_that("cursor pagination works with endpoint-like data", {
  endpoint_like_data <- tibble(
    entity_id = 1:20,
    symbol = paste0("GENE", 1:20)
  )

  # Test pagination with page_size
  pag_result <- generate_cursor_pag_inf(
    endpoint_like_data,
    page_size = 5,
    page_after = 0,
    pagination_identifier = "entity_id"
  )

  expect_equal(nrow(pag_result$data), 5)
  expect_true("meta" %in% names(pag_result))
  expect_equal(pag_result$meta$perPage, 5)
  expect_equal(pag_result$meta$totalItems, 20)
})

test_that("cursor pagination handles 'all' page size", {
  # Endpoints use 'all' as a special page_size value
  endpoint_like_data <- tibble(
    symbol = c("BRCA1", "TP53", "EGFR"),
    category = c("Definitive", "Definitive", "Moderate")
  )

  pag_result <- generate_cursor_pag_inf(
    endpoint_like_data,
    page_size = "all",
    page_after = 0,
    pagination_identifier = "symbol"
  )

  expect_equal(nrow(pag_result$data), 3)
  expect_equal(pag_result$meta$totalItems, 3)
})

# =============================================================================
# Field selection integration
# =============================================================================

test_that("field selection works with endpoint defaults", {
  # Test field selection similar to endpoint usage
  endpoint_data <- tibble(
    entity_id = 1:5,
    symbol = c("BRCA1", "TP53", "EGFR", "KRAS", "PTEN"),
    category = c("Definitive", "Definitive", "Moderate", "Limited", "Definitive"),
    hgnc_id = paste0("HGNC:", 1:5),
    ndd_phenotype_word = c("Yes", "Yes", "No", "Yes", "No")
  )

  # Select subset of fields (as endpoints do)
  selected <- select_tibble_fields(
    endpoint_data,
    "entity_id,symbol,category",
    "entity_id"
  )

  expect_equal(ncol(selected), 3)
  expect_true("entity_id" %in% names(selected))
  expect_true("symbol" %in% names(selected))
  expect_true("category" %in% names(selected))
  expect_false("hgnc_id" %in% names(selected))
})

test_that("field selection with empty fields returns all columns", {
  # Endpoints pass empty string to return all fields
  endpoint_data <- tibble(
    symbol = c("BRCA1", "TP53"),
    category = c("Definitive", "Moderate")
  )

  selected <- select_tibble_fields(endpoint_data, "", "symbol")

  expect_equal(ncol(selected), ncol(endpoint_data))
})

# =============================================================================
# Category normalization patterns
# =============================================================================

test_that("category normalization logic is testable", {
  # Test the pattern used in generate_comparisons_list
  # This tests the case_when logic used to normalize categories
  test_data <- tibble(
    list = c("gene2phenotype", "gene2phenotype", "panelapp", "sfari"),
    category = c("strong", "limited", "3", "1")
  )

  normalized <- test_data %>%
    mutate(category_normalized = case_when(
      list == "gene2phenotype" & category == "strong" ~ "Definitive",
      list == "gene2phenotype" & category == "limited" ~ "Limited",
      list == "panelapp" & category == "3" ~ "Definitive",
      list == "sfari" & category == "1" ~ "Definitive",
      TRUE ~ category
    ))

  expect_equal(normalized$category_normalized[1], "Definitive")
  expect_equal(normalized$category_normalized[2], "Limited")
  expect_equal(normalized$category_normalized[3], "Definitive")
  expect_equal(normalized$category_normalized[4], "Definitive")
})

# =============================================================================
# Inheritance pattern normalization
# =============================================================================

test_that("inheritance pattern normalization matches endpoint logic", {
  # Test the pattern used in generate_stat_tibble
  test_inheritance <- c(
    "X-linked dominant inheritance",
    "Autosomal dominant inheritance",
    "Autosomal recessive inheritance",
    "Mitochondrial inheritance"
  )

  normalized <- case_when(
    str_detect(test_inheritance, "X-linked") ~ "X-linked",
    str_detect(test_inheritance, "Autosomal dominant inheritance") ~ "Autosomal dominant",
    str_detect(test_inheritance, "Autosomal recessive inheritance") ~ "Autosomal recessive",
    TRUE ~ "Other"
  )

  expect_equal(normalized[1], "X-linked")
  expect_equal(normalized[2], "Autosomal dominant")
  expect_equal(normalized[3], "Autosomal recessive")
  expect_equal(normalized[4], "Other")
})

# =============================================================================
# Date and time formatting
# =============================================================================

test_that("execution time formatting matches endpoint pattern", {
  # Endpoints format execution time as "X.XX secs"
  start_time <- Sys.time()
  Sys.sleep(0.1)
  end_time <- Sys.time()

  execution_time <- as.character(paste0(round(end_time - start_time, 2), " secs"))

  expect_true(str_detect(execution_time, "\\d+\\.\\d+ secs"))
})

# =============================================================================
# Pivot wider/longer patterns
# =============================================================================

test_that("pivot_wider pattern for comparison table works", {
  # Test the pattern used in generate_comparisons_list
  test_data <- tibble(
    symbol = c("BRCA1", "BRCA1", "TP53", "TP53"),
    list = c("SysNDD", "gene2phenotype", "SysNDD", "panelapp"),
    category = c("Definitive", "Definitive", "Definitive", "Limited")
  )

  wide_data <- test_data %>%
    pivot_wider(
      names_from = list,
      values_from = category,
      values_fill = "not listed"
    )

  expect_equal(nrow(wide_data), 2)
  expect_true("SysNDD" %in% names(wide_data))
  expect_true("gene2phenotype" %in% names(wide_data))
  expect_true("panelapp" %in% names(wide_data))
  expect_equal(wide_data$gene2phenotype[2], "not listed")
})

test_that("pivot_longer pattern for links works", {
  # Test the pattern used in endpoints to build links
  test_links <- tibble(
    first = "link1",
    `next` = "link2",
    prev = "null"
  )

  long_links <- test_links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link")

  expect_equal(nrow(long_links), 3)
  expect_true("type" %in% names(long_links))
  expect_true("link" %in% names(long_links))
  expect_equal(long_links$type, c("first", "next", "prev"))
})

# =============================================================================
# Nested tibble patterns
# =============================================================================

test_that("nested tibble pattern for statistics works", {
  # Test the pattern used in generate_stat_tibble
  test_stats <- tibble(
    category = c("Definitive", "Definitive", "Moderate", "Moderate"),
    inheritance = c("Autosomal dominant", "X-linked", "Autosomal dominant", "X-linked"),
    n = c(100, 50, 30, 20)
  )

  nested_stats <- test_stats %>%
    mutate(category_group = category) %>%
    group_by(category_group) %>%
    nest() %>%
    ungroup() %>%
    select(category = category_group, groups = data)

  expect_equal(nrow(nested_stats), 2)
  expect_true("groups" %in% names(nested_stats))
  expect_true(is.list(nested_stats$groups))
  expect_equal(nrow(nested_stats$groups[[1]]), 2)
})

# =============================================================================
# Filter replacement patterns
# =============================================================================

test_that("filter replacement for 'All' values works", {
  # Test the pattern used in generate_panels_list
  test_filter <- "equals(category,'All'),any(inheritance_filter,'All')"
  category_values <- c("Definitive", "Moderate", "Limited")
  inheritance_values <- c("Autosomal dominant", "Autosomal recessive", "X-linked")

  replaced_filter <- test_filter %>%
    str_replace(
      "category,'All'",
      paste0("category,", paste(category_values, collapse = ","))
    ) %>%
    str_replace(
      "inheritance_filter,'All'",
      paste0("inheritance_filter,", paste(inheritance_values, collapse = ","))
    )

  expect_true(str_detect(replaced_filter, "category,Definitive,Moderate,Limited"))
  expect_true(str_detect(replaced_filter, "inheritance_filter,Autosomal dominant"))
})
