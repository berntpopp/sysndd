# Unit tests for the durable clustering handler's result `meta` (#574 D3).
#
# `.async_job_run_clustering()` (api/functions/async-job-handlers.R) is the
# worker-run (cache-miss) counterpart to the cache-hit path in
# `svc_job_submit_functional_clustering()` (job-functional-submission-service.R,
# #574 D2). D2 already stitches the request's cheap-path `provenance` list
# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
# source_data_version) plus an `effective_fingerprint` (the STRING
# `weight_channel` actually observed on the computed result) into the
# cache-hit result `meta`. D3 makes the durable handler mirror that SAME
# shape for a worker-run job, so a silent exp+db -> combined-score STRING
# fallback is visible in a freshly-computed job's stored result too, not
# just a cache hit's.
#
# DB-free: `gen_string_clust_obj` and its category-enrichment/progress-reporter
# collaborators are stubbed in a child environment. This file never opens a
# DB connection and always runs (no skip guard).
#
# Trap (documented in test-unit-clustering-gene-universe.R and repeated here):
# do NOT stub via `testthat::local_mocked_bindings(..., .env = globalenv())`
# -- under testthat 3.3.2 that aborts with "No packages loaded with
# pkgload" because globalenv() has no package namespace. A child-env
# override (source into a fresh `new.env(parent = globalenv())`, then
# reassign bindings on that env) sidesteps this entirely.

.clustering_handler_env <- function() {
  e <- new.env(parent = globalenv())
  # async-job-handlers.R's eagerly-built async_job_handler_registry list()
  # references handler functions from these sibling modules by bare symbol
  # (#346 Wave 4 split; see the file's own header comment), so they must be
  # sourced first or the list() construction fails with "object '...' not
  # found" -- mirrors test-unit-async-job-handlers.R.
  source_api_file("functions/async-job-force-apply-payload.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-omim-apply.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-provider-handlers.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-network-layout-handlers.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-analysis-snapshot-handlers.R", local = FALSE, envir = e)
  # `.async_job_run_clustering()`'s result-`meta` assembly calls
  # `clustering_result_meta()` (#574 D3 fix wave 1), the shared helper defined
  # in clustering-gene-universe.R -- source it too or the handler errors with
  # "could not find function".
  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-handlers.R", local = FALSE, envir = e)

  # Stub the heavy clustering computation: returns a minimal tibble carrying
  # the SAME `weight_channel` attribute contract `gen_string_clust_obj` sets
  # (analyses-functions.R:351) so the handler's `effective_fingerprint`
  # extraction is exercised for real.
  e$gen_string_clust_obj <- function(genes, algorithm, string_id_table) {
    x <- tibble::tibble(cluster = 1L)
    attr(x, "weight_channel") <- "experimental_database"
    x
  }

  # `.async_job_functional_categories(clusters, category_links)` is called
  # unconditionally by the handler; stub it out so this test does not also
  # have to fabricate a `term_enrichment` column on the stub clusters tibble.
  e$.async_job_functional_categories <- function(clusters, category_links) {
    tibble::tibble()
  }

  # Bypasses `create_async_job_progress_reporter()` (a separate, unsourced
  # module in this DB-free test) -- see file header trap note.
  e$.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
    function(...) invisible(NULL)
  }

  e
}

test_that(".async_job_run_clustering echoes payload provenance + effective_fingerprint into result meta", {
  e <- .clustering_handler_env()

  payload <- list(
    genes = c("HGNC:1", "HGNC:5"),
    algorithm = "leiden",
    string_id_table = NULL,
    category_links = NULL,
    provenance = list(
      selector = list(kind = "category", category_filter = "Definitive"),
      resolved_gene_count = 2L,
      gene_list_sha256 = "abc",
      intended_fingerprint = list(string_cache_fingerprint = "fp"),
      source_data_version = "srcv-1"
    )
  )

  result <- e$.async_job_run_clustering(
    job = list(job_id = "j1"),
    payload = payload,
    state = NULL,
    worker_config = NULL
  )

  meta <- result$meta

  expect_identical(meta$algorithm, "leiden")
  expect_identical(meta$gene_count, 2L)
  expect_identical(meta$cluster_count, 1L)
  # Shape parity with the cache-hit path's meta (job-functional-submission-
  # service.R), which always carries cache_hit = TRUE: a worker-run job must
  # carry cache_hit = FALSE so callers can distinguish the two without an
  # absent-field check.
  expect_identical(meta$cache_hit, FALSE)
  expect_identical(meta$selector$kind, "category")
  expect_identical(meta$gene_list_sha256, "abc")
  expect_identical(meta$source_data_version, "srcv-1")
  expect_identical(meta$intended_fingerprint$string_cache_fingerprint, "fp")
  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
})

test_that(".async_job_run_clustering: gene_count is the DISTINCT gene count, matching the cache-hit path (Codex round-2 review fix)", {
  # Bug: the worker handler reported `gene_count = length(genes)` (raw),
  # while the cache-hit path (job-functional-submission-service.R) reports
  # `resolved_count <- length(unique(genes_list))` (distinct) -- for
  # `["HGNC:1","HGNC:1"]` the cache-hit path reports gene_count=1 but the
  # worker reported gene_count=2 for the identical payload. Both paths must
  # agree.
  e <- .clustering_handler_env()

  payload <- list(
    genes = c("HGNC:1", "HGNC:1"),
    algorithm = "leiden",
    string_id_table = NULL,
    category_links = NULL
  )

  result <- e$.async_job_run_clustering(
    job = list(job_id = "j-dup-genes"),
    payload = payload,
    state = NULL,
    worker_config = NULL
  )

  expect_identical(result$meta$gene_count, 1L)
})

test_that(".async_job_run_clustering: legacy payload with no provenance still returns a valid meta (backward compat)", {
  e <- .clustering_handler_env()

  payload <- list(
    genes = c("HGNC:1", "HGNC:5", "HGNC:9"),
    algorithm = "walktrap",
    string_id_table = NULL,
    category_links = NULL
    # No `provenance` field -- mirrors an explicit/no-arg pre-#574 submit.
  )

  result <- NULL
  expect_no_error({
    result <- e$.async_job_run_clustering(
      job = list(job_id = "j2"),
      payload = payload,
      state = NULL,
      worker_config = NULL
    )
  })

  meta <- result$meta

  expect_identical(meta$algorithm, "walktrap")
  expect_identical(meta$gene_count, 3L)
  expect_identical(meta$cluster_count, 1L)
  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
  # No provenance fields leaked in when the payload never carried them.
  expect_null(meta$selector)
  expect_null(meta$gene_list_sha256)
  expect_null(meta$source_data_version)
  expect_null(meta$intended_fingerprint)
})
