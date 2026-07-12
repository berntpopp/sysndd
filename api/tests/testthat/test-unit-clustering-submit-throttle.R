# Tests for the per-caller clustering submit throttle (#535 S6).
# Pure logic (injectable clock + store); no DB.

staged_api_dir <- Sys.getenv("SYSNDD_API_DIR", "")
if (nzchar(staged_api_dir)) {
  api_dir <- staged_api_dir
} else if (exists("get_api_dir")) {
  api_dir <- get_api_dir()
} else {
  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
  if (!file.exists(file.path(api_dir, "functions", "clustering-submit-throttle.R"))) {
    api_dir <- normalizePath(file.path(getwd()), mustWork = FALSE)
  }
}
source(file.path(api_dir, "functions", "per-caller-throttle.R"), local = FALSE)
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

test_that("invalid limiter params FAIL CLOSED (stop), never silently allow", {
  st <- new.env(parent = emptyenv())
  # An internal misconfiguration (max_n / window_s non-positive or non-finite) must
  # raise, so the admission guard maps it to a fail-closed 503 rather than admitting.
  expect_error(async_job_submit_rate_limit("x", now = 1000, max_n = 0L, window_s = 60L, store = st))
  expect_error(async_job_submit_rate_limit("x", now = 1000, max_n = 5L, window_s = 0L, store = st))
  expect_error(async_job_submit_rate_limit("x", now = 1000, max_n = NA_integer_, window_s = 60L, store = st))
})

test_that("empty/NULL fingerprint collapses to a single 'unknown' bucket", {
  st <- new.env(parent = emptyenv())
  async_job_submit_rate_limit(NULL, now = 1000, max_n = 1L, window_s = 60L, store = st)
  expect_false(async_job_submit_rate_limit("", now = 1000, max_n = 1L, window_s = 60L, store = st)$allowed)
})

test_that("fingerprint uses the proxy-appended (rightmost) XFF hop by default, not the spoofable first", {
  # Single-Traefik direct edge (empty trust set): Traefik appends the real client as
  # the LAST entry; leftmost entries are client-supplied and must not be trusted.
  req <- list(HTTP_X_FORWARDED_FOR = "9.9.9.9, 10.0.0.1", REMOTE_ADDR = "172.18.0.5")
  expect_equal(async_job_submit_fingerprint(req), "10.0.0.1")
  # A spoofed leftmost value cannot change the appended hop.
  spoof <- list(HTTP_X_FORWARDED_FOR = "1.1.1.1, 10.0.0.1")
  expect_equal(async_job_submit_fingerprint(spoof), "10.0.0.1")
})

test_that("fingerprint walks past TRUSTED proxies and is unspoofable under a front proxy", {
  # A front proxy (10.9.0.0/24) sits in front of Traefik. Real chain reaching us:
  # "<real-client>, <front-proxy-ip>". Walk right-to-left, skip the trusted front
  # proxy, select the real client.
  cidrs <- "10.9.0.0/24"
  legit <- list(HTTP_X_FORWARDED_FOR = "203.0.113.7, 10.9.0.5")
  expect_equal(async_job_submit_fingerprint(legit, trusted_cidrs = cidrs), "203.0.113.7")
  # A DIRECT attacker (bypassing the front proxy) hits Traefik and forges a
  # trusted-CIDR IP on the left; Traefik appends the attacker's real peer at the
  # right. The rightmost UNTRUSTED hop (the attacker) is selected -> not spoofable.
  attack <- list(HTTP_X_FORWARDED_FOR = "203.0.113.7, 10.9.0.5, 198.51.100.66")
  expect_equal(async_job_submit_fingerprint(attack, trusted_cidrs = cidrs), "198.51.100.66")
  # If every hop is a trusted proxy, fall back to REMOTE_ADDR.
  allproxy <- list(HTTP_X_FORWARDED_FOR = "10.9.0.5", REMOTE_ADDR = "172.18.0.5")
  expect_equal(async_job_submit_fingerprint(allproxy, trusted_cidrs = cidrs), "172.18.0.5")
})

test_that("an IPv6 trusted proxy is matched on the FULL address, not the /64 key", {
  # A front proxy in 2001:db8:abcd::/48 appended the real IPv6 client. The trust check
  # must evaluate the full proxy address (not the /64-collapsed bucket key) or the
  # proxy is treated as a client and everyone behind it shares one quota.
  cidr6 <- "2001:db8:abcd::/48"
  legit <- list(HTTP_X_FORWARDED_FOR = "2001:4860:4860::8888, 2001:db8:abcd:1::5")
  # Real client is grouped to its /64; the trusted proxy hop is skipped.
  expect_equal(async_job_submit_fingerprint(legit, trusted_cidrs = cidr6), "2001:4860:4860:0::/64")
  # Exact IPv6 trusted address also matches.
  expect_equal(
    async_job_submit_fingerprint(legit, trusted_cidrs = "2001:db8:abcd:1::5"),
    "2001:4860:4860:0::/64"
  )
  # A direct IPv6 attacker forging a trusted-CIDR hop on the left cannot be skipped:
  # the rightmost untrusted hop (its real address) is selected.
  attack <- list(HTTP_X_FORWARDED_FOR = "2001:db8:abcd:1::5, 2001:dead:beef::9")
  expect_equal(async_job_submit_fingerprint(attack, trusted_cidrs = cidr6), "2001:dead:beef:0::/64")
})

test_that(".async_job_submit_valid_cidr accepts valid IPv4/IPv6 CIDRs and rejects junk", {
  expect_true(.async_job_submit_valid_cidr("10.9.0.0/24"))
  expect_true(.async_job_submit_valid_cidr("192.168.1.1"))
  expect_true(.async_job_submit_valid_cidr("2001:db8::/32"))
  expect_true(.async_job_submit_valid_cidr("2001:db8:abcd:1::5"))
  expect_false(.async_job_submit_valid_cidr("10.9.0.0/33"))
  expect_false(.async_job_submit_valid_cidr("nonsense"))
  expect_false(.async_job_submit_valid_cidr("2001:db8::/129"))
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
  expect_equal(async_job_submit_fingerprint(req), "172.18.0.5")
  # No valid IP anywhere -> stable constant, never the attacker string.
  req2 <- list(HTTP_X_FORWARDED_FOR = "not an ip")
  expect_equal(async_job_submit_fingerprint(req2), "unknown")
  # Out-of-range octets are not a valid IPv4.
  req3 <- list(HTTP_X_FORWARDED_FOR = "999.1.1.1", REMOTE_ADDR = "10.0.0.9")
  expect_equal(async_job_submit_fingerprint(req3), "10.0.0.9")
})

test_that("an IPv4 host:port is normalized to the bare IP", {
  req <- list(HTTP_X_FORWARDED_FOR = "203.0.113.7:54321")
  expect_equal(async_job_submit_fingerprint(req), "203.0.113.7")
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

test_that("IPv6 /64 is compression-invariant and rejects malformed addresses", {
  ip <- function(x) async_job_submit_fingerprint(list(HTTP_X_FORWARDED_FOR = x))
  # SAME address, different valid compressions -> ONE /64 key (no quota multiplication).
  full <- ip("2001:0db8:0000:0001:0000:0000:0000:0005") # uncompressed, leading zeros
  mid  <- ip("2001:db8:0:1::5")                          # "::" spans the interface bits
  expect_equal(full, mid)
  expect_equal(full, "2001:db8:0:1::/64")
  # "::" that lands INSIDE the /64 prefix still expands to the correct hextets.
  expect_equal(ip("2001::1:0:0:0:5"), "2001:0:0:1::/64")
  # Malformed IPv6 is rejected (falls back to REMOTE_ADDR / "unknown"), not keyed.
  expect_equal(async_job_submit_fingerprint(
    list(HTTP_X_FORWARDED_FOR = "a:b", REMOTE_ADDR = "10.0.0.7")), "10.0.0.7")
  expect_equal(ip("2001:::1"), "unknown")           # double "::"
  expect_equal(ip("2001:db8:zzzz::1"), "unknown")   # non-hex hextet
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
  # Bounded: <= 10 tracked callers (the 50 rotated IPs collapsed into the shared
  # overflow bucket), and total bindings never approach 50.
  expect_lte(.async_job_submit_size(st), 10L)
  expect_lt(length(ls(envir = st, all.names = TRUE)), 50L)
  # After the window, a fresh caller reclaims the fully-expired buckets.
  async_job_submit_rate_limit("newcomer", now = 2000,
    max_n = 3L, window_s = 60L, store = st, max_tracked = 10L)
  expect_lte(.async_job_submit_size(st), 10L)
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
