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
  spoof <- list(HTTP_X_FORWARDED_FOR = "1.1.1.1, 10.0.0.1")
  expect_equal(async_job_submit_fingerprint(spoof, trusted_hops = 1L), "10.0.0.1")
  # Real 2-proxy chain: the edge appends the real client, Traefik appends the edge.
  # XFF = "<spoof>, <real-client>, <edge-ip>"; 2 trusted hops -> the real client
  # (the entry the OUTERMOST trusted proxy appended = 2nd from the right).
  req2 <- list(HTTP_X_FORWARDED_FOR = "1.1.1.1, 2.2.2.2, 3.3.3.3")
  expect_equal(async_job_submit_fingerprint(req2, trusted_hops = 2L), "2.2.2.2")
})

test_that("fingerprint falls back to REMOTE_ADDR, then 'unknown'", {
  expect_equal(async_job_submit_fingerprint(list(REMOTE_ADDR = "172.18.0.5")), "172.18.0.5")
  expect_equal(async_job_submit_fingerprint(list()), "unknown")
  expect_equal(async_job_submit_fingerprint(list(HTTP_X_FORWARDED_FOR = "")), "unknown")
})

test_that("a non-IP XFF token is rejected and falls back to a server-owned source", {
  # Header-alias injection (X_Forwarded_For colliding with X-Forwarded-For) or any
  # junk in the selected hop must NOT become a throttle key: it would let an
  # attacker rotate arbitrary strings to evade the limit and exhaust the store.
  req <- list(HTTP_X_FORWARDED_FOR = "evil-rotating-value", REMOTE_ADDR = "172.18.0.5")
  expect_equal(async_job_submit_fingerprint(req, trusted_hops = 1L), "172.18.0.5")
  # No valid IP anywhere -> stable constant, never the attacker string.
  req2 <- list(HTTP_X_FORWARDED_FOR = "not an ip")
  expect_equal(async_job_submit_fingerprint(req2, trusted_hops = 1L), "unknown")
  # Out-of-range octets are not a valid IPv4.
  req3 <- list(HTTP_X_FORWARDED_FOR = "999.1.1.1", REMOTE_ADDR = "10.0.0.9")
  expect_equal(async_job_submit_fingerprint(req3, trusted_hops = 1L), "10.0.0.9")
})

test_that("an IPv4 host:port is normalized to the bare IP", {
  req <- list(HTTP_X_FORWARDED_FOR = "203.0.113.7:54321")
  expect_equal(async_job_submit_fingerprint(req, trusted_hops = 1L), "203.0.113.7")
})

test_that("IPv6 rotation within a /64 collapses to one throttle bucket", {
  # An attacker with a /64 allocation can rotate 2^64 addresses; grouping by the
  # /64 network prefix keeps them one caller instead of 2^64 fresh buckets.
  a <- async_job_submit_fingerprint(list(HTTP_X_FORWARDED_FOR = "2001:db8:abcd:1::1"))
  b <- async_job_submit_fingerprint(list(HTTP_X_FORWARDED_FOR = "2001:db8:abcd:1::dead:beef"))
  expect_equal(a, b)              # same /64 -> same key
  expect_match(a, "/64$")
  c <- async_job_submit_fingerprint(list(HTTP_X_FORWARDED_FOR = "2001:db8:abcd:2::1"))
  expect_false(identical(a, c))   # different /64 -> different key
})

# --- Admission guard (fingerprint + throttle -> HTTP decision) ----------------

mock_res <- function() {
  r <- new.env(parent = emptyenv())
  r$status <- NA_integer_
  r$headers <- list()
  r$setHeader <- function(name, value) {
    r$headers[[name]] <- value
    invisible(NULL)
  }
  r
}

test_that("admission guard admits under the limit and blocks with 429 over it", {
  async_job_submit_rate_limit_reset()
  req <- list(HTTP_X_FORWARDED_FOR = "198.51.100.7")
  # Default module limit is 5 per 60s. First 5 admit, 6th -> 429 + Retry-After.
  for (i in 1:5) {
    res <- mock_res()
    adm <- async_job_submit_admission_guard(req, res)
    expect_true(adm$admitted)
  }
  res <- mock_res()
  adm <- async_job_submit_admission_guard(req, res)
  expect_false(adm$admitted)
  expect_equal(res$status, 429)
  expect_equal(adm$response$error, "RATE_LIMITED")
  expect_true(!is.null(res$headers[["Retry-After"]]))
  expect_gte(as.integer(res$headers[["Retry-After"]]), 1L)
  async_job_submit_rate_limit_reset()
})

test_that("admission guard fails CLOSED (503) on an internal throttle error", {
  # A throttle bug must neither 500 the endpoint nor silently admit an abusive
  # caller: an internal error is caught and mapped to 503 THROTTLE_UNAVAILABLE.
  orig <- async_job_submit_rate_limit
  async_job_submit_rate_limit <<- function(...) stop("boom")
  on.exit(async_job_submit_rate_limit <<- orig, add = TRUE)
  res <- mock_res()
  adm <- async_job_submit_admission_guard(list(REMOTE_ADDR = "10.0.0.1"), res)
  expect_false(adm$admitted)
  expect_equal(res$status, 503)
  expect_equal(adm$response$error, "THROTTLE_UNAVAILABLE")
  expect_true(!is.null(res$headers[["Retry-After"]]))
})

test_that("the store is bounded against fingerprint rotation (memory-DoS guard)", {
  st <- new.env(parent = emptyenv())
  # Simulate rotation: many distinct fingerprints, each allowed once, at t=1000.
  for (i in 1:50) {
    async_job_submit_rate_limit(sprintf("ip-%d", i), now = 1000,
      max_n = 3L, window_s = 60L, store = st, max_tracked = 10L)
  }
  # Bounded: 10 tracked buckets + overflow + sweep marker, never 50.
  expect_lte(length(ls(envir = st, all.names = TRUE)), 12L)
  expect_lt(length(ls(envir = st, all.names = TRUE)), 50L)
  # After the window, a fresh caller reclaims the fully-expired buckets.
  async_job_submit_rate_limit("newcomer", now = 2000,
    max_n = 3L, window_s = 60L, store = st, max_tracked = 10L)
  expect_lte(length(ls(envir = st, all.names = TRUE)), 12L)
})

test_that("saturation routes new fingerprints to a shared overflow bucket, never evicting an active caller", {
  st <- new.env(parent = emptyenv())
  # Establish an active caller that has already spent 2 of 3 submissions.
  async_job_submit_rate_limit("1.2.3.4", now = 1000, max_n = 3L, window_s = 60L, store = st, max_tracked = 3L)
  async_job_submit_rate_limit("1.2.3.4", now = 1001, max_n = 3L, window_s = 60L, store = st, max_tracked = 3L)
  # Saturate with distinct rotating callers within the same window.
  for (i in 1:30) {
    async_job_submit_rate_limit(sprintf("10.0.0.%d", i), now = 1002,
      max_n = 3L, window_s = 60L, store = st, max_tracked = 3L)
  }
  # The active caller's window was NOT reset by the flood: it still has its 3rd (last)
  # submission available, then the 4th is throttled.
  r3 <- async_job_submit_rate_limit("1.2.3.4", now = 1003, max_n = 3L, window_s = 60L, store = st, max_tracked = 3L)
  expect_true(r3$allowed)
  r4 <- async_job_submit_rate_limit("1.2.3.4", now = 1004, max_n = 3L, window_s = 60L, store = st, max_tracked = 3L)
  expect_false(r4$allowed)
  # The rotating callers collapsed into ONE overflow bucket that is itself throttled.
  denied <- async_job_submit_rate_limit("10.0.0.99", now = 1005, max_n = 3L, window_s = 60L, store = st, max_tracked = 3L)
  expect_false(denied$allowed)
})

test_that("admission guard fails CLOSED (503) on a malformed (non-NULL) decision", {
  orig <- async_job_submit_rate_limit
  async_job_submit_rate_limit <<- function(...) list(nonsense = TRUE) # no valid $allowed
  on.exit(async_job_submit_rate_limit <<- orig, add = TRUE)
  res <- mock_res()
  adm <- async_job_submit_admission_guard(list(REMOTE_ADDR = "10.0.0.1"), res)
  expect_false(adm$admitted)
  expect_equal(res$status, 503L)
  expect_equal(adm$response$error, "THROTTLE_UNAVAILABLE")
})

test_that("invalid env values fall back to safe defaults (not disable/corrupt)", {
  expect_equal(.async_job_submit_env_int("NOPE_UNSET_VAR_XYZ", 5L, 0L), 5L)
  withr::with_envvar(c(SOME_BAD = "abc"), expect_equal(.async_job_submit_env_int("SOME_BAD", 5L, 0L), 5L))
  withr::with_envvar(c(SOME_NEG = "-3"), expect_equal(.async_job_submit_env_int("SOME_NEG", 60L, 1L), 60L))
  withr::with_envvar(c(SOME_OK = "7"), expect_equal(.async_job_submit_env_int("SOME_OK", 5L, 0L), 7L))
})

test_that("env values are clamped to a ceiling so a typo cannot make vectors unbounded", {
  withr::with_envvar(
    c(SOME_HUGE = "1000000000"),
    expect_equal(.async_job_submit_env_int("SOME_HUGE", 5L, 0L, max_value = 10000L), 10000L)
  )
  withr::with_envvar( # a value under the ceiling is untouched
    c(SOME_FINE = "42"),
    expect_equal(.async_job_submit_env_int("SOME_FINE", 5L, 0L, max_value = 10000L), 42L)
  )
})
