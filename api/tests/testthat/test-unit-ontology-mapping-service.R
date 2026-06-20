# test-unit-ontology-mapping-service.R
#
# Unit tests for the shared submit / status / bootstrap service (WP-C, C3).
# All paths use injected submit_fn / exists_fn spies — no DB, no network.

library(testthat)

source_api_file("services/disease-ontology-mapping-service.R", local = FALSE)

# A spy submit_fn capturing the call args and returning a non-duplicate job.
.spy_submit <- function(store) {
  function(job_type, request_payload, queue_name, priority, max_attempts, scheduled_at, conn = NULL) {
    store$calls[[length(store$calls) + 1L]] <- list(
      job_type = job_type, request_payload = request_payload,
      scheduled_at = scheduled_at, priority = priority, max_attempts = max_attempts
    )
    list(job = list(job_id = "job-xyz"), duplicate = FALSE)
  }
}

test_that("bootstrap (stagger) with an existing build skips submission", {
  store <- new.env(); store$calls <- list()
  out <- service_disease_ontology_mapping_submit_refresh(
    force = FALSE,
    stagger = TRUE,
    submit_fn = .spy_submit(store),
    exists_fn = function() TRUE
  )
  expect_true(isTRUE(out$skipped))
  expect_false(isTRUE(out$submitted))
  expect_length(store$calls, 0L)
})

test_that("cron (force=FALSE, no stagger) submits even when a build exists", {
  store <- new.env(); store$calls <- list()
  exists_called <- FALSE
  out <- service_disease_ontology_mapping_submit_refresh(
    force = FALSE,
    stagger = FALSE,
    submit_fn = .spy_submit(store),
    exists_fn = function() {
      exists_called <<- TRUE
      TRUE
    }
  )
  expect_true(isTRUE(out$submitted))
  expect_length(store$calls, 1L)
  # The existence probe is bootstrap-only; the cron must not consult it.
  expect_false(exists_called)
})

test_that("force=TRUE submits at now (no stagger) even when a build exists", {
  store <- new.env(); store$calls <- list()
  now <- as.POSIXct("2026-06-20 12:00:00", tz = "UTC")
  out <- service_disease_ontology_mapping_submit_refresh(
    force = TRUE,
    submit_fn = .spy_submit(store),
    exists_fn = function() TRUE,
    now = now
  )
  expect_true(isTRUE(out$submitted))
  expect_length(store$calls, 1L)
  call <- store$calls[[1]]
  expect_identical(call$job_type, "disease_ontology_mapping_refresh")
  expect_true(isTRUE(call$request_payload$force))
  expect_equal(call$scheduled_at, now)
})

test_that("bootstrap stagger submits at now + stagger_seconds when no build exists", {
  store <- new.env(); store$calls <- list()
  now <- as.POSIXct("2026-06-20 12:00:00", tz = "UTC")
  out <- service_disease_ontology_mapping_submit_refresh(
    force = FALSE,
    stagger = TRUE,
    submit_fn = .spy_submit(store),
    exists_fn = function() FALSE,
    now = now,
    stagger_seconds = 360L
  )
  expect_true(isTRUE(out$submitted))
  expect_length(store$calls, 1L)
  expect_equal(store$calls[[1]]$scheduled_at, now + 360L)
})

test_that("duplicate submit is reported as reused, not newly submitted", {
  dup_submit <- function(...) list(job = list(job_id = "dup-1"), duplicate = TRUE)
  out <- service_disease_ontology_mapping_submit_refresh(
    force = TRUE,
    submit_fn = dup_submit,
    exists_fn = function() FALSE
  )
  expect_true(isTRUE(out$duplicate))
  expect_false(isTRUE(out$submitted))
  expect_identical(out$job_id, "dup-1")
})

test_that("build_exists probes the meta table for a success row", {
  seen_sql <- NULL
  exists_yes <- disease_ontology_mapping_build_exists(query_fn = function(sql) {
    seen_sql <<- sql
    data.frame(present = 1L)
  })
  expect_true(exists_yes)
  expect_match(seen_sql, "disease_ontology_mapping_meta")
  expect_match(seen_sql, "status = 'success'")

  exists_no <- disease_ontology_mapping_build_exists(query_fn = function(sql) data.frame())
  expect_false(exists_no)
})

test_that("bootstrap_on_startup is a no-op when disabled", {
  called <- FALSE
  res <- disease_ontology_mapping_bootstrap_on_startup(
    submit_refresh_fn = function(...) {
      called <<- TRUE
      list(submitted = TRUE)
    },
    enabled_fn = function() FALSE
  )
  expect_false(isTRUE(res))
  expect_false(called)
})

test_that("bootstrap_on_startup submits with stagger when enabled and not present", {
  captured <- NULL
  res <- disease_ontology_mapping_bootstrap_on_startup(
    submit_refresh_fn = function(force, stagger) {
      captured <<- list(force = force, stagger = stagger)
      list(submitted = TRUE, duplicate = FALSE, skipped = FALSE, job_id = "boot-1")
    },
    enabled_fn = function() TRUE
  )
  expect_true(isTRUE(res))
  expect_false(isTRUE(captured$force))
  expect_true(isTRUE(captured$stagger))
})

test_that("status returns build_exists FALSE on an empty meta table", {
  out <- service_disease_ontology_mapping_status(query_fn = function(sql) data.frame())
  expect_false(isTRUE(out$build_exists))
  expect_null(out$latest)
})
