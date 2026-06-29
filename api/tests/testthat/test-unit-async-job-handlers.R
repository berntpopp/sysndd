library(testthat)

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
