# Unit tests for the full-job-result access predicate.
source_api_file("functions/job-manager.R", local = FALSE)

test_that("anonymous may read full results only for public operations", {
  expect_true(can_read_full_job_result("clustering", user_role = NULL))
  expect_true(can_read_full_job_result("phenotype_clustering", user_role = NULL))
  expect_false(can_read_full_job_result("backup_create", user_role = NULL))
  expect_false(can_read_full_job_result("hgnc_update", user_role = NULL))
})

test_that("maintenance/admin job results are Administrator-only (LOW-1)", {
  # Heavy/admin maintenance results (backups, imports, upstream errors) must be
  # Administrator-only even for otherwise-privileged Reviewer/Curator roles.
  expect_false(can_read_full_job_result("backup_create", user_role = "Reviewer"))
  expect_false(can_read_full_job_result("backup_create", user_role = "Curator"))
  expect_false(can_read_full_job_result("hgnc_update", user_role = "Curator"))
  expect_true(can_read_full_job_result("backup_create", user_role = "Administrator"))
  expect_true(can_read_full_job_result("hgnc_update", user_role = "Administrator"))
  expect_false(can_read_full_job_result("backup_create", user_role = "Viewer"))
  # The full maintenance set is covered (Codex PR-2: 3 types were omitted).
  for (jt in c("publication_date_backfill", "pubtator_enrichment_refresh",
               "pubtatornidd_nightly", "comparisons_update", "nddscore_import")) {
    expect_false(can_read_full_job_result(jt, user_role = "Curator"),
                 info = paste("maintenance type must be admin-only:", jt))
    expect_true(can_read_full_job_result(jt, user_role = "Administrator"))
  }
})

test_that("Reviewer+ may still read full results for non-maintenance operations", {
  # Interactive/curation job types (not in ADMIN_ONLY_RESULT_JOB_TYPES) remain
  # readable by Reviewer/Curator/Administrator.
  expect_true(can_read_full_job_result("llm_generation", user_role = "Reviewer"))
  expect_true(can_read_full_job_result("analysis_snapshot_refresh", user_role = "Curator"))
})

test_that("edge cases: null job_type and unknown roles", {
  expect_false(can_read_full_job_result(NULL, user_role = NULL))
  # Unknown role on a private op denies; on a public op behaves like anonymous.
  expect_false(can_read_full_job_result("backup_create", user_role = "unknown_role"))
  expect_true(can_read_full_job_result("clustering", user_role = "unknown_role"))
})
