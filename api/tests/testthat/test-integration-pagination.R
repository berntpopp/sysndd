# tests/testthat/test-integration-pagination.R
# Integration tests for cursor-based pagination
#
# These tests verify that pagination works correctly on refactored endpoints,
# respects page_size limits, and provides proper navigation structure.
# Phase C7 rollback-audit exempt: non-transactional HTTP-only integration file.
# rollback: none needed — every test issues read-only HTTP GETs, no mutation.
# non-transactional: skip_if_no_test_db() token below is documentation-only.
# exempt rationale: see .planning/_archive/legacy-plans/v11.0/phase-c.md §3 Phase C.4 / §4.5.

library(testthat)
library(httr2)

# =============================================================================
# Helper: Check if API is running
# =============================================================================

skip_if_api_not_running <- function() {
  skip_if_sysndd_api_not_running("http://localhost:8000")
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

# =============================================================================
# Entity-list compact mode (filter pushdown + skip global fspec)
# =============================================================================
# These tests guard the v11.3 perf fix that emits SQL-equality for
# `equals(col, val)` and pushes the filter to dbplyr when `compact=true`.
# See .planning/perf/2026-04-26-deep-load-analysis.md.

test_that("entity-list returns the same rows in compact and default mode", {
  skip_if_api_not_running()

  default <- request("http://localhost:8000/api/entity") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)", page_size = 50) %>%
    req_perform() %>%
    resp_body_json()

  compact <- request("http://localhost:8000/api/entity") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)", page_size = 50, compact = "true") %>%
    req_perform() %>%
    resp_body_json()

  default_ids <- sort(vapply(default$data, function(r) r$entity_id, integer(1)))
  compact_ids <- sort(vapply(compact$data, function(r) r$entity_id, integer(1)))
  expect_equal(compact_ids, default_ids)
  expect_equal(length(compact$data), length(default$data))
})

test_that("compact mode collapses count and count_filtered (no global fspec)", {
  skip_if_api_not_running()

  body <- request("http://localhost:8000/api/entity") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)", page_size = 10, compact = "true") %>%
    req_perform() %>%
    resp_body_json()

  fspec <- body$meta$fspec$fspec
  expect_true(length(fspec) > 0)
  for (row in fspec) {
    if (!is.null(row$count) && !is.null(row$count_filtered)) {
      expect_equal(row$count, row$count_filtered,
                   info = paste("compact mode count != count_filtered for key:", row$key))
    }
  }
})

test_that("default mode keeps the global fspec (count >= count_filtered)", {
  skip_if_api_not_running()

  body <- request("http://localhost:8000/api/entity") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)", page_size = 10) %>%
    req_perform() %>%
    resp_body_json()

  fspec <- body$meta$fspec$fspec
  expect_true(length(fspec) > 0)
  saw_global_gt_filtered <- FALSE
  for (row in fspec) {
    if (!is.null(row$count) && !is.null(row$count_filtered)) {
      expect_true(row$count >= row$count_filtered,
                  info = paste("global count must be >= filtered for key:", row$key))
      if (row$count > row$count_filtered) saw_global_gt_filtered <- TRUE
    }
  }
  # At least one fspec row should show the global is wider than the filter,
  # otherwise the test data is too small to verify the contract.
  expect_true(saw_global_gt_filtered,
              info = "expected at least one fspec row where global count > filtered count")
})

test_that("compact mode HGNC-id filter form returns the same rows as symbol form", {
  skip_if_api_not_running()

  by_symbol <- request("http://localhost:8000/api/entity") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)", page_size = 50, compact = "true") %>%
    req_perform() %>%
    resp_body_json()

  by_hgnc <- request("http://localhost:8000/api/entity") %>%
    req_url_query(filter = "equals(hgnc_id,HGNC:4586)", page_size = 50, compact = "true") %>%
    req_perform() %>%
    resp_body_json()

  symbol_ids <- sort(vapply(by_symbol$data, function(r) r$entity_id, integer(1)))
  hgnc_ids <- sort(vapply(by_hgnc$data, function(r) r$entity_id, integer(1)))
  expect_equal(hgnc_ids, symbol_ids)
})

test_that("compact mode unknown symbol returns 0 rows (not an error)", {
  skip_if_api_not_running()

  body <- request("http://localhost:8000/api/entity") %>%
    req_url_query(filter = "equals(symbol,NOT_A_REAL_GENE_XYZ)",
                  page_size = 10, compact = "true") %>%
    req_perform() %>%
    resp_body_json()

  expect_equal(length(body$data), 0)
})

test_that("compact mode equals matches case-insensitively (MySQL collation)", {
  skip_if_api_not_running()

  upper <- request("http://localhost:8000/api/entity") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)", page_size = 50, compact = "true") %>%
    req_perform() %>%
    resp_body_json()
  lower <- request("http://localhost:8000/api/entity") %>%
    req_url_query(filter = "equals(symbol,grin2b)", page_size = 50, compact = "true") %>%
    req_perform() %>%
    resp_body_json()

  upper_ids <- sort(vapply(upper$data, function(r) r$entity_id, integer(1)))
  lower_ids <- sort(vapply(lower$data, function(r) r$entity_id, integer(1)))
  # Behavioural change vs the pre-v11.3 in-R str_detect path: SQL `=` uses
  # column collation (utf8mb3_general_ci on our schema), so case folds.
  expect_equal(lower_ids, upper_ids)
})

test_that("compact mode handles composed and()/or() filters", {
  skip_if_api_not_running()

  combined <- request("http://localhost:8000/api/entity") %>%
    req_url_query(
      filter = "or(equals(symbol,GRIN2B),equals(symbol,MECP2))",
      page_size = 50, compact = "true"
    ) %>%
    req_perform() %>%
    resp_body_json()

  symbols <- vapply(combined$data, function(r) r$symbol, character(1))
  expect_true(all(symbols %in% c("GRIN2B", "MECP2")))
  expect_true("GRIN2B" %in% symbols || "MECP2" %in% symbols)
})

# =============================================================================
# Publication endpoint — unconditional SQL pushdown (no compact flag)
# =============================================================================

test_that("publication endpoint with equals filter pushes to SQL and returns the same rows as no-filter scan", {
  skip_if_api_not_running()

  # Pick a known PMID by fetching the first row, then re-fetch by exact id.
  first <- request("http://localhost:8000/api/publication") %>%
    req_url_query(page_size = 1) %>%
    req_perform() %>%
    resp_body_json()
  skip_if(length(first$data) == 0, "no publication rows available")

  pmid <- first$data[[1]]$publication_id
  filtered <- request("http://localhost:8000/api/publication") %>%
    req_url_query(filter = paste0("equals(publication_id,", pmid, ")"), page_size = 5) %>%
    req_perform() %>%
    resp_body_json()

  expect_equal(length(filtered$data), 1)
  expect_equal(filtered$data[[1]]$publication_id, pmid)
})

test_that("publication endpoint without filter returns full first page (regression guard)", {
  skip_if_api_not_running()

  body <- request("http://localhost:8000/api/publication") %>%
    req_url_query(page_size = 10) %>%
    req_perform() %>%
    resp_body_json()

  expect_gt(length(body$data), 0)
})

# =============================================================================
# /api/gene/ — pre-pushdown baseline (default mode)
# =============================================================================

test_that("/api/gene/ returns the GRIN2B row when filtered by symbol", {
  skip_if_api_not_running()
  resp <- request("http://localhost:8000/api/gene/") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)") %>%
    req_perform()
  expect_equal(resp_status(resp), 200)
  body <- resp_body_json(resp)
  expect_gte(length(body$data), 1L)
  expect_true(any(vapply(body$data, function(r) r$symbol == "GRIN2B", logical(1L))))
})

test_that("/api/gene/ returns the GRIN2B row when filtered by hgnc_id", {
  skip_if_api_not_running()
  resp <- request("http://localhost:8000/api/gene/") %>%
    req_url_query(filter = "equals(hgnc_id,HGNC:4586)") %>%
    req_perform()
  expect_equal(resp_status(resp), 200)
  body <- resp_body_json(resp)
  expect_true(any(vapply(body$data, function(r) r$symbol == "GRIN2B", logical(1L))))
})

test_that("/api/gene/ default and compact modes return same data for GRIN2B (parity)", {
  skip_if_api_not_running()
  default_body <- request("http://localhost:8000/api/gene/") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)") %>%
    req_perform() %>% resp_body_json()
  compact_body <- request("http://localhost:8000/api/gene/") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)", compact = "true") %>%
    req_perform() %>% resp_body_json()
  expect_equal(length(default_body$data), length(compact_body$data))
  default_grin <- Filter(function(r) r$symbol == "GRIN2B", default_body$data)[[1L]]
  compact_grin <- Filter(function(r) r$symbol == "GRIN2B", compact_body$data)[[1L]]
  expect_equal(default_grin$entities_count, compact_grin$entities_count)
})

# =============================================================================
# /api/gene/?compact=true — edge cases
# =============================================================================

test_that("/api/gene/?compact=true is case-insensitive (utf8mb3_general_ci)", {
  skip_if_api_not_running()
  upper <- request("http://localhost:8000/api/gene/") %>%
    req_url_query(filter = "equals(symbol,GRIN2B)", compact = "true") %>%
    req_perform() %>% resp_body_json()
  lower <- request("http://localhost:8000/api/gene/") %>%
    req_url_query(filter = "equals(symbol,grin2b)", compact = "true") %>%
    req_perform() %>% resp_body_json()
  expect_equal(length(upper$data), length(lower$data))
})

test_that("/api/gene/?compact=true returns empty data for unknown symbol", {
  skip_if_api_not_running()
  resp <- request("http://localhost:8000/api/gene/") %>%
    req_url_query(filter = "equals(symbol,DEFINITELY_NOT_REAL)", compact = "true") %>%
    req_perform()
  body <- resp_body_json(resp)
  expect_equal(length(body$data), 0L)
})

test_that("/api/gene/?compact=true accepts composed and(equals(...),equals(...))", {
  skip_if_api_not_running()
  resp <- request("http://localhost:8000/api/gene/") %>%
    req_url_query(filter = "and(equals(symbol,GRIN2B),equals(category,Definitive))",
                  compact = "true") %>%
    req_perform()
  expect_equal(resp_status(resp), 200)
})

test_that("/api/gene/?compact=true falls back to in-R when filter cannot be SQL-translated", {
  skip_if_api_not_running()
  # contains() with a substring may or may not translate to SQL via dbplyr.
  # Whichever path is taken, the response should still be correct.
  resp <- request("http://localhost:8000/api/gene/") %>%
    req_url_query(filter = "contains(symbol,GRIN)", compact = "true") %>%
    req_perform()
  expect_equal(resp_status(resp), 200)
  body <- resp_body_json(resp)
  expect_gte(length(body$data), 1L)
})

# =============================================================================
# /api/statistics/entities_over_time — pre-pushdown baseline
# =============================================================================

test_that("/api/statistics/entities_over_time returns aggregated counts (default)", {
  skip_if_api_not_running()
  resp <- request("http://localhost:8000/api/statistics/entities_over_time") %>%
    req_url_query(aggregate = "entity_id", group = "category", summarize = "year") %>%
    req_perform()
  expect_equal(resp_status(resp), 200)
  body <- resp_body_json(resp)
  expect_gte(length(body$data %||% body), 1L)
})

test_that("/api/statistics/entities_over_time respects a category filter", {
  skip_if_api_not_running()
  resp <- request("http://localhost:8000/api/statistics/entities_over_time") %>%
    req_url_query(
      aggregate = "entity_id", group = "category", summarize = "year",
      filter = "equals(category,Definitive)"
    ) %>%
    req_perform()
  expect_equal(resp_status(resp), 200)
})

test_that("/api/statistics/entities_over_time pushdown parity (filtered <= unfiltered)", {
  skip_if_api_not_running()
  unfiltered <- request("http://localhost:8000/api/statistics/entities_over_time") %>%
    req_url_query(aggregate = "entity_id", group = "category", summarize = "year") %>%
    req_perform() %>% resp_body_json()
  filtered <- request("http://localhost:8000/api/statistics/entities_over_time") %>%
    req_url_query(
      aggregate = "entity_id", group = "category", summarize = "year",
      filter = "equals(category,Definitive)"
    ) %>%
    req_perform() %>% resp_body_json()
  expect_lte(length(filtered$data %||% filtered),
             length(unfiltered$data %||% unfiltered))
})
