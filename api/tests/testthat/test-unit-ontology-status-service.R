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

test_that("an empty job history is the safe fallback: neither blocked nor stale", {
  s <- derive_ontology_dictionary_status(list(), now, stale_after_days = 30)
  expect_false(s$blocked)
  expect_false(s$stale)
  expect_true(is.na(s$blocked_job_id))
  expect_equal(s$additive_applied, 0L)
})

test_that("last_additive_apply_at is populated when additive_applied > 0", {
  jobs <- list(job("omim_update", 1, "blocked", fresh = TRUE, crit = 5, add = 12))
  s <- derive_ontology_dictionary_status(jobs, now, stale_after_days = 30)
  expect_false(is.na(s$last_additive_apply_at))
  expect_equal(s$additive_applied, 12)
})

test_that("ontology_dictionary_status IO wrapper resolves injected deps and parses ISO-8601 without truncation", {
  fixed_now <- as.POSIXct("2026-06-29 14:00:00", tz = "UTC")
  fake_jid <- "blocked-job-1"

  fake_history <- function(limit) {
    data.frame(
      job_id      = fake_jid,
      operation   = "omim_update",
      status      = "completed",
      completed_at = "2026-06-29T12:30:00Z",
      stringsAsFactors = FALSE
    )
  }

  fake_status <- function(jid, result_mode) {
    list(result = list(
      status            = "blocked",
      pending_csv_path  = "x.csv",
      critical_count    = 5,
      auto_fixable_count = 1,
      additive_applied  = 12
    ))
  }

  fake_csv_fresh <- function(path, now) TRUE

  fake_db_lookup <- function() {
    list(last_applied = "2026-06-29", max_omim_id = "OMIM:621533")
  }

  s <- ontology_dictionary_status(
    get_history    = fake_history,
    get_status     = fake_status,
    now            = fixed_now,
    csv_fresh      = fake_csv_fresh,
    db_lookup      = fake_db_lookup,
    stale_after_days = 30
  )

  expect_true(s$blocked)
  expect_equal(s$blocked_job_id, fake_jid)
  expect_equal(s$critical_count, 5L)
  expect_equal(s$additive_applied, 12L)
  expect_equal(s$disease_ontology_last_applied, "2026-06-29")
  expect_equal(s$max_omim_id, "OMIM:621533")
  # Fix 2 lock: ISO-8601 "T12:30:00Z" must not be truncated to midnight
  at <- s$latest_blocked_omim_update_at
  expect_false(is.na(at))
  expect_equal(as.integer(format(at, "%H", tz = "UTC")), 12L)
})
