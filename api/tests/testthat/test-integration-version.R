# tests/testthat/test-integration-version.R
# Integration tests for /api/version endpoint
#
# These tests verify that the version endpoint returns correct structure
# and works without authentication (public endpoint).

library(testthat)
library(httr2)

# =============================================================================
# Helper: Check if API is running
# =============================================================================

skip_if_api_not_running <- function() {
  is_running <- tryCatch(
    {
      request("http://localhost:8000/health") %>%
        req_timeout(2) %>%
        req_perform()
      TRUE
    },
    error = function(e) FALSE
  )

  if (!is_running) {
    testthat::skip("API not running on localhost:8000")
  }
}

# =============================================================================
# Version Endpoint Tests
# =============================================================================

test_that("version endpoint returns 200 status", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/version") %>%
    req_perform()

  expect_equal(resp_status(resp), 200)
})

test_that("version endpoint returns correct structure", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/version") %>%
    req_perform()

  body <- resp_body_json(resp)

  # Verify required fields exist
  expect_true("version" %in% names(body))
  expect_true("commit" %in% names(body))
  expect_true("title" %in% names(body))
  expect_true("description" %in% names(body))
})

test_that("version endpoint returns semantic version format", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/version") %>%
    req_perform()

  body <- resp_body_json(resp)

  # Verify version format (semantic versioning: X.Y.Z)
  expect_match(body$version, "^\\d+\\.\\d+\\.\\d+$")
})

test_that("version endpoint returns non-empty commit hash", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/version") %>%
    req_perform()

  body <- resp_body_json(resp)

  # Verify commit is not empty (may be "unknown" in some environments)
  expect_true(nchar(body$commit) > 0)
  expect_true(is.character(body$commit))
})

test_that("version endpoint does not require authentication", {
  skip_if_api_not_running()

  # Request without Authorization header should succeed
  resp <- request("http://localhost:8000/api/version") %>%
    req_perform()

  expect_equal(resp_status(resp), 200)
})

test_that("version endpoint title matches API name", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/version") %>%
    req_perform()

  body <- resp_body_json(resp)

  # Title should contain "SysNDD" (per version_spec.json)
  expect_match(body$title, "SysNDD", ignore.case = TRUE)
})

test_that("version endpoint description is non-empty", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/version") %>%
    req_perform()

  body <- resp_body_json(resp)

  expect_true(nchar(body$description) > 0)
  expect_true(is.character(body$description))
})
