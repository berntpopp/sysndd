# tests/testthat/test-unit-user-update-allowlist.R
#
# Guard (#4): user_update() built its UPDATE ... SET clause from caller-supplied
# field names, allowing SQL-identifier injection and mass-assignment of
# non-updatable `user` columns. The allowlist rejects any non-writable key
# before the SET clause is interpolated.
#
# Pure (rejection paths run before db_execute_statement) — runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-user-update-allowlist.R')"

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)
if (!requireNamespace("logger", quietly = TRUE)) {
  stop("logger package not available — cannot run user-repository tests")
}
source_api_file("functions/user-repository.R", local = FALSE)

test_that("user_update rejects injection + unknown field names (before touching the DB)", {
  skip_if_not(exists("user_update"))
  expect_error(user_update(1, list("user_role = 'x', y" = "z")))       # SQL-identifier injection
  expect_error(user_update(1, list(bogus_col = "x")))                  # unknown column
  expect_error(user_update(1, list(user_id = 2)))                      # PK not writable
  expect_error(user_update(1, list(created_at = "2020-01-01")))        # immutable
  expect_error(user_update(1, list(user_name = "ok", evil_col = "y"))) # mixed valid+invalid
})

test_that("user_update allowlist covers writable columns and excludes PK/password/created_at", {
  skip_if_not(exists("user_update"))
  body <- paste(deparse(body(user_update)), collapse = " ")
  expect_true(grepl("allowed_user_cols", body))
  for (col in c("user_role", "email", "approved", "password_reset_date")) {
    expect_true(grepl(col, body), info = paste("writable column missing:", col))
  }
  # password fields are stripped earlier; PK + created_at must not be writable.
  expect_false(grepl('"user_id"', body, fixed = TRUE))
  expect_false(grepl('"created_at"', body, fixed = TRUE))
  expect_false(grepl('"password"', body, fixed = TRUE))
})
