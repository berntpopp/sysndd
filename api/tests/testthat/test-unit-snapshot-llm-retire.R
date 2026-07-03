# tests/testthat/test-unit-snapshot-llm-retire.R
#
# Unit tests for the snapshot -> orphan-retirement wiring (#485):
# analysis_snapshot_trigger_llm_generation must retire orphaned is_current
# summary rows using the just-published payload$clusters$cluster_hash, scoped to
# the refreshed cluster type, and thread the refresh connection.
#
# Host-runnable (no DB, no ellmer): dependencies are stubbed in a fresh env.
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-snapshot-llm-retire.R')"

library(testthat)
library(tibble)

source_builder_env <- function() {
  env <- new.env(parent = globalenv())
  source_api_file("functions/analysis-snapshot-presets.R", local = FALSE, envir = env)
  source_api_file("functions/analysis-snapshot-builder.R", local = FALSE, envir = env)
  env
}

test_that("trigger_llm_generation retires orphans by payload$clusters$cluster_hash", {
  env <- source_builder_env()
  captured <- new.env()
  env$retire_orphan_cluster_summaries <- function(cluster_type, current_hashes, conn = NULL) {
    captured$cluster_type <- cluster_type
    captured$hashes <- current_hashes
    captured$conn <- conn
    length(current_hashes)
  }
  env$trigger_llm_batch_generation <- function(clusters, cluster_type, parent_job_id, force = FALSE) {
    captured$trigger_cluster_type <- cluster_type
    list(job_id = "llm-job")
  }

  payload <- list(
    raw = tibble::tibble(cluster = 1:2),
    clusters = tibble::tibble(cluster_hash = c("hh1", "hh2"))
  )
  out <- env$analysis_snapshot_trigger_llm_generation(
    "phenotype_clusters", payload,
    parent_job_id = "p", conn = "CONN"
  )

  expect_equal(captured$cluster_type, "phenotype")
  expect_equal(captured$hashes, c("hh1", "hh2"))
  expect_equal(captured$conn, "CONN")
  expect_equal(out$job_id, "llm-job")
})

test_that("trigger_llm_generation retires even when generation is unavailable", {
  env <- source_builder_env()
  captured <- new.env()
  env$retire_orphan_cluster_summaries <- function(cluster_type, current_hashes, conn = NULL) {
    captured$hashes <- current_hashes
    length(current_hashes)
  }
  # trigger_llm_batch_generation intentionally NOT defined -> exists() FALSE.

  payload <- list(clusters = tibble::tibble(cluster_hash = c("f556", "175f")))
  out <- env$analysis_snapshot_trigger_llm_generation("functional_clusters", payload)

  expect_equal(captured$hashes, c("f556", "175f"))
  expect_true(isTRUE(out$skipped))
  expect_equal(out$reason, "llm_trigger_unavailable")
})

test_that("trigger_llm_generation returns NULL (no retire) for non-cluster analysis types", {
  env <- source_builder_env()
  retire_called <- FALSE
  env$retire_orphan_cluster_summaries <- function(...) {
    retire_called <<- TRUE
    0L
  }
  out <- env$analysis_snapshot_trigger_llm_generation(
    "phenotype_correlations",
    list(clusters = tibble::tibble(cluster_hash = "x"))
  )
  expect_null(out)
  expect_false(retire_called)
})
