# tests/testthat/test-unit-snapshot-dependency-ordering.R
#
# The bootstrap stagger (#447) delays HEAVY presets 120s -- but
# phenotype_functional_correlations (light, eligible immediately) DEPENDS on
# functional_clusters + phenotype_clusters (both heavy, delayed). After a data
# change the dependent job therefore ran first, found its dependency snapshots
# source_version_mismatch, and failed hard. Observed in production 2026-09-01
# 22:03 UTC (job 631178dd): "Dependency snapshot functional_clusters is not
# available (status: source_version_mismatch)" -- and because the worker's
# generic error path sets no next_attempt_at, the failure was terminal despite
# max_attempts = 3.
#
# Three fixes, tested here:
#   1. presets declare depends_on, and the stagger schedules a dependent AFTER
#      its slowest dependency (with the single default-queue worker, claim
#      order is scheduled_at order, so dependencies COMPLETE first),
#   2. dependency-unavailable is a typed transient condition,
#   3. the worker schedules a retry (next_attempt_at) for transient failures
#      instead of failing terminally (tested in test-unit-async-job-worker.R,
#      which owns the worker runtime harness).
#
# Pure functions only (injected submit_fn / clock / fail_fn); no DB.

source_api_file("functions/analysis-snapshot-presets.R", local = FALSE)
source_api_file("services/analysis-snapshot-refresh-service.R", local = FALSE)
source_api_file("functions/analysis-snapshot-dependencies.R", local = FALSE)

# --- 1. dependency declaration + ordering ------------------------------------

test_that("the correlation preset declares its cluster dependencies", {
  deps <- analysis_snapshot_preset_depends_on("phenotype_functional_correlations")
  expect_setequal(deps, c("functional_clusters", "phenotype_clusters"))
})

test_that("presets without dependencies declare none", {
  for (at in c("functional_clusters", "phenotype_clusters",
               "phenotype_correlations", "gene_network_edges")) {
    expect_length(analysis_snapshot_preset_depends_on(at), 0L)
  }
  # unknown types fail open to no dependencies
  expect_length(analysis_snapshot_preset_depends_on("unknown_type"), 0L)
})

test_that("staggered submit schedules a dependent after its slowest dependency", {
  submitted <- list()
  submit_fn <- function(job_type, request_payload, queue_name, priority,
                        max_attempts, scheduled_at, conn = NULL) {
    submitted[[request_payload$analysis_type]] <<- scheduled_at
    list(job = list(job_id = "j"), duplicate = FALSE)
  }
  now <- as.POSIXct("2026-09-01 22:03:00", tz = "UTC")

  service_analysis_snapshot_submit_refresh(
    force = TRUE, submit_fn = submit_fn, stagger = TRUE,
    now = now, stagger_seconds = 120L
  )

  heavy_sched <- submitted[["functional_clusters"]]
  dependent_sched <- submitted[["phenotype_functional_correlations"]]
  expect_true(dependent_sched > heavy_sched)
  # deps-free light presets stay immediate
  expect_equal(submitted[["phenotype_correlations"]], now)
})

test_that("unstaggered submit leaves every preset immediate (operator force path)", {
  submitted <- list()
  submit_fn <- function(job_type, request_payload, queue_name, priority,
                        max_attempts, scheduled_at, conn = NULL) {
    submitted[[request_payload$analysis_type]] <<- scheduled_at
    list(job = list(job_id = "j"), duplicate = FALSE)
  }
  now <- as.POSIXct("2026-09-01 22:03:00", tz = "UTC")

  service_analysis_snapshot_submit_refresh(
    force = TRUE, submit_fn = submit_fn, stagger = FALSE, now = now
  )

  for (at in names(submitted)) expect_equal(submitted[[at]], now)
})

# --- 2. typed transient condition --------------------------------------------

test_that("an unavailable dependency raises a typed transient condition", {
  loader <- function(analysis_type, parameter_hash, conn = NULL) {
    list(status_code = "source_version_mismatch")
  }

  err <- tryCatch(
    analysis_snapshot_load_cluster_dependency(
      "functional_clusters", list(), cluster_snapshot_loader = loader
    ),
    error = function(e) e
  )

  expect_s3_class(err, "analysis_snapshot_dependency_unavailable")
  expect_s3_class(err, "async_job_transient_error")
  expect_match(conditionMessage(err), "source_version_mismatch")
})

