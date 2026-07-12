# Tests for the per-caller clustering submit throttle (#535 S6).
# Pure logic (injectable clock + store); no DB.

if (exists("get_api_dir")) {
  api_dir <- get_api_dir()
} else {
  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
  if (!file.exists(file.path(api_dir, "functions", "clustering-submit-throttle.R"))) {
    api_dir <- normalizePath(file.path(getwd()), mustWork = FALSE)
  }
}
source(file.path(api_dir, "functions", "clustering-submit-throttle.R"), local = FALSE)

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

test_that("fingerprint uses the proxy-appended (rightmost) XFF hop, not the spoofable first", {
  # Traefik (1 trusted hop) appends the real client as the LAST entry; leftmost
  # entries are client-supplied and must not be trusted.
  req <- list(HTTP_X_FORWARDED_FOR = "9.9.9.9, 10.0.0.1", REMOTE_ADDR = "172.18.0.5")
  expect_equal(async_job_submit_fingerprint(req, trusted_hops = 1L), "10.0.0.1")
  # A spoofed leftmost value cannot change the appended hop.
  spoof <- list(HTTP_X_FORWARDED_FOR = "evil-rotating-value, 10.0.0.1")
  expect_equal(async_job_submit_fingerprint(spoof, trusted_hops = 1L), "10.0.0.1")
  # Two trusted hops -> take the entry two from the right.
  req2 <- list(HTTP_X_FORWARDED_FOR = "client, edge, traefik")
  expect_equal(async_job_submit_fingerprint(req2, trusted_hops = 2L), "edge")
})

test_that("fingerprint falls back to REMOTE_ADDR, then 'unknown'", {
  expect_equal(async_job_submit_fingerprint(list(REMOTE_ADDR = "172.18.0.5")), "172.18.0.5")
  expect_equal(async_job_submit_fingerprint(list()), "unknown")
  expect_equal(async_job_submit_fingerprint(list(HTTP_X_FORWARDED_FOR = "")), "unknown")
})

test_that("the store is bounded against fingerprint rotation (memory-DoS guard)", {
  st <- new.env(parent = emptyenv())
  # Simulate rotation: many distinct fingerprints, each allowed once, at t=1000.
  for (i in 1:50) {
    async_job_submit_rate_limit(sprintf("ip-%d", i), now = 1000,
      max_n = 3L, window_s = 60L, store = st, max_tracked = 10L)
  }
  expect_lte(length(ls(envir = st)), 10L) # hard-capped, not 50
  # After the window, a fresh caller sweeps out the fully-expired buckets.
  async_job_submit_rate_limit("newcomer", now = 2000,
    max_n = 3L, window_s = 60L, store = st, max_tracked = 10L)
  expect_lte(length(ls(envir = st)), 10L)
})

test_that("invalid env values fall back to safe defaults (not disable/corrupt)", {
  expect_equal(.async_job_submit_env_int("NOPE_UNSET_VAR_XYZ", 5L, 0L), 5L)
  withr::with_envvar(c(SOME_BAD = "abc"), expect_equal(.async_job_submit_env_int("SOME_BAD", 5L, 0L), 5L))
  withr::with_envvar(c(SOME_NEG = "-3"), expect_equal(.async_job_submit_env_int("SOME_NEG", 60L, 1L), 60L))
  withr::with_envvar(c(SOME_OK = "7"), expect_equal(.async_job_submit_env_int("SOME_OK", 5L, 0L), 7L))
})
