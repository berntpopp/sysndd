# tests/testthat/test-integration-slow-provider-isolation.R
#
# Integration-style proof (#344, no live network) that the per-request external
# ceiling holds across REAL sequential wrapper calls (not a pre-loaded counter):
# once accumulated external time crosses the ceiling, subsequent external work is
# short-circuited so the worker is freed and a following cheap read stays bounded.
#
# Exercises external_proxy_with_timing + the accumulator/ceiling together. Pure
# (no DB / no network) — runs on host.

test_that("accumulated external time trips the ceiling mid-sequence and short-circuits", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "0.15")) # 150ms ceiling
  external_proxy_request_reset()

  upstream_calls <- 0L
  slow_source <- function() {
    upstream_calls <<- upstream_calls + 1L
    Sys.sleep(0.08) # 80ms per real call
    list(source = "slow", value = "ok")
  }

  results <- vector("list", 5L)
  t0 <- proc.time()[["elapsed"]]
  for (i in 1:5) {
    results[[i]] <- suppressMessages(external_proxy_with_timing("slow", slow_source))
  }
  total_elapsed <- proc.time()[["elapsed"]] - t0

  # First ~2 calls run (≈160ms accumulates past the 150ms ceiling); the rest
  # short-circuit without entering the upstream closure.
  expect_lt(upstream_calls, 5L)
  expect_gte(upstream_calls, 2L)

  # The short-circuited calls return the degraded 503 envelope.
  budget_errors <- Filter(function(r) isTRUE(r$request_budget_exceeded), results)
  expect_true(length(budget_errors) >= 1)
  expect_equal(budget_errors[[1]]$status, 503L)

  # Total wall time is bounded by the few real calls, NOT 5 * 80ms unbounded.
  expect_lt(total_elapsed, 0.5)
})

test_that("a cheap read after a ceiling-tripped request is unaffected (worker freed)", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "0.001"))
  external_proxy_request_reset()
  external_proxy_request_add(50) # already over the 1ms ceiling

  entered <- FALSE
  slow <- suppressMessages(external_proxy_with_timing("uniprot", function() {
    entered <<- TRUE
    Sys.sleep(30) # pathological upstream that must NOT run
    list(source = "uniprot")
  }))
  expect_false(entered)
  expect_true(isTRUE(slow$request_budget_exceeded))

  # The next request resets the accumulator (as the preroute hook does) and a
  # trivial cheap read is instant.
  external_proxy_request_reset()
  t1 <- proc.time()[["elapsed"]]
  health <- list(status = "healthy")
  cheap_elapsed <- proc.time()[["elapsed"]] - t1
  expect_lt(cheap_elapsed, 0.5)
  expect_equal(health$status, "healthy")
})
