library(testthat)

source_api_file("functions/async-job-force-apply-payload.R", local = FALSE)
source_api_file("functions/async-job-omim-apply.R", local = FALSE)
# The eagerly-built async_job_handler_registry list() references provider and
# maintenance handler functions by bare symbol (#346 Wave 4 split), so both
# extracted modules must be sourced BEFORE async-job-handlers.R or the list()
# construction fails with "object '...' not found".
source_api_file("functions/async-job-provider-handlers.R", local = FALSE)
source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE)
source_api_file("functions/async-job-handlers.R", local = FALSE)

handler_body <- function(fn) {
  paste(deparse(body(fn)), collapse = "\n")
}

test_that(".async_job_omim_db_write uses the shared ontology refresh helper", {
  body_txt <- handler_body(.async_job_omim_db_write)

  expect_match(body_txt, "refresh_disease_ontology_set")
  expect_false(grepl("\\bTRUNCATE\\b", body_txt, ignore.case = TRUE))
  expect_false(grepl("DBI::dbBegin|DBI::dbCommit|DBI::dbRollback", body_txt))
})

test_that(".async_job_run_force_apply_ontology uses helper-managed transaction lifecycle", {
  body_txt <- handler_body(.async_job_run_force_apply_ontology)

  expect_match(body_txt, "refresh_disease_ontology_set")
  expect_false(grepl("\\bTRUNCATE\\b", body_txt, ignore.case = TRUE))
  expect_false(grepl("DBI::dbRollback\\(sysndd_db\\)", body_txt))
})

test_that(".async_job_run_omim_update forces a fresh combined ontology build", {
  body_txt <- handler_body(.async_job_run_omim_update)

  expect_match(body_txt, "process_combine_ontology")
  expect_match(body_txt, "max_file_age\\s*=\\s*0")
})

test_that("disease_ontology_mapping_refresh handler is registered and callable", {
  entry <- async_job_get_handler("disease_ontology_mapping_refresh")

  expect_type(entry, "list")
  expect_true(is.function(entry$run))
  expect_identical(entry$cancel_mode, "non_interruptible")
  expect_true(is.function(entry$after_success))

  body_txt <- handler_body(.async_job_run_disease_ontology_mapping_refresh)
  expect_match(body_txt, "disease_ontology_mapping_refresh_run")
})

test_that(".async_job_run_omim_update applies additive terms best-effort on block", {
  handler_txt <- handler_body(.async_job_run_omim_update)
  expect_match(handler_txt, "apply_additive_terms_on_block")
  expect_match(handler_txt, "additive_applied")

  helper_txt <- handler_body(apply_additive_terms_on_block)
  expect_match(helper_txt, "extract_additive_ontology_terms")
  expect_match(helper_txt, "apply_additive_ontology_terms")
  expect_match(helper_txt, "tryCatch")
  expect_match(helper_txt, "async_job_chain_ontology_mapping_refresh")
})

# ---------------------------------------------------------------------------
# Force-apply payload-shape regression
#
# The blocked omim_update result builds critical_entities / auto_fixes as
# purrr::transpose() lists of records, but get_job_status(result_mode = "full")
# and the worker both decode with jsonlite::fromJSON(simplifyVector = TRUE),
# which collapses an array of uniform objects into a data.frame. The previous
# helpers iterated with vapply(table, \(x) x$field) — over a data.frame that
# walks COLUMNS, so the column access crashed Force Apply with
# "$ operator is invalid for atomic vectors". These tests pin the realistic
# runtime shapes so the regression cannot return silently.
# ---------------------------------------------------------------------------

# Reproduce the JSON round-trip get_job_status()/the worker apply to the blocked
# result before the force-apply helpers see it.
.force_apply_roundtrip <- function(records) {
  json <- jsonlite::toJSON(records, auto_unbox = TRUE)
  jsonlite::fromJSON(json, simplifyVector = TRUE)
}

.force_apply_auto_fix_records <- function() {
  tibble::tibble(
    old_version = c("OMIM:125310", "OMIM:244200", "OMIM:305400_1"),
    new_version = c("OMIM:125310_1", "OMIM:244200_1", "OMIM:305400"),
    fix_type = c("id_fingerprint", "name_fingerprint", "name_fingerprint"),
    disease_ontology_name = c("Disease A", "Disease B", "Disease C"),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0000007", "HP:0001419")
  ) |>
    as.list() |>
    purrr::transpose()
}

test_that(".async_job_force_apply_auto_fixes handles the simplifyVector data.frame shape", {
  raw <- .force_apply_roundtrip(.force_apply_auto_fix_records())
  # Pin the realistic runtime shape: simplifyVector turns the array of records
  # into a data.frame, which is exactly what crashed the old vapply() helper.
  expect_s3_class(raw, "data.frame")

  out <- .async_job_force_apply_auto_fixes(raw)
  expect_equal(out$old_version, c("OMIM:125310", "OMIM:244200", "OMIM:305400_1"))
  expect_equal(out$new_version, c("OMIM:125310_1", "OMIM:244200_1", "OMIM:305400"))
})

test_that(".async_job_force_apply_auto_fixes handles the transpose list-of-records shape", {
  out <- .async_job_force_apply_auto_fixes(.force_apply_auto_fix_records())
  expect_equal(out$old_version, c("OMIM:125310", "OMIM:244200", "OMIM:305400_1"))
  expect_equal(out$new_version, c("OMIM:125310_1", "OMIM:244200_1", "OMIM:305400"))
})

test_that(".async_job_force_apply_auto_fixes handles empty / null input", {
  out_list <- .async_job_force_apply_auto_fixes(list())
  out_null <- .async_job_force_apply_auto_fixes(NULL)
  expect_equal(nrow(out_list), 0)
  expect_equal(nrow(out_null), 0)
  expect_named(out_list, c("old_version", "new_version"))
})

test_that(".async_job_force_apply_critical_versions handles the simplifyVector data.frame shape", {
  records <- tibble::tibble(
    disease_ontology_id_version = c("OMIM:169500", "OMIM:301058_1", "OMIM:619701"),
    disease_ontology_name = c("Leukodystrophy", "DEE 90", "Yoon-Bellen syndrome"),
    hgnc_id = c("HGNC:6637", "HGNC:3670", "HGNC:25590"),
    hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0001419", "HP:0000007")
  ) |>
    as.list() |>
    purrr::transpose()
  raw <- .force_apply_roundtrip(records)
  expect_s3_class(raw, "data.frame")

  out <- .async_job_force_apply_critical_versions(raw)
  expect_equal(out, c("OMIM:169500", "OMIM:301058_1", "OMIM:619701"))
})

test_that(".async_job_force_apply_critical_versions handles empty / null input", {
  expect_equal(.async_job_force_apply_critical_versions(list()), character(0))
  expect_equal(.async_job_force_apply_critical_versions(NULL), character(0))
})

# ---------------------------------------------------------------------------
# #346 Wave 4 registry regression: the handler-family split (provider vs.
# maintenance vs. shell) must not change the registered job-type set, which
# handler function backs each job type, its cancel_mode, or its after_success
# hook. Bare-symbol entries are asserted by identity (proves the shell's
# registry list binds the SAME function object the extracted module defines,
# not a re-implemented/forward-declared copy); wrapper-closure entries
# (network_layout_prewarm, analysis_snapshot_refresh, and the passthrough
# factory job types) are asserted by callable shape only, since they are
# intentionally not bare symbols.
# ---------------------------------------------------------------------------

test_that("async_job_handler_registry has the exact expected job-type set", {
  expected_job_types <- c(
    "clustering", "phenotype_clustering", "ontology_update", "hgnc_update",
    "comparisons_update", "pubtator_update", "pubtator_enrichment_refresh",
    "pubtatornidd_nightly", "disease_ontology_mapping_refresh", "nddscore_import",
    "llm_generation", "network_layout_prewarm", "analysis_snapshot_refresh",
    "backup_create", "backup_restore", "omim_update", "force_apply_ontology",
    "publication_refresh", "publication_date_backfill"
  )

  expect_equal(sort(names(async_job_handler_registry)), sort(expected_job_types))
})

test_that("registry entries bind the exact expected handler function by identity", {
  bare_symbol_handlers <- list(
    clustering = .async_job_run_clustering,
    phenotype_clustering = .async_job_run_phenotype_clustering,
    ontology_update = .async_job_run_ontology_update,
    hgnc_update = .async_job_run_hgnc_update,
    pubtator_update = .async_job_run_pubtator,
    pubtator_enrichment_refresh = .async_job_run_pubtator_enrichment,
    pubtatornidd_nightly = .async_job_run_pubtatornidd_nightly,
    disease_ontology_mapping_refresh = .async_job_run_disease_ontology_mapping_refresh,
    nddscore_import = .async_job_run_nddscore_import,
    backup_create = .async_job_run_backup_create,
    backup_restore = .async_job_run_backup_restore,
    omim_update = .async_job_run_omim_update,
    force_apply_ontology = .async_job_run_force_apply_ontology,
    publication_refresh = .async_job_run_publication_refresh,
    publication_date_backfill = .async_job_run_publication_date_backfill
  )

  for (job_type in names(bare_symbol_handlers)) {
    expect_identical(
      async_job_handler_registry[[job_type]]$run,
      bare_symbol_handlers[[job_type]],
      info = job_type
    )
  }

  # Wrapper-closure / passthrough-factory job types: callable, not bare-symbol.
  for (job_type in c(
    "comparisons_update", "llm_generation", "network_layout_prewarm", "analysis_snapshot_refresh"
  )) {
    expect_true(is.function(async_job_handler_registry[[job_type]]$run), info = job_type)
  }
})

test_that("registry entries have the exact expected cancel_mode", {
  expected_cancel_modes <- c(
    clustering = "best_effort",
    phenotype_clustering = "best_effort",
    ontology_update = "non_interruptible",
    hgnc_update = "non_interruptible",
    comparisons_update = "non_interruptible",
    pubtator_update = "best_effort",
    pubtator_enrichment_refresh = "best_effort",
    pubtatornidd_nightly = "non_interruptible",
    disease_ontology_mapping_refresh = "non_interruptible",
    nddscore_import = "non_interruptible",
    llm_generation = "best_effort",
    network_layout_prewarm = "best_effort",
    analysis_snapshot_refresh = "best_effort",
    backup_create = "non_interruptible",
    backup_restore = "non_interruptible",
    omim_update = "non_interruptible",
    force_apply_ontology = "non_interruptible",
    publication_refresh = "best_effort",
    publication_date_backfill = "non_interruptible"
  )

  for (job_type in names(expected_cancel_modes)) {
    expect_identical(
      async_job_handler_registry[[job_type]]$cancel_mode,
      unname(expected_cancel_modes[job_type]),
      info = job_type
    )
  }
})

test_that("registry entries have the exact expected after_success hook", {
  noop_job_types <- c(
    "ontology_update", "hgnc_update", "comparisons_update", "pubtator_update",
    "pubtator_enrichment_refresh", "pubtatornidd_nightly",
    "disease_ontology_mapping_refresh", "nddscore_import", "llm_generation",
    "network_layout_prewarm", "analysis_snapshot_refresh", "backup_create",
    "backup_restore", "omim_update", "force_apply_ontology", "publication_refresh",
    "publication_date_backfill"
  )

  for (job_type in noop_job_types) {
    expect_identical(
      async_job_handler_registry[[job_type]]$after_success,
      .async_job_after_success_noop,
      info = job_type
    )
  }

  # clustering / phenotype_clustering chain LLM generation via a custom closure,
  # not the noop.
  for (job_type in c("clustering", "phenotype_clustering")) {
    expect_true(is.function(async_job_handler_registry[[job_type]]$after_success), info = job_type)
    expect_false(
      identical(async_job_handler_registry[[job_type]]$after_success, .async_job_after_success_noop),
      info = job_type
    )
  }
})
