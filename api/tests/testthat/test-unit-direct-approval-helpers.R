# tests/testthat/test-unit-direct-approval-helpers.R
#
# Unit tests for the modify-path direct-approval helpers (issues #36 / #37):
#   - svc_status_apply_direct_approval()
#   - review_apply_direct_approval()
#
# These fold an optional "approve in the same request" step onto the status /
# review write responses, reusing svc_approval_*_approve. The helpers are
# pure orchestration over a stubbable approval service, so no DB is needed.

library(testthat)

# Source the service under test. It calls svc_approval_*_approve, which we
# override with deterministic stubs after sourcing so we can assert routing.
source_api_file("services/approval-service.R", local = FALSE, envir = globalenv())

# ---------------------------------------------------------------------------
# svc_status_apply_direct_approval
# ---------------------------------------------------------------------------

test_that("status: returns the write response unchanged when direct_approval is FALSE", {
  called <- FALSE
  svc_approval_status_approve <<- function(...) {
    called <<- TRUE
    list(status = 200)
  }
  resp <- list(status = 200, message = "OK.", entry = 5L)
  out <- svc_status_apply_direct_approval(resp, user_id = 9L, direct_approval = FALSE, pool = NULL)
  expect_identical(out, resp)
  expect_false(called)
})

test_that("status: approves the written status when direct_approval is TRUE", {
  captured <- list()
  svc_approval_status_approve <<- function(status_id, user_id, approve, pool) {
    captured <<- list(status_id = status_id, user_id = user_id, approve = approve)
    list(status = 200, message = "OK. Status approved.", entry = status_id)
  }
  resp <- list(status = 200, message = "OK. Status created.", entry = 5L)
  out <- svc_status_apply_direct_approval(resp, user_id = 9L, direct_approval = TRUE, pool = "P")
  expect_equal(out$status, 200)
  expect_equal(captured$status_id, 5L)
  expect_equal(captured$user_id, 9L)
  expect_true(isTRUE(captured$approve))
})

test_that("status: does not approve when the write itself failed", {
  called <- FALSE
  svc_approval_status_approve <<- function(...) {
    called <<- TRUE
    list(status = 200)
  }
  resp <- list(status = 400, message = "Bad.", entry = NA)
  out <- svc_status_apply_direct_approval(resp, user_id = 9L, direct_approval = TRUE, pool = NULL)
  expect_equal(out$status, 400)
  expect_false(called)
})

test_that("status: surfaces an approval failure on the response status", {
  svc_approval_status_approve <<- function(...) list(status = 500, message = "approve boom")
  resp <- list(status = 200, message = "OK. Status created.", entry = 5L)
  out <- svc_status_apply_direct_approval(resp, user_id = 9L, direct_approval = TRUE, pool = NULL)
  expect_equal(out$status, 500)
  expect_true(grepl("Direct approval failed", out$message))
})

# ---------------------------------------------------------------------------
# review_apply_direct_approval
# ---------------------------------------------------------------------------

test_that("review: returns the write response unchanged when direct_approval is FALSE", {
  called <- FALSE
  svc_approval_review_approve <<- function(...) {
    called <<- TRUE
    list(status = 200)
  }
  resp <- list(status = 200, message = "OK.")
  out <- review_apply_direct_approval(
    resp, review_id = 42L, user_id = 7L, direct_approval = FALSE, pool = NULL
  )
  expect_identical(out, resp)
  expect_false(called)
})

test_that("review: approves the written review when direct_approval is TRUE", {
  captured <- list()
  svc_approval_review_approve <<- function(review_id, user_id, approve, pool) {
    captured <<- list(review_id = review_id, user_id = user_id, approve = approve)
    list(status = 200, message = "OK. Review approved.", entry = review_id)
  }
  resp <- list(status = 200, message = "OK. Review stored.")
  out <- review_apply_direct_approval(
    resp, review_id = 42L, user_id = 7L, direct_approval = TRUE, pool = "P"
  )
  expect_equal(out$status, 200)
  expect_equal(captured$review_id, 42L)
  expect_equal(captured$user_id, 7L)
  expect_true(isTRUE(captured$approve))
})

test_that("review: skips approval gracefully when review_id is unavailable", {
  called <- FALSE
  svc_approval_review_approve <<- function(...) {
    called <<- TRUE
    list(status = 200)
  }
  resp <- list(status = 200, message = "OK.")
  out <- review_apply_direct_approval(
    resp, review_id = NULL, user_id = 7L, direct_approval = TRUE, pool = NULL
  )
  expect_equal(out$status, 200)
  expect_false(called)
  expect_true(grepl("Direct approval skipped", out$message))
})
