# Tests for async-job retention cleanup (#535 S7). Pure SQL builders + injected
# DB layer; no live database.

if (exists("get_api_dir")) {
  api_dir <- get_api_dir()
} else {
  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
  if (!file.exists(file.path(api_dir, "functions", "async-job-retention.R"))) {
    api_dir <- normalizePath(getwd(), mustWork = FALSE)
  }
}
source(file.path(api_dir, "functions", "log-cleanup.R"), local = FALSE) # validate_retention_days
source(file.path(api_dir, "functions", "async-job-retention.R"), local = FALSE)

test_that("count SQL targets only terminal, non-retryable, aged rows", {
  sql <- build_async_job_retention_count_sql(90L)
  expect_true(grepl("FROM async_jobs", sql, fixed = TRUE))
  expect_true(grepl("status IN ('completed', 'failed', 'cancelled')", sql, fixed = TRUE))
  expect_true(grepl("active_request_hash IS NULL", sql, fixed = TRUE))
  expect_true(grepl("submitted_at < (NOW() - INTERVAL 90 DAY)", sql, fixed = TRUE))
  # Terminal-age guard: also require updated_at older than the window so a
  # just-completed but long-ago-submitted job is not deleted immediately.
  expect_true(grepl("updated_at < (NOW() - INTERVAL 90 DAY)", sql, fixed = TRUE))
  expect_true(grepl("^SELECT COUNT", sql))
})

test_that("count and delete share the same WHERE predicate", {
  count_where <- sub("^SELECT COUNT\\(\\*\\) AS n FROM async_jobs WHERE ", "",
    build_async_job_retention_count_sql(90L))
  del_where <- sub("^DELETE FROM async_jobs WHERE ", "",
    build_async_job_retention_delete_sql(90L))
  expect_equal(count_where, del_where)
})

test_that("delete supports a bounded batch LIMIT", {
  expect_true(grepl("LIMIT 500", build_async_job_retention_delete_sql(90L, 500L), fixed = TRUE))
  expect_false(grepl("LIMIT", build_async_job_retention_delete_sql(90L), fixed = TRUE))
})

test_that("the run loop deletes in batches until under a full batch", {
  returns <- c(1000L, 1000L, 3L) # ASYNC_JOB_RETENTION_BATCH_SIZE is 1000
  i <- 0L
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE),
    count_fn = function(sql) 2003L,
    execute_fn = function(sql) {
      i <<- i + 1L
      returns[i]
    },
    logger = function(msg) invisible(NULL)
  )
  expect_equal(i, 3L) # three batches
  expect_equal(summary$deleted_rows, 2003L)
})

test_that("delete SQL mirrors the count predicate exactly", {
  del <- build_async_job_retention_delete_sql(30L)
  expect_true(grepl("^DELETE FROM async_jobs WHERE", del))
  expect_true(grepl("INTERVAL 30 DAY", del, fixed = TRUE))
  expect_true(grepl("active_request_hash IS NULL", del, fixed = TRUE))
})

test_that("retention days are validated (injection-proof)", {
  expect_error(build_async_job_retention_delete_sql("30; DROP TABLE async_jobs"))
  expect_error(build_async_job_retention_count_sql("0")) # must be >= 1
  # default applies for empty
  expect_true(grepl("INTERVAL 90 DAY", build_async_job_retention_count_sql(NULL), fixed = TRUE))
})

test_that("config_from_env reads ASYNC_JOB_RETENTION_* with defaults", {
  cfg <- async_job_retention_config_from_env(getenv = function(k, d = "") {
    switch(k, ASYNC_JOB_RETENTION_DAYS = "45", ASYNC_JOB_RETENTION_DRY_RUN = "true", d)
  })
  expect_equal(cfg$retention_days, 45L)
  expect_true(cfg$dry_run)
  cfg2 <- async_job_retention_config_from_env(getenv = function(k, d = "") d)
  expect_equal(cfg2$retention_days, 90L)
  expect_false(cfg2$dry_run)
})

test_that("dry-run counts but never deletes", {
  executed <- character(0)
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = TRUE),
    count_fn = function(sql) 7L,
    execute_fn = function(sql) {
      executed <<- c(executed, sql)
      99L
    },
    logger = function(msg) invisible(NULL)
  )
  expect_equal(summary$candidate_rows, 7L)
  expect_equal(summary$deleted_rows, 0L)
  expect_length(executed, 0L) # DELETE never issued
})

test_that("non-dry-run deletes and reports rows affected", {
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE),
    count_fn = function(sql) 5L,
    execute_fn = function(sql) 5L,
    logger = function(msg) invisible(NULL)
  )
  expect_false(summary$dry_run)
  expect_equal(summary$candidate_rows, 5L)
  expect_equal(summary$deleted_rows, 5L)
})
