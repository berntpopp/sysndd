# tests/testthat/test-unit-job-capacity.R
#
# Unit tests for the async job queue-depth capacity predicate.
# These tests are pure (no DB required) and must run on the host.

source_api_file("functions/async-job-service.R", local = FALSE)

test_that("capacity predicate trips at the configured cap", {
  expect_false(async_job_capacity_exceeded(active_count = 4L, cap = 5L))
  expect_true(async_job_capacity_exceeded(active_count = 5L, cap = 5L))
  expect_true(async_job_capacity_exceeded(active_count = 9L, cap = 5L))
})

test_that("predicate coerces non-integer inputs and fails open on NA", {
  # COUNT(*) and env vars can arrive as character; the predicate coerces.
  expect_true(async_job_capacity_exceeded(active_count = "5", cap = 5L))
  expect_false(async_job_capacity_exceeded(active_count = "4", cap = 5L))
  # NA (e.g. a failed/empty count) must not falsely trip the cap (fail-open).
  expect_false(async_job_capacity_exceeded(active_count = NA_integer_, cap = 5L))
})
