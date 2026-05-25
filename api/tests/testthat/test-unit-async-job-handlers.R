library(testthat)

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
