# tests/testthat/job-endpoint-services-fixtures.R
#
# Shared fixtures for the job-endpoint-service unit tests, split across four files
# to keep each under the 600-line ceiling:
#   - test-unit-job-endpoint-services.R              (functional submission)
#   - test-unit-job-endpoint-services-category.R     (functional submission:
#                                                      category_filter, #574 D2)
#   - test-unit-job-endpoint-services-phenotype.R    (phenotype submission)
#   - test-unit-job-endpoint-services-maintenance.R  (maintenance submission + query)
# All four files EXPLICITLY source() this file at the top so they run standalone under a
# single-file `testthat::test_file()` (a plain helper-*.R auto-load is not guaranteed
# to run there); mirrors the pubmed-xml-fixtures.R convention.
#
# `pool %>% dplyr::tbl(name)` is faked with a small S3 dispatch trick: a "fake_pool"
# object wrapping a named list of tibbles, plus one `tbl.fake_pool` method registered in
# the environment the service was sourced into (S3 dispatch finds it there). This needs
# no test DB / RSQLite, so every test is a real PASS on host R.

library(dplyr)
library(tidyr)

#' Source a service file into a fresh child-of-globalenv environment.
#'
#' The two public clustering submit services now call `async_job_submit_admission_guard()`
#' FIRST (#535 S6) before any DB/cache work; stub it to "admit" by default so these
#' isolated tests exercise the downstream request/response logic. A test can override
#' `env$async_job_submit_admission_guard` to exercise the throttle-block path.
#'
#' Also sources `functions/clustering-gene-universe.R` (#574 D1/D3) into `env` so
#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
#' `job-functional-submission-service.R`'s cache-hit path -- is available for real
#' (a pure list-assembly function, safe to source unstubbed). Individual tests still
#' stub the DB/cache-touching siblings from that same file
#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
#' this sourcing only supplies defaults those stubs override.
job_endpoint_source_service <- function(filename) {
  env <- new.env(parent = globalenv())
  env$async_job_submit_admission_guard <- function(req, res) list(admitted = TRUE)
  sys.source(file.path(get_api_dir(), "functions", "clustering-gene-universe.R"), envir = env)
  sys.source(file.path(get_api_dir(), "services", filename), envir = env)
  env
}

#' Register `tbl.fake_pool` in `env` and build a fake pool over `tables`.
job_endpoint_fake_pool <- function(env, tables) {
  env$tbl.fake_pool <- function(src, from, ...) src$tables[[from]]
  structure(list(tables = tables), class = "fake_pool")
}

#' Fake pool for job-functional-submission-service.R tests: always includes
#' `non_alt_loci_set` (the STRING-id pre-fetch table every submit path reads),
#' and optionally an `ndd_entity_view` for tests that exercise the all-NDD
#' default universe. Shared by test-unit-job-endpoint-services.R and
#' test-unit-job-endpoint-services-category.R.
job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
  tables <- list(
    non_alt_loci_set = tibble::tibble(
      symbol = c("A", "B"),
      hgnc_id = c("HGNC:1", "HGNC:3"),
      STRING_id = c("9606.P1", "9606.P2")
    )
  )
  if (!is.null(ndd_entity_view)) {
    tables$ndd_entity_view <- ndd_entity_view
  }
  job_endpoint_fake_pool(env, tables)
}

#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
#' (#574 D2): reads `ndd_phenotype == 1` rows straight off `env$pool`'s fake
#' `ndd_entity_view`, mirroring what the real resolver's NULL branch
#' (`generate_ndd_hgnc_ids()`) would compute -- without needing the real
#' function (and its DB-query internals) sourced into these isolated envs.
job_endpoint_stub_all_ndd_universe <- function(env) {
  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
    testthat::expect_null(category_filter)
    tbl <- env$pool$tables$ndd_entity_view
    hgnc_ids <- unique(dplyr::pull(dplyr::filter(tbl, ndd_phenotype == 1), hgnc_id))
    list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids))
  }
}

#' Cheap provenance stubs (#574 D2): every submit path that reaches past dedup
#' now computes `intended_fingerprint`/`gene_list_sha256`/`source_data_version`
#' regardless of selector kind, so any test reaching that far needs these
#' three bare globals stubbed even when it does not care about their values.
job_endpoint_stub_clustering_provenance <- function(env) {
  env$analysis_string_cache_fingerprint <- function() "fp-test"
  env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
  env$clustering_cached_source_data_version <- function(...) "srcv-test"
}

#' Minimal Plumber-response stand-in: an environment with `$status` and a
#' `$setHeader()` that records every header set (mirrors the `res_env`
#' pattern in test-unit-pubtator-enrichment.R).
job_endpoint_fake_res <- function() {
  res <- new.env()
  res$status <- NULL
  res$headers <- list()
  res$setHeader <- function(name, value) {
    res$headers[[name]] <- value
    invisible(NULL)
  }
  res
}
