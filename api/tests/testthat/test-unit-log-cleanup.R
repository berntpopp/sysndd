# Unit tests for retention-based log cleanup logic (functions/log-cleanup.R).
#
# These tests exercise the pure logic (validation, SQL construction, dry-run vs
# delete, env parsing) with an injected fake DB layer, so they run on host R
# without RMariaDB / a live database.
source_api_file("functions/log-cleanup.R", local = FALSE)

# --- validate_retention_days ------------------------------------------------

test_that("retention defaults apply for empty / NULL input", {
  expect_identical(validate_retention_days(""), 30L)
  expect_identical(validate_retention_days(NULL), 30L)
  expect_identical(validate_retention_days("", default = 14L), 14L)
})

test_that("valid integer-like retention values are accepted", {
  expect_identical(validate_retention_days("30"), 30L)
  expect_identical(validate_retention_days("7"), 7L)
  expect_identical(validate_retention_days(90), 90L)
  expect_identical(validate_retention_days("  45  "), 45L)
})

test_that("non-integer / unsafe retention values are rejected (injection guard)", {
  expect_error(validate_retention_days("30; DROP TABLE logging"))
  expect_error(validate_retention_days("30 OR 1=1"))
  expect_error(validate_retention_days("abc"))
  expect_error(validate_retention_days("-5"))
  expect_error(validate_retention_days("0"))
  expect_error(validate_retention_days("3.5"))
})

# --- validate_sql_identifier ------------------------------------------------

test_that("bare identifiers are accepted, unsafe ones rejected", {
  expect_identical(validate_sql_identifier("logging"), "logging")
  expect_identical(validate_sql_identifier("timestamp", "column"), "timestamp")
  expect_error(validate_sql_identifier("logging; DROP TABLE x"))
  expect_error(validate_sql_identifier("log table"))
  expect_error(validate_sql_identifier("1bad"))
  expect_error(validate_sql_identifier(""))
  expect_error(validate_sql_identifier(NULL))
})

# --- SQL builders -----------------------------------------------------------

test_that("count SQL targets the real table/column with a validated integer", {
  sql <- build_log_cleanup_count_sql("logging", "timestamp", 30L)
  expect_match(sql, "^SELECT COUNT\\(\\*\\) AS n FROM logging WHERE timestamp < \\(NOW\\(\\) - INTERVAL 30 DAY\\)$")
})

test_that("delete SQL targets the real table/column with a validated integer", {
  sql <- build_log_cleanup_delete_sql("logging", "timestamp", 30L)
  expect_match(sql, "^DELETE FROM logging WHERE timestamp < \\(NOW\\(\\) - INTERVAL 30 DAY\\)$")
})

test_that("SQL builders coerce string retention and reject unsafe values", {
  expect_match(build_log_cleanup_delete_sql("logging", "timestamp", "15"), "INTERVAL 15 DAY")
  expect_error(build_log_cleanup_delete_sql("logging", "timestamp", "x; DROP TABLE logging"))
})

# --- env parsing ------------------------------------------------------------

test_that("truthy env detection is case-insensitive and conservative", {
  expect_true(log_cleanup_env_is_true("1"))
  expect_true(log_cleanup_env_is_true("true"))
  expect_true(log_cleanup_env_is_true("TRUE"))
  expect_true(log_cleanup_env_is_true("yes"))
  expect_true(log_cleanup_env_is_true("on"))
  expect_false(log_cleanup_env_is_true("0"))
  expect_false(log_cleanup_env_is_true("false"))
  expect_false(log_cleanup_env_is_true(""))
  expect_false(log_cleanup_env_is_true(NULL))
})

test_that("config is assembled from env with validated defaults", {
  fake_env <- function(name, unset = "") {
    vals <- list(
      LOG_RETENTION_DAYS = "45",
      LOG_CLEANUP_DRY_RUN = "true"
    )
    if (!is.null(vals[[name]])) vals[[name]] else unset
  }
  cfg <- log_cleanup_config_from_env(getenv = fake_env)
  expect_identical(cfg$retention_days, 45L)
  expect_identical(cfg$table, "logging")
  expect_identical(cfg$timestamp_column, "timestamp")
  expect_true(cfg$dry_run)
})

test_that("config falls back to defaults when env is unset", {
  empty_env <- function(name, unset = "") unset
  cfg <- log_cleanup_config_from_env(getenv = empty_env)
  expect_identical(cfg$retention_days, 30L)
  expect_identical(cfg$table, "logging")
  expect_identical(cfg$timestamp_column, "timestamp")
  expect_false(cfg$dry_run)
})

# --- run_log_cleanup orchestration -----------------------------------------

test_that("dry-run reports candidates but never calls the executor", {
  count_calls <- character(0)
  execute_called <- FALSE
  cfg <- list(table = "logging", timestamp_column = "timestamp", retention_days = 30L, dry_run = TRUE)

  res <- run_log_cleanup(
    config = cfg,
    count_fn = function(sql) {
      count_calls <<- c(count_calls, sql)
      42L
    },
    execute_fn = function(sql) {
      execute_called <<- TRUE
      stop("executor must not run in dry-run mode")
    },
    logger = function(msg) invisible(NULL)
  )

  expect_false(execute_called)
  expect_length(count_calls, 1L)
  expect_match(count_calls[[1]], "^SELECT COUNT")
  expect_identical(res$candidate_rows, 42L)
  expect_identical(res$deleted_rows, 0L)
  expect_true(res$dry_run)
})

test_that("non-dry-run counts then deletes and reports affected rows", {
  seen_sql <- character(0)
  cfg <- list(table = "logging", timestamp_column = "timestamp", retention_days = 30L, dry_run = FALSE)

  res <- run_log_cleanup(
    config = cfg,
    count_fn = function(sql) {
      seen_sql <<- c(seen_sql, sql)
      100L
    },
    execute_fn = function(sql) {
      seen_sql <<- c(seen_sql, sql)
      100L
    },
    logger = function(msg) invisible(NULL)
  )

  expect_length(seen_sql, 2L)
  expect_match(seen_sql[[1]], "^SELECT COUNT")
  expect_match(seen_sql[[2]], "^DELETE FROM logging")
  expect_identical(res$candidate_rows, 100L)
  expect_identical(res$deleted_rows, 100L)
  expect_false(res$dry_run)
})

test_that("non-integer count/delete results degrade safely to zero", {
  cfg <- list(table = "logging", timestamp_column = "timestamp", retention_days = 30L, dry_run = FALSE)
  res <- run_log_cleanup(
    config = cfg,
    count_fn = function(sql) NA_integer_,
    execute_fn = function(sql) NA_integer_,
    logger = function(msg) invisible(NULL)
  )
  expect_identical(res$candidate_rows, 0L)
  expect_identical(res$deleted_rows, 0L)
})
