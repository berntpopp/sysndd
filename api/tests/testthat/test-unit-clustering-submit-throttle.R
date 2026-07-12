# Tests for the per-caller clustering submit throttle (#535 S6).
# Pure logic (injectable clock + store); no DB.

if (exists("get_api_dir")) {
  api_dir <- get_api_dir()
} else {
  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
  if (!file.exists(file.path(api_dir, "functions", "async-job-service.R"))) {
    api_dir <- normalizePath(file.path(getwd()), mustWork = FALSE)
  }
}
source(file.path(api_dir, "functions", "async-job-service.R"), local = FALSE)

test_that("allows up to max_n submissions in the window, then throttles", {
  st <- new.env(parent = emptyenv())
  for (i in 1:3) {
    r <- async_job_submit_rate_limit("1.2.3.4", now = 1000, max_n = 3L, window_s = 60L, store = st)
    expect_true(r$allowed)
    expect_equal(r$count, i)
  }
  r4 <- async_job_submit_rate_limit("1.2.3.4", now = 1000, max_n = 3L, window_s = 60L, store = st)
  expect_false(r4$allowed)
  expect_equal(r4$retry_after, 60L) # oldest (t=1000) frees at 1060, now=1000
})

test_that("the window slides: old submissions expire", {
  st <- new.env(parent = emptyenv())
  for (i in 1:3) {
    async_job_submit_rate_limit("ip", now = 1000, max_n = 3L, window_s = 60L, store = st)
  }
  # at now=1061 the t=1000 entries are all outside the 60s window
  r <- async_job_submit_rate_limit("ip", now = 1061, max_n = 3L, window_s = 60L, store = st)
  expect_true(r$allowed)
  expect_equal(r$count, 1L)
})

test_that("retry_after reflects when the oldest in-window entry ages out", {
  st <- new.env(parent = emptyenv())
  async_job_submit_rate_limit("ip", now = 1000, max_n = 1L, window_s = 60L, store = st)
  r <- async_job_submit_rate_limit("ip", now = 1030, max_n = 1L, window_s = 60L, store = st)
  expect_false(r$allowed)
  expect_equal(r$retry_after, 30L) # oldest t=1000 frees at 1060, now=1030 -> 30
})

test_that("distinct fingerprints are throttled independently", {
  st <- new.env(parent = emptyenv())
  for (i in 1:3) {
    async_job_submit_rate_limit("a", now = 1000, max_n = 3L, window_s = 60L, store = st)
  }
  expect_false(async_job_submit_rate_limit("a", now = 1000, max_n = 3L, window_s = 60L, store = st)$allowed)
  # a different caller is unaffected
  expect_true(async_job_submit_rate_limit("b", now = 1000, max_n = 3L, window_s = 60L, store = st)$allowed)
})

test_that("a non-positive cap disables the limiter", {
  st <- new.env(parent = emptyenv())
  for (i in 1:100) {
    expect_true(async_job_submit_rate_limit("x", now = 1000, max_n = 0L, window_s = 60L, store = st)$allowed)
  }
})

test_that("empty/NULL fingerprint collapses to a single 'unknown' bucket", {
  st <- new.env(parent = emptyenv())
  async_job_submit_rate_limit(NULL, now = 1000, max_n = 1L, window_s = 60L, store = st)
  expect_false(async_job_submit_rate_limit("", now = 1000, max_n = 1L, window_s = 60L, store = st)$allowed)
})

test_that("fingerprint prefers X-Forwarded-For first hop over REMOTE_ADDR", {
  req <- list(HTTP_X_FORWARDED_FOR = "9.9.9.9, 10.0.0.1", REMOTE_ADDR = "172.18.0.5")
  expect_equal(async_job_submit_fingerprint(req), "9.9.9.9")
})

test_that("fingerprint falls back to REMOTE_ADDR, then 'unknown'", {
  expect_equal(async_job_submit_fingerprint(list(REMOTE_ADDR = "172.18.0.5")), "172.18.0.5")
  expect_equal(async_job_submit_fingerprint(list()), "unknown")
  expect_equal(async_job_submit_fingerprint(list(HTTP_X_FORWARDED_FOR = "")), "unknown")
})
