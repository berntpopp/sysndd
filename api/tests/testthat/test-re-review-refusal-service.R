# tests/testthat/test-re-review-refusal-service.R
#
# Unit tests for re-review-refusal-service.R (issue #54).
#
# Strategy mirrors test-re-review-service.R: replace db_execute_query and
# db_execute_statement in .GlobalEnv so the refusal logic runs without a live
# database. We assert the recorded SQL + params (refusal flag, reason capping,
# user/timestamp, submitted reset) and the status-code branches.

source_api_file("functions/db-helpers.R", local = FALSE, envir = .GlobalEnv)
if (!requireNamespace("logger", quietly = TRUE)) {
  stop("logger package not available — cannot run re-review-refusal-service tests")
}
source_api_file("services/re-review-refusal-service.R", local = FALSE, envir = .GlobalEnv)

make_mock_conn <- function() structure(list(), class = "MockPool")

# Install query + statement mocks in .GlobalEnv; restore on exit.
with_refusal_mock <- function(query_fn, statement_fn, expr) {
  orig_q <- if (exists("db_execute_query", envir = .GlobalEnv)) {
    get("db_execute_query", envir = .GlobalEnv)
  } else {
    NULL
  }
  orig_s <- if (exists("db_execute_statement", envir = .GlobalEnv)) {
    get("db_execute_statement", envir = .GlobalEnv)
  } else {
    NULL
  }

  assign("db_execute_query", query_fn, envir = .GlobalEnv)
  assign("db_execute_statement", statement_fn, envir = .GlobalEnv)

  on.exit({
    if (is.null(orig_q)) rm("db_execute_query", envir = .GlobalEnv) else assign("db_execute_query", orig_q, envir = .GlobalEnv)
    if (is.null(orig_s)) rm("db_execute_statement", envir = .GlobalEnv) else assign("db_execute_statement", orig_s, envir = .GlobalEnv)
  }, add = TRUE)

  force(expr)
}

# SELECT result for an existing, not-yet-refused row.
existing_not_refused <- function() {
  tibble::tibble(
    re_review_entity_id = 42L,
    re_review_refused = 0L,
    re_review_approved = 0L
  )
}

context("re-review-refusal-service: refuse_re_review_entity (issue #54)")

test_that("refuse service functions are defined", {
  expect_true(exists("refuse_re_review_entity", mode = "function"))
  expect_true(exists("clear_re_review_refusal", mode = "function"))
})

test_that("refusal records flag, reason, user, timestamp and resets submitted", {
  captured <- list()
  query_fn <- function(sql, params = list(), conn = NULL) existing_not_refused()
  statement_fn <- function(sql, params = list(), conn = NULL) {
    captured$sql <<- sql
    captured$params <<- params
    1L
  }

  with_refusal_mock(query_fn, statement_fn, {
    result <- refuse_re_review_entity(
      re_review_entity_id = 42L,
      user_id = 7L,
      reason = "  Too complex; needs specialist  ",
      pool = make_mock_conn()
    )
  })

  expect_equal(result$status, 200L)
  expect_equal(result$entry$re_review_entity_id, 42L)

  # UPDATE must set the refusal flag, reason, user, date and reset submitted.
  expect_match(captured$sql, "re_review_refused = 1", fixed = TRUE)
  expect_match(captured$sql, "re_review_refusal_comment = ?", fixed = TRUE)
  expect_match(captured$sql, "re_review_refused_user_id = ?", fixed = TRUE)
  expect_match(captured$sql, "re_review_refused_date = UTC_TIMESTAMP()", fixed = TRUE)
  expect_match(captured$sql, "re_review_submitted = 0", fixed = TRUE)

  # Params: trimmed reason, user_id, re_review_entity_id (unnamed for ? binding).
  expect_null(names(captured$params))
  expect_equal(captured$params[[1]], "Too complex; needs specialist")
  expect_equal(captured$params[[2]], 7L)
  expect_equal(captured$params[[3]], 42L)
})

test_that("empty / whitespace reason is stored as NA (NULL reason column)", {
  captured <- list()
  query_fn <- function(sql, params = list(), conn = NULL) existing_not_refused()
  statement_fn <- function(sql, params = list(), conn = NULL) {
    captured$params <<- params
    1L
  }

  with_refusal_mock(query_fn, statement_fn, {
    result <- refuse_re_review_entity(42L, user_id = 7L, reason = "   ", pool = make_mock_conn())
  })

  expect_equal(result$status, 200L)
  expect_true(is.na(captured$params[[1]]))
})

test_that("reason is capped at 1000 characters", {
  captured <- list()
  long_reason <- paste(rep("x", 1500L), collapse = "")
  query_fn <- function(sql, params = list(), conn = NULL) existing_not_refused()
  statement_fn <- function(sql, params = list(), conn = NULL) {
    captured$params <<- params
    1L
  }

  with_refusal_mock(query_fn, statement_fn, {
    refuse_re_review_entity(42L, user_id = 7L, reason = long_reason, pool = make_mock_conn())
  })

  expect_equal(nchar(captured$params[[1]]), 1000L)
})

test_that("refusal returns 404 when the item does not exist", {
  query_fn <- function(sql, params = list(), conn = NULL) tibble::tibble()
  statement_fn <- function(sql, params = list(), conn = NULL) {
    stop("statement must not run when item is missing")
  }

  with_refusal_mock(query_fn, statement_fn, {
    result <- refuse_re_review_entity(999L, user_id = 7L, reason = NULL, pool = make_mock_conn())
  })

  expect_equal(result$status, 404L)
})

test_that("refusal returns 409 when already refused (no UPDATE issued)", {
  statement_called <- FALSE
  query_fn <- function(sql, params = list(), conn = NULL) {
    tibble::tibble(
      re_review_entity_id = 42L,
      re_review_refused = 1L,
      re_review_approved = 0L
    )
  }
  statement_fn <- function(sql, params = list(), conn = NULL) {
    statement_called <<- TRUE
    1L
  }

  with_refusal_mock(query_fn, statement_fn, {
    result <- refuse_re_review_entity(42L, user_id = 7L, reason = "again", pool = make_mock_conn())
  })

  expect_equal(result$status, 409L)
  expect_false(statement_called)
})

test_that("refusal validates the re_review_entity_id and user_id", {
  with_refusal_mock(
    function(...) existing_not_refused(),
    function(...) 1L,
    {
      # as.integer() on non-numeric text warns "NAs introduced by coercion";
      # that NA path is exactly what we assert returns a 400.
      bad_id <- suppressWarnings(
        refuse_re_review_entity("not-an-int", user_id = 7L, pool = make_mock_conn())
      )
      bad_user <- suppressWarnings(
        refuse_re_review_entity(42L, user_id = "nope", pool = make_mock_conn())
      )
    }
  )
  expect_equal(bad_id$status, 400L)
  expect_equal(bad_user$status, 400L)
})

context("re-review-refusal-service: clear_re_review_refusal")

test_that("clearing a refusal nulls the flag/reason/user/date", {
  captured <- list()
  query_fn <- function(sql, params = list(), conn = NULL) {
    tibble::tibble(re_review_entity_id = 42L)
  }
  statement_fn <- function(sql, params = list(), conn = NULL) {
    captured$sql <<- sql
    1L
  }

  with_refusal_mock(query_fn, statement_fn, {
    result <- clear_re_review_refusal(42L, pool = make_mock_conn())
  })

  expect_equal(result$status, 200L)
  expect_match(captured$sql, "re_review_refused = 0", fixed = TRUE)
  expect_match(captured$sql, "re_review_refusal_comment = NULL", fixed = TRUE)
  expect_match(captured$sql, "re_review_refused_user_id = NULL", fixed = TRUE)
  expect_match(captured$sql, "re_review_refused_date = NULL", fixed = TRUE)
})

test_that("clearing a refusal returns 404 when the item does not exist", {
  query_fn <- function(sql, params = list(), conn = NULL) tibble::tibble()
  statement_fn <- function(sql, params = list(), conn = NULL) {
    stop("statement must not run when item is missing")
  }

  with_refusal_mock(query_fn, statement_fn, {
    result <- clear_re_review_refusal(999L, pool = make_mock_conn())
  })

  expect_equal(result$status, 404L)
})
