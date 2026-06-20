# test-unit-ontology-mapping-refresh.R
#
# Unit tests for the disease ontology mapping refresh orchestrator (WP-C, C1).
# Exercises the single-flight lock-held skip path and the failed-step meta path
# with injected fakes — no network and no real DB.

library(testthat)

source_api_file("functions/disease-ontology-mapping-refresh.R", local = FALSE)

# A fake DBI-like connection (only an opaque token; the injected lock/meta fns
# never touch it).
.fake_conn <- function() structure(list(), class = "fake_mapping_conn")

test_that("lock helpers issue the canonical advisory lock name", {
  expect_identical(.DISEASE_ONTOLOGY_MAPPING_LOCK, "disease_ontology_mapping_refresh")
})

test_that("a held lock skips the rebuild and completes successfully", {
  fake <- .fake_conn()
  meta_written <- 0L

  result <- disease_ontology_mapping_refresh_run(
    job = list(job_id = "j1"),
    payload = list(),
    pool_obj = fake,
    checkout_fn = function(p) fake,
    return_fn = function(conn) invisible(NULL),
    try_lock_fn = function(conn) FALSE,
    release_lock_fn = function(conn) TRUE,
    write_meta_fn = function(conn, fields) {
      meta_written <<- meta_written + 1L
      NULL
    }
  )

  expect_identical(result$status, "skipped")
  expect_true(isTRUE(result$success))
  expect_identical(result$reason, "lock_held")
  # No rebuild, so no meta row is written on a benign lock skip.
  expect_identical(meta_written, 0L)
})

test_that("a failed refresh step writes a status=failed meta row and re-raises", {
  fake <- .fake_conn()
  meta_status <- NULL

  expect_error(
    disease_ontology_mapping_refresh_run(
      job = list(job_id = "j2"),
      payload = list(),
      pool_obj = fake,
      checkout_fn = function(p) fake,
      return_fn = function(conn) invisible(NULL),
      try_lock_fn = function(conn) TRUE,
      release_lock_fn = function(conn) TRUE,
      download_obo_fn = function(...) stop("boom: upstream OBO unavailable"),
      write_meta_fn = function(conn, fields) {
        meta_status <<- fields$status
        NULL
      }
    ),
    "Disease ontology mapping refresh failed"
  )
  expect_identical(meta_status, "failed")
})

test_that("OBO URL resolution honors arg > env > default precedence", {
  expect_equal(
    disease_ontology_mapping_resolve_obo_url("https://example.org/custom.obo"),
    "https://example.org/custom.obo"
  )
  withr::with_envvar(
    list(DISEASE_ONTOLOGY_MONDO_OBO_URL = "https://example.org/env.obo"),
    expect_equal(disease_ontology_mapping_resolve_obo_url(NULL), "https://example.org/env.obo")
  )
})
