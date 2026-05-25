# test-integration-health.R
#
# Integration tests for health endpoints.
# These tests verify /api/health and /api/health/ready endpoints work correctly.
# Run with: cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-health.R')"
#
# Rollback audit (Phase C unit C9, v11.0):
#   This file is exempt from wrapping in `with_test_db_transaction`
#   because the tests are read-only HTTP probes against /api/health and
#   /api/health/ready: they never write to any SysNDD table. The ready
#   endpoint reads migration and pool status via its own connection
#   (outside the test process), so there is no test-owned DB session
#   to roll back. No rollback scope is applicable. The C9 orphan
#   absorption keeps this file green under
#   `scripts/verify-test-gate.sh --extended`.

library(testthat)
library(httr)

api_url <- function(path) {
  origin <- Sys.getenv("API_URL", "http://localhost:7778")
  prefix <- Sys.getenv("API_PATH_PREFIX", "/api")
  paste0(origin, prefix, path)
}

api_get <- function(path, ...) {
  host_header <- Sys.getenv("API_HOST_HEADER", "")
  args <- list(api_url(path))
  if (nzchar(host_header)) {
    args <- c(args, list(httr::add_headers(Host = host_header)))
  }
  args <- c(args, list(...))
  do.call(httr::GET, args)
}

json_scalar <- function(value) {
  if ((is.list(value) || is.atomic(value)) && length(value) == 1L) {
    return(value[[1L]])
  }
  value
}

# Helper to check if API is running
skip_if_no_api <- function() {
  tryCatch({
    resp <- api_get("/health/", timeout(5))
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

    resp <- api_get("/health/")

    expect_equal(httr::status_code(resp), 200)

    body <- httr::content(resp, as = "parsed")
    expect_equal(json_scalar(body$status), "healthy")
    expect_true(!is.null(body$version))
    expect_true(!is.null(body$timestamp))
  })
})

describe("/health/ready endpoint", {
  it("returns healthy status when database connected", {
    skip_if_no_api()

    resp <- api_get("/health/ready")

    expect_equal(httr::status_code(resp), 200)

    body <- httr::content(resp, as = "parsed")
    expect_equal(json_scalar(body$status), "healthy")
    expect_equal(json_scalar(body$database), "connected")
  })

  it("includes migration status in response", {
    skip_if_no_api()

    resp <- api_get("/health/ready")
    body <- httr::content(resp, as = "parsed")

    expect_true(!is.null(body$migrations))
    expect_true(!is.null(body$migrations$pending))
    expect_true(!is.null(body$migrations$applied))
    # When healthy, pending should be 0
    expect_equal(json_scalar(body$migrations$pending), 0)
  })

  it("includes pool statistics in response", {
    skip_if_no_api()

    resp <- api_get("/health/ready")
    body <- httr::content(resp, as = "parsed")

    expect_true(!is.null(body$pool))
    expect_true(!is.null(body$pool$max_size))
    # max_size should match DB_POOL_SIZE env var (default 5)
    expect_true(body$pool$max_size >= 1)
  })

  it("includes timestamp in ISO 8601 format", {
    skip_if_no_api()

    resp <- api_get("/health/ready")
    body <- httr::content(resp, as = "parsed")

    expect_true(!is.null(body$timestamp))
    # Should be ISO 8601 format ending in Z (UTC)
    expect_true(grepl("T.*Z$", json_scalar(body$timestamp)))
  })
})

describe("health endpoint content type", {
  it("returns application/json content type", {
    skip_if_no_api()

    resp <- api_get("/health/ready")

    content_type <- httr::headers(resp)$`content-type`
    expect_true(grepl("application/json", content_type))
  })
})
