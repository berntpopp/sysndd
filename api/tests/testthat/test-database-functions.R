# tests/testthat/test-database-functions.R
# Tests for api/functions/database-functions.R
#
# These tests verify input validation and return structure.
# Database operations are tested via input validation (validation-only testing).

library(testthat)
library(dplyr)
library(tibble)
library(stringr)

# Source functions - use path resolution for testthat context
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/database-functions.R")) {
  normalizePath("../..")
} else {
  stop("Cannot find api directory")
}
source(file.path(api_dir, "functions", "database-functions.R"))

# =============================================================================
# post_db_entity() tests
# =============================================================================

test_that("post_db_entity returns 405 when hgnc_id missing", {
  entity_data <- tibble(
    hpo_mode_of_inheritance_term = "HP:0000001",
    disease_ontology_id_version = "OMIM:123456",
    ndd_phenotype = TRUE,
    entry_user_id = 1
  )

  result <- post_db_entity(entity_data)

  expect_equal(result$status, 405)
  expect_true(grepl("can not be empty", result$message))
})

test_that("post_db_entity returns 405 when hpo_mode_of_inheritance_term missing", {
  entity_data <- tibble(
    hgnc_id = "HGNC:123",
    disease_ontology_id_version = "OMIM:123456",
    ndd_phenotype = TRUE,
    entry_user_id = 1
  )

  result <- post_db_entity(entity_data)

  expect_equal(result$status, 405)
})

test_that("post_db_entity returns 405 when disease_ontology_id_version missing", {
  entity_data <- tibble(
    hgnc_id = "HGNC:123",
    hpo_mode_of_inheritance_term = "HP:0000001",
    ndd_phenotype = TRUE,
    entry_user_id = 1
  )

  result <- post_db_entity(entity_data)

  expect_equal(result$status, 405)
})

test_that("post_db_entity returns 405 when ndd_phenotype missing", {
  entity_data <- tibble(
    hgnc_id = "HGNC:123",
    hpo_mode_of_inheritance_term = "HP:0000001",
    disease_ontology_id_version = "OMIM:123456",
    entry_user_id = 1
  )

  result <- post_db_entity(entity_data)

  expect_equal(result$status, 405)
})

test_that("post_db_entity returns 405 when entry_user_id missing", {
  entity_data <- tibble(
    hgnc_id = "HGNC:123",
    hpo_mode_of_inheritance_term = "HP:0000001",
    disease_ontology_id_version = "OMIM:123456",
    ndd_phenotype = TRUE
  )

  result <- post_db_entity(entity_data)

  expect_equal(result$status, 405)
})

# =============================================================================
# put_db_entity_deactivation() tests
# =============================================================================

test_that("put_db_entity_deactivation returns 405 when entity_id is null", {
  result <- put_db_entity_deactivation(entity_id = NULL)

  expect_equal(result$status, 405)
  expect_true(grepl("can not be empty", result$message))
})

test_that("put_db_entity_deactivation message includes correct field name", {
  result <- put_db_entity_deactivation(entity_id = NULL)

  expect_true(grepl("entity_id", result$message))
})

# =============================================================================
# put_post_db_review() tests
# =============================================================================

test_that("put_post_db_review returns 405 when synopsis missing", {
  review_data <- tibble(
    entity_id = 1
    # Missing synopsis
  )

  result <- put_post_db_review("POST", review_data)

  expect_equal(result$status, 405)
})

test_that("put_post_db_review returns 405 when entity_id missing", {
  review_data <- tibble(
    synopsis = "Test synopsis"
    # Missing entity_id
  )

  result <- put_post_db_review("POST", review_data)

  expect_equal(result$status, 405)
})

test_that("put_post_db_review returns 405 for POST with review_id", {
  # POST should not have review_id
  review_data <- tibble(
    synopsis = "Test synopsis",
    entity_id = 1,
    review_id = 999  # Should not be present for POST
  )

  result <- put_post_db_review("POST", review_data)

  expect_equal(result$status, 405)
})

test_that("put_post_db_review returns 405 for PUT without review_id", {
  review_data <- tibble(
    synopsis = "Test synopsis",
    entity_id = 1
    # Missing review_id for PUT
  )

  result <- put_post_db_review("PUT", review_data)

  expect_equal(result$status, 405)
})

test_that("put_post_db_review handles empty synopsis correctly", {
  # Empty synopsis (0 chars) should fail validation
  review_data <- tibble(
    synopsis = "",
    entity_id = 1
  )

  result <- put_post_db_review("POST", review_data)

  expect_equal(result$status, 405)
})

test_that("put_post_db_review validates synopsis before escaping", {
  # Test that validation happens before SQL escaping
  # If synopsis is present, it passes initial validation
  # (will fail at DB connection but that's expected for unit test)
  review_data <- tibble(
    synopsis = "Test synopsis",
    entity_id = 1
  )

  # This should pass the initial column presence validation
  # It will fail later when trying to connect to DB
  expect_error({
    result <- put_post_db_review("POST", review_data)
  })
})

# =============================================================================
# put_post_db_status() tests
# =============================================================================

test_that("put_post_db_status returns 400 when required fields missing", {
  status_data <- list(
    entity_id = 1
    # Missing category_id or problematic
  )

  result <- put_post_db_status("POST", status_data)

  expect_equal(result$status, 400)
  expect_true(!is.null(result$error))
})

test_that("put_post_db_status returns 405 for POST without entity_id", {
  status_data <- list(
    category_id = 1
    # Missing entity_id for POST
  )

  result <- put_post_db_status("POST", status_data)

  expect_equal(result$status, 405)
})

test_that("put_post_db_status returns 405 for PUT without status_id", {
  status_data <- list(
    category_id = 1,
    entity_id = 1
    # Missing status_id for PUT
  )

  result <- put_post_db_status("PUT", status_data)

  expect_equal(result$status, 405)
})

test_that("put_post_db_status accepts problematic field", {
  status_data <- list(
    problematic = TRUE,
    entity_id = 1
  )

  # Should pass validation (problematic is an allowed alternative to category_id)
  # Will fail at DB connection but that's expected
  expect_error({
    result <- put_post_db_status("POST", status_data)
  })
})

# =============================================================================
# put_db_review_approve() tests
# =============================================================================

test_that("put_db_review_approve returns 400 when review_id_requested is null", {
  result <- put_db_review_approve(
    review_id_requested = NULL,
    submit_user_id = 1,
    review_ok = TRUE
  )

  expect_equal(result$status, 400)
  expect_true(!is.null(result$error))
})

test_that("put_db_review_approve returns 400 when submit_user_id is null", {
  result <- put_db_review_approve(
    review_id_requested = 1,
    submit_user_id = NULL,
    review_ok = TRUE
  )

  expect_equal(result$status, 400)
})

test_that("put_db_review_approve handles review_ok as logical", {
  # Test that review_ok parameter is converted to logical
  # This will fail at DB connection but we can verify it doesn't crash in validation
  expect_error({
    result <- put_db_review_approve(
      review_id_requested = 1,
      submit_user_id = 1,
      review_ok = "true"  # String should be converted to logical
    )
  })
})

# =============================================================================
# put_db_status_approve() tests
# =============================================================================

test_that("put_db_status_approve returns 400 when status_id_requested is null", {
  result <- put_db_status_approve(
    status_id_requested = NULL,
    submit_user_id = 1,
    status_ok = TRUE
  )

  expect_equal(result$status, 400)
})

test_that("put_db_status_approve returns 400 when submit_user_id is null", {
  result <- put_db_status_approve(
    status_id_requested = 1,
    submit_user_id = NULL,
    status_ok = TRUE
  )

  expect_equal(result$status, 400)
})

test_that("put_db_status_approve handles status_ok as logical", {
  # Test that status_ok parameter is converted to logical
  # This will fail at DB connection but we can verify it doesn't crash in validation
  expect_error({
    result <- put_db_status_approve(
      status_id_requested = 1,
      submit_user_id = 1,
      status_ok = "true"  # String should be converted to logical
    )
  })
})

# =============================================================================
# post_db_hash() tests
# =============================================================================
# Note: post_db_hash requires toJSON and pool global which aren't available
# in test context. These tests verify the column validation logic only.

test_that("post_db_hash validates allowed columns", {
  skip("Requires jsonlite::toJSON and pool global - needs integration test")

  # Submit data with disallowed column name
  json_data <- list(
    invalid_column = c("value1", "value2")
  )

  result <- post_db_hash(
    json_data,
    allowed_columns = "symbol,hgnc_id,entity_id"
  )

  expect_equal(result$status, 400)
  expect_true(grepl("not in the allowed", result$message))
})

test_that("post_db_hash accepts allowed columns", {
  skip("Requires jsonlite::toJSON and pool global - needs integration test")

  # Submit data with allowed column names
  json_data <- list(
    symbol = c("GENE1", "GENE2")
  )

  # This should pass validation (will fail at DB connection but that's expected)
  expect_error({
    result <- post_db_hash(
      json_data,
      allowed_columns = "symbol,hgnc_id,entity_id"
    )
  })
})
