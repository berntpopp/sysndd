# Unit tests for the serve-time snapshot self-heal (closes the gap where a
# post-startup data change left public analysis endpoints on a permanent 503).
# Pure-unit: injects a fake submit fn + fake clock + isolated throttle state,
# no DB.

source_api_file("functions/analysis-snapshot-presets.R", local = FALSE)
source_api_file("services/analysis-snapshot-service.R", local = FALSE)
source_api_file("services/analysis-snapshot-refresh-service.R", local = FALSE)

selfheal_fake_summary <- function(submitted = 5L) {
  list(requested = 5L, submitted = submitted, reused = 0L, skipped = 0L, failed = 0L)
}

selfheal_fresh_state <- function() {
  env <- new.env(parent = emptyenv())
  env$last_submit_epoch <- NULL
  env
}

test_that("self-heal enqueues an all-preset refresh with force=FALSE and no stagger", {
  captured <- new.env(parent = emptyenv())
  captured$calls <- list()
  fake_submit <- function(force = TRUE, stagger = TRUE, ...) {
    captured$calls[[length(captured$calls) + 1L]] <- list(force = force, stagger = stagger)
    selfheal_fake_summary()
  }

  fired <- service_analysis_snapshot_selfheal_on_serve(
    analysis_type = "gene_network_edges",
    submit_fn = fake_submit,
    enabled_fn = function() TRUE,
    throttle_seconds = 60L,
    state = selfheal_fresh_state(),
    now = as.POSIXct("2026-07-23 20:00:00", tz = "UTC")
  )

  expect_true(fired)
  expect_equal(length(captured$calls), 1L)
  expect_false(captured$calls[[1]]$force)
  expect_false(captured$calls[[1]]$stagger)
})

test_that("self-heal throttles repeated calls within the window but fires again after it", {
  n <- new.env(parent = emptyenv())
  n$count <- 0L
  fake_submit <- function(force = TRUE, stagger = TRUE, ...) {
    n$count <- n$count + 1L
    selfheal_fake_summary()
  }
  state <- selfheal_fresh_state()
  base <- as.POSIXct("2026-07-23 20:00:00", tz = "UTC")

  first <- service_analysis_snapshot_selfheal_on_serve(
    submit_fn = fake_submit, enabled_fn = function() TRUE,
    throttle_seconds = 60L, state = state, now = base
  )
  # 30s later: still inside the 60s window -> throttled, no new submit
  second <- service_analysis_snapshot_selfheal_on_serve(
    submit_fn = fake_submit, enabled_fn = function() TRUE,
    throttle_seconds = 60L, state = state, now = base + 30
  )
  # 90s later: past the window -> fires again
  third <- service_analysis_snapshot_selfheal_on_serve(
    submit_fn = fake_submit, enabled_fn = function() TRUE,
    throttle_seconds = 60L, state = state, now = base + 90
  )

  expect_true(first)
  expect_false(second)
  expect_true(third)
  expect_equal(n$count, 2L)
})

test_that("self-heal is a no-op when disabled and never calls submit", {
  called <- FALSE
  fake_submit <- function(...) {
    called <<- TRUE
    selfheal_fake_summary()
  }

  fired <- service_analysis_snapshot_selfheal_on_serve(
    submit_fn = fake_submit,
    enabled_fn = function() FALSE,
    state = selfheal_fresh_state()
  )

  expect_false(fired)
  expect_false(called)
})

test_that("self-heal swallows a submit error and still claims the throttle window", {
  state <- selfheal_fresh_state()
  fired <- service_analysis_snapshot_selfheal_on_serve(
    submit_fn = function(...) stop("db down"),
    enabled_fn = function() TRUE,
    throttle_seconds = 60L,
    state = state,
    now = as.POSIXct("2026-07-23 20:00:00", tz = "UTC")
  )
  # Attempted (returns TRUE) and did not propagate the error; window is claimed
  # so a retry storm does not hammer the failing submit path.
  expect_true(fired)
  expect_true(is.finite(state$last_submit_epoch))
})

test_that("enable gate parses common truthy/falsey env values", {
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_SELFHEAL_ON_SERVE = "false"), {
    expect_false(analysis_snapshot_selfheal_enabled())
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_SELFHEAL_ON_SERVE = "off"), {
    expect_false(analysis_snapshot_selfheal_enabled())
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_SELFHEAL_ON_SERVE = ""), {
    expect_true(analysis_snapshot_selfheal_enabled())
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_SELFHEAL_ON_SERVE = "true"), {
    expect_true(analysis_snapshot_selfheal_enabled())
  })
})
