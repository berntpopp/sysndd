# test-integration-llm-endpoints.R
#
# Integration tests for LLM summary endpoints.
# Tests the refactored functional_cluster_summary and phenotype_cluster_summary endpoints.
# Run with: cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-llm-endpoints.R')"

library(testthat)
library(httr)

# Helper to check if API is running
skip_if_no_api <- function() {
  api_url <- Sys.getenv("API_URL", "http://localhost:7778")
  tryCatch(
    {
      resp <- httr::GET(paste0(api_url, "/health/"), timeout(5))
      if (httr::status_code(resp) != 200) {
        skip("API not responding (health check failed)")
      }
    },
    error = function(e) {
      skip(paste("API not available:", e$message))
    }
  )
}

# Helper to get API URL
get_api_url <- function() {
  Sys.getenv("API_URL", "http://localhost:7778")
}

# ============================================================================
# /api/analysis/functional_cluster_summary Tests
# ============================================================================

describe("/api/analysis/functional_cluster_summary endpoint", {
  it("returns 400 for missing cluster_hash parameter", {
    skip_if_no_api()

    resp <- httr::GET(
      paste0(get_api_url(), "/api/analysis/functional_cluster_summary"),
      query = list(cluster_number = "1")
    )

    expect_equal(httr::status_code(resp), 400)

    body <- httr::content(resp, as = "parsed")
    expect_true(grepl("cluster_hash", body$message, ignore.case = TRUE))
  })

  it("returns 400 for missing cluster_number parameter", {
    skip_if_no_api()

    resp <- httr::GET(
      paste0(get_api_url(), "/api/analysis/functional_cluster_summary"),
      query = list(cluster_hash = "testhash123")
    )

    expect_equal(httr::status_code(resp), 400)

    body <- httr::content(resp, as = "parsed")
    expect_true(grepl("cluster_number", body$message, ignore.case = TRUE))
  })

  it("returns 404 or 503 for nonexistent cluster hash", {
    skip_if_no_api()

    resp <- httr::GET(
      paste0(get_api_url(), "/api/analysis/functional_cluster_summary"),
      query = list(
        cluster_hash = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        cluster_number = "999999"
      )
    )

    # Should return either 404 (not found) or 503 (service unavailable if Gemini not configured)
    expect_true(httr::status_code(resp) %in% c(404, 503))
  })

  it("accepts equals(hash,...) format", {
    skip_if_no_api()

    resp <- httr::GET(
      paste0(get_api_url(), "/api/analysis/functional_cluster_summary"),
      query = list(
        cluster_hash = "equals(hash,testnonexistenthash)",
        cluster_number = "1"
      )
    )

    # Should NOT return 400 (bad request) - hash format is valid
    expect_true(httr::status_code(resp) != 400)
  })

  it("returns proper JSON structure when cached summary exists", {
    skip_if_no_api()
    skip("Requires test fixture with known cached summary")

    # This test would need a known cluster hash that has a cached summary
    # In a real test environment, we would seed the database with test data
    #
    # resp <- httr::GET(
    #   paste0(get_api_url(), "/api/analysis/functional_cluster_summary"),
    #   query = list(cluster_hash = KNOWN_CACHED_HASH, cluster_number = "1")
    # )
    #
    # expect_equal(httr::status_code(resp), 200)
    # body <- httr::content(resp, as = "parsed")
    # expect_true(!is.null(body$cache_id))
    # expect_true(!is.null(body$cluster_type))
    # expect_true(!is.null(body$summary_json))
    # expect_equal(body$cluster_type, "functional")
  })
})

# ============================================================================
# /api/analysis/phenotype_cluster_summary Tests
# ============================================================================

describe("/api/analysis/phenotype_cluster_summary endpoint", {
  it("returns 400 for missing cluster_hash parameter", {
    skip_if_no_api()

    resp <- httr::GET(
      paste0(get_api_url(), "/api/analysis/phenotype_cluster_summary"),
      query = list(cluster_number = "1")
    )

    expect_equal(httr::status_code(resp), 400)

    body <- httr::content(resp, as = "parsed")
    expect_true(grepl("cluster_hash", body$message, ignore.case = TRUE))
  })

  it("returns 400 for missing cluster_number parameter", {
    skip_if_no_api()

    resp <- httr::GET(
      paste0(get_api_url(), "/api/analysis/phenotype_cluster_summary"),
      query = list(cluster_hash = "testhash456")
    )

    expect_equal(httr::status_code(resp), 400)

    body <- httr::content(resp, as = "parsed")
    expect_true(grepl("cluster_number", body$message, ignore.case = TRUE))
  })

  it("returns 404 or 503 for nonexistent cluster hash", {
    skip_if_no_api()

    resp <- httr::GET(
      paste0(get_api_url(), "/api/analysis/phenotype_cluster_summary"),
      query = list(
        cluster_hash = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
        cluster_number = "888888"
      )
    )

    # Should return either 404 (not found) or 503 (service unavailable if Gemini not configured)
    expect_true(httr::status_code(resp) %in% c(404, 503))
  })

  it("accepts equals(hash,...) format", {
    skip_if_no_api()

    resp <- httr::GET(
      paste0(get_api_url(), "/api/analysis/phenotype_cluster_summary"),
      query = list(
        cluster_hash = "equals(hash,phenotypenonexistenthash)",
        cluster_number = "1"
      )
    )

    # Should NOT return 400 (bad request) - hash format is valid
    expect_true(httr::status_code(resp) != 400)
  })

  it("returns proper JSON structure when cached summary exists", {
    skip_if_no_api()
    skip("Requires test fixture with known cached summary")

    # This test would need a known cluster hash that has a cached summary
    # In a real test environment, we would seed the database with test data
  })
})

# ============================================================================
# Cross-endpoint Consistency Tests
# ============================================================================

describe("LLM summary endpoint consistency", {
  it("both endpoints return same error format for missing params", {
    skip_if_no_api()

    # Test functional endpoint
    resp1 <- httr::GET(
      paste0(get_api_url(), "/api/analysis/functional_cluster_summary"),
      query = list(cluster_number = "1") # Missing hash
    )

    # Test phenotype endpoint
    resp2 <- httr::GET(
      paste0(get_api_url(), "/api/analysis/phenotype_cluster_summary"),
      query = list(cluster_number = "1") # Missing hash
    )

    body1 <- httr::content(resp1, as = "parsed")
    body2 <- httr::content(resp2, as = "parsed")

    # Both should have message field
    expect_true(!is.null(body1$message))
    expect_true(!is.null(body2$message))

    # Both should return 400
    expect_equal(httr::status_code(resp1), httr::status_code(resp2))
  })

  it("both endpoints use same hash extraction logic", {
    skip_if_no_api()

    # Test with equals format on both endpoints
    hash_format <- "equals(hash,testconsistencyhash)"

    resp1 <- httr::GET(
      paste0(get_api_url(), "/api/analysis/functional_cluster_summary"),
      query = list(cluster_hash = hash_format, cluster_number = "1")
    )

    resp2 <- httr::GET(
      paste0(get_api_url(), "/api/analysis/phenotype_cluster_summary"),
      query = list(cluster_hash = hash_format, cluster_number = "1")
    )

    # Neither should return 400 (hash format should be accepted)
    expect_true(httr::status_code(resp1) != 400)
    expect_true(httr::status_code(resp2) != 400)
  })
})

# ============================================================================
# Response Structure Tests (when API is available with test data)
# ============================================================================

describe("LLM summary response structure", {
  it("functional endpoint response includes required fields when successful", {
    skip_if_no_api()
    skip("Requires seeded test data with cached summary")

    # When a valid cached summary exists, response should include:
    # - cache_id (integer)
    # - cluster_type ("functional")
    # - cluster_number (integer)
    # - model_name (string)
    # - created_at (string, ISO timestamp)
    # - validation_status (string: "pending", "validated", "rejected")
    # - summary_json (object with summary content)
    # - generated (boolean, FALSE for cached)
  })

  it("phenotype endpoint response includes required fields when successful", {
    skip_if_no_api()
    skip("Requires seeded test data with cached summary")

    # Same structure as functional endpoint but cluster_type = "phenotype"
  })

  it("generated flag is TRUE when summary is freshly created", {
    skip_if_no_api()
    skip("Requires Gemini API configured and new cluster data")

    # When a summary is generated on-demand (not from cache),
    # the response should include generated: TRUE
  })
})
