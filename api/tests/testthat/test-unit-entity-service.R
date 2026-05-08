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
  # Use mockery::stub for non-package code
  fn <- svc_entity_create_full
  mockery::stub(fn, "svc_entity_validate", function(entity_data) TRUE)
  mockery::stub(fn, "svc_entity_check_duplicate", function(entity_data, pool) {
    list(entity_id = 999)
  })

  # Minimal valid arguments
  entity_data <- list(
    hgnc_id = 1,
    disease_ontology_id_version = "MONDO:0000001",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = "Definitive"
  )
  review_data <- list(synopsis = "Test", review_user_id = 1)
  status_data <- list(
    category_id = 1, problematic = 0, status_user_id = 1
  )
  pool <- "fake_pool"

  result <- fn(
    entity_data = entity_data,
    review_data = review_data,
    status_data = status_data,
    pool = pool
  )

  expect_equal(result$status, 409)
  expect_true(
    grepl("already exists|Conflict", result$message, ignore.case = TRUE)
  )
})

test_that("svc_entity_create_full returns 400 on validation error", {
  # The 400 path catches entity_creation_validation_error from INSIDE

  # the tryCatch (line 584). This fires when publication_validate_ids
  # throws publication_validation_error, which gets re-wrapped at
  # line 574-576. Mock the transaction to signal the condition directly.
  fn <- svc_entity_create_full
  mockery::stub(
    fn, "svc_entity_validate", function(entity_data) TRUE
  )
  mockery::stub(
    fn, "svc_entity_check_duplicate",
    function(entity_data, pool) NULL
  )
  mockery::stub(fn, "db_with_transaction", function(fn, ...) {
    rlang::abort(
      "Invalid publication: PMID:99999999",
      class = "entity_creation_validation_error"
    )
  })

  entity_data <- list(
    hgnc_id = 1,
    disease_ontology_id_version = "MONDO:0000001",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = "Definitive"
  )
  review_data <- list(synopsis = "Test", review_user_id = 1)
  status_data <- list(
    category_id = 1, problematic = 0, status_user_id = 1
  )
  pool <- "fake_pool"

  result <- fn(
    entity_data = entity_data,
    review_data = review_data,
    status_data = status_data,
    pool = pool
  )

  expect_equal(result$status, 400)
  expect_true(grepl("Bad Request", result$message, ignore.case = TRUE))
})

test_that("svc_entity_create_full returns 500 on transaction error", {
  fn <- svc_entity_create_full
  mockery::stub(
    fn, "svc_entity_validate", function(entity_data) TRUE
  )
  mockery::stub(
    fn, "svc_entity_check_duplicate",
    function(entity_data, pool) NULL
  )
  mockery::stub(fn, "db_with_transaction", function(fn, ...) {
    rlang::abort("Connection lost", class = "db_transaction_error")
  })

  entity_data <- list(
    hgnc_id = 1,
    disease_ontology_id_version = "MONDO:0000001",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = "Definitive"
  )
  review_data <- list(synopsis = "Test", review_user_id = 1)
  status_data <- list(
    category_id = 1, problematic = 0, status_user_id = 1
  )
  pool <- "fake_pool"

  result <- fn(
    entity_data = entity_data,
    review_data = review_data,
    status_data = status_data,
    pool = pool
  )

  expect_equal(result$status, 500)
  expect_true(grepl("rolled back", result$message, ignore.case = TRUE))
})

test_that("svc_entity_create_full returns 500 on unexpected error", {
  fn <- svc_entity_create_full
  mockery::stub(
    fn, "svc_entity_validate", function(entity_data) TRUE
  )
  mockery::stub(
    fn, "svc_entity_check_duplicate",
    function(entity_data, pool) NULL
  )
  mockery::stub(fn, "db_with_transaction", function(fn, ...) {
    stop("Unexpected error: something went wrong")
  })

  entity_data <- list(
    hgnc_id = 1,
    disease_ontology_id_version = "MONDO:0000001",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = "Definitive"
  )
  review_data <- list(synopsis = "Test", review_user_id = 1)
  status_data <- list(
    category_id = 1, problematic = 0, status_user_id = 1
  )
  pool <- "fake_pool"

  result <- fn(
    entity_data = entity_data,
    review_data = review_data,
    status_data = status_data,
    pool = pool
  )

  expect_equal(result$status, 500)
  expect_true(
    grepl("Entity creation failed", result$message, ignore.case = TRUE)
  )
})

# =============================================================================
# svc_entity_rename_full Signature Tests
# =============================================================================

test_that("svc_entity_rename_full exists with expected signature", {
  expect_true(is.function(svc_entity_rename_full))
  svc_params <- names(formals(svc_entity_rename_full))
  expect_equal(svc_params, c("rename_data", "user_id", "pool"))
})

test_that("svc_entity_rename_full does not shadow repository functions", {
  expect_equal(names(formals(entity_create)), c("entity_data", "conn"))
  expect_equal(names(formals(review_create)), c("review_data", "conn"))
  expect_equal(names(formals(status_create)), c("status_data", "conn"))
})

# =============================================================================
# svc_entity_rename_full Validation and Transaction Tests
# =============================================================================

entity_service_valid_rename_payload <- function() {
  list(
    entity = list(
      entity_id = 1L,
      hgnc_id = 1234L,
      hpo_mode_of_inheritance_term = "HP:0000006",
      ndd_phenotype = "Definitive",
      disease_ontology_id_version = "MONDO:0000002"
    )
  )
}

entity_service_rename_read_conn <- function(status_is_active = 1L) {
  skip_if_not_installed("RSQLite")

  conn <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")

  DBI::dbWriteTable(conn, "ndd_entity", tibble::tibble(
    entity_id = 1L,
    hgnc_id = 1234L,
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = "MONDO:0000001",
    ndd_phenotype = "Definitive",
    is_active = 1L
  ))

  DBI::dbWriteTable(conn, "ndd_entity_review", tibble::tibble(
    review_id = integer(),
    entity_id = integer(),
    synopsis = character(),
    is_primary = integer(),
    review_approved = integer(),
    approving_user_id = integer(),
    comment = character()
  ))

  status_rows <- tibble::tibble(
    entity_id = integer(),
    category_id = integer(),
    status_user_id = integer(),
    is_active = integer(),
    status_approved = integer(),
    approving_user_id = integer(),
    problematic = integer(),
    comment = character()
  )

  if (!is.null(status_is_active)) {
    status_rows <- tibble::add_row(
      status_rows,
      entity_id = 1L,
      category_id = 2L,
      status_user_id = 7L,
      is_active = status_is_active,
      status_approved = 1L,
      approving_user_id = 8L,
      problematic = 0L,
      comment = "source status"
    )
  }

  DBI::dbWriteTable(conn, "ndd_entity_status", status_rows)

  conn
}

test_that("svc_entity_rename_full rejects missing entity or entity_id before querying pool", {
  fn <- svc_entity_rename_full
  payload_without_id <- entity_service_valid_rename_payload()
  payload_without_id$entity$entity_id <- NULL

  cases <- list(
    missing_entity = list(),
    missing_entity_id = payload_without_id
  )

  for (case_name in names(cases)) {
    result <- NULL
    expect_error(
      result <- fn(cases[[case_name]], user_id = 7L, pool = "pool must not be used"),
      NA,
      info = case_name
    )
    expect_true(is.list(result), info = case_name)
    if (is.list(result)) {
      expect_equal(result$status, 400, info = case_name)
      expect_match(result$message, "entity", ignore.case = TRUE, info = case_name)
    }
  }
})

test_that("svc_entity_rename_full rejects missing rename fields before querying pool", {
  fn <- svc_entity_rename_full
  required_fields <- c(
    "hgnc_id",
    "hpo_mode_of_inheritance_term",
    "ndd_phenotype",
    "disease_ontology_id_version"
  )

  for (field in required_fields) {
    payload <- entity_service_valid_rename_payload()
    payload$entity[[field]] <- NULL

    result <- NULL
    expect_error(
      result <- fn(payload, user_id = 7L, pool = "pool must not be used"),
      NA,
      info = field
    )
    expect_true(is.list(result), info = field)
    if (is.list(result)) {
      expect_equal(result$status, 400, info = field)
      expect_match(result$message, field, fixed = TRUE, info = field)
    }
  }
})

test_that("svc_entity_rename_full fails before transaction when source has no active status", {
  conn <- entity_service_rename_read_conn(status_is_active = 0L)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  fn <- svc_entity_rename_full
  mockery::stub(fn, "svc_entity_check_duplicate", function(entity_data, pool) NULL)
  mockery::stub(fn, "db_with_transaction", function(...) {
    stop("transaction should not be called")
  })

  result <- fn(entity_service_valid_rename_payload(), user_id = 7L, pool = conn)

  expect_equal(result$status, 409)
  expect_match(result$message, "active source status", ignore.case = TRUE)
})

test_that("svc_entity_rename_full rolls back when source deactivation affects no rows", {
  conn <- entity_service_rename_read_conn(status_is_active = 1L)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  fn <- svc_entity_rename_full
  deactivation_sql <- NULL

  mockery::stub(fn, "svc_entity_check_duplicate", function(entity_data, pool) NULL)
  mockery::stub(fn, "entity_create", function(entity_data, conn = NULL) 11L)
  mockery::stub(fn, "review_create", function(review_data, conn = NULL) 12L)
  mockery::stub(fn, "status_create", function(status_data, conn = NULL) 13L)
  mockery::stub(fn, "db_execute_statement", function(sql, params = list(), conn = NULL) {
    deactivation_sql <<- sql
    0L
  })
  mockery::stub(fn, "db_with_transaction", function(code, pool_obj = NULL) {
    tryCatch(
      code("txn_conn"),
      error = function(e) {
        rlang::abort(
          message = paste("Transaction failed:", e$message),
          class = "db_transaction_error",
          original_error = e$message
        )
      }
    )
  })

  result <- fn(entity_service_valid_rename_payload(), user_id = 7L, pool = conn)

  expect_equal(result$status, 500)
  expect_true(!is.null(result$error))
  expect_match(
    deactivation_sql,
    "WHERE\\s+entity_id\\s*=\\s*\\?\\s+AND\\s+is_active\\s*=\\s*1",
    ignore.case = TRUE
  )
  expect_match(result$error, "source entity.*active|deactivat", ignore.case = TRUE)
})
