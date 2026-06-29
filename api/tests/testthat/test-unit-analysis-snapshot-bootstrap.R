# Unit tests for the analysis snapshot startup bootstrap + shared submit (#420).
# Pure-unit: injects fake submit/exists fns, no DB.

source_api_file("functions/analysis-snapshot-presets.R", local = FALSE)
# Read/shape helpers (service_analysis_snapshot_scalar_value / _time_string /
# _record_counts) live in the read service; the shared submit/status/bootstrap
# functions under test live in the refresh service.
source_api_file("services/analysis-snapshot-service.R", local = FALSE)
source_api_file("services/analysis-snapshot-refresh-service.R", local = FALSE)

fake_job <- function(id, duplicate = FALSE) {
  list(
    job = data.frame(job_id = id, stringsAsFactors = FALSE),
    duplicate = duplicate,
    created = !duplicate
  )
}

test_that("submit refresh skips presets that already have a public-ready snapshot", {
  seen <- character()
  fake_submit <- function(job_type, request_payload, ...) {
    seen[[length(seen) + 1L]] <<- request_payload$analysis_type
    fake_job(paste0("job-", length(seen)))
  }
  fake_exists <- function(analysis_type, parameter_hash, conn = NULL) {
    identical(analysis_type, "gene_network_edges")
  }

  summary <- service_analysis_snapshot_submit_refresh(
    force = FALSE, submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$requested, 5L)
  expect_equal(summary$skipped, 1L)
  expect_equal(summary$submitted, 4L)
  expect_false("gene_network_edges" %in% seen)
})

test_that("the default skip predicate re-enqueues a STALE snapshot so it self-heals on restart", {
  # Regression (#440 gap): a public-ready snapshot that has aged past
  # stale_after must NOT be treated as "already present". Before the fix the
  # bootstrap skipped any existing public-ready row (stale or fresh), so a stale
  # snapshot served a permanent 503 until an operator forced a rebuild.
  source_api_file("functions/analysis-snapshot-repository.R", local = FALSE)

  stale_manifest <- function(analysis_type, parameter_hash, conn = NULL) {
    data.frame(status_code = "snapshot_stale", stringsAsFactors = FALSE)
  }
  stale_skip <- function(analysis_type, parameter_hash, conn = NULL) {
    analysis_snapshot_public_current(
      analysis_type, parameter_hash,
      conn = conn, manifest_fn = stale_manifest
    )
  }

  n <- 0L
  fake_submit <- function(job_type, request_payload, ...) {
    n <<- n + 1L
    fake_job(paste0("job-", n))
  }

  summary <- service_analysis_snapshot_submit_refresh(
    force = FALSE, submit_fn = fake_submit, exists_fn = stale_skip
  )

  expect_equal(summary$skipped, 0L)
  expect_equal(summary$submitted, 5L)
})

test_that("submit refresh skip predicate defaults to the staleness-aware probe", {
  # Guard against reverting to analysis_snapshot_public_exists, which ignores
  # staleness and re-introduces the permanent-503 bug for stale snapshots.
  default_exists <- formals(service_analysis_snapshot_submit_refresh)$exists_fn
  expect_equal(as.character(default_exists), "analysis_snapshot_public_current")
})

test_that("force = TRUE submits every preset regardless of existence", {
  n <- 0L
  fake_submit <- function(job_type, request_payload, ...) {
    n <<- n + 1L
    fake_job(paste0("job-", n))
  }
  fake_exists <- function(...) TRUE

  summary <- service_analysis_snapshot_submit_refresh(
    force = TRUE, submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$submitted, 5L)
  expect_equal(summary$skipped, 0L)
  expect_equal(n, 5L)
})

test_that("submitted snapshot jobs are retryable so an expired lease self-heals (#440)", {
  captured <- list()
  fake_submit <- function(job_type, request_payload, ..., max_attempts = 1L) {
    captured[[length(captured) + 1L]] <<- as.integer(max_attempts)
    fake_job(paste0("job-", length(captured)))
  }
  fake_exists <- function(...) FALSE

  service_analysis_snapshot_submit_refresh(
    force = TRUE, submit_fn = fake_submit, exists_fn = fake_exists
  )

  # Every preset must be submitted with > 1 attempt; otherwise a lease that
  # expires under contention is reaped to a permanent LEASE_EXPIRED failure.
  expect_gt(ANALYSIS_SNAPSHOT_REFRESH_MAX_ATTEMPTS, 1L)
  expect_true(length(captured) >= 1L)
  expect_true(all(vapply(
    captured,
    function(x) identical(x, ANALYSIS_SNAPSHOT_REFRESH_MAX_ATTEMPTS),
    logical(1)
  )))
})

test_that("a single analysis_type targets just that preset", {
  fake_submit <- function(job_type, request_payload, ...) fake_job("job-1")
  fake_exists <- function(...) FALSE

  summary <- service_analysis_snapshot_submit_refresh(
    analysis_type = "phenotype_clusters", force = FALSE,
    submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$requested, 1L)
  expect_equal(summary$submitted, 1L)
  expect_equal(summary$results[[1]]$analysis_type, "phenotype_clusters")
})

test_that("an unknown analysis_type raises unsupported_parameter", {
  expect_error(
    service_analysis_snapshot_submit_refresh(
      analysis_type = "nope",
      submit_fn = function(...) NULL,
      exists_fn = function(...) FALSE
    ),
    class = "analysis_snapshot_unsupported_parameter_error"
  )
})

test_that("dedup hits are counted as reused, not submitted", {
  fake_submit <- function(job_type, request_payload, ...) fake_job("existing", duplicate = TRUE)
  fake_exists <- function(...) FALSE

  summary <- service_analysis_snapshot_submit_refresh(
    force = FALSE, submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$reused, 5L)
  expect_equal(summary$submitted, 0L)
})

test_that("a failing submit is isolated and counted, not thrown", {
  fake_submit <- function(job_type, request_payload, ...) stop("db down")
  fake_exists <- function(...) FALSE

  summary <- service_analysis_snapshot_submit_refresh(
    force = FALSE, submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$failed, 5L)
  expect_equal(summary$submitted, 0L)
})

test_that("analysis_snapshot_bootstrap_enabled honours the env var", {
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP = "false"), {
    expect_false(analysis_snapshot_bootstrap_enabled())
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP = "true"), {
    expect_true(analysis_snapshot_bootstrap_enabled())
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP = NA), {
    expect_true(analysis_snapshot_bootstrap_enabled())
  })
})

test_that("bootstrap_on_startup is a no-op when disabled", {
  called <- FALSE
  summary_fn <- function(...) {
    called <<- TRUE
    list(requested = 5L, submitted = 0L, reused = 0L, skipped = 5L, failed = 0L)
  }
  res <- analysis_snapshot_bootstrap_on_startup(
    submit_refresh_fn = summary_fn, enabled_fn = function() FALSE
  )
  expect_false(called)
  expect_false(res)
})

test_that("bootstrap_on_startup swallows submit errors (never crashes boot)", {
  res <- analysis_snapshot_bootstrap_on_startup(
    submit_refresh_fn = function(...) stop("db down"),
    enabled_fn = function() TRUE
  )
  expect_false(isTRUE(res))
})

test_that("bootstrap_on_startup reports submitted jobs when presets are missing", {
  summary_fn <- function(...) {
    list(requested = 5L, submitted = 3L, reused = 1L, skipped = 1L, failed = 0L)
  }
  res <- analysis_snapshot_bootstrap_on_startup(
    submit_refresh_fn = summary_fn, enabled_fn = function() TRUE
  )
  expect_true(res)
})

test_that("status maps a missing manifest to state=missing for all presets", {
  summary <- service_analysis_snapshot_status(manifest_fn = function(...) NULL)
  expect_equal(summary$summary$total, 5L)
  expect_equal(summary$summary$missing, 5L)
  expect_equal(summary$summary$available, 0L)
  expect_true(all(vapply(summary$presets, function(p) identical(p$state, "missing"), logical(1))))
})

test_that("status maps an available manifest row to state=available", {
  fake_manifest <- function(analysis_type, parameter_hash, conn = NULL) {
    data.frame(
      status_code = "available",
      generated_at = "2026-06-14 00:00:00",
      activated_at = "2026-06-14 00:01:00",
      stale_after = "2026-06-21 00:00:00",
      source_data_version = "abc123",
      row_counts_json = "{\"network_node\":10}",
      stringsAsFactors = FALSE
    )
  }
  summary <- service_analysis_snapshot_status(manifest_fn = fake_manifest)
  expect_equal(summary$summary$available, 5L)
  expect_equal(summary$summary$missing, 0L)
  expect_equal(summary$presets[[1]]$state, "available")
  expect_equal(summary$presets[[1]]$source_data_version, "abc123")
})
