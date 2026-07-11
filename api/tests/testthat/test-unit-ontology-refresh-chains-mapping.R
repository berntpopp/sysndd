# test-unit-ontology-refresh-chains-mapping.R
#
# Unit tests for correction #2 (WP-C, C7): a successful ontology-set refresh must
# enqueue exactly one forced disease-ontology mapping refresh, best-effort (a
# submit hiccup must not fail the ontology refresh). Uses an injected spy for the
# mapping-submit service — no DB, no network.

library(testthat)

# .async_job_omim_db_write was extracted to async-job-omim-apply.R (#470); source
# it so handler_body(.async_job_omim_db_write) below still resolves.
source_api_file("functions/async-job-omim-apply.R", local = FALSE)
# #346 Wave 4: .async_job_run_force_apply_ontology and
# .async_job_chain_ontology_mapping_refresh now live in
# async-job-provider-handlers.R; the shell's registry list() also eagerly
# binds provider/maintenance handlers by bare symbol, so both extracted
# modules must be sourced before async-job-handlers.R.
source_api_file("functions/async-job-provider-handlers.R", local = FALSE)
source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE)
source_api_file("functions/async-job-handlers.R", local = FALSE)

handler_body <- function(fn) paste(deparse(body(fn)), collapse = "\n")

test_that("the chain helper submits exactly one forced mapping refresh", {
  calls <- list()
  # Spy override of the shared submit service, installed into the global env so
  # the chain helper resolves it at call time.
  assign(
    "service_disease_ontology_mapping_submit_refresh",
    function(force = FALSE, ...) {
      calls[[length(calls) + 1L]] <<- list(force = force)
      list(submitted = TRUE, duplicate = FALSE, job_id = "chain-1")
    },
    envir = .GlobalEnv
  )
  on.exit(
    rm("service_disease_ontology_mapping_submit_refresh", envir = .GlobalEnv),
    add = TRUE
  )

  .async_job_chain_ontology_mapping_refresh()

  expect_length(calls, 1L)
  expect_true(isTRUE(calls[[1]]$force))
})

test_that("a submit failure in the chain is swallowed (non-fatal)", {
  assign(
    "service_disease_ontology_mapping_submit_refresh",
    function(force = FALSE, ...) stop("transient submit failure"),
    envir = .GlobalEnv
  )
  on.exit(
    rm("service_disease_ontology_mapping_submit_refresh", envir = .GlobalEnv),
    add = TRUE
  )

  # Must not propagate the error.
  expect_no_error(.async_job_chain_ontology_mapping_refresh())
})

test_that("the chain is a no-op when the service is not loaded", {
  if (exists("service_disease_ontology_mapping_submit_refresh", envir = .GlobalEnv, inherits = FALSE)) {
    rm("service_disease_ontology_mapping_submit_refresh", envir = .GlobalEnv)
  }
  expect_no_error(.async_job_chain_ontology_mapping_refresh())
})

test_that("both ontology-set refresh sites call the chaining helper", {
  expect_match(
    handler_body(.async_job_omim_db_write),
    "\\.async_job_chain_ontology_mapping_refresh"
  )
  expect_match(
    handler_body(.async_job_run_force_apply_ontology),
    "\\.async_job_chain_ontology_mapping_refresh"
  )
  # The helper itself forces a rebuild.
  expect_match(
    handler_body(.async_job_chain_ontology_mapping_refresh),
    "service_disease_ontology_mapping_submit_refresh"
  )
  expect_match(
    handler_body(.async_job_chain_ontology_mapping_refresh),
    "force = TRUE"
  )
})
