# tests/testthat/test-unit-pubtator-public-route-guard.R
#
# Guard (#6): the two public pubtator GET routes made live PubTator calls with
# raw fetchers (no budget, no per-request ceiling). /pubtator/search must route
# through the budget-bounded helper, and /pubtator/cache-status (user-supplied,
# cache-defeating query) must be role-gated AND budget-bounded.
#
# Source scan — runs on host.

test_that("public pubtator routes are budget-bounded and cache-status is gated", {
  ep <- paste(readLines(file.path(get_api_dir(), "endpoints", "publication_endpoints.R"),
                        warn = FALSE), collapse = "\n")

  # Both public routes go through the budget-bounded helpers.
  expect_true(grepl("pubtator_public_search", ep, fixed = TRUE))
  expect_true(grepl("pubtator_public_total_pages", ep, fixed = TRUE))

  # The cache-status handler must require a role (operational probe, not public).
  cs_idx <- regexpr("@get /pubtator/cache-status", ep, fixed = TRUE)
  expect_gt(cs_idx, 0)
  cs_block <- substr(ep, cs_idx, cs_idx + 500)
  expect_true(grepl("require_role", cs_block),
              info = "/pubtator/cache-status must be role-gated")
})

test_that("pubtator public helpers derive their budget + enforce the request ceiling", {
  h <- paste(readLines(file.path(get_api_dir(), "functions", "publication-endpoint-helpers.R"),
                       warn = FALSE), collapse = "\n")
  expect_true(grepl('external_proxy_budget("pubtator"', h, fixed = TRUE))
  expect_true(grepl('external_proxy_with_timing("pubtator"', h, fixed = TRUE))
  # No hardcoded req_timeout / options(timeout = <literal>) — must derive from budget.
  expect_true(grepl("options(timeout = budget$max_seconds)", h, fixed = TRUE))
  # The public search must cap the raw client's internal retry loop so it cannot
  # hold a worker past the budget, and must treat NULL (post-retry failure) as a
  # degraded 503, not a 200 with empty data (Codex PR-2 MEDIUM-1).
  expect_true(grepl("max_retries = 0", h, fixed = TRUE))
  expect_true(grepl("is.null(pmids)", h, fixed = TRUE))
})
