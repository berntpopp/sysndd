# tests/testthat/test-unit-job-endpoint-services-maintenance.R
#
# Host-runnable unit tests for the MAINTENANCE submission + QUERY job-endpoint
# services (split from test-unit-job-endpoint-services.R to keep both files under the
# 600-line ceiling, #535 S6): job-maintenance-submission-service.R and
# job-query-endpoint-service.R. Shared fixtures (job_endpoint_source_service /
# job_endpoint_fake_pool / job_endpoint_fake_res) live in
# job-endpoint-services-fixtures.R and are explicitly sourced below.

# Resolve api_dir robustly so the file runs both under the full suite and a single-file
# testthat::test_file(), then source the shared fixtures.
if (exists("get_api_dir")) {
  api_dir <- get_api_dir()
} else {
  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
  if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
    api_dir <- normalizePath(getwd(), mustWork = FALSE)
  }
}
# local = TRUE keeps the shared helpers in this test file's environment (as if defined
# inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)

## -------------------------------------------------------------------##
## job-maintenance-submission-service.R
## -------------------------------------------------------------------##

job_endpoint_ontology_pool <- function(env) {
  job_endpoint_fake_pool(env, list(
    non_alt_loci_set = tibble::tibble(symbol = "A", hgnc_id = "HGNC:1"),
    mode_of_inheritance_list = tibble::tibble(
      is_active = c(1L, 0L),
      hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0000007"),
      hpo_mode_of_inheritance_term_name = c("AD", "AR")
    )
  ))
}

job_endpoint_maintenance_env <- function(needs_pool) {
  env <- job_endpoint_source_service("job-maintenance-submission-service.R")
  if (needs_pool) {
    env$pool <- job_endpoint_ontology_pool(env)
  } else {
    env$dw <- list(dbname = "sysndd_db", host = "db", user = "sysndd", password = "s3cr3t", port = 3306L)
  }
  # hgnc/comparisons now dedupe via job-type single-flight (#535 S2b HIGH-4);
  # ontology_update still uses check_duplicate_job. Provide a no-duplicate
  # default for both seams so per-test overrides only set the case they exercise.
  env$async_job_service_duplicate_by_type <- function(...) list(duplicate = FALSE)
  env
}

# Table-driven: the three maintenance types share duplicate/new-submit flow,
# differing only in operation name and Retry-After (30 / 60 / 30 seconds).
job_endpoint_maintenance_specs <- list(
  list(
    fn = "svc_job_submit_ontology_update", op = "ontology_update",
    retry_after = "30", needs_pool = TRUE,
    payload_names = c("hgnc_list", "mode_of_inheritance_list")
  ),
  list(
    fn = "svc_job_submit_hgnc_update", op = "hgnc_update",
    retry_after = "60", needs_pool = FALSE, payload_names = character()
  ),
  list(
    fn = "svc_job_submit_comparisons_update", op = "comparisons_update",
    retry_after = "30", needs_pool = FALSE, payload_names = character()
  )
)

for (job_endpoint_spec in job_endpoint_maintenance_specs) {
  test_that(paste(job_endpoint_spec$op, ": duplicate job returns 409 with Location"), {
    env <- job_endpoint_maintenance_env(job_endpoint_spec$needs_pool)
    dup_id <- paste0("dup-", job_endpoint_spec$op)
    env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = dup_id)
    env$async_job_service_duplicate_by_type <- function(...) list(duplicate = TRUE, existing_job_id = dup_id)
    res <- job_endpoint_fake_res()

    out <- env[[job_endpoint_spec$fn]](res)

    expect_equal(res$status, 409)
    expect_equal(out$error, "DUPLICATE_JOB")
    expect_match(res$headers[["Location"]], paste0("/api/jobs/", dup_id, "/status"))
  })

  test_that(paste(job_endpoint_spec$op, ": new submit returns 202 with the expected Retry-After"), {
    env <- job_endpoint_maintenance_env(job_endpoint_spec$needs_pool)
    env$check_duplicate_job <- function(...) list(duplicate = FALSE)
    new_job_id <- paste0(job_endpoint_spec$op, "-1")
    create_job_operation <- NULL
    create_job_params <- NULL
    env$create_job <- function(operation, params) {
      create_job_operation <<- operation
      create_job_params <<- params
      list(job_id = new_job_id, status = "accepted", estimated_seconds = 30)
    }

    out <- {
      res <- job_endpoint_fake_res()
      env[[job_endpoint_spec$fn]](res)
    }

    expect_equal(res$status, 202)
    expect_equal(res$headers[["Retry-After"]], job_endpoint_spec$retry_after)
    expect_equal(out$job_id, new_job_id)
    expect_equal(create_job_operation, job_endpoint_spec$op)
    actual_payload_names <- names(create_job_params)
    if (is.null(actual_payload_names)) actual_payload_names <- character()
    expect_setequal(actual_payload_names, job_endpoint_spec$payload_names)
  })
}

test_that("ontology update: create_job error surfaces as 503 with Retry-After", {
  env <- job_endpoint_maintenance_env(needs_pool = TRUE)
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env$create_job <- function(...) list(error = "CAPACITY_EXCEEDED", retry_after = 60)
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_ontology_update(res)

  expect_equal(res$status, 503)
  expect_equal(res$headers[["Retry-After"]], "60")
  expect_equal(out$error, "CAPACITY_EXCEEDED")
})

# Job-type single-flight (#535 S2b HIGH-4): the destructive maintenance submits
# dedupe on job_type ALONE — no db_config/password/payload reaches the dedup
# path — so a payload-schema change (dropping db_config) cannot open a
# deploy-window where two concurrent full-table-replace jobs run.
job_endpoint_single_flight_specs <- list(
  list(fn = "svc_job_submit_hgnc_update", op = "hgnc_update"),
  list(fn = "svc_job_submit_comparisons_update", op = "comparisons_update")
)

for (job_endpoint_spec in job_endpoint_single_flight_specs) {
  test_that(paste(job_endpoint_spec$op, ": dedupe is job-type single-flight (no credential/payload)"), {
    env <- job_endpoint_maintenance_env(needs_pool = FALSE)
    captured <- NULL
    env$async_job_service_duplicate_by_type <- function(...) {
      captured <<- list(...)
      list(duplicate = TRUE, existing_job_id = paste0("dup-", job_endpoint_spec$op))
    }
    res <- job_endpoint_fake_res()

    env[[job_endpoint_spec$fn]](res)

    # Only the job_type is passed to the dedup path (no params/credentials).
    expect_equal(captured[[1]], job_endpoint_spec$op)
    expect_false(any(grepl("s3cr3t", unlist(captured), fixed = TRUE)))
  })
}

## -------------------------------------------------------------------##
## job-query-endpoint-service.R — history
## -------------------------------------------------------------------##

job_endpoint_history_rows <- function(n = 2L) {
  if (n == 0L) {
    return(data.frame(
      job_id = character(0), operation = character(0), status = character(0),
      submitted_at = character(0), completed_at = character(0),
      duration_seconds = integer(0), error_message = character(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    job_id = paste0("job-", seq_len(n)),
    operation = rep("clustering", n),
    status = rep("completed", n),
    submitted_at = rep("2026-07-01T00:00:00Z", n),
    completed_at = rep("2026-07-01T00:05:00Z", n),
    duration_seconds = rep(300L, n),
    error_message = rep(NA_character_, n),
    stringsAsFactors = FALSE
  )
}

test_that("job history: limit clamps to [1, 100] and non-numeric falls back to 20", {
  env <- job_endpoint_source_service("job-query-endpoint-service.R")
  captured_limit <- NULL
  env$get_job_history <- function(limit) {
    captured_limit <<- limit
    job_endpoint_history_rows(0L)
  }

  env$svc_job_get_history(limit = 0)
  expect_equal(captured_limit, 20L)

  env$svc_job_get_history(limit = 500)
  expect_equal(captured_limit, 100L)

  # as.integer() on a non-numeric string warns (matches the original inline
  # handler's un-guarded as.integer(limit) coercion); assert it explicitly
  # instead of leaking it to the console.
  expect_warning(env$svc_job_get_history(limit = "not-a-number"), "NAs introduced")
  expect_equal(captured_limit, 20L)

  env$svc_job_get_history(limit = 50)
  expect_equal(captured_limit, 50L)
})

test_that("job history: shapes rows into a list (or an empty list) and reports meta count/limit", {
  env <- job_endpoint_source_service("job-query-endpoint-service.R")

  env$get_job_history <- function(limit) job_endpoint_history_rows(2L)
  out <- env$svc_job_get_history(limit = 20)
  expect_length(out$data, 2)
  expect_equal(out$data[[1]]$job_id, "job-1")
  expect_equal(out$meta$count, 2)
  expect_equal(out$meta$limit, 20L)

  env$get_job_history <- function(limit) job_endpoint_history_rows(0L)
  out <- env$svc_job_get_history(limit = 20)
  expect_equal(out$data, list())
  expect_equal(out$meta$count, 0)
})

## -------------------------------------------------------------------##
## job-query-endpoint-service.R — status
## -------------------------------------------------------------------##

test_that("job status: invalid result_mode (400), summary bypasses the gate (200), 404, and running Retry-After", {
  req <- list(user_role = NULL)

  env <- job_endpoint_source_service("job-query-endpoint-service.R")
  out <- env$svc_job_get_status("job-1", "bogus", req, job_endpoint_fake_res())
  expect_equal(out$error, "INVALID_RESULT_MODE")

  # Summary mode is a public read: it must never touch the full-result gate.
  gate_called <- FALSE
  env$async_job_repository_get <- function(...) {
    gate_called <<- TRUE
    NULL
  }
  env$get_job_status <- function(job_id, result_mode) {
    list(job_id = job_id, status = "completed", result = list(ok = TRUE))
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("job-1", "summary", req, res)
  expect_false(gate_called)
  expect_equal(res$status, 200)
  expect_equal(out$status, "completed")
  expect_null(res$headers[["Retry-After"]])

  env$get_job_status <- function(job_id, result_mode) list(error = "JOB_NOT_FOUND")
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("missing-job", "summary", req, res)
  expect_equal(res$status, 404)
  expect_equal(out$error, "JOB_NOT_FOUND")

  env$get_job_status <- function(job_id, result_mode) list(job_id = job_id, status = "running", retry_after = 7)
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("job-1", "summary", req, res)
  expect_equal(res$status, 200)
  expect_equal(res$headers[["Retry-After"]], "7")
  expect_equal(out$status, "running")
})

test_that("job status: full mode gates on access-verification failure (503) and role (403)", {
  req <- list(user_role = "Viewer")

  env <- job_endpoint_source_service("job-query-endpoint-service.R")
  env$async_job_repository_get <- function(job_id) stop("db unavailable")
  out <- env$svc_job_get_status("job-1", "full", req, job_endpoint_fake_res())
  expect_equal(out$error, "SERVICE_UNAVAILABLE")

  env$async_job_repository_get <- function(job_id) tibble::tibble(job_id = job_id, job_type = "hgnc_update")
  env$can_read_full_job_result <- function(job_type, user_role) FALSE
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("job-1", "full", req, res)
  expect_equal(res$status, 403)
  expect_equal(out$error, "FORBIDDEN")
})

test_that("job status: full mode skips the gate for an unknown id (404) and returns the result when authorized", {
  req <- list(user_role = NULL)

  env <- job_endpoint_source_service("job-query-endpoint-service.R")
  env$async_job_repository_get <- function(job_id) tibble::tibble(job_id = character(0), job_type = character(0))
  gate_called <- FALSE
  env$can_read_full_job_result <- function(job_type, user_role) {
    gate_called <<- TRUE
    FALSE
  }
  env$get_job_status <- function(job_id, result_mode) list(error = "JOB_NOT_FOUND")
  out <- env$svc_job_get_status("missing-job", "full", req, job_endpoint_fake_res())
  expect_false(gate_called)
  expect_equal(out$error, "JOB_NOT_FOUND")

  env$async_job_repository_get <- function(job_id) tibble::tibble(job_id = job_id, job_type = "clustering")
  env$can_read_full_job_result <- function(job_type, user_role) TRUE
  env$get_job_status <- function(job_id, result_mode) {
    list(job_id = job_id, status = "completed", result = list(cluster_count = 2))
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("job-1", "full", req, res)
  expect_equal(res$status, 200)
  expect_equal(out$result$cluster_count, 2)
})
