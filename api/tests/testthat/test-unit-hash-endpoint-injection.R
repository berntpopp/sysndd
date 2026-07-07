# Guard: the hash-create path must validate column tokens BEFORE any
# expression evaluation, and must never parse a column name as R code (#1 RCE).
test_that("post_db_hash rejects a non-allowlisted column before any evaluation", {
  src <- readLines("../../functions/data-helpers.R", warn = FALSE)
  body <- paste(src, collapse = "\n")

  # (a) No parse_exprs over a column name inside post_db_hash's arrange.
  expect_false(
    grepl("arrange\\(!!!rlang::parse_exprs\\(", body),
    info = "post_db_hash must not parse a column name as an R expression"
  )

  # (b) hash_validate_columns must appear BEFORE the first arrange() call.
  first_validate <- regexpr("hash_validate_columns\\(colnames", body)
  first_arrange  <- regexpr("arrange\\(", body)
  expect_true(first_validate > 0 && first_arrange > 0)
  expect_lt(first_validate, first_arrange)
})

test_that("post_db_hash raises a bad-request error on an unexpected column and runs no shell", {
  skip_if_not(exists("post_db_hash"), "API not sourced")
  sentinel <- tempfile()
  malicious <- stats::setNames(list(1L), paste0("system('touch ", sentinel, "')"))
  expect_error(
    post_db_hash(malicious, "symbol,hgnc_id,entity_id", "/api/gene")
  )
  expect_false(file.exists(sentinel),
               info = "injected command must NOT have executed")
})
