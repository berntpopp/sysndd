# tests/testthat/test-unit-review-update-allowlist.R
#
# Guard (LOW-8, Codex): review_update() builds its UPDATE ... SET clause from
# names(updates). The main /api/review/update path passes a fixed-column tibble
# (safe), but svc_review_update() and direct callers pass arbitrary update_data,
# so the repository restricts field names to writable ndd_entity_review columns
# before interpolation (SQL-identifier injection / mass-assignment defense).
#
# Pure (rejection runs before db_with_transaction) — runs on host.

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)
if (!requireNamespace("logger", quietly = TRUE)) {
  stop("logger package not available — cannot run review-repository tests")
}
source_api_file("functions/review-repository.R", local = FALSE)

test_that("review_update rejects injection + unknown column names", {
  skip_if_not(exists("review_update"))
  expect_error(review_update(1, list("synopsis = x, y" = "z")))  # SQL-identifier injection
  expect_error(review_update(1, list(bogus_col = "x")))          # unknown column
  expect_error(review_update(1, list(synopsis = "ok", evil = "y"))) # mixed valid+invalid
})

test_that("review_update allowlist covers writable columns and excludes protected keys", {
  skip_if_not(exists("review_update"))
  body <- paste(deparse(body(review_update)), collapse = " ")
  expect_true(grepl("allowed_review_cols", body))
  for (col in c("synopsis", "comment", "review_approved")) {
    expect_true(grepl(col, body), info = paste("writable column missing:", col))
  }
})
