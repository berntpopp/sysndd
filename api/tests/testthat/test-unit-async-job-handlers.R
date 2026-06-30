library(testthat)

source_api_file("functions/async-job-force-apply-payload.R", local = FALSE)
source_api_file("functions/async-job-handlers.R", local = FALSE)
source_api_file("functions/async-job-omim-apply.R", local = FALSE)

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
