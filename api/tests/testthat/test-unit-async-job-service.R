library(testthat)
library(tibble)
library(jsonlite)

async_job_service_runtime_path <- function() {
  file.path(get_api_dir(), "functions", "async-job-service.R")
}

load_async_job_service_runtime <- function() {
  runtime_path <- async_job_service_runtime_path()
  if (!file.exists(runtime_path)) {
    stop("async-job service file is missing: ", runtime_path)
  }

  runtime_env <- new.env(parent = globalenv())
  sys.source(runtime_path, envir = runtime_env)
  runtime_env
}

test_that("async_job_service_submit creates a durable job and returns the stored row", {
  runtime <- load_async_job_service_runtime()
  created_job <- NULL
  get_call <- NULL
  scheduled_at <- as.POSIXct("2026-04-23 10:15:00", tz = "UTC")

  runtime$async_job_repository_create <- function(job, conn = NULL) {
    created_job <<- job
    job$job_id
  }

  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
    get_call <<- list(job_id = job_id, include_result = include_result)
    tibble::tibble(
      job_id = job_id,
      job_type = created_job$job_type,
      queue_name = created_job$queue_name,
      priority = created_job$priority,
      status = "queued",
      request_hash = created_job$request_hash,
      request_payload_json = created_job$request_payload_json,
      submitted_by = created_job$submitted_by,
      submitted_at = created_job$submitted_at,
      scheduled_at = created_job$scheduled_at,
      attempt_count = 0L,
      max_attempts = created_job$max_attempts
    )
  }

  result <- runtime$async_job_service_submit(
    job_type = "comparisons_update",
    request_payload = list(genes = c("GENE1", "GENE2"), algorithm = "walktrap"),
    submitted_by = 42L,
    queue_name = "bulk",
    priority = 5L,
    max_attempts = 3L,
    scheduled_at = scheduled_at,
    job_id = "job-submit"
  )

  expect_false(result$duplicate)
  expect_true(result$created)
  expect_equal(result$job$job_id[[1]], "job-submit")
  expect_equal(created_job$job_type, "comparisons_update")
  expect_equal(created_job$queue_name, "bulk")
  expect_equal(created_job$priority, 5L)
  expect_equal(created_job$submitted_by, 42L)
  expect_equal(created_job$max_attempts, 3L)
  expect_equal(created_job$scheduled_at, scheduled_at)
  expect_equal(
    jsonlite::fromJSON(created_job$request_payload_json, simplifyVector = TRUE),
    list(genes = c("GENE1", "GENE2"), algorithm = "walktrap")
  )
  expect_equal(
    created_job$request_hash,
    runtime$async_job_service_request_hash(
      "comparisons_update",
      created_job$request_payload_json
    )
  )
  expect_equal(get_call, list(job_id = "job-submit", include_result = FALSE))
})

test_that("async_job_service_submit returns the duplicate job when the repository rejects a concurrent create", {
  runtime <- load_async_job_service_runtime()
  duplicate_row <- tibble::tibble(job_id = "job-duplicate", status = "queued")

  runtime$async_job_repository_create <- function(job, conn = NULL) {
    rlang::abort(
      "duplicate",
      class = "async_job_duplicate_error",
      job_id = "job-duplicate",
      duplicate_job = duplicate_row
    )
  }

  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
    stop("status lookup should not be needed when duplicate row is attached")
  }

  result <- runtime$async_job_service_submit(
    job_type = "hgnc_update",
    request_payload = list(refresh = TRUE),
    job_id = "job-new"
  )

  expect_true(result$duplicate)
  expect_false(result$created)
  expect_equal(result$job, duplicate_row)
})

test_that("async_job_service_find_duplicate hashes the request payload before querying the repository", {
  runtime <- load_async_job_service_runtime()
  captured <- NULL

  runtime$async_job_repository_find_active_duplicate <- function(job_type, request_hash, conn = NULL) {
    captured <<- list(job_type = job_type, request_hash = request_hash)
    tibble::tibble(job_id = "job-existing", status = "running")
  }

  result <- runtime$async_job_service_find_duplicate(
    job_type = "clustering",
    request_payload = list(genes = c("A", "B"), algorithm = "leiden")
  )

  expect_equal(result$job_id[[1]], "job-existing")
  expect_equal(captured$job_type, "clustering")
  expect_equal(
    captured$request_hash,
    runtime$async_job_service_request_hash(
      "clustering",
      runtime$async_job_service_payload_json(
        list(genes = c("A", "B"), algorithm = "leiden")
      )
    )
  )
})

test_that("find_active_by_type is job-type scoped and payload-hash independent (#535 S2b HIGH-4)", {
  runtime <- load_async_job_service_runtime()
  captured <- NULL

  # Job-type single-flight must not hash a payload: destructive maintenance jobs
  # dedupe on job_type alone, so a payload-schema change (dropping db_config)
  # cannot open a deploy-window where two concurrent full-table-replace jobs run.
  expect_true(is.function(runtime$async_job_service_find_active_by_type))
  expect_equal(names(formals(runtime$async_job_service_find_active_by_type)),
               c("job_type", "conn"))

  runtime$async_job_repository_find_active_by_type <- function(job_type, conn = NULL) {
    captured <<- list(job_type = job_type)
    tibble::tibble(job_id = "job-active", status = "running")
  }

  dup <- runtime$async_job_service_duplicate_by_type("hgnc_update")
  expect_true(dup$duplicate)
  expect_equal(dup$existing_job_id, "job-active")
  expect_equal(captured$job_type, "hgnc_update")
})

test_that("duplicate_by_type reports no duplicate when no active job of that type exists", {
  runtime <- load_async_job_service_runtime()
  runtime$async_job_repository_find_active_by_type <- function(job_type, conn = NULL) {
    tibble::tibble()
  }
  dup <- runtime$async_job_service_duplicate_by_type("comparisons_update")
  expect_false(dup$duplicate)
  expect_null(dup$existing_job_id)
})

test_that("async_job_service_status and history delegate to the durable repository helpers", {
  runtime <- load_async_job_service_runtime()
  status_call <- NULL
  history_call <- NULL

  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
    status_call <<- list(job_id = job_id, include_result = include_result)
    tibble::tibble(job_id = job_id, status = "completed", result_json = "{\"ok\":true}")
  }

  runtime$async_job_repository_history <- function(limit = 20L, conn = NULL) {
    history_call <<- list(limit = limit)
    tibble::tibble(job_id = c("job-2", "job-1"), status = c("completed", "failed"))
  }

  status <- runtime$async_job_service_status("job-status", include_result = TRUE)
  history <- runtime$async_job_service_history(limit = 0)

  expect_equal(status$job_id[[1]], "job-status")
  expect_equal(status_call, list(job_id = "job-status", include_result = TRUE))
  expect_equal(history$job_id, c("job-2", "job-1"))
  expect_equal(history_call$limit, 1L)
})

test_that("async_job_service_cancel returns the refreshed durable job row", {
  runtime <- load_async_job_service_runtime()
  cancel_call <- NULL

  runtime$async_job_repository_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
    cancel_call <<- list(job_id = job_id, cancelled_by = cancelled_by)
    1L
  }

  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
    tibble::tibble(job_id = job_id, status = "cancel_requested", cancelled_by = 9L)
  }

  cancelled <- runtime$async_job_service_cancel("job-cancel", cancelled_by = 9L)

  expect_equal(cancel_call, list(job_id = "job-cancel", cancelled_by = 9L))
  expect_equal(cancelled$status[[1]], "cancel_requested")
  expect_equal(cancelled$cancelled_by[[1]], 9L)
})

# --- #486: queue routing + priority by job type ----------------------------

test_that("async_job_queue_for_type routes heavy maintenance jobs to the maintenance lane", {
  runtime <- load_async_job_service_runtime()

  expect_equal(runtime$async_job_queue_for_type("publication_date_backfill"), "maintenance")
  expect_equal(runtime$async_job_queue_for_type("omim_update"), "maintenance")
  expect_equal(runtime$async_job_queue_for_type("disease_ontology_mapping_refresh"), "maintenance")
  expect_equal(runtime$async_job_queue_for_type("nddscore_import"), "maintenance")

  expect_equal(runtime$async_job_queue_for_type("llm_generation"), "default")
  expect_equal(runtime$async_job_queue_for_type("clustering"), "default")
  expect_equal(runtime$async_job_queue_for_type("phenotype_clustering"), "default")
  # Unknown / unclassified job types default to the interactive lane.
  expect_equal(runtime$async_job_queue_for_type("some_new_job"), "default")
})

test_that("interactive jobs outrank maintenance jobs in claim priority", {
  runtime <- load_async_job_service_runtime()

  interactive <- runtime$async_job_priority_for_type("llm_generation")
  maintenance <- runtime$async_job_priority_for_type("publication_date_backfill")
  other <- runtime$async_job_priority_for_type("some_new_job")

  # Lower number = claimed first (claim query orders priority ASC).
  expect_lt(interactive, maintenance)
  expect_lt(maintenance, other)
  expect_equal(runtime$async_job_priority_for_type("clustering"), interactive)
  expect_equal(runtime$async_job_priority_for_type("omim_update"), maintenance)
})

test_that("async_job_service_submit defaults queue + priority from the job type", {
  runtime <- load_async_job_service_runtime()
  created_job <- NULL

  runtime$async_job_repository_create <- function(job, conn = NULL) {
    created_job <<- job
    job$job_id
  }
  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
    tibble::tibble(job_id = job_id, queue_name = created_job$queue_name,
                   priority = created_job$priority)
  }

  # publication_date_backfill (maintenance) with no explicit queue/priority.
  runtime$async_job_service_submit(
    job_type = "publication_date_backfill",
    request_payload = list(dry_run = FALSE),
    job_id = "job-maint"
  )
  expect_equal(created_job$queue_name, "maintenance")
  expect_equal(created_job$priority, 50L)

  # llm_generation (interactive) with no explicit queue/priority.
  runtime$async_job_service_submit(
    job_type = "llm_generation",
    request_payload = list(cluster = 1L),
    job_id = "job-llm"
  )
  expect_equal(created_job$queue_name, "default")
  expect_equal(created_job$priority, 10L)
})

test_that("async_job_service_submit still honors explicit queue + priority overrides", {
  runtime <- load_async_job_service_runtime()
  created_job <- NULL

  runtime$async_job_repository_create <- function(job, conn = NULL) {
    created_job <<- job
    job$job_id
  }
  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
    tibble::tibble(job_id = job_id, queue_name = created_job$queue_name,
                   priority = created_job$priority)
  }

  runtime$async_job_service_submit(
    job_type = "publication_date_backfill",
    request_payload = list(dry_run = FALSE),
    queue_name = "analysis",
    priority = 5L,
    job_id = "job-explicit"
  )
  expect_equal(created_job$queue_name, "analysis")
  expect_equal(created_job$priority, 5L)
})
