# tests/testthat/test-unit-status-repository.R
# Unit tests for status_create — focus on optional approval-state propagation
# added in #318. Existing required-field validation is already covered indirectly
# via svc_entity_create_full integration paths.

library(testthat)
library(tibble)

source_api_file("functions/status-repository.R", local = FALSE)

# =============================================================================
# Required-field validation
# =============================================================================

test_that("status_create validates entity_id, category_id, status_user_id", {
  expect_error(
    status_create(tibble(category_id = 1, status_user_id = 1)),
    class = "status_validation_error"
  )
  expect_error(
    status_create(tibble(entity_id = 1, status_user_id = 1)),
    class = "status_validation_error"
  )
  expect_error(
    status_create(tibble(entity_id = 1, category_id = 1)),
    class = "status_validation_error"
  )
})

# =============================================================================
# Optional approval-state propagation (Refs #318)
# =============================================================================

test_that("status_create propagates is_active, status_approved, approving_user_id, comment when provided", {
  # Capture the SQL and params passed to db_execute_statement.
  # status_create is sourced into globalenv; mock its dependencies via
  # mockery::stub so lookups inside the function body are intercepted.
  captured <- list()
  mockery::stub(
    status_create, "db_execute_statement",
    function(sql, params, conn = NULL) {
      captured$sql <<- sql
      captured$params <<- params
      invisible(NULL)
    }
  )
  mockery::stub(
    status_create, "db_execute_query",
    function(sql, conn = NULL) tibble::tibble(status_id = 99L)
  )

  status_id <- status_create(tibble(
    entity_id = 5,
    category_id = 1,
    status_user_id = 3,
    is_active = 1,
    status_approved = 1,
    approving_user_id = 7,
    problematic = 0,
    comment = "carried over"
  ))

  expect_equal(status_id, 99L)
  expect_match(captured$sql, "is_active")
  expect_match(captured$sql, "status_approved")
  expect_match(captured$sql, "approving_user_id")
  expect_match(captured$sql, "comment")
  expect_true(7 %in% captured$params)
  expect_true("carried over" %in% captured$params)
})

test_that("status_create omits approval-state columns when keys are absent (back-compat)", {
  captured <- list()
  mockery::stub(
    status_create, "db_execute_statement",
    function(sql, params, conn = NULL) {
      captured$sql <<- sql
      captured$params <<- params
      invisible(NULL)
    }
  )
  mockery::stub(
    status_create, "db_execute_query",
    function(sql, conn = NULL) tibble::tibble(status_id = 1L)
  )

  status_create(tibble(entity_id = 5, category_id = 1, status_user_id = 3))

  # These columns must be absent so DB defaults apply (back-compat with create-entity flow)
  expect_false(grepl("is_active", captured$sql))
  expect_false(grepl("status_approved", captured$sql))
  expect_false(grepl("approving_user_id", captured$sql))
  expect_false(grepl("comment", captured$sql))
})

test_that("status_create omits optional columns when values are NA", {
  captured <- list()
  mockery::stub(
    status_create, "db_execute_statement",
    function(sql, params, conn = NULL) {
      captured$sql <<- sql
      captured$params <<- params
      invisible(NULL)
    }
  )
  mockery::stub(
    status_create, "db_execute_query",
    function(sql, conn = NULL) tibble::tibble(status_id = 1L)
  )

  status_create(tibble(
    entity_id = 5, category_id = 1, status_user_id = 3,
    is_active = NA_integer_, approving_user_id = NA_integer_
  ))

  expect_false(grepl("is_active", captured$sql))
  expect_false(grepl("approving_user_id", captured$sql))
})

test_that("status_create scalar guard fires before NA check (length>1 optional column)", {
  # Regression: pre-fix the loop checked is.na first, then length.
  # A length>1 optional column should abort with status_validation_error before
  # any NA check is attempted. We pass a 2-row tibble so that the optional
  # column has length 2 at the column level; the guard must fire first.
  expect_error(
    status_create(tibble::tibble(
      entity_id = c(5L, 5L),
      category_id = c(1L, 1L),
      status_user_id = c(3L, 3L),
      is_active = c(NA_integer_, NA_integer_)
    )),
    class = "status_validation_error"
  )
})
