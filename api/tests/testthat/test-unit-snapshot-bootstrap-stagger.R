# tests/testthat/test-unit-snapshot-bootstrap-stagger.R
#
# Unit tests for the startup analysis-snapshot bootstrap stagger (#447).
# Pure functions only (injected submit_fn / clock); no DB, no ellmer.

source_api_file("functions/analysis-snapshot-presets.R", local = FALSE)
source_api_file("services/analysis-snapshot-refresh-service.R", local = FALSE)
source_api_file("functions/pubtatornidd-nightly.R", local = FALSE)

# --- Task 1: preset weights -------------------------------------------------

test_that("functional_clusters is the only heavy preset", {
  expect_equal(analysis_snapshot_preset_weight("functional_clusters"), "heavy")
  for (at in c("phenotype_clusters", "phenotype_correlations",
               "phenotype_functional_correlations", "gene_network_edges")) {
    expect_equal(analysis_snapshot_preset_weight(at), "light")
  }
  # unknown types fail open to "light" (never delay an unknown preset)
  expect_equal(analysis_snapshot_preset_weight("unknown_type"), "light")
})

test_that("every supported preset carries a weight", {
  for (p in analysis_snapshot_supported_presets()) {
    expect_true(isTRUE(p$weight %in% c("heavy", "light")))
  }
})

# --- Task 2: stagger-seconds env helper -------------------------------------

test_that("snapshot stagger seconds resolves env with safe default", {
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS = ""), {
    expect_equal(analysis_snapshot_bootstrap_stagger_seconds(), 120L)
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS = "300"), {
    expect_equal(analysis_snapshot_bootstrap_stagger_seconds(), 300L)
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS = "abc"), {
    expect_equal(analysis_snapshot_bootstrap_stagger_seconds(), 120L)
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS = "-5"), {
    expect_equal(analysis_snapshot_bootstrap_stagger_seconds(), 120L)
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS = "0"), {
    expect_equal(analysis_snapshot_bootstrap_stagger_seconds(), 0L)
  })
})

# --- Task 3: stagger applied in submit --------------------------------------

test_that("bootstrap stagger offsets heavy presets only", {
  captured <- list()
  fake_submit <- function(job_type, request_payload, queue_name, priority,
                          max_attempts, scheduled_at = NULL, conn = NULL) {
    captured[[length(captured) + 1L]] <<- list(
      at = request_payload$analysis_type, scheduled_at = scheduled_at
    )
    list(job = tibble::tibble(job_id = "j"), duplicate = FALSE, created = TRUE)
  }
  t0 <- as.POSIXct("2026-06-15 00:00:00", tz = "UTC")
  service_analysis_snapshot_submit_refresh(
    force = TRUE, stagger = TRUE, submit_fn = fake_submit,
    exists_fn = function(...) FALSE, now = t0, stagger_seconds = 120L
  )
  offs <- stats::setNames(
    lapply(captured, function(c) as.numeric(difftime(c$scheduled_at, t0, units = "secs"))),
    vapply(captured, function(c) c$at, character(1))
  )
  expect_equal(offs[["functional_clusters"]], 120)
  expect_equal(offs[["phenotype_clusters"]], 0)
  expect_equal(offs[["gene_network_edges"]], 0)
  expect_equal(offs[["phenotype_correlations"]], 0)
})

test_that("force/non-stagger path submits all at now", {
  captured <- list()
  fake_submit <- function(job_type, request_payload, queue_name, priority,
                          max_attempts, scheduled_at = NULL, conn = NULL) {
    captured[[length(captured) + 1L]] <<- scheduled_at
    list(job = tibble::tibble(job_id = "j"), duplicate = FALSE, created = TRUE)
  }
  t0 <- as.POSIXct("2026-06-15 00:00:00", tz = "UTC")
  service_analysis_snapshot_submit_refresh(
    force = TRUE, stagger = FALSE, submit_fn = fake_submit,
    exists_fn = function(...) FALSE, now = t0
  )
  for (s in captured) {
    expect_equal(as.numeric(difftime(s, t0, units = "secs")), 0)
  }
})

test_that("stagger_seconds = 0 disables the heavy offset", {
  captured <- list()
  fake_submit <- function(job_type, request_payload, queue_name, priority,
                          max_attempts, scheduled_at = NULL, conn = NULL) {
    captured[[length(captured) + 1L]] <<- list(
      at = request_payload$analysis_type, scheduled_at = scheduled_at
    )
    list(job = tibble::tibble(job_id = "j"), duplicate = FALSE, created = TRUE)
  }
  t0 <- as.POSIXct("2026-06-15 00:00:00", tz = "UTC")
  service_analysis_snapshot_submit_refresh(
    force = TRUE, stagger = TRUE, submit_fn = fake_submit,
    exists_fn = function(...) FALSE, now = t0, stagger_seconds = 0L
  )
  for (c in captured) {
    expect_equal(as.numeric(difftime(c$scheduled_at, t0, units = "secs")), 0)
  }
})

# --- Task 4: PubTator nightly bootstrap offset ------------------------------

test_that("pubtatornidd bootstrap offsets scheduled_at by env default", {
  captured <- NULL
  fake_submit <- function(job_type, request_payload, scheduled_at = NULL, ...) {
    captured <<- list(scheduled_at = scheduled_at)
    list(job = tibble::tibble(job_id = "p"))
  }
  t0 <- as.POSIXct("2026-06-15 00:00:00", tz = "UTC")
  withr::with_envvar(c(PUBTATORNIDD_BOOTSTRAP_STAGGER_SECONDS = ""), {
    pubtatornidd_bootstrap_enrichment(
      query_fn = function(...) data.frame(n = 0L),
      submit_fn = fake_submit, now = t0
    )
  })
  expect_equal(as.numeric(difftime(captured$scheduled_at, t0, units = "secs")), 240)
})

test_that("pubtatornidd bootstrap is a no-op when a current snapshot exists", {
  called <- FALSE
  fake_submit <- function(...) {
    called <<- TRUE
    list(job = tibble::tibble(job_id = "p"))
  }
  pubtatornidd_bootstrap_enrichment(
    query_fn = function(...) data.frame(n = 5L),
    submit_fn = fake_submit, now = as.POSIXct("2026-06-15 00:00:00", tz = "UTC")
  )
  expect_false(called)
})
