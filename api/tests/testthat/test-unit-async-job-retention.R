# Tests for async-job retention cleanup (#535 S7). Pure parameterized SQL
# builders + injected DB layer; no live database. The lock-safe delete path is
# select-candidate-PKs (non-locking) then delete-by-PK with a full-predicate
# re-check.

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

.fake_ids <- function(n) as.character(seq_len(n))

test_that("count SQL is the EXACT terminal, non-retryable, aged predicate", {
  spec <- build_async_job_retention_count_sql(90L)
  expect_identical(
    spec$sql,
    paste("SELECT COUNT(*) AS n FROM async_jobs WHERE", EXPECTED_RETENTION_WHERE)
  )
  # Retention window is a BOUND parameter (never interpolated), negative offset.
  expect_identical(spec$params, list(-90L, -90L))
})

test_that("select-ids SQL is a bounded, deterministic, non-locking read", {
  spec <- build_async_job_retention_select_ids_sql(90L, 500L)
  expect_identical(
    spec$sql,
    paste("SELECT job_id FROM async_jobs WHERE", EXPECTED_RETENTION_WHERE,
          "ORDER BY submitted_at, job_id LIMIT ?")
  )
  # oldest-first, PK tiebreak, bound LIMIT; no FOR UPDATE / locking read.
  expect_lt(regexpr("ORDER BY", spec$sql, fixed = TRUE), regexpr("LIMIT", spec$sql, fixed = TRUE))
  expect_true(grepl("submitted_at, job_id", spec$sql, fixed = TRUE))
  expect_false(grepl("FOR UPDATE", spec$sql, ignore.case = TRUE))
  expect_identical(spec$params, list(-90L, -90L, 500L))
})

test_that("delete-by-ids is by PRIMARY KEY and RE-CHECKS the full predicate", {
  spec <- build_async_job_retention_delete_by_ids_sql(c("a", "b", "c"), 90L)
  expect_identical(
    spec$sql,
    paste0("DELETE FROM async_jobs WHERE job_id IN (?, ?, ?) AND ", EXPECTED_RETENTION_WHERE)
  )
  # IN-list PKs first, then the two bound TIMESTAMPADD offsets.
  expect_identical(spec$params, list("a", "b", "c", -90L, -90L))
  # No literal day count is ever baked into the SQL text.
  expect_false(grepl("90", spec$sql, fixed = TRUE))
})

test_that("delete-by-ids refuses an empty id set (never an unbounded DELETE)", {
  expect_error(build_async_job_retention_delete_by_ids_sql(character(0), 90L))
  expect_error(build_async_job_retention_delete_by_ids_sql(NA_character_, 90L))
  expect_error(build_async_job_retention_delete_by_ids_sql(c("", NA), 90L))
})

test_that("count, select, and delete share the exact same terminal WHERE clause", {
  count_where <- sub("^SELECT COUNT\\(\\*\\) AS n FROM async_jobs WHERE ", "",
    build_async_job_retention_count_sql(90L)$sql)
  select_where <- sub(" ORDER BY submitted_at, job_id LIMIT \\?$", "",
    sub("^SELECT job_id FROM async_jobs WHERE ", "",
      build_async_job_retention_select_ids_sql(90L, 10L)$sql))
  delete_where <- sub("^DELETE FROM async_jobs WHERE job_id IN \\(\\?\\) AND ", "",
    build_async_job_retention_delete_by_ids_sql("a", 90L)$sql)
  expect_identical(count_where, EXPECTED_RETENTION_WHERE)
  expect_identical(select_where, EXPECTED_RETENTION_WHERE)
  expect_identical(delete_where, EXPECTED_RETENTION_WHERE)
})

test_that("retention days are validated (injection-proof) AND bound", {
  expect_error(build_async_job_retention_select_ids_sql("30; DROP TABLE async_jobs"))
  expect_error(build_async_job_retention_count_sql("0")) # must be >= 1
  expect_error(build_async_job_retention_count_sql("-5")) # negative fails closed
  # default applies for empty/NULL -> bound offset -90
  expect_identical(build_async_job_retention_count_sql(NULL)$params, list(-90L, -90L))
})

test_that("config_from_env reads ASYNC_JOB_RETENTION_* with defaults", {
  cfg <- async_job_retention_config_from_env(getenv = function(k, d = "") {
    switch(k,
      ASYNC_JOB_RETENTION_DAYS = "45",
      ASYNC_JOB_RETENTION_BATCH_SIZE = "250",
      ASYNC_JOB_RETENTION_DRY_RUN = "true", d)
  })
  expect_equal(cfg$retention_days, 45L)
  expect_equal(cfg$batch_size, 250L)
  expect_true(cfg$dry_run)
  cfg2 <- async_job_retention_config_from_env(getenv = function(k, d = "") d)
  expect_equal(cfg2$retention_days, 90L)
  expect_equal(cfg2$batch_size, 1000L) # default
  expect_false(cfg2$dry_run)
})

test_that("a configured batch_size drives the read LIMIT and delete size", {
  seen_limit <- NULL
  reads <- 0L
  run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE, batch_size = 250L),
    count_fn = function(sql, params) 0L,
    select_ids_fn = function(sql, params) {
      reads <<- reads + 1L
      seen_limit <<- params[[length(params)]] # LIMIT ? is the last bound param
      .fake_ids(10L) # fewer than batch -> single batch
    },
    execute_fn = function(sql, params) length(params) - 2L,
    logger = function(msg) invisible(NULL)
  )
  expect_equal(reads, 1L)
  expect_equal(seen_limit, 250L) # the configured batch size flowed into the read
})

test_that("dry-run counts (with bound params) but never selects or deletes", {
  seen_params <- NULL
  selects <- 0L
  deletes <- 0L
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = TRUE),
    count_fn = function(sql, params) {
      seen_params <<- params
      7L
    },
    select_ids_fn = function(sql, params) {
      selects <<- selects + 1L
      .fake_ids(5)
    },
    execute_fn = function(sql, params) {
      deletes <<- deletes + 1L
      99L
    },
    logger = function(msg) invisible(NULL)
  )
  expect_equal(summary$candidate_rows, 7L)
  expect_equal(summary$deleted_rows, 0L)
  expect_equal(selects, 0L) # no candidate read in dry-run
  expect_equal(deletes, 0L) # DELETE never issued
  expect_identical(seen_params, list(-90L, -90L)) # count bound the window
})

test_that("destructive run skips pre-count, reads PKs, deletes by PK in batches", {
  count_calls <- 0L
  batches <- list(.fake_ids(1000L), .fake_ids(1000L), .fake_ids(3L)) # batch size 1000
  s <- 0L
  del_id_lengths <- integer(0)
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE),
    count_fn = function(sql, params) {
      count_calls <<- count_calls + 1L
      2003L
    },
    select_ids_fn = function(sql, params) {
      s <<- s + 1L
      batches[[s]]
    },
    execute_fn = function(sql, params) {
      # params = c(ids..., off, off); rows deleted == number of ids in this batch
      del_id_lengths <<- c(del_id_lengths, length(params) - 2L)
      length(params) - 2L
    },
    logger = function(msg) invisible(NULL),
    now_fn = function() as.POSIXct(0, origin = "1970-01-01", tz = "UTC")
  )
  expect_equal(count_calls, 0L) # no pre-count on destructive runs
  expect_equal(s, 3L) # three candidate reads
  expect_identical(del_id_lengths, c(1000L, 1000L, 3L))
  expect_equal(summary$deleted_rows, 2003L)
  expect_true(is.na(summary$candidate_rows))
  expect_false(summary$batch_cap_reached)
  expect_false(summary$time_cap_reached)
})

test_that("run loop stops immediately when no candidates remain", {
  deletes <- 0L
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE),
    count_fn = function(sql, params) 0L,
    select_ids_fn = function(sql, params) character(0),
    execute_fn = function(sql, params) {
      deletes <<- deletes + 1L
      5L
    },
    logger = function(msg) invisible(NULL)
  )
  expect_equal(deletes, 0L)
  expect_equal(summary$deleted_rows, 0L)
})

test_that("the run loop is bounded by a max-batches cap", {
  # Every read returns a full batch (would loop forever without a cap).
  reads <- 0L
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE),
    count_fn = function(sql, params) 1e9,
    select_ids_fn = function(sql, params) {
      reads <<- reads + 1L
      .fake_ids(ASYNC_JOB_RETENTION_BATCH_SIZE)
    },
    execute_fn = function(sql, params) length(params) - 2L, # full batch deleted
    logger = function(msg) invisible(NULL),
    max_batches = 3L,
    now_fn = function() as.POSIXct(0, origin = "1970-01-01", tz = "UTC") # freeze clock
  )
  expect_equal(reads, 3L) # stops at the cap, not indefinitely
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
  reads <- 0L
  summary <- run_async_job_retention(
    config = list(retention_days = 90L, dry_run = FALSE),
    count_fn = function(sql, params) 1e9,
    select_ids_fn = function(sql, params) {
      reads <<- reads + 1L
      .fake_ids(ASYNC_JOB_RETENTION_BATCH_SIZE)
    },
    execute_fn = function(sql, params) length(params) - 2L,
    logger = function(msg) invisible(NULL),
    max_batches = 1000L,
    max_seconds = 50, # tripped after the first batch (elapsed 100s)
    now_fn = clock
  )
  expect_equal(reads, 1L)
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
