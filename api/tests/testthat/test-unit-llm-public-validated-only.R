# tests/testthat/test-unit-llm-public-validated-only.R
#
# Guard (#7): the public / cache-hit cluster-summary path must serve ONLY
# judge-validated summaries. Previously it looked up with require_validated =
# FALSE and fell through to serve `pending` (un-judged) rows to anonymous
# callers. It now serves validated-only and fetches the terminal `rejected`
# card via an explicit status lookup.
#
# Source scan — runs on host.

test_that("public cluster-summary serve path requires validated summaries", {
  src <- paste(readLines(file.path(get_api_dir(), "functions", "llm-endpoint-helpers.R"),
                         warn = FALSE), collapse = "\n")
  # The primary serve lookup must NOT be require_validated = FALSE.
  expect_false(grepl("get_cached_summary\\(raw_hash,\\s*require_validated\\s*=\\s*FALSE\\)", src),
               info = "the serve path must not fetch/serve non-validated rows")
  # It must be require_validated = TRUE.
  expect_true(grepl("get_cached_summary\\(raw_hash,\\s*require_validated\\s*=\\s*TRUE\\)", src))
  # The terminal rejected card is fetched explicitly by status.
  expect_true(grepl('status = "rejected"', src, fixed = TRUE))
})

test_that("get_cached_summary supports an explicit status filter", {
  src <- paste(readLines(file.path(get_api_dir(), "functions", "llm-cache-repository.R"),
                         warn = FALSE), collapse = "\n")
  # New optional status arg + a parameterized validation_status predicate.
  expect_true(grepl("status = NULL", src, fixed = TRUE))
  expect_true(grepl("AND validation_status = ?", src, fixed = TRUE))
})
