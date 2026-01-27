# tests/testthat/test-integration-gene-endpoints.R
# Integration tests for /api/gene endpoints
#
# These tests verify that the gene endpoint returns correct structure
# including the bed_hg38 field for chromosome coordinates (REDESIGN-01).

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
# Gene Endpoint bed_hg38 Field Tests
# =============================================================================

test_that("gene endpoint returns bed_hg38 field", {
  skip_if_api_not_running()

  # Test with MECP2 (HGNC:6990) - a well-known gene that should have coordinates
  resp <- request("http://localhost:8000/api/gene/HGNC:6990") %>%
    req_perform()

  expect_equal(resp_status(resp), 200)

  body <- resp_body_json(resp)

  # Verify bed_hg38 is in the response
  expect_true("bed_hg38" %in% names(body))
})

test_that("gene endpoint bed_hg38 has expected format when present", {
  skip_if_api_not_running()

  # Test with MECP2 (HGNC:6990) - known gene with coordinates
  resp <- request("http://localhost:8000/api/gene/HGNC:6990") %>%
    req_perform()

  body <- resp_body_json(resp)

  # bed_hg38 should be a list (array after str_split)
  expect_true(is.list(body$bed_hg38) || is.null(body$bed_hg38))

  # If not null, should contain chromosome coordinate string(s)
  if (!is.null(body$bed_hg38) && length(body$bed_hg38) > 0) {
    # First element should match pattern: chrN:start-end
    expect_match(body$bed_hg38[[1]], "^chr[0-9XY]+:\\d+-\\d+$")
  }
})

test_that("gene endpoint returns consistent field count with bed_hg38", {
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/gene/HGNC:6990") %>%
    req_perform()

  body <- resp_body_json(resp)

  # Should have 14 fields now (13 original + bed_hg38)
  expected_fields <- c(
    "hgnc_id", "symbol", "name", "entrez_id", "ensembl_gene_id",
    "ucsc_id", "ccds_id", "uniprot_ids", "omim_id", "mane_select",
    "mgd_id", "rgd_id", "STRING_id", "bed_hg38"
  )

  expect_equal(length(body), 14)
  expect_true(all(expected_fields %in% names(body)))
})

test_that("gene endpoint by symbol returns bed_hg38", {
  skip_if_api_not_running()

  # Test querying by symbol instead of HGNC ID
  resp <- request("http://localhost:8000/api/gene/MECP2?input_type=symbol") %>%
    req_perform()

  expect_equal(resp_status(resp), 200)

  body <- resp_body_json(resp)

  # Verify bed_hg38 is present when querying by symbol too
  expect_true("bed_hg38" %in% names(body))
})
