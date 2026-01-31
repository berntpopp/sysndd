# tests/testthat/test-integration-pagination.R
# Integration tests for cursor-based pagination
#
# These tests verify that pagination works correctly on refactored endpoints,
# respects page_size limits, and provides proper navigation structure.

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
# Pagination Structure Tests
# =============================================================================

test_that("entity endpoint returns pagination structure", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/entity") %>%
    req_url_query(page_size = 5) %>%
    req_perform()

  expect_equal(resp_status(resp), 200)

  body <- resp_body_json(resp)

  # Verify pagination structure (links, meta, data)
  expect_true("links" %in% names(body))
  expect_true("meta" %in% names(body))
  expect_true("data" %in% names(body))
})

test_that("pagination meta contains required fields", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/entity") %>%
    req_url_query(page_size = 5) %>%
    req_perform()

  body <- resp_body_json(resp)

  # Verify meta fields
  expect_true("perPage" %in% names(body$meta))
  expect_equal(body$meta$perPage, 5)
})

test_that("pagination links contain navigation URLs", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/entity") %>%
    req_url_query(page_size = 5) %>%
    req_perform()

  body <- resp_body_json(resp)

  # Verify links structure
  expect_true(is.list(body$links))
  # Links should have 'next' field (may be null if last page)
  expect_true("next" %in% names(body$links))
})

# =============================================================================
# Page Size Limit Tests
# =============================================================================

test_that("pagination respects max page_size limit", {
  skip_if_api_not_running()

  # Request with page_size > max (500 per PAG-02)
  resp <- request("http://localhost:8000/api/entity") %>%
    req_url_query(page_size = 1000) %>%
    req_perform()

  body <- resp_body_json(resp)

  # Should be capped at 500
  expect_lte(body$meta$perPage, 500)
})

test_that("pagination handles small page_size correctly", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/entity") %>%
    req_url_query(page_size = 2) %>%
    req_perform()

  body <- resp_body_json(resp)

  # Should return exactly 2 items (or fewer if not enough data)
  expect_lte(length(body$data), 2)
  expect_equal(body$meta$perPage, 2)
})

test_that("pagination defaults to reasonable page_size when not specified", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/entity") %>%
    req_perform()

  body <- resp_body_json(resp)

  # Should have a default page_size (usually "all" or 10)
  expect_true("perPage" %in% names(body$meta))
  expect_true(!is.null(body$meta$perPage))
})

# =============================================================================
# Cursor Navigation Tests
# =============================================================================

test_that("pagination cursor navigation works", {
  skip_if_api_not_running()

  # Get first page
  resp1 <- request("http://localhost:8000/api/entity") %>%
    req_url_query(page_size = 2, page_after = 0) %>%
    req_perform()

  body1 <- resp_body_json(resp1)

  # Skip if not enough data for multiple pages
  if (body1$links[["next"]] == "null" || is.null(body1$links[["next"]])) {
    skip("Not enough data for pagination test")
  }

  # Get next page using cursor
  next_link <- body1$links[["next"]]

  # Extract page_after from next link
  page_after <- as.integer(gsub(".*page_after=(\\d+).*", "\\1", next_link))

  resp2 <- request("http://localhost:8000/api/entity") %>%
    req_url_query(page_size = 2, page_after = page_after) %>%
    req_perform()

  body2 <- resp_body_json(resp2)

  # Verify different data returned
  # Convert to JSON strings for comparison
  data1_json <- jsonlite::toJSON(body1$data, auto_unbox = TRUE)
  data2_json <- jsonlite::toJSON(body2$data, auto_unbox = TRUE)

  expect_false(identical(data1_json, data2_json))
})

test_that("pagination returns empty data array when page_after exceeds data", {
  skip_if_api_not_running()

  # Request page far beyond available data
  resp <- request("http://localhost:8000/api/entity") %>%
    req_url_query(page_size = 10, page_after = 999999) %>%
    req_perform()

  body <- resp_body_json(resp)

  # Should return empty data array
  expect_equal(length(body$data), 0)
  expect_true("next" %in% names(body$links))
  # Next should be null when no more data
  expect_true(body$links[["next"]] == "null" || is.null(body$links[["next"]]))
})

# =============================================================================
# Pagination on Other Endpoints Tests
# =============================================================================

test_that("user endpoint supports pagination", {
  skip_if_api_not_running()
  skip("Requires authentication")

  # This test requires valid JWT authentication
  # Manual verification: GET /api/user?page_size=5
})

test_that("re-review endpoint supports pagination", {
  skip_if_api_not_running()
  skip("Requires authentication")

  # This test requires valid JWT authentication
  # Manual verification: GET /api/re-review?page_size=5
})
