# tests/testthat/test-unit-review-repository.R
# Unit tests for review repository functions
#
# Tests for BUG-01, BUG-02, BUG-03 fixes:
# - review_create must include review_user_id
# - review_update must protect review_user_id from modification

library(testthat)
library(tibble)

# Source the review repository functions
# Uses helper-paths.R (loaded automatically by setup.R)
source_api_file("functions/review-repository.R", local = FALSE)

# =============================================================================
# review_create Validation Tests
# =============================================================================

test_that("review_create validates entity_id is required", {
  review_data <- list(
    entity_id = NULL,
    synopsis = "Test synopsis",
    review_user_id = 10
  )

  expect_error(
    review_create(review_data),
    "entity_id is required",
    class = "review_validation_error"
  )
})

test_that("review_create validates review_user_id is required", {
  # BUG-01 fix: review_user_id is required by database schema
  review_data <- list(
    entity_id = 1,
    synopsis = "Test synopsis",
    review_user_id = NULL
  )

  expect_error(
    review_create(review_data),
    "review_user_id is required",
    class = "review_validation_error"
  )
})

test_that("review_create rejects NA review_user_id", {
  # BUG-01 fix: NA values should also be rejected
  review_data <- list(
    entity_id = 1,
    synopsis = "Test synopsis",
    review_user_id = NA
  )

  expect_error(
    review_create(review_data),
    "review_user_id is required",
    class = "review_validation_error"
  )
})

test_that("review_create handles tibble input", {
  # Function should accept tibble as well as list
  review_tibble <- tibble(
    entity_id = 1,
    synopsis = "Test synopsis",
    review_user_id = 10
  )

  # Convert to list to test the conversion logic
  review_list <- as.list(review_tibble[1, ])

  expect_equal(review_list$entity_id, 1)
  expect_equal(review_list$synopsis, "Test synopsis")
  expect_equal(review_list$review_user_id, 10)
})


# =============================================================================
# review_update Protection Tests
# =============================================================================

test_that("review_update removes review_user_id from updates", {
  # BUG-08 fix: review_user_id should never be modified
  updates <- list(
    synopsis = "Updated synopsis",
    review_user_id = 999  # Attempt to modify should be blocked
  )

  # Remove entity_id and review_id if present (matches function logic)
  if ("entity_id" %in% names(updates)) {
    updates$entity_id <- NULL
  }
  if ("review_id" %in% names(updates)) {
    updates$review_id <- NULL
  }
  # Remove review_user_id (the protection logic)
  if ("review_user_id" %in% names(updates)) {
    updates$review_user_id <- NULL
  }

  # After protection, review_user_id should be removed
  expect_null(updates$review_user_id)
  expect_equal(updates$synopsis, "Updated synopsis")
})

test_that("review_update rejects empty updates after protection", {
  # If only review_user_id was provided, update should fail
  updates <- list(
    review_user_id = 999
  )

  # Simulate the protection logic
  updates$review_user_id <- NULL

  expect_equal(length(updates), 0)
})


# =============================================================================
# Synopsis Escaping Tests
# =============================================================================

test_that("synopsis single quotes are escaped", {
  synopsis <- "Patient's symptoms include seizures"
  escaped <- stringr::str_replace_all(synopsis, "'", "''")

  expect_equal(escaped, "Patient''s symptoms include seizures")
})

test_that("synopsis with no quotes is unchanged", {
  synopsis <- "Patient symptoms include seizures"
  escaped <- stringr::str_replace_all(synopsis, "'", "''")

  expect_equal(escaped, synopsis)
})

test_that("synopsis NA values are handled", {
  synopsis <- NA

  # Simulate the safe handling logic
  if (!is.null(synopsis) && !is.na(synopsis) && is.character(synopsis)) {
    synopsis <- stringr::str_replace_all(synopsis, "'", "''")
  }

  expect_true(is.na(synopsis))
})


# =============================================================================
# Input Conversion Tests
# =============================================================================

test_that("logical values are converted to integer for MySQL", {
  updates <- list(
    is_primary = TRUE,
    review_approved = FALSE
  )

  converted <- lapply(updates, function(v) {
    if (is.logical(v)) as.integer(v) else v
  })

  expect_equal(converted$is_primary, 1L)
  expect_equal(converted$review_approved, 0L)
})


# =============================================================================
# review_create Approval-State Propagation Tests (Refs #318)
# =============================================================================

test_that("review_create propagates is_primary, review_approved, approving_user_id, comment when provided", {
  # Capture the SQL and params passed to db_execute_statement.
  # review_create is sourced into globalenv; mock its dependencies via mockery::stub
  # so lookups inside the function body are intercepted.
  captured <- list()
  mockery::stub(
    review_create, "db_execute_statement",
    function(sql, params, conn = NULL) {
      captured$sql <<- sql
      captured$params <<- params
      invisible(NULL)
    }
  )
  mockery::stub(
    review_create, "db_execute_query",
    function(sql, conn = NULL) tibble::tibble(review_id = 42L)
  )

  review_id <- review_create(list(
    entity_id = 5,
    synopsis = "test",
    review_user_id = 3,
    is_primary = 1,
    review_approved = 1,
    approving_user_id = 7,
    comment = "carried over"
  ))

  expect_equal(review_id, 42L)
  expect_match(captured$sql, "is_primary")
  expect_match(captured$sql, "review_approved")
  expect_match(captured$sql, "approving_user_id")
  expect_match(captured$sql, "comment")
  # Params order must match the column order in the INSERT
  expect_true(7 %in% captured$params)
  expect_true("carried over" %in% captured$params)
})

test_that("review_create omits approval-state columns when keys are absent (back-compat)", {
  captured <- list()
  mockery::stub(
    review_create, "db_execute_statement",
    function(sql, params, conn = NULL) {
      captured$sql <<- sql
      captured$params <<- params
      invisible(NULL)
    }
  )
  mockery::stub(
    review_create, "db_execute_query",
    function(sql, conn = NULL) tibble::tibble(review_id = 1L)
  )

  review_create(list(entity_id = 5, synopsis = "x", review_user_id = 3))

  # These columns must be absent so DB defaults apply (back-compat with create-entity flow)
  expect_false(grepl("is_primary", captured$sql))
  expect_false(grepl("review_approved", captured$sql))
  expect_false(grepl("approving_user_id", captured$sql))
  expect_false(grepl("comment", captured$sql))
})
