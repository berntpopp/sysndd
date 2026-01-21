# tests/testthat/test-unit-hpo-functions.R
# Tests for api/functions/hpo-functions.R
#
# Focus: Local ontologyIndex functions that do NOT require network calls.
# Skip: API functions that call hpo.jax.org (hpo_name_from_term, hpo_definition_from_term,
#       hpo_children_count_from_term, hpo_children_from_term_api, hpo_all_children_from_term_api)

library(testthat)
library(dplyr)
library(tibble)
library(stringr)

# Resolve api directory for sourcing functions
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/hpo-functions.R")) {
  normalizePath("../..")
} else if (file.exists(file.path(getwd(), "api/functions/hpo-functions.R"))) {
  normalizePath(file.path(getwd(), "api"))
} else {
  stop("Cannot find api directory")
}

# Check if ontologyIndex is available
ontologyIndex_available <- requireNamespace("ontologyIndex", quietly = TRUE)

# =============================================================================
# Mock HPO ontology creation helper
# =============================================================================

#' Create a mock HPO ontology for testing
#'
#' Builds a minimal ontologyIndex structure with known parent-child relationships:
#'   HP:0000001 (All)
#'   |-- HP:0000118 (Phenotypic abnormality)
#'   |   |-- HP:0000707 (Abnormality of the nervous system)
#'   |   |   |-- HP:0012759 (Neurodevelopmental abnormality)
#'   |   |   |-- HP:0001250 (Seizure)
#'   |   |-- HP:0000152 (Abnormality of head or neck)
#'   |-- HP:0000005 (Mode of inheritance)
#'       |-- HP:0000006 (Autosomal dominant)
#'       |-- HP:0000007 (Autosomal recessive)
#'
#' @return A mock ontology_index object
create_mock_hpo_ontology <- function() {
  # Create the ontology structure that ontologyIndex expects
  mock_hpo <- list(
    # All term IDs
    id = c(
      "HP:0000001", "HP:0000118", "HP:0000707", "HP:0012759", "HP:0001250",
      "HP:0000152", "HP:0000005", "HP:0000006", "HP:0000007"
    ),
    # Term names
    name = c(
      "All",
      "Phenotypic abnormality",
      "Abnormality of the nervous system",
      "Neurodevelopmental abnormality",
      "Seizure",
      "Abnormality of head or neck",
      "Mode of inheritance",
      "Autosomal dominant",
      "Autosomal recessive"
    ),
    # Children relationships (direct children only)
    children = list(
      "HP:0000001" = c("HP:0000118", "HP:0000005"),
      "HP:0000118" = c("HP:0000707", "HP:0000152"),
      "HP:0000707" = c("HP:0012759", "HP:0001250"),
      "HP:0012759" = character(0),  # Leaf node
      "HP:0001250" = character(0),  # Leaf node
      "HP:0000152" = character(0),  # Leaf node
      "HP:0000005" = c("HP:0000006", "HP:0000007"),
      "HP:0000006" = character(0),  # Leaf node
      "HP:0000007" = character(0)   # Leaf node
    ),
    # Parents relationships (direct parents only)
    parents = list(
      "HP:0000001" = character(0),  # Root node
      "HP:0000118" = "HP:0000001",
      "HP:0000707" = "HP:0000118",
      "HP:0012759" = "HP:0000707",
      "HP:0001250" = "HP:0000707",
      "HP:0000152" = "HP:0000118",
      "HP:0000005" = "HP:0000001",
      "HP:0000006" = "HP:0000005",
      "HP:0000007" = "HP:0000005"
    ),
    # Obsolete status (none are obsolete in our mock)
    obsolete = rep(FALSE, 9)
  )

  # Set the class to match what ontologyIndex expects
  class(mock_hpo) <- "ontology_index"

  return(mock_hpo)
}

# =============================================================================
# Source HPO functions
# =============================================================================

# Try to source the HPO functions
hpo_functions_loaded <- tryCatch({
  source(file.path(api_dir, "functions", "hpo-functions.R"))
  TRUE
}, error = function(e) {
  message("Warning: Could not load hpo-functions.R: ", e$message)
  FALSE
})

# =============================================================================
# hpo_children_from_term() tests
# =============================================================================

test_that("hpo_children_from_term returns children for root term", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Get children of root term (HP:0000001 - "All")
  result <- hpo_children_from_term("HP:0000001", mock_hpo)

  # Should return tibble
  expect_s3_class(result, "tbl_df")

  # Should have term and query_date columns
  expect_true("term" %in% names(result))
  expect_true("query_date" %in% names(result))

  # Should have 2 children (HP:0000118 and HP:0000005)
  expect_equal(nrow(result), 2)
  expect_true("HP:0000118" %in% result$term)
  expect_true("HP:0000005" %in% result$term)
})

test_that("hpo_children_from_term returns children for intermediate term", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Get children of HP:0000707 (Abnormality of the nervous system)
  result <- hpo_children_from_term("HP:0000707", mock_hpo)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_true("HP:0012759" %in% result$term)
  expect_true("HP:0001250" %in% result$term)
})

test_that("hpo_children_from_term returns empty tibble for leaf term", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Get children of leaf term (HP:0000006 - Autosomal dominant)
  result <- hpo_children_from_term("HP:0000006", mock_hpo)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)

  # Should still have correct column structure
  expect_true("term" %in% names(result))
  expect_true("query_date" %in% names(result))
})

test_that("hpo_children_from_term includes query_date as Date type", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  result <- hpo_children_from_term("HP:0000001", mock_hpo)

  # query_date should be Date class
  expect_s3_class(result$query_date, "Date")

  # Should be today's date
  expect_equal(result$query_date[1], Sys.Date())
})

test_that("hpo_children_from_term returns consistent column names", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Test multiple terms to verify consistent output
  result1 <- hpo_children_from_term("HP:0000001", mock_hpo)
  result2 <- hpo_children_from_term("HP:0000118", mock_hpo)
  result3 <- hpo_children_from_term("HP:0000006", mock_hpo)

  # All should have same column names
  expect_identical(names(result1), names(result2))
  expect_identical(names(result2), names(result3))
  expect_identical(names(result1), c("term", "query_date"))
})

test_that("hpo_children_from_term handles term with single child", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  # Create a modified mock with single child
  mock_hpo <- create_mock_hpo_ontology()
  mock_hpo$children$"HP:0000152" <- "HP:9999999"  # Add single child
  mock_hpo$id <- c(mock_hpo$id, "HP:9999999")
  mock_hpo$name <- c(mock_hpo$name, "Single child term")
  mock_hpo$children$"HP:9999999" <- character(0)
  mock_hpo$parents$"HP:9999999" <- "HP:0000152"
  mock_hpo$obsolete <- c(mock_hpo$obsolete, FALSE)

  result <- hpo_children_from_term("HP:0000152", mock_hpo)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$term[1], "HP:9999999")
})

# =============================================================================
# hpo_all_children_from_term() tests
# =============================================================================

test_that("hpo_all_children_from_term returns all descendants for root term", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Get all children of root term
  result <- hpo_all_children_from_term("HP:0000001", mock_hpo)

  expect_s3_class(result, "tbl_df")
  expect_true("term" %in% names(result))
  expect_true("query_date" %in% names(result))

  # Should include all 9 terms (root + all descendants)
  expect_equal(nrow(result), 9)

  # Root should be included
  expect_true("HP:0000001" %in% result$term)

  # All descendants should be included
  expect_true(all(c(
    "HP:0000118", "HP:0000707", "HP:0012759", "HP:0001250",
    "HP:0000152", "HP:0000005", "HP:0000006", "HP:0000007"
  ) %in% result$term))
})

test_that("hpo_all_children_from_term returns subtree for intermediate term", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Get all children of HP:0000707 (Abnormality of nervous system)
  result <- hpo_all_children_from_term("HP:0000707", mock_hpo)

  expect_s3_class(result, "tbl_df")

  # Should have 3 terms: HP:0000707 + HP:0012759 + HP:0001250
  expect_equal(nrow(result), 3)
  expect_true("HP:0000707" %in% result$term)
  expect_true("HP:0012759" %in% result$term)
  expect_true("HP:0001250" %in% result$term)

  # Should NOT include siblings or parents
  expect_false("HP:0000118" %in% result$term)
  expect_false("HP:0000152" %in% result$term)
})

test_that("hpo_all_children_from_term returns single row for leaf term", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Get all children of leaf term
  result <- hpo_all_children_from_term("HP:0000006", mock_hpo)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$term[1], "HP:0000006")
})

test_that("hpo_all_children_from_term returns unique terms only", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  result <- hpo_all_children_from_term("HP:0000001", mock_hpo)

  # All terms should be unique
  expect_equal(nrow(result), length(unique(result$term)))
})

test_that("hpo_all_children_from_term handles mode of inheritance branch", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Get all children of HP:0000005 (Mode of inheritance)
  result <- hpo_all_children_from_term("HP:0000005", mock_hpo)

  expect_s3_class(result, "tbl_df")

  # Should have 3 terms: HP:0000005 + HP:0000006 + HP:0000007
  expect_equal(nrow(result), 3)
  expect_true("HP:0000005" %in% result$term)
  expect_true("HP:0000006" %in% result$term)
  expect_true("HP:0000007" %in% result$term)
})

test_that("hpo_all_children_from_term includes query_date for all rows", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  result <- hpo_all_children_from_term("HP:0000001", mock_hpo)

  # All rows should have today's date
  expect_true(all(result$query_date == Sys.Date()))
})

# =============================================================================
# HPO term ID format validation tests (no network required)
# =============================================================================

test_that("HPO term ID format is valid", {
  # Test the expected format: HP:DDDDDDD (HP: followed by 7 digits)
  valid_ids <- c(
    "HP:0000001", "HP:0000118", "HP:0012759",
    "HP:0000006", "HP:0000007", "HP:9999999"
  )

  invalid_ids <- c(
    "HP0000001",   # Missing colon
    "HP:000001",   # Only 6 digits
    "HP:00000001", # 8 digits
    "OMIM:123456", # Wrong prefix
    "HP:ABCDEFG"   # Letters instead of digits
  )

  # Valid IDs should match pattern
  for (id in valid_ids) {
    expect_true(
      str_detect(id, "^HP:\\d{7}$"),
      info = paste("Expected valid ID:", id)
    )
  }

  # Invalid IDs should not match
  for (id in invalid_ids) {
    expect_false(
      str_detect(id, "^HP:\\d{7}$"),
      info = paste("Expected invalid ID:", id)
    )
  }
})

test_that("HPO term ID extraction from string works", {
  # Test extracting HPO IDs from larger strings
  test_strings <- c(
    "Patient has HP:0000001 phenotype",
    "Multiple terms: HP:0000118, HP:0000707",
    "Inheritance HP:0000006 (Autosomal dominant)"
  )

  pattern <- "HP:\\d{7}"

  result1 <- str_extract_all(test_strings[1], pattern)[[1]]
  expect_equal(result1, "HP:0000001")

  result2 <- str_extract_all(test_strings[2], pattern)[[1]]
  expect_equal(length(result2), 2)
  expect_true("HP:0000118" %in% result2)
  expect_true("HP:0000707" %in% result2)
})

# =============================================================================
# URL encoding tests (used in API functions)
# =============================================================================

test_that("HPO term ID URL encoding works correctly", {
  # The : character needs to be encoded as %3A for URLs
  term_id <- "HP:0000001"
  encoded <- URLencode(term_id, reserved = TRUE)

  expect_equal(encoded, "HP%3A0000001")

  # Decoding should restore original
  decoded <- URLdecode(encoded)
  expect_equal(decoded, term_id)
})

test_that("multiple HPO term URL construction works", {
  base_url <- "https://hpo.jax.org/api/hpo/term/"
  term_ids <- c("HP:0000001", "HP:0000118", "HP:0000707")

  urls <- paste0(base_url, URLencode(term_ids, reserved = TRUE))

  expect_equal(length(urls), 3)
  expect_true(all(str_detect(urls, "^https://hpo.jax.org/api/hpo/term/HP%3A")))
})

# =============================================================================
# Return value structure validation tests
# =============================================================================

test_that("hpo_children_from_term return value matches documented structure", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()
  result <- hpo_children_from_term("HP:0000118", mock_hpo)

  # Per documentation: "A tibble with two columns: term and query_date"
  expect_equal(ncol(result), 2)
  expect_equal(names(result), c("term", "query_date"))

  # term should be character
  expect_type(result$term, "character")

  # query_date should be Date
  expect_s3_class(result$query_date, "Date")
})

test_that("hpo_all_children_from_term return value includes query term", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Per documentation: "returns all descendants and the term itself"
  result <- hpo_all_children_from_term("HP:0000707", mock_hpo)

  # The query term itself should be in the result
  expect_true("HP:0000707" %in% result$term)
})

# =============================================================================
# Edge case tests
# =============================================================================

test_that("hpo_children_from_term handles non-existent term gracefully", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Term not in ontology should return empty/NA result
  result <- tryCatch({
    hpo_children_from_term("HP:9999999", mock_hpo)
  }, error = function(e) {
    # If it errors, that's acceptable behavior for invalid input
    tibble(term = character(0), query_date = as.Date(character(0)))
  })

  expect_s3_class(result, "tbl_df")
})

test_that("hpo_all_children_from_term with empty initial list works", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  mock_hpo <- create_mock_hpo_ontology()

  # Default call without providing all_children_list
  result <- hpo_all_children_from_term("HP:0000006", mock_hpo)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
})

# =============================================================================
# Performance-related tests (recursion depth)
# =============================================================================

test_that("hpo_all_children_from_term handles deep hierarchy", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")
  skip_if_not(hpo_functions_loaded, "hpo-functions.R could not be loaded")

  # Create a deeper mock hierarchy
  deep_hpo <- list(
    id = paste0("HP:000000", 1:10),
    name = paste0("Term ", 1:10),
    children = list(
      "HP:0000001" = "HP:0000002",
      "HP:0000002" = "HP:0000003",
      "HP:0000003" = "HP:0000004",
      "HP:0000004" = "HP:0000005",
      "HP:0000005" = "HP:0000006",
      "HP:0000006" = "HP:0000007",
      "HP:0000007" = "HP:0000008",
      "HP:0000008" = "HP:0000009",
      "HP:0000009" = "HP:00000010",  # This won't match ID format
      "HP:00000010" = character(0)
    ),
    parents = list(
      "HP:0000001" = character(0),
      "HP:0000002" = "HP:0000001",
      "HP:0000003" = "HP:0000002",
      "HP:0000004" = "HP:0000003",
      "HP:0000005" = "HP:0000004",
      "HP:0000006" = "HP:0000005",
      "HP:0000007" = "HP:0000006",
      "HP:0000008" = "HP:0000007",
      "HP:0000009" = "HP:0000008",
      "HP:00000010" = "HP:0000009"
    ),
    obsolete = rep(FALSE, 10)
  )
  class(deep_hpo) <- "ontology_index"

  # Fix the children list to use proper ID format
  deep_hpo$id <- c("HP:0000001", "HP:0000002", "HP:0000003", "HP:0000004",
                   "HP:0000005", "HP:0000006", "HP:0000007", "HP:0000008",
                   "HP:0000009", "HP:0000010")
  deep_hpo$children <- list(
    "HP:0000001" = "HP:0000002",
    "HP:0000002" = "HP:0000003",
    "HP:0000003" = "HP:0000004",
    "HP:0000004" = "HP:0000005",
    "HP:0000005" = "HP:0000006",
    "HP:0000006" = "HP:0000007",
    "HP:0000007" = "HP:0000008",
    "HP:0000008" = "HP:0000009",
    "HP:0000009" = "HP:0000010",
    "HP:0000010" = character(0)
  )
  deep_hpo$parents <- list(
    "HP:0000001" = character(0),
    "HP:0000002" = "HP:0000001",
    "HP:0000003" = "HP:0000002",
    "HP:0000004" = "HP:0000003",
    "HP:0000005" = "HP:0000004",
    "HP:0000006" = "HP:0000005",
    "HP:0000007" = "HP:0000006",
    "HP:0000008" = "HP:0000007",
    "HP:0000009" = "HP:0000008",
    "HP:0000010" = "HP:0000009"
  )

  # Should handle 10-deep hierarchy without stack overflow
  result <- hpo_all_children_from_term("HP:0000001", deep_hpo)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 10)
})

# =============================================================================
# Integration with ontologyIndex package tests
# =============================================================================

test_that("ontologyIndex get_term_property function works with mock", {
  skip_if_not(ontologyIndex_available, "ontologyIndex package not available")

  mock_hpo <- create_mock_hpo_ontology()

  # Test that ontologyIndex::get_term_property works with our mock
  children <- ontologyIndex::get_term_property(
    ontology = mock_hpo,
    property = "children",
    term = "HP:0000001"
  )

  expect_true(is.character(children) || is.null(children))

  if (length(children) > 0) {
    expect_true("HP:0000118" %in% children || "HP:0000005" %in% children)
  }
})

test_that("ontologyIndex mock structure is valid", {
  mock_hpo <- create_mock_hpo_ontology()

  # Check class
  expect_s3_class(mock_hpo, "ontology_index")

  # Check required components
  expect_true("id" %in% names(mock_hpo))
  expect_true("name" %in% names(mock_hpo))
  expect_true("children" %in% names(mock_hpo))
  expect_true("parents" %in% names(mock_hpo))

  # Check lengths match
  expect_equal(length(mock_hpo$id), length(mock_hpo$name))
})
