# test-unit-external-circuit-breaker.R
# Tests for external proxy circuit breaker and selective memoise cache invalidation (#663)

library(testthat)

source_api_file("functions/external-proxy-circuit-breaker.R", local = FALSE)
source_api_file("functions/external-proxy-functions.R", local = FALSE)

test_that("circuit breaker starts in CLOSED state and permits requests", {
  external_proxy_cb_reset()
  expect_false(external_proxy_cb_is_open("test_src"))
})

test_that("circuit breaker trips to OPEN after consecutive failures meet threshold", {
  external_proxy_cb_reset()
  for (i in 1:4) {
    external_proxy_cb_record_failure("test_src", status = 503L)
    expect_false(external_proxy_cb_is_open("test_src"))
  }
  external_proxy_cb_record_failure("test_src", status = 503L)
  expect_true(external_proxy_cb_is_open("test_src"))

  status <- external_proxy_cb_status()
  expect_equal(status$test_src$state, "OPEN")
  expect_equal(status$test_src$consecutive_failures, 5L)
})

test_that("circuit breaker ignores client errors like 400 and 404", {
  external_proxy_cb_reset()
  for (i in 1:10) {
    external_proxy_cb_record_failure("test_src", status = 404L)
  }
  expect_false(external_proxy_cb_is_open("test_src"))
})

test_that("circuit breaker transitions to HALF-OPEN after cooldown expires and allows probe", {
  external_proxy_cb_reset()
  t0 <- as.POSIXct("2026-01-01 12:00:00", tz = "UTC")
  for (i in 1:5) {
    external_proxy_cb_record_failure("test_src", status = 503L, now = t0)
  }
  expect_true(external_proxy_cb_is_open("test_src", now = t0 + 10))

  # After 65 seconds (> 60s cooldown)
  expect_false(external_proxy_cb_is_open("test_src", now = t0 + 65))
  # Subsequent calls while probe in flight are blocked
  expect_true(external_proxy_cb_is_open("test_src", now = t0 + 66))

  # Probe succeeds: recovers to CLOSED
  external_proxy_cb_record_success("test_src", now = t0 + 67)
  expect_false(external_proxy_cb_is_open("test_src", now = t0 + 68))
  status <- external_proxy_cb_status()
  expect_equal(status$test_src$state, "CLOSED")
  expect_equal(status$test_src$consecutive_failures, 0L)
})

test_that("memoise_external_success_only drops only single key and preserves other cached keys", {
  external_proxy_cb_reset()
  call_counts <- list(A = 0L, B = 0L)
  flaky_fetch <- function(key) {
    call_counts[[key]] <<- call_counts[[key]] + 1L
    if (key == "B" && call_counts[[key]] == 1L) {
      return(list(error = TRUE, source = "test_drop", message = "fail once"))
    }
    list(source = "test_drop", key = key, val = call_counts[[key]])
  }

  mem_fn <- memoise_external_success_only(flaky_fetch, cachem::cache_mem(), source = "test_drop")

  # Call A -> succeeds and is cached
  res_a1 <- mem_fn("A")
  expect_equal(res_a1$val, 1L)
  expect_equal(call_counts$A, 1L)

  # Call B -> fails (error = TRUE, drop_cache should drop B only)
  res_b1 <- mem_fn("B")
  expect_true(isTRUE(res_b1$error))
  expect_equal(call_counts$B, 1L)

  # Call A again -> MUST BE A CACHE HIT!
  res_a2 <- mem_fn("A")
  expect_equal(res_a2$val, 1L)
  expect_equal(call_counts$A, 1L) # Not re-fetched!

  # Call B again -> re-fetches and succeeds
  res_b2 <- mem_fn("B")
  expect_equal(res_b2$val, 2L)
  expect_equal(call_counts$B, 2L)
})
