# tests/testthat/test-unit-async-job-db-config.R
# #535 P1-1: durable job handlers resolve DB credentials from runtime config,
# not from the job payload. Host-runnable (no DB).

library(testthat)

source_api_file("functions/async-job-db-config.R", local = FALSE)

test_that("resolver returns the five connection fields from injected config", {
  cfg <- list(dbname = "d", host = "h", user = "u", password = "p", port = 3306L, extra = "x")
  out <- async_job_worker_db_config(runtime_config = cfg)
  expect_equal(out, list(dbname = "d", host = "h", user = "u", password = "p", port = 3306L))
})

test_that("resolver coerces port to a positive integer", {
  cfg <- list(dbname = "d", host = "h", user = "u", password = "p", port = "3307")
  out <- async_job_worker_db_config(runtime_config = cfg)
  expect_identical(out$port, 3307L)
})

test_that("resolver rejects missing/empty fields without echoing credential values", {
  cfg <- list(dbname = "d", host = "h", user = "u", password = "", port = 3306L)
  expect_error(async_job_worker_db_config(runtime_config = cfg), "password")
  # The error must not leak the (here empty) password value verbatim in a way
  # that could echo a real secret: assert the message names the field only.
  cfg2 <- list(dbname = "d", host = "h", user = "u", password = "sup3rsecret", port = 0L)
  err <- tryCatch(async_job_worker_db_config(runtime_config = cfg2), error = function(e) conditionMessage(e))
  expect_true(grepl("port", err))
  expect_false(grepl("sup3rsecret", err, fixed = TRUE))
})

test_that("resolver errors clearly when no runtime config is available", {
  skip_if(base::exists("dw", envir = .GlobalEnv, inherits = FALSE), "dw present in .GlobalEnv")
  expect_error(async_job_worker_db_config(), "runtime config", ignore.case = TRUE)
})
