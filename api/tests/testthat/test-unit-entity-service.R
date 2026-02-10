# tests/testthat/test-unit-entity-service.R
# Unit tests for entity-service.R
#
# Verifies:
# 1. Service functions use svc_entity_ prefix (no naming collision with repository)
# 2. svc_entity_validate correctly validates entity data
# 3. Repository functions entity_create/entity_deactivate are not shadowed

library(testthat)
library(tibble)

# Source the error helpers (needed by entity-service.R)
source_api_file("core/errors.R", local = FALSE)

# Source the entity service
source_api_file("services/entity-service.R", local = FALSE)

# Source db-helpers (needed for db_with_transaction)
source_api_file("functions/db-helpers.R", local = FALSE)

# Source repository functions (order matters: repo after service to confirm no shadowing)
source_api_file("functions/entity-repository.R", local = FALSE)
source_api_file("functions/review-repository.R", local = FALSE)
source_api_file("functions/status-repository.R", local = FALSE)
source_api_file("functions/phenotype-repository.R", local = FALSE)
source_api_file("functions/ontology-repository.R", local = FALSE)
source_api_file("functions/publication-repository.R", local = FALSE)

# =============================================================================
# Service Function Naming Tests
# =============================================================================

test_that("service functions exist with svc_entity_ prefix", {
  expect_true(is.function(svc_entity_validate))
  expect_true(is.function(svc_entity_create))
  expect_true(is.function(svc_entity_deactivate))
  expect_true(is.function(svc_entity_get_full))
  expect_true(is.function(svc_entity_check_duplicate))
  expect_true(is.function(svc_entity_create_with_review_status))
  expect_true(is.function(svc_entity_create_full))
})

test_that("repository functions are not shadowed by service functions", {
  # entity_create from repository takes 2 args (entity_data, conn)
  repo_params <- names(formals(entity_create))
  expect_equal(repo_params, c("entity_data", "conn"))

  # entity_deactivate from repository takes 2 args (entity_id, replacement_id)
  repo_deactivate_params <- names(formals(entity_deactivate))
  expect_equal(repo_deactivate_params, c("entity_id", "replacement_id"))
})

test_that("service functions have correct signatures", {
  # svc_entity_create takes 3 args: entity_data, user_id, pool
  svc_params <- names(formals(svc_entity_create))
  expect_equal(svc_params, c("entity_data", "user_id", "pool"))

  # svc_entity_deactivate takes 3 args: entity_id, replacement, pool
  svc_deactivate_params <- names(formals(svc_entity_deactivate))
  expect_equal(svc_deactivate_params, c("entity_id", "replacement", "pool"))

  # svc_entity_validate takes 1 arg: entity_data
  svc_validate_params <- names(formals(svc_entity_validate))
  expect_equal(svc_validate_params, "entity_data")
})

# =============================================================================
# svc_entity_validate Tests
# =============================================================================

test_that("svc_entity_validate accepts valid entity data", {
  valid_data <- list(
    hgnc_id = 1234,
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = "ORDO:123",
    ndd_phenotype = "Intellectual disability"
  )

  expect_true(svc_entity_validate(valid_data))
})

test_that("svc_entity_validate rejects missing required fields", {
  incomplete_data <- list(
    hgnc_id = 1234
    # Missing: hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype
  )

  expect_error(
    svc_entity_validate(incomplete_data),
    "Missing required fields"
  )
})

test_that("svc_entity_validate rejects empty values", {
  empty_field_data <- list(
    hgnc_id = 1234,
    hpo_mode_of_inheritance_term = "",
    disease_ontology_id_version = "ORDO:123",
    ndd_phenotype = "Intellectual disability"
  )

  expect_error(
    svc_entity_validate(empty_field_data),
    "cannot be empty"
  )
})

test_that("svc_entity_validate rejects NA values", {
  na_field_data <- list(
    hgnc_id = NA,
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = "ORDO:123",
    ndd_phenotype = "Intellectual disability"
  )

  expect_error(
    svc_entity_validate(na_field_data),
    "cannot be empty"
  )
})

test_that("svc_entity_validate rejects NULL values", {
  null_field_data <- list(
    hgnc_id = 1234,
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = NULL,
    ndd_phenotype = "Intellectual disability"
  )

  # NULL field is effectively missing from the list
  expect_error(
    svc_entity_validate(null_field_data),
    "Missing required fields|cannot be empty"
  )
})

test_that("svc_entity_validate handles tibble input", {
  valid_tibble <- tibble::tibble(
    hgnc_id = 1234,
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = "ORDO:123",
    ndd_phenotype = "Intellectual disability"
  )

  expect_true(svc_entity_validate(valid_tibble))
})

test_that("svc_entity_validate rejects whitespace-only string values", {
  whitespace_data <- list(
    hgnc_id = 1234,
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = "   ",
    ndd_phenotype = "Intellectual disability"
  )

  expect_error(
    svc_entity_validate(whitespace_data),
    "cannot be empty"
  )
})

# =============================================================================
# No-collision Regression Test
# =============================================================================

test_that("calling entity_create with 1 arg does not hit service function", {
  # The key regression test: entity_create should accept entity_data
  # (and optional conn) without requiring user_id and pool. This confirms
  # the repository version is the one exposed, not the service version.
  #
  # Before the fix, entity_create was the service version (3 args),
  # so calling with 1 arg would error: "argument 'user_id' is missing"
  #
  # We can't actually create the entity without a DB, but we CAN verify
  # the function signature. conn has a default (NULL) so it's optional.
  params <- formals(entity_create)
  expect_equal(names(params), c("entity_data", "conn"))
  expect_null(params$conn)
})

test_that("calling entity_deactivate with 1-2 args does not hit service function", {
  # Similar regression test: entity_deactivate repository version takes
  # (entity_id, replacement_id = NULL), not (entity_id, replacement, pool)
  params <- formals(entity_deactivate)
  expect_equal(length(params), 2)
  expect_true("replacement_id" %in% names(params))
  # The service version uses "replacement" (not "replacement_id")
  expect_false("pool" %in% names(params))
})

# =============================================================================
# svc_entity_create_full Signature Tests
# =============================================================================

test_that("svc_entity_create_full has correct signature", {
  params <- names(formals(svc_entity_create_full))
  expect_equal(params, c(
    "entity_data", "review_data", "status_data",
    "publications", "phenotypes", "variation_ontology",
    "direct_approval", "approving_user_id", "pool"
  ))
})

test_that("svc_entity_create_full has correct defaults", {
  defaults <- formals(svc_entity_create_full)
  expect_null(defaults$publications)
  expect_null(defaults$phenotypes)
  expect_null(defaults$variation_ontology)
  expect_false(defaults$direct_approval)
  expect_null(defaults$approving_user_id)
})

# =============================================================================
# Repository conn Parameter Tests
# =============================================================================

test_that("repository functions accept optional conn parameter", {
  # entity_create
  expect_true("conn" %in% names(formals(entity_create)))
  expect_null(formals(entity_create)$conn)

  # review_create
  expect_true("conn" %in% names(formals(review_create)))
  expect_null(formals(review_create)$conn)

  # status_create
  expect_true("conn" %in% names(formals(status_create)))
  expect_null(formals(status_create)$conn)

  # phenotype_connect_to_review
  expect_true("conn" %in% names(formals(phenotype_connect_to_review)))
  expect_null(formals(phenotype_connect_to_review)$conn)

  # variation_ontology_connect_to_review
  expect_true("conn" %in% names(formals(variation_ontology_connect_to_review)))
  expect_null(formals(variation_ontology_connect_to_review)$conn)

  # publication_connect_to_review
  expect_true("conn" %in% names(formals(publication_connect_to_review)))
  expect_null(formals(publication_connect_to_review)$conn)
})

# =============================================================================
# svc_entity_create_full Error-Handling Contract Tests
# =============================================================================

test_that("svc_entity_create_full returns 409 when duplicate detected", {
  # Mock dependencies
  local_mocked_bindings(
    svc_entity_validate = function(entity_data) TRUE,
    svc_entity_check_duplicate = function(entity_data, pool) {
      # Return non-NULL to simulate duplicate found
      list(entity_id = 999)
    }
  )

  # Minimal valid arguments
  entity_data <- list(
    hgnc_id = 1,
    disease_ontology_id_version = "MONDO:0000001",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = "Definitive"
  )
  review_data <- list(synopsis = "Test", review_user_id = 1)
  status_data <- list(category_id = 1, problematic = 0, status_user_id = 1)
  pool <- "fake_pool"

  # Call function
  result <- svc_entity_create_full(
    entity_data = entity_data,
    review_data = review_data,
    status_data = status_data,
    pool = pool
  )

  # Verify 409 response
  expect_equal(result$status, 409)
  expect_true(grepl("already exists|Conflict", result$message, ignore.case = TRUE))
})

test_that("svc_entity_create_full returns 400 on validation error", {
  # Mock dependencies
  local_mocked_bindings(
    svc_entity_validate = function(entity_data) {
      stop(structure(
        list(message = "Missing required fields: hgnc_id"),
        class = c("entity_creation_validation_error", "error", "condition")
      ))
    },
    svc_entity_check_duplicate = function(entity_data, pool) NULL
  )

  # Minimal valid arguments (will be rejected by mock validation)
  entity_data <- list(
    disease_ontology_id_version = "MONDO:0000001",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = "Definitive"
  )
  review_data <- list(synopsis = "Test", review_user_id = 1)
  status_data <- list(category_id = 1, problematic = 0, status_user_id = 1)
  pool <- "fake_pool"

  # Call function
  result <- svc_entity_create_full(
    entity_data = entity_data,
    review_data = review_data,
    status_data = status_data,
    pool = pool
  )

  # Verify 400 response
  expect_equal(result$status, 400)
  expect_true(grepl("Bad Request", result$message, ignore.case = TRUE))
})

test_that("svc_entity_create_full returns 500 on transaction error", {
  # Mock dependencies
  local_mocked_bindings(
    svc_entity_validate = function(entity_data) TRUE,
    svc_entity_check_duplicate = function(entity_data, pool) NULL,
    db_with_transaction = function(fn, pool = NULL) {
      stop(structure(
        list(message = "Connection lost"),
        class = c("db_transaction_error", "error", "condition")
      ))
    }
  )

  # Minimal valid arguments
  entity_data <- list(
    hgnc_id = 1,
    disease_ontology_id_version = "MONDO:0000001",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = "Definitive"
  )
  review_data <- list(synopsis = "Test", review_user_id = 1)
  status_data <- list(category_id = 1, problematic = 0, status_user_id = 1)
  pool <- "fake_pool"

  # Call function
  result <- svc_entity_create_full(
    entity_data = entity_data,
    review_data = review_data,
    status_data = status_data,
    pool = pool
  )

  # Verify 500 response with rollback message
  expect_equal(result$status, 500)
  expect_true(grepl("rolled back", result$message, ignore.case = TRUE))
})

test_that("svc_entity_create_full returns 500 on unexpected error", {
  # Mock dependencies
  local_mocked_bindings(
    svc_entity_validate = function(entity_data) TRUE,
    svc_entity_check_duplicate = function(entity_data, pool) NULL,
    db_with_transaction = function(fn, pool = NULL) {
      stop("Unexpected error: something went wrong")
    }
  )

  # Minimal valid arguments
  entity_data <- list(
    hgnc_id = 1,
    disease_ontology_id_version = "MONDO:0000001",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = "Definitive"
  )
  review_data <- list(synopsis = "Test", review_user_id = 1)
  status_data <- list(category_id = 1, problematic = 0, status_user_id = 1)
  pool <- "fake_pool"

  # Call function
  result <- svc_entity_create_full(
    entity_data = entity_data,
    review_data = review_data,
    status_data = status_data,
    pool = pool
  )

  # Verify 500 response
  expect_equal(result$status, 500)
  expect_true(grepl("Entity creation failed", result$message, ignore.case = TRUE))
})
