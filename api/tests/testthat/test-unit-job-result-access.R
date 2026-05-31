# Unit tests for the full-job-result access predicate.
source_api_file("functions/job-manager.R", local = FALSE)

test_that("anonymous may read full results only for public operations", {
  expect_true(can_read_full_job_result("clustering", user_role = NULL))
  expect_true(can_read_full_job_result("phenotype_clustering", user_role = NULL))
  expect_false(can_read_full_job_result("backup_create", user_role = NULL))
  expect_false(can_read_full_job_result("hgnc_update", user_role = NULL))
})

test_that("Reviewer+ may read full results for any operation", {
  expect_true(can_read_full_job_result("backup_create", user_role = "Reviewer"))
  expect_true(can_read_full_job_result("backup_create", user_role = "Curator"))
  expect_true(can_read_full_job_result("hgnc_update", user_role = "Administrator"))
  expect_false(can_read_full_job_result("backup_create", user_role = "Viewer"))
})

test_that("edge cases: null job_type and unknown roles", {
  expect_false(can_read_full_job_result(NULL, user_role = NULL))
  # Unknown role on a private op denies; on a public op behaves like anonymous.
  expect_false(can_read_full_job_result("backup_create", user_role = "unknown_role"))
  expect_true(can_read_full_job_result("clustering", user_role = "unknown_role"))
})
