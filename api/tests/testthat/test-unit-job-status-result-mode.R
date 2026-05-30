job_status_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(job_status_test_wd), testthat::teardown_env())

test_that("get_job_status defaults to summary without result_json", {
  env <- new.env(parent = globalenv())
  sys.source(file.path("functions", "job-manager.R"), envir = env)

  captured_include_result <- NULL
  env$async_job_service_status <- function(job_id, include_result = FALSE) {
    captured_include_result <<- include_result
    tibble::tibble(
      job_id = job_id,
      job_type = "clustering",
      status = "completed",
      submitted_at = Sys.time(),
      completed_at = Sys.time(),
      progress_pct = 100,
      progress_message = "done",
      last_error_code = NA_character_,
      last_error_message = NA_character_
    )
  }

  result <- env$get_job_status("job-1")
  expect_false(captured_include_result)
  expect_equal(result$status, "completed")
  expect_null(result$result)
})

test_that("get_job_status includes result only for full result mode", {
  env <- new.env(parent = globalenv())
  sys.source(file.path("functions", "job-manager.R"), envir = env)

  captured_include_result <- NULL
  env$async_job_service_status <- function(job_id, include_result = FALSE) {
    captured_include_result <<- include_result
    tibble::tibble(
      job_id = job_id,
      job_type = "clustering",
      status = "completed",
      submitted_at = Sys.time(),
      completed_at = Sys.time(),
      progress_pct = 100,
      progress_message = "done",
      result_json = '{"meta":{"cluster_count":2}}',
      last_error_code = NA_character_,
      last_error_message = NA_character_
    )
  }

  result <- env$get_job_status("job-1", result_mode = "full")
  expect_true(captured_include_result)
  expect_equal(result$result$meta$cluster_count, 2)
})

test_that("get_job_status returns structured error for corrupt full result JSON", {
  env <- new.env(parent = globalenv())
  sys.source(file.path("functions", "job-manager.R"), envir = env)

  env$async_job_service_status <- function(job_id, include_result = FALSE) {
    tibble::tibble(
      job_id = job_id,
      job_type = "clustering",
      status = "completed",
      submitted_at = Sys.time(),
      completed_at = Sys.time(),
      progress_pct = 100,
      progress_message = "done",
      result_json = '{"meta":',
      last_error_code = NA_character_,
      last_error_message = NA_character_
    )
  }

  result <- env$get_job_status("job-1", result_mode = "full")
  expect_equal(result$status, "completed")
  expect_null(result$result)
  expect_equal(result$error$code, "RESULT_PARSE_FAILED")
})
