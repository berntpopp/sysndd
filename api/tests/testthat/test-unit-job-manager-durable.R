library(testthat)
library(tibble)
library(withr)

job_manager_runtime_path <- function() {
  file.path(get_api_dir(), "functions", "job-manager.R")
}

load_job_manager_runtime <- function() {
  runtime_path <- job_manager_runtime_path()
  if (!file.exists(runtime_path)) {
    stop("job-manager runtime file is missing: ", runtime_path)
  }

  runtime_env <- new.env(parent = globalenv())
  temp_dir <- tempfile("job-manager-runtime-")
  dir.create(temp_dir, recursive = TRUE)

  on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)
  old_wd <- setwd(temp_dir)
  on.exit(setwd(old_wd), add = TRUE)

  sys.source(runtime_path, envir = runtime_env)
  runtime_env
}

test_that("create_job delegates to async_job_service_submit and preserves accepted response shape", {
  runtime <- load_job_manager_runtime()
  submit_call <- NULL

  runtime$async_job_service_submit <- function(job_type, request_payload, submitted_by = NULL, queue_name = "default", priority = 100L, max_attempts = 1L, scheduled_at = Sys.time(), job_id = uuid::UUIDgenerate(), conn = NULL) { # nolint: line_length_linter
    submit_call <<- list(job_type = job_type, request_payload = request_payload)
    list(job = tibble(job_id = "job-created"), duplicate = FALSE, created = TRUE)
  }

  result <- runtime$create_job(
    operation = "hgnc_update",
    params = list(refresh = TRUE)
  )

  expect_equal(submit_call$job_type, "hgnc_update")
  expect_equal(submit_call$request_payload, list(refresh = TRUE))
  expect_equal(result$job_id, "job-created")
  expect_equal(result$status, "accepted")
  expect_equal(result$estimated_seconds, 30)
})

test_that("create_job and production source have no dead executor or timeout API", {
  runtime <- load_job_manager_runtime()

  expect_setequal(names(formals(runtime$create_job)), c("operation", "params"))

  dead_arguments <- c("executor_fn", "timeout_ms")
  collect_dead_symbols <- function(expression) {
    found <- character()
    visit <- function(node) {
      if (is.name(node) && as.character(node) %in% dead_arguments) {
        found <<- c(found, as.character(node))
      }
      if (is.call(node) || is.expression(node) || is.pairlist(node)) {
        node_parts <- as.list(node)
        found <<- c(found, intersect(names(node_parts), dead_arguments))
        lapply(node_parts, visit)
      }
      invisible(NULL)
    }
    visit(expression)
    unique(found)
  }

  expect_setequal(
    collect_dead_symbols(quote(submit_fn(timeout_ms = 1, executor_fn = NULL))),
    dead_arguments
  )
  expect_setequal(
    collect_dead_symbols(quote(function(executor_fn, timeout_ms = 1) NULL)),
    dead_arguments
  )

  source_files <- list.files(
    get_api_dir(),
    pattern = "\\.R$",
    recursive = TRUE,
    full.names = TRUE
  )
  source_files <- source_files[!grepl("/tests/", source_files, fixed = TRUE)]
  offenders <- unlist(lapply(source_files, function(source_file) {
    paste(
      source_file,
      collect_dead_symbols(parse(source_file, keep.source = FALSE)),
      sep = ":"
    )
  }))
  offenders <- offenders[!endsWith(offenders, ":")]

  expect_equal(length(offenders), 0L, info = paste(offenders, collapse = ", "))
})

test_that("get_job_status translates durable rows into the legacy polling contract", {
  runtime <- load_job_manager_runtime()

  runtime$async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
    tibble(
      job_id = job_id,
      job_type = "pubtator_update",
      status = "running",
      submitted_at = as.POSIXct("2026-04-23 12:00:00", tz = "UTC"),
      progress_pct = 55,
      progress_message = "Fetching publications",
      completed_at = as.POSIXct(NA),
      result_json = NA_character_,
      last_error_code = NA_character_,
      last_error_message = NA_character_
    )
  }

  running <- runtime$get_job_status("job-running")

  expect_equal(running$status, "running")
  expect_equal(running$step, "Fetching publications")
  expect_equal(running$progress$current, 55L)
  expect_equal(running$progress$total, 100L)
  expect_equal(running$retry_after, 5)

  runtime$async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
    tibble(
      job_id = job_id,
      job_type = "pubtator_update",
      status = "completed",
      submitted_at = as.POSIXct("2026-04-23 12:00:00", tz = "UTC"),
      progress_pct = NA_real_,
      progress_message = NA_character_,
      completed_at = as.POSIXct("2026-04-23 12:05:00", tz = "UTC"),
      result_json = '{"ok":true}',
      last_error_code = NA_character_,
      last_error_message = NA_character_
    )
  }

  completed <- runtime$get_job_status("job-completed", result_mode = "full")
  expect_equal(completed$status, "completed")
  expect_true(isTRUE(completed$result$ok))

  runtime$async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
    tibble(
      job_id = job_id,
      job_type = "pubtator_update",
      status = "cancelled",
      submitted_at = as.POSIXct("2026-04-23 12:00:00", tz = "UTC"),
      progress_pct = NA_real_,
      progress_message = NA_character_,
      completed_at = as.POSIXct("2026-04-23 12:04:00", tz = "UTC"),
      result_json = NA_character_,
      last_error_code = "CANCELLED",
      last_error_message = "Job was cancelled by the user"
    )
  }

  cancelled <- runtime$get_job_status("job-cancelled")
  expect_equal(cancelled$status, "cancelled")
  expect_equal(cancelled$error$code, "CANCELLED")
  expect_match(cancelled$error$message, "cancelled")

  runtime$async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) tibble()
  missing <- runtime$get_job_status("job-missing")
  expect_equal(missing$error, "JOB_NOT_FOUND")
})

test_that("check_duplicate_job and get_job_history delegate to durable service helpers", {
  runtime <- load_job_manager_runtime()

  runtime$async_job_service_duplicate <- function(job_type, request_payload, conn = NULL) {
    list(duplicate = TRUE, existing_job_id = "job-dup")
  }
  runtime$async_job_service_history <- function(limit = 20L, conn = NULL) {
    tibble(
      job_id = c("job-2", "job-1"),
      job_type = c("ontology_update", "hgnc_update"),
      status = c("failed", "completed"),
      submitted_at = as.POSIXct(c("2026-04-23 11:00:00", "2026-04-23 10:00:00"), tz = "UTC"),
      completed_at = as.POSIXct(c("2026-04-23 11:03:00", "2026-04-23 10:04:00"), tz = "UTC"),
      last_error_message = c("boom", NA_character_)
    )
  }

  duplicate <- runtime$check_duplicate_job("ontology_update", list(operation = "ontology_update"))
  history <- runtime$get_job_history(2)

  expect_true(isTRUE(duplicate$duplicate))
  expect_equal(duplicate$existing_job_id, "job-dup")
  expect_equal(history$job_id, c("job-2", "job-1"))
  expect_equal(history$operation, c("ontology_update", "hgnc_update"))
  expect_equal(history$error_message[[1]], "boom")
})
