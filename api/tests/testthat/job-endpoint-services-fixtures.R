# tests/testthat/job-endpoint-services-fixtures.R
#
# Shared fixtures for the job-endpoint-service unit tests, split across two files
# to keep each under the 600-line ceiling:
#   - test-unit-job-endpoint-services.R              (functional + phenotype submission)
#   - test-unit-job-endpoint-services-maintenance.R  (maintenance submission + query)
# Both files EXPLICITLY source() this file at the top so they run standalone under a
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
job_endpoint_source_service <- function(filename) {
  env <- new.env(parent = globalenv())
  env$async_job_submit_admission_guard <- function(req, res) list(admitted = TRUE)
  sys.source(file.path(get_api_dir(), "services", filename), envir = env)
  env
}

#' Register `tbl.fake_pool` in `env` and build a fake pool over `tables`.
job_endpoint_fake_pool <- function(env, tables) {
  env$tbl.fake_pool <- function(src, from, ...) src$tables[[from]]
  structure(list(tables = tables), class = "fake_pool")
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
