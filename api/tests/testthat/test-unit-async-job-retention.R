# Tests for async-job retention cleanup (#535 S7). Pure parameterized SQL
# builders + injected DB layer; no live database.

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

# The exact terminal + non-retryable + aged WHERE clause. Asserting the WHOLE
# clause (not fragments) is deliberate: a predicate that gained `OR 1=1` or
# dropped `active_request_hash IS NULL` would fail this exact match.
EXPECTED_RETENTION_WHERE <- paste(
  "status IN ('completed', 'failed', 'cancelled')",
  "AND active_request_hash IS NULL",
  "AND submitted_at < TIMESTAMPADD(DAY, ?, CURRENT_TIMESTAMP(6))",
  "AND updated_at < TIMESTAMPADD(DAY, ?, CURRENT_TIMESTAMP(6))"
)

test_that("count SQL is the EXACT terminal, non-retryable, aged predicate", {
  spec <- build_async_job_retention_count_sql(90L)
  expect_identical(
    spec$sql,
    paste("SELECT COUNT(*) AS n FROM async_jobs WHERE", EXPECTED_RETENTION_WHERE)
  )
  # Retention window is a BOUND parameter (never interpolated), negative offset.
  expect_identical(spec$params, list(-90L, -90L))
})

test_that("count and delete share the exact same WHERE predicate + params", {
  count_spec <- build_async_job_retention_count_sql(90L)
  del_spec <- build_async_job_retention_delete_sql(90L)
  count_where <- sub("^SELECT COUNT\\(\\*\\) AS n FROM async_jobs WHERE ", "", count_spec$sql)
  del_where <- sub("^DELETE FROM async_jobs WHERE ", "", del_spec$sql)
  expect_identical(count_where, EXPECTED_RETENTION_WHERE)
  expect_identical(del_where, EXPECTED_RETENTION_WHERE)
  expect_identical(count_spec$params, del_spec$params)
})

test_that("delete is a fully-parameterized statement (no interpolation)", {
  spec <- build_async_job_retention_delete_sql(30L)
  expect_identical(spec$sql, paste("DELETE FROM async_jobs WHERE", EXPECTED_RETENTION_WHERE))
  expect_identical(spec$params, list(-30L, -30L))
  # No literal day count is ever baked into the SQL text.
  expect_false(grepl("30", spec$sql, fixed = TRUE))
})

test_that("batched delete is deterministic and bounded (ORDER BY tiebreak + LIMIT ?)", {
  spec <- build_async_job_retention_delete_sql(90L, 500L)
  expect_identical(
    spec$sql,
    paste("DELETE FROM async_jobs WHERE", EXPECTED_RETENTION_WHERE,
          "ORDER BY submitted_at, job_id LIMIT ?")
  )
  # ORDER BY must precede LIMIT, tiebreak on the PK, and LIMIT is also bound.
  expect_lt(regexpr("ORDER BY", spec$sql, fixed = TRUE), regexpr("LIMIT", spec$sql, fixed = TRUE))
  expect_true(grepl("submitted_at, job_id", spec$sql, fixed = TRUE))
  expect_identical(spec$params, list(-90L, -90L, 500L))
  # The unbatched form carries neither ORDER BY nor LIMIT.
  expect_false(grepl("ORDER BY", build_async_job_retention_delete_sql(90L)$sql, fixed = TRUE))
  expect_false(grepl("LIMIT", build_async_job_retention_delete_sql(90L)$sql, fixed = TRUE))
})

test_that("retention days are validated (injection-proof) AND bound", {
  expect_error(build_async_job_retention_delete_sql("30; DROP TABLE async_jobs"))
  expect_error(build_async_job_retention_count_sql("0")) # must be >= 1
  expect_error(build_async_job_retention_count_sql("-5")) # negative fails closed
  # default applies for empty/NULL -> bound offset -90
  expect_identical(build_async_job_retention_count_sql(NULL)$params, list(-90L, -90L))
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

test_that("dry-run counts (with bound params) but never deletes", {
  seen_params <- NULL
  executed <- 0L
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = TRUE),
    count_fn = function(sql, params) {
      seen_params <<- params
      7L
    },
    execute_fn = function(sql, params) {
      executed <<- executed + 1L
      99L
    },
    logger = function(msg) invisible(NULL)
  )
  expect_equal(summary$candidate_rows, 7L)
  expect_equal(summary$deleted_rows, 0L)
  expect_equal(executed, 0L) # DELETE never issued
  expect_identical(seen_params, list(-90L, -90L)) # count bound the window
})

test_that("destructive run skips the pre-count and deletes in batches", {
  # Never pre-counts on a destructive run (extra scan); reports deleted_rows.
  count_calls <- 0L
  returns <- c(1000L, 1000L, 3L) # ASYNC_JOB_RETENTION_BATCH_SIZE is 1000
  i <- 0L
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE),
    count_fn = function(sql, params) {
      count_calls <<- count_calls + 1L
      2003L
    },
    execute_fn = function(sql, params) {
      i <<- i + 1L
      returns[i]
    },
    logger = function(msg) invisible(NULL),
    now_fn = function() as.POSIXct(0, origin = "1970-01-01", tz = "UTC")
  )
  expect_equal(count_calls, 0L) # no pre-count on destructive runs
  expect_equal(i, 3L) # three batches
  expect_equal(summary$deleted_rows, 2003L)
  expect_true(is.na(summary$candidate_rows))
  expect_false(summary$batch_cap_reached)
  expect_false(summary$time_cap_reached)
})

test_that("the run loop is bounded by a max-batches cap", {
  # Every execution reports a full batch (would loop forever without a cap).
  calls <- 0L
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE),
    count_fn = function(sql, params) 1e9,
    execute_fn = function(sql, params) {
      calls <<- calls + 1L
      ASYNC_JOB_RETENTION_BATCH_SIZE # always a full batch
    },
    logger = function(msg) invisible(NULL),
    max_batches = 3L,
    now_fn = function() as.POSIXct(0, origin = "1970-01-01", tz = "UTC") # freeze clock
  )
  expect_equal(calls, 3L) # stops at the cap, not indefinitely
  expect_equal(summary$deleted_rows, 3L * ASYNC_JOB_RETENTION_BATCH_SIZE)
  expect_true(isTRUE(summary$batch_cap_reached))
})

test_that("the run loop is bounded by a wall-clock max-seconds cap", {
  # Fake clock advances 100s per read; the loop must stop on the time cap even
  # though every batch is full and the batch cap is far away.
  step <- 100
  t <- 0
  clock <- function() {
    t <<- t + step
    as.POSIXct(t, origin = "1970-01-01", tz = "UTC")
  }
  calls <- 0L
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE),
    count_fn = function(sql, params) 1e9,
    execute_fn = function(sql, params) {
      calls <<- calls + 1L
      ASYNC_JOB_RETENTION_BATCH_SIZE
    },
    logger = function(msg) invisible(NULL),
    max_batches = 1000L,
    max_seconds = 50, # tripped after the first batch (elapsed 100s)
    now_fn = clock
  )
  expect_equal(calls, 1L)
  expect_true(isTRUE(summary$time_cap_reached))
  expect_false(summary$batch_cap_reached)
})

test_that("dry-run is fail-safe: an unrecognized flag never deletes", {
  # A typo'd dry-run flag (e.g. `treu`) must NOT silently enable deletion.
  expect_warning(res <- async_job_retention_resolve_dry_run("treu"))
  expect_true(res)
  # Explicit truthy / falsy / unset keep intuitive semantics.
  expect_true(async_job_retention_resolve_dry_run("yes"))
  expect_false(async_job_retention_resolve_dry_run("off"))
  expect_false(async_job_retention_resolve_dry_run("false"))
  expect_false(async_job_retention_resolve_dry_run(""))
  expect_false(async_job_retention_resolve_dry_run(NULL))
})

test_that("config_from_env fails safe for an unrecognized dry-run flag", {
  cfg <- suppressWarnings(async_job_retention_config_from_env(getenv = function(k, d = "") {
    switch(k, ASYNC_JOB_RETENTION_DRY_RUN = "treu", d)
  }))
  expect_true(cfg$dry_run) # never deletes on an ambiguous flag
})
