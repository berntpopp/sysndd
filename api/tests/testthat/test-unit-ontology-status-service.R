library(testthat)

source_api_file("functions/ontology-status-service.R", local = FALSE)

now <- as.POSIXct("2026-06-29 12:00:00", tz = "UTC")
job <- function(op, ago_h, rs, fresh = NA, crit = 0, add = 0) {
  list(
    operation = op, job_id = paste0(op, "-", ago_h),
    completed_at = now - ago_h * 3600,
    result_status = rs, critical_count = crit, auto_fixable_count = 0,
    additive_applied = add, pending_csv_fresh = fresh
  )
}

test_that("a fresh blocked omim_update sets blocked + stale", {
  jobs <- list(job("omim_update", 1, "blocked", fresh = TRUE, crit = 5, add = 12))
  s <- derive_ontology_dictionary_status(jobs, now, stale_after_days = 30)
  expect_true(s$blocked)
  expect_true(s$stale)
  expect_equal(s$blocked_job_id, "omim_update-1")
  expect_equal(s$critical_count, 5)
  expect_equal(s$additive_applied, 12)
})

test_that("a blocked omim_update with a stale CSV is stale-only (not blocked)", {
  jobs <- list(
    job("omim_update", 1, "blocked", fresh = FALSE, crit = 5),
    job("force_apply_ontology", 200, "success")
  )
  s <- derive_ontology_dictionary_status(jobs, now, stale_after_days = 30)
  expect_false(s$blocked)
  expect_true(s$stale)
})

test_that("a clean recent success is neither blocked nor stale", {
  jobs <- list(job("omim_update", 2, "success", add = 0))
  s <- derive_ontology_dictionary_status(jobs, now, stale_after_days = 30)
  expect_false(s$blocked)
  expect_false(s$stale)
  expect_false(is.na(s$last_full_apply_at))
})

test_that("an old last-full-apply is stale even with no block", {
  jobs <- list(job("omim_update", 24 * 60, "success"))  # 60 days ago
  s <- derive_ontology_dictionary_status(jobs, now, stale_after_days = 30)
  expect_true(s$stale)
})
