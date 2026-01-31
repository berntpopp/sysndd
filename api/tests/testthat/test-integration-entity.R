# tests/testthat/test-integration-entity.R
# Integration tests for entity operations
#
# These tests validate entity data structures and helper function behavior
# using the sorting, filtering, and pagination helpers from helper-functions.R.

library(testthat)
library(dplyr)
library(tibble)
library(stringr)

# Source the helper functions used by entity endpoints
# Uses helper-paths.R (loaded automatically by setup.R)
# Use local = FALSE to make functions available in test scope
source_api_file("functions/helper-functions.R", local = FALSE)

# =============================================================================
# Entity Data Structure Tests
# =============================================================================

test_that("entity tibble can be created with required fields", {
  entity <- tibble(
    entity_id = 1,
    hgnc_id = "HGNC:12345",
    symbol = "TEST1",
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = "OMIM:123456",
    ndd_phenotype = TRUE,
    entry_user_id = 1
  )

  expect_s3_class(entity, "tbl_df")
  expect_equal(nrow(entity), 1)
  expect_true(all(c("entity_id", "hgnc_id", "symbol") %in% names(entity)))
})

test_that("entity data validates required columns", {
  # Simulate the validation logic from post_db_entity
  required_cols <- c(
    "hgnc_id",
    "hpo_mode_of_inheritance_term",
    "disease_ontology_id_version",
    "ndd_phenotype",
    "entry_user_id"
  )

  # Complete entity should pass
  complete_entity <- tibble(
    hgnc_id = "HGNC:12345",
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = "OMIM:123456",
    ndd_phenotype = TRUE,
    entry_user_id = 1
  )

  expect_true(all(required_cols %in% names(complete_entity)))

  # Incomplete entity should fail
  incomplete_entity <- tibble(
    hgnc_id = "HGNC:12345",
    # Missing other required fields
    entry_user_id = 1
  )

  expect_false(all(required_cols %in% names(incomplete_entity)))
})


# =============================================================================
# Entity Sorting Tests
# =============================================================================

test_that("entity sorting works with generate_sort_expressions", {
  entities <- tibble(
    entity_id = c(3, 1, 2),
    symbol = c("ZZEF1", "AARS1", "MECP2"),
    category = c("Definitive", "Moderate", "Definitive")
  )

  # Generate sort expressions
  sort_exprs <- generate_sort_expressions("+symbol", unique_id = "entity_id")

  # Apply sorting
  sorted <- entities %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # Should be sorted by symbol ascending
  expect_equal(sorted$symbol[1], "AARS1")
  expect_equal(sorted$symbol[3], "ZZEF1")
})

test_that("entity sorting handles descending order", {
  entities <- tibble(
    entity_id = c(1, 2, 3),
    symbol = c("AARS1", "MECP2", "ZZEF1"),
    category = c("Definitive", "Moderate", "Definitive")
  )

  sort_exprs <- generate_sort_expressions("-symbol", unique_id = "entity_id")
  sorted <- entities %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # Should be sorted by symbol descending
  expect_equal(sorted$symbol[1], "ZZEF1")
  expect_equal(sorted$symbol[3], "AARS1")
})


# =============================================================================
# Entity Field Selection Tests
# =============================================================================

test_that("select_tibble_fields returns requested entity fields", {
  entities <- tibble(
    entity_id = 1:3,
    symbol = c("AARS1", "MECP2", "ZZEF1"),
    category = c("Definitive", "Moderate", "Definitive"),
    ndd_phenotype = c(TRUE, TRUE, FALSE),
    extra_field = c("a", "b", "c")
  )

  selected <- select_tibble_fields(entities, "symbol,category", unique_id = "entity_id")

  # Should have entity_id (always included), symbol, and category
  expect_equal(names(selected), c("entity_id", "symbol", "category"))
})

test_that("select_tibble_fields returns all fields when empty string", {
  entities <- tibble(
    entity_id = 1:3,
    symbol = c("AARS1", "MECP2", "ZZEF1"),
    category = c("Definitive", "Moderate", "Definitive")
  )

  selected <- select_tibble_fields(entities, "", unique_id = "entity_id")

  # Should have all columns
  expect_equal(names(selected), names(entities))
})

test_that("select_tibble_fields throws error for invalid fields", {
  entities <- tibble(
    entity_id = 1:3,
    symbol = c("AARS1", "MECP2", "ZZEF1")
  )

  expect_error(
    select_tibble_fields(entities, "nonexistent_field", unique_id = "entity_id"),
    "not in the column names"
  )
})


# =============================================================================
# Entity Pagination Tests
# =============================================================================

test_that("generate_cursor_pag_inf paginates entity data", {
  entities <- tibble(
    entity_id = 1:10,
    symbol = paste0("GENE", 1:10)
  )

  result <- generate_cursor_pag_inf(
    entities,
    page_size = 3,
    page_after = 0,
    pagination_identifier = "entity_id"
  )

  # Should return list with links, meta, and data
  expect_true(all(c("links", "meta", "data") %in% names(result)))

  # Data should have 3 rows (page_size)
  expect_equal(nrow(result$data), 3)

  # First entity should be entity_id 1
  expect_equal(result$data$entity_id[1], 1)
})

test_that("generate_cursor_pag_inf handles page_size='all'", {
  entities <- tibble(
    entity_id = 1:10,
    symbol = paste0("GENE", 1:10)
  )

  result <- generate_cursor_pag_inf(
    entities,
    page_size = "all",
    page_after = 0,
    pagination_identifier = "entity_id"
  )

  # Should return all 10 rows
  expect_equal(nrow(result$data), 10)
})
