# test-integration-health.R
#
# Integration tests for health endpoints.
# These tests verify /health and /health/ready endpoints work correctly.
# Run with: cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-health.R')"
#
# Rollback audit (Phase C unit C9, v11.0):
#   This file is exempt from wrapping in `with_test_db_transaction`
#   because the tests are read-only HTTP probes against /health and
#   /health/ready: they never write to any SysNDD table. The ready
#   endpoint reads migration and pool status via its own connection
#   (outside the test process), so there is no test-owned DB session
#   to roll back. No rollback scope is applicable. The C9 orphan
#   absorption keeps this file green under
#   `scripts/verify-test-gate.sh --extended`.

library(testthat)
library(httr)

# Helper to check if API is running
skip_if_no_api <- function() {
  api_url <- Sys.getenv("API_URL", "http://localhost:7778")
  tryCatch({
    resp <- httr::GET(paste0(api_url, "/health/"), timeout(5))
    if (httr::status_code(resp) != 200) {
      skip("API not responding (health check failed)")
    }
  }, error = function(e) {
    skip(paste("API not available:", e$message))
  })
}

describe("/health endpoint", {
  it("returns healthy status with version", {
    skip_if_no_api()
    api_url <- Sys.getenv("API_URL", "http://localhost:7778")

    resp <- httr::GET(paste0(api_url, "/health/"))

    expect_equal(httr::status_code(resp), 200)

    body <- httr::content(resp, as = "parsed")
    expect_equal(body$status, "healthy")
    expect_true(!is.null(body$version))
    expect_true(!is.null(body$timestamp))
  })
})

describe("/health/ready endpoint", {
  it("returns healthy status when database connected", {
    skip_if_no_api()
    api_url <- Sys.getenv("API_URL", "http://localhost:7778")

    resp <- httr::GET(paste0(api_url, "/health/ready"))

    expect_equal(httr::status_code(resp), 200)

    body <- httr::content(resp, as = "parsed")
    expect_equal(body$status, "healthy")
    expect_equal(body$database, "connected")
  })

  it("includes migration status in response", {
    skip_if_no_api()
    api_url <- Sys.getenv("API_URL", "http://localhost:7778")

    resp <- httr::GET(paste0(api_url, "/health/ready"))
    body <- httr::content(resp, as = "parsed")

    expect_true(!is.null(body$migrations))
    expect_true(!is.null(body$migrations$pending))
    expect_true(!is.null(body$migrations$applied))
    # When healthy, pending should be 0
    expect_equal(body$migrations$pending, 0)
  })

  it("includes pool statistics in response", {
    skip_if_no_api()
    api_url <- Sys.getenv("API_URL", "http://localhost:7778")

    resp <- httr::GET(paste0(api_url, "/health/ready"))
    body <- httr::content(resp, as = "parsed")

    expect_true(!is.null(body$pool))
    expect_true(!is.null(body$pool$max_size))
    # max_size should match DB_POOL_SIZE env var (default 5)
    expect_true(body$pool$max_size >= 1)
  })

  it("includes timestamp in ISO 8601 format", {
    skip_if_no_api()
    api_url <- Sys.getenv("API_URL", "http://localhost:7778")

    resp <- httr::GET(paste0(api_url, "/health/ready"))
    body <- httr::content(resp, as = "parsed")

    expect_true(!is.null(body$timestamp))
    # Should be ISO 8601 format ending in Z (UTC)
    expect_true(grepl("T.*Z$", body$timestamp))
  })
})

describe("health endpoint content type", {
  it("returns application/json content type", {
    skip_if_no_api()
    api_url <- Sys.getenv("API_URL", "http://localhost:7778")

    resp <- httr::GET(paste0(api_url, "/health/ready"))

    content_type <- httr::headers(resp)$`content-type`
    expect_true(grepl("application/json", content_type))
  })
})
