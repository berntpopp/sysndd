# tests/testthat/test-unit-helper-functions.R
# Unit tests for api/functions/helper-functions.R
#
# These tests cover pure functions that don't require database access.
# Run with: Rscript -e "testthat::test_file('tests/testthat/test-unit-helper-functions.R')"

# Load required libraries
library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(tidyr)

# Source the functions being tested
# Use here::here() approach - find api/ directory and go from there
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/helper-functions.R")) {
  normalizePath("../..")
} else {
  stop("Cannot find api directory")
}
source(file.path(api_dir, "functions", "helper-functions.R"))

# =============================================================================
# is_valid_email() tests
# =============================================================================

test_that("is_valid_email returns TRUE for valid email addresses", {
  expect_true(is_valid_email("test@example.com"))
  expect_true(is_valid_email("user.name@domain.org"))
  expect_true(is_valid_email("user+tag@example.co.uk"))
  expect_true(is_valid_email("USER@CAPS.COM"))
  expect_true(is_valid_email("john.doe123@university.edu"))
})

test_that("is_valid_email returns FALSE for invalid email addresses", {
  expect_false(is_valid_email("not-an-email"))
  expect_false(is_valid_email("missing@"))
  expect_false(is_valid_email("@nodomain.com"))
  expect_false(is_valid_email(""))
  expect_false(is_valid_email("no-at-sign.com"))
})

test_that("is_valid_email handles edge cases", {
  # Single character domain parts should fail (needs 2+ chars in TLD)
  expect_false(is_valid_email("test@example.c"))

  # Numbers in email are valid
  expect_true(is_valid_email("user123@domain456.com"))

  # Dots in local part are valid
  expect_true(is_valid_email("first.last@example.com"))

  # Underscores are valid
  expect_true(is_valid_email("user_name@example.com"))
})


# =============================================================================
# generate_initials() tests
# =============================================================================

test_that("generate_initials creates correct initials from names", {
  expect_equal(generate_initials("John", "Doe"), "JD")
  expect_equal(generate_initials("Ada", "Lovelace"), "AL")
  expect_equal(generate_initials("Marie", "Curie"), "MC")
})

test_that("generate_initials handles single-letter names", {
  expect_equal(generate_initials("A", "B"), "AB")
})

test_that("generate_initials handles lowercase input", {
  # Function takes first char regardless of case
  expect_equal(generate_initials("john", "doe"), "jd")
})


# =============================================================================
# generate_sort_expressions() tests
# =============================================================================

test_that("generate_sort_expressions parses ascending sort", {
  result <- generate_sort_expressions("+name", unique_id = "id")

  expect_true("name" %in% result)
  # unique_id should be appended if not present
  expect_true("id" %in% result)
})

test_that("generate_sort_expressions parses descending sort", {
  result <- generate_sort_expressions("-name", unique_id = "id")

  expect_true("desc(name)" %in% result)
  expect_true("id" %in% result)
})

test_that("generate_sort_expressions handles multiple columns", {
  result <- generate_sort_expressions("+name,-age,+date", unique_id = "id")

  expect_true("name" %in% result)
  expect_true("desc(age)" %in% result)
  expect_true("date" %in% result)
  expect_true("id" %in% result)
})

test_that("generate_sort_expressions defaults to ascending without prefix", {

  result <- generate_sort_expressions("name", unique_id = "id")

  expect_true("name" %in% result)
})

test_that("generate_sort_expressions includes unique_id only once", {
  # When unique_id is already in sort list, don't duplicate
  result <- generate_sort_expressions("+entity_id,-name", unique_id = "entity_id")

  # entity_id should appear only once
  expect_equal(sum(grepl("entity_id", result)), 1)
})


# =============================================================================
# generate_filter_expressions() tests
# =============================================================================

test_that("generate_filter_expressions returns empty string for empty input", {
  expect_equal(generate_filter_expressions(""), "")
})

test_that("generate_filter_expressions returns empty string for 'null' input", {
  expect_equal(generate_filter_expressions("null"), "")
})

test_that("generate_filter_expressions handles contains operation", {
  result <- generate_filter_expressions("contains(name,'John')")
  expect_true(grepl("str_detect", result))
  expect_true(grepl("name", result))
  expect_true(grepl("John", result))
})

test_that("generate_filter_expressions handles equals operation", {
  result <- generate_filter_expressions("equals(status,'active')")
  expect_true(grepl("str_detect", result))
  expect_true(grepl("status", result))
  expect_true(grepl("\\^active\\$", result))  # equals uses ^ and $ anchors
})

test_that("generate_filter_expressions handles any operation with multiple values", {
  result <- generate_filter_expressions("any(category,'A,B,C')")
  expect_true(grepl("str_detect", result))
  expect_true(grepl("category", result))
  expect_true(grepl("A|B|C", result))  # any uses | for alternatives
})

test_that("generate_filter_expressions handles 'and' logical operator", {
  result <- generate_filter_expressions("and(contains(name,'John'),equals(status,'active'))")
  expect_true(grepl("&", result))  # and uses &
})

test_that("generate_filter_expressions handles 'or' logical operator", {
  result <- generate_filter_expressions("or(contains(name,'John'),equals(status,'active'))")
  expect_true(grepl("\\|", result))  # or uses |
})

test_that("generate_filter_expressions throws error for unsupported operations", {
  expect_error(
    generate_filter_expressions("contains(name,'John')", operations_allowed = "fakeop"),
    "not supported"
  )
})


# =============================================================================
# select_tibble_fields() tests
# =============================================================================

test_that("select_tibble_fields selects specific columns", {
  test_data <- tibble(
    entity_id = 1:5,
    name = letters[1:5],
    age = 20:24,
    city = c("NYC", "LA", "SF", "CHI", "BOS")
  )

  result <- select_tibble_fields(test_data, "name,age", unique_id = "entity_id")

  expect_equal(ncol(result), 3)  # entity_id + name + age
  expect_true("entity_id" %in% colnames(result))
  expect_true("name" %in% colnames(result))
  expect_true("age" %in% colnames(result))
  expect_false("city" %in% colnames(result))
})

test_that("select_tibble_fields returns all columns when fields_requested is empty", {
  test_data <- tibble(
    entity_id = 1:3,
    name = letters[1:3],
    value = 10:12
  )

  result <- select_tibble_fields(test_data, "", unique_id = "entity_id")

  expect_equal(ncol(result), 3)
  expect_equal(colnames(result), colnames(test_data))
})

test_that("select_tibble_fields always includes unique_id even if not requested", {
  test_data <- tibble(
    entity_id = 1:3,
    name = letters[1:3],
    value = 10:12
  )

  result <- select_tibble_fields(test_data, "name", unique_id = "entity_id")

  expect_true("entity_id" %in% colnames(result))
  expect_true("name" %in% colnames(result))
})

test_that("select_tibble_fields throws error for non-existent columns", {
  test_data <- tibble(
    entity_id = 1:3,
    name = letters[1:3]
  )

  expect_error(
    select_tibble_fields(test_data, "nonexistent_column", unique_id = "entity_id"),
    "not in the column names"
  )
})


# =============================================================================
# generate_cursor_pag_inf() tests
# =============================================================================

test_that("generate_cursor_pag_inf returns all rows with page_size='all'", {
  test_data <- tibble(
    entity_id = 1:20,
    value = letters[1:20]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = "all", pagination_identifier = "entity_id")

  expect_equal(nrow(result$data), 20)
  expect_equal(result$meta$perPage, 20)
  expect_equal(result$meta$totalItems, 20)
})

test_that("generate_cursor_pag_inf returns correct slice with numeric page_size", {
  test_data <- tibble(
    entity_id = 1:20,
    value = letters[1:20]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = 5, page_after = 0, pagination_identifier = "entity_id")

  expect_equal(nrow(result$data), 5)
  expect_equal(result$meta$perPage, 5)
  expect_equal(result$meta$totalPages, 4)  # 20 / 5 = 4
})

test_that("generate_cursor_pag_inf meta contains expected fields", {
  test_data <- tibble(
    entity_id = 1:10,
    value = letters[1:10]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = 3, pagination_identifier = "entity_id")

  expect_true("perPage" %in% names(result$meta))
  expect_true("currentPage" %in% names(result$meta))
  expect_true("totalPages" %in% names(result$meta))
  expect_true("totalItems" %in% names(result$meta))
})

test_that("generate_cursor_pag_inf links contain expected navigation links", {
  test_data <- tibble(
    entity_id = 1:10,
    value = letters[1:10]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = 3, pagination_identifier = "entity_id")

  expect_true("prev" %in% names(result$links))
  expect_true("self" %in% names(result$links))
  expect_true("next" %in% names(result$links))
  expect_true("last" %in% names(result$links))
})

test_that("generate_cursor_pag_inf returns correct structure", {
  test_data <- tibble(
    entity_id = 1:5,
    value = letters[1:5]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = 2, pagination_identifier = "entity_id")

  expect_true("links" %in% names(result))
  expect_true("meta" %in% names(result))
  expect_true("data" %in% names(result))
})


# =============================================================================
# generate_tibble_fspec() tests
# =============================================================================

test_that("generate_tibble_fspec generates field specs from tibble", {
  test_data <- tibble(
    entity_id = 1:10,
    category = rep(c("A", "B"), 5),
    status = rep(c("active", "inactive"), 5)
  )

  result <- generate_tibble_fspec(test_data, "entity_id,category,status")

  expect_true("fspec" %in% names(result))
  expect_true("key" %in% names(result$fspec))
  expect_true("filterable" %in% names(result$fspec))
  expect_true("sortable" %in% names(result$fspec))
})

test_that("generate_tibble_fspec determines filterable/selectable based on unique values", {
  # Few unique values should be selectable
  # Threshold: >10 unique values -> filterable, <=2 -> selectable, 3-10 -> multi_selectable
  test_data <- tibble(
    entity_id = 1:15,
    binary = rep(c("yes", "no"), length.out = 15),
    multi = rep(c("A", "B", "C", "D"), length.out = 15),
    many = paste0("value", 1:15)  # 15 unique values -> >10 -> filterable
  )

  result <- generate_tibble_fspec(test_data, "binary,multi,many")

  binary_spec <- result$fspec %>% filter(key == "binary")
  multi_spec <- result$fspec %>% filter(key == "multi")
  many_spec <- result$fspec %>% filter(key == "many")

  # 2 unique values -> selectable
  expect_true(binary_spec$selectable)
  # 4 unique values -> multi_selectable
  expect_true(multi_spec$multi_selectable)
  # 15 unique values (>10) -> filterable
  expect_true(many_spec$filterable)
})

test_that("generate_tibble_fspec handles fspecInput filtering", {
  test_data <- tibble(
    entity_id = 1:5,
    col_a = letters[1:5],
    col_b = LETTERS[1:5],
    col_c = 1:5
  )

  result <- generate_tibble_fspec(test_data, "entity_id,col_a")

  # Only requested columns should be in output
  expect_equal(nrow(result$fspec), 2)
  expect_true("entity_id" %in% result$fspec$key)
  expect_true("col_a" %in% result$fspec$key)
  expect_false("col_b" %in% result$fspec$key)
})


# =============================================================================
# generate_panel_hash() and generate_json_hash() tests
# =============================================================================

test_that("generate_panel_hash produces consistent hash for same input", {
  genes <- c("HGNC:12345", "HGNC:67890")

  hash1 <- generate_panel_hash(genes)
  hash2 <- generate_panel_hash(genes)

  expect_equal(hash1, hash2)
})

test_that("generate_panel_hash produces different hash for different inputs", {
  genes1 <- c("HGNC:12345", "HGNC:67890")
  genes2 <- c("HGNC:12345", "HGNC:99999")

  hash1 <- generate_panel_hash(genes1)
  hash2 <- generate_panel_hash(genes2)

  expect_false(hash1 == hash2)
})

test_that("generate_panel_hash removes HGNC prefix before hashing", {
  # Same identifiers with and without HGNC prefix should produce same hash
  genes_with_prefix <- c("HGNC:12345", "HGNC:67890")
  genes_without_prefix <- c("12345", "67890")

  hash_with <- generate_panel_hash(genes_with_prefix)
  hash_without <- generate_panel_hash(genes_without_prefix)

  expect_equal(hash_with, hash_without)
})

test_that("generate_json_hash produces consistent hash for same input", {
  json_string <- '{"key": "value", "number": 123}'

  hash1 <- generate_json_hash(json_string)
  hash2 <- generate_json_hash(json_string)

  expect_equal(hash1, hash2)
})

test_that("generate_json_hash produces different hash for different inputs", {
  json1 <- '{"key": "value1"}'
  json2 <- '{"key": "value2"}'

  hash1 <- generate_json_hash(json1)
  hash2 <- generate_json_hash(json2)

  expect_false(hash1 == hash2)
})


# =============================================================================
# nest_gene_tibble() tests
# =============================================================================

test_that("nest_gene_tibble groups by symbol/hgnc_id/entities_count", {
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    hgnc_id = c(100, 100, 200),
    entities_count = c(2, 2, 1),
    extra_col = c("a", "b", "c")
  )

  result <- nest_gene_tibble(test_data)

  # Should have 2 rows (one per unique symbol/hgnc_id/entities_count combo)
  expect_equal(nrow(result), 2)
  expect_true("entities" %in% colnames(result))
})

test_that("nest_gene_tibble result has entities as list-column", {
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    hgnc_id = c(100, 100, 200),
    entities_count = c(2, 2, 1),
    extra_col = c("a", "b", "c")
  )

  result <- nest_gene_tibble(test_data)

  expect_true(is.list(result$entities))
  # First group (GENE1) should have 2 rows in its nested tibble
  expect_equal(nrow(result$entities[[1]]), 2)
})
