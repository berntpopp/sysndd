library(testthat)
library(withr)
library(jsonlite)
library(tibble)

async_job_worker_runtime_paths <- function() {
  api_dir <- get_api_dir()
  c(
    file.path(api_dir, "functions", "async-job-progress.R"),
    file.path(api_dir, "functions", "async-job-handlers.R"),
    file.path(api_dir, "functions", "async-job-worker.R"),
    file.path(api_dir, "functions", "job-progress.R")
  )
}

load_async_job_worker_runtime <- function() {
  runtime_env <- new.env(parent = globalenv())
  runtime_paths <- async_job_worker_runtime_paths()

  missing <- runtime_paths[!file.exists(runtime_paths)]
  if (length(missing) > 0) {
    stop(
      "async-job worker runtime files are missing: ",
      paste(basename(missing), collapse = ", ")
    )
  }

  for (path in runtime_paths) {
    sys.source(path, envir = runtime_env)
  }

  runtime_env
}

test_that("async_job_worker_config_from_env reads bounded worker settings", {
  runtime <- load_async_job_worker_runtime()

  withr::local_envvar(c(
    ASYNC_JOB_LEASE_SECONDS = "75",
    ASYNC_JOB_IDLE_SLEEP_SECONDS = "1.5",
    MAX_JOBS_PER_WORKER = "7",
    MAX_WORKER_LIFETIME = "900",
    ASYNC_JOB_QUEUES = "default,bulk",
    ASYNC_JOB_DRAIN_FILE = "/tmp/sysndd-test-drain"
  ))

  config <- runtime$async_job_worker_config_from_env()

  expect_true(is.character(config$worker_id))
  expect_true(nzchar(config$worker_id))
  expect_true(is.character(config$hostname))
  expect_true(nzchar(config$hostname))
  expect_equal(config$lease_seconds, 75L)
  expect_equal(config$idle_sleep_seconds, 1.5)
  expect_equal(config$max_jobs_per_worker, 7L)
  expect_equal(config$max_worker_lifetime_seconds, 900L)
  expect_equal(config$queues, c("default", "bulk"))
  expect_equal(config$drain_file, "/tmp/sysndd-test-drain")
})

test_that("create_async_job_progress_reporter updates durable row progress and throttles interim writes", {
  runtime <- load_async_job_worker_runtime()
  calls <- list()
  heartbeat_calls <- list()

  runtime$async_job_repository_update_progress <- function(job_id, progress_pct = NULL, progress_message = NULL, claim_token, conn = NULL) { # nolint: line_length_linter
    calls[[length(calls) + 1L]] <<- list(
      job_id = job_id,
      progress_pct = progress_pct,
      progress_message = progress_message,
      claim_token = claim_token
    )
    1L
  }
  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
    heartbeat_calls[[length(heartbeat_calls) + 1L]] <<- list(
      job_id = job_id,
      lease_seconds = lease_seconds,
      claim_token = claim_token
    )
    1L
  }

  runtime$async_job_worker_set_claim_context(
    list(
      job_id = "job-progress",
      claim_token = "claim-progress"
    ),
    worker_config = list(lease_seconds = 90L)
  )
  on.exit(runtime$async_job_worker_clear_claim_context(), add = TRUE)

  reporter <- runtime$create_async_job_progress_reporter(
    "job-progress",
    throttle_seconds = 60
  )

  reporter("download", "Downloading source", current = 1, total = 4)
  reporter("download", "Throttled update", current = 2, total = 4)
  reporter("download", "Download complete", current = 4, total = 4)

  expect_length(calls, 2L)
  expect_equal(calls[[1]]$job_id, "job-progress")
  expect_equal(calls[[1]]$claim_token, "claim-progress")
  expect_equal(calls[[1]]$progress_pct, 25)
  expect_equal(calls[[1]]$progress_message, "Downloading source")
  expect_equal(calls[[2]]$progress_pct, 100)
  expect_equal(calls[[2]]$progress_message, "Download complete")
  expect_length(heartbeat_calls, 2L)
  expect_equal(heartbeat_calls[[1]]$lease_seconds, 90L)
  expect_equal(heartbeat_calls[[1]]$claim_token, "claim-progress")
})

test_that("async_job_worker_claim_once skips claims during drain and uses repository claim API otherwise", {
  runtime <- load_async_job_worker_runtime()
  state <- runtime$async_job_worker_state()

  worker_config <- list(
    worker_id = "worker-a",
    hostname = "host-a",
    lease_seconds = 60L,
    idle_sleep_seconds = 0.1,
    max_jobs_per_worker = 5L,
    max_worker_lifetime_seconds = 600L,
    queues = c("default", "bulk")
  )

  state$draining <- TRUE
  expect_null(runtime$async_job_worker_claim_once(
    state = state,
    worker_config = worker_config,
    claim_fn = function(...) {
      stop("claim should not run while draining")
    }
  ))

  claim_args <- NULL
  state$draining <- FALSE
  claimed <- runtime$async_job_worker_claim_once(
    state = state,
    worker_config = worker_config,
    claim_fn = function(worker_id, worker_hostname, worker_pid, lease_seconds, queues, conn = NULL) {
      claim_args <<- list(
        worker_id = worker_id,
        worker_hostname = worker_hostname,
        worker_pid = worker_pid,
        lease_seconds = lease_seconds,
        queues = queues
      )
      tibble(
        job_id = "job-claim",
        job_type = "hgnc_update",
        request_payload_json = "{}",
        claim_token = "claim-claim"
      )
    }
  )

  expect_equal(claimed$job_id[[1]], "job-claim")
  expect_equal(claim_args$worker_id, "worker-a")
  expect_equal(claim_args$worker_hostname, "host-a")
  expect_type(claim_args$worker_pid, "integer")
  expect_equal(claim_args$lease_seconds, 60L)
  expect_equal(claim_args$queues, c("default", "bulk"))
})

test_that("async_job_worker_heartbeat extends the lease with the current claim token", {
  runtime <- load_async_job_worker_runtime()
  heartbeat_call <- NULL

  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
    heartbeat_call <<- list(
      job_id = job_id,
      lease_seconds = lease_seconds,
      claim_token = claim_token
    )
    1L
  }

  rows <- runtime$async_job_worker_heartbeat(
    claimed_job = tibble(job_id = "job-heartbeat", claim_token = "claim-heartbeat"),
    worker_config = list(lease_seconds = 45L)
  )

  expect_equal(rows, 1L)
  expect_equal(heartbeat_call$job_id, "job-heartbeat")
  expect_equal(heartbeat_call$lease_seconds, 45L)
  expect_equal(heartbeat_call$claim_token, "claim-heartbeat")
})

test_that("async_job_worker_run_claimed_job dispatches the matching handler and persists completion", {
  runtime <- load_async_job_worker_runtime()
  events <- character(0)
  completed <- NULL
  call_order <- character(0)

  runtime$async_job_repository_append_event <- function(job_id, event_type, event_message = NULL, event_payload = NULL, conn = NULL) { # nolint: line_length_linter
    events <<- c(events, paste(job_id, event_type, sep = ":"))
    1L
  }
  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
    1L
  }
  runtime$async_job_repository_complete <- function(job_id, result_json, claim_token, conn = NULL) {
    call_order <<- c(call_order, "complete")
    completed <<- list(
      job_id = job_id,
      result = jsonlite::fromJSON(result_json, simplifyVector = TRUE),
      claim_token = claim_token
    )
    1L
  }
  runtime$async_job_repository_fail <- function(...) {
    stop("failure path should not be used in this test")
  }

  claimed <- tibble(
    job_id = "job-run",
    job_type = "hgnc_update",
    request_payload_json = '{"refresh":true}',
    claim_token = "claim-run"
  )

  registry <- list(
    hgnc_update = list(
      cancel_mode = "non_interruptible",
      run = function(job, payload, state, worker_config) {
        reporter <- runtime$create_async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
        reporter("execute", "Running handler", current = 1, total = 1)
        list(ok = TRUE, refresh = payload$refresh)
      },
      after_success = function(result, job, payload, state, worker_config) {
        call_order <<- c(call_order, "after_success")
        events <<- c(events, paste(job$job_id[[1]], "after_success", sep = ":"))
        invisible(result)
      }
    )
  )

  progress_calls <- list()
  runtime$async_job_repository_update_progress <- function(job_id, progress_pct = NULL, progress_message = NULL, claim_token, conn = NULL) { # nolint: line_length_linter
    progress_calls[[length(progress_calls) + 1L]] <<- list(
      job_id = job_id,
      progress_pct = progress_pct,
      progress_message = progress_message,
      claim_token = claim_token
    )
    1L
  }

  runtime$async_job_worker_run_claimed_job(
    claimed_job = claimed,
    state = runtime$async_job_worker_state(),
    worker_config = list(worker_id = "worker-run", lease_seconds = 60L),
    registry = registry
  )

  expect_equal(completed$job_id, "job-run")
  expect_equal(completed$claim_token, "claim-run")
  expect_true(isTRUE(completed$result$ok))
  expect_true(isTRUE(completed$result$refresh))
  expect_true("job-run:started" %in% events)
  expect_true("job-run:completed" %in% events)
  expect_true("job-run:after_success" %in% events)
  expect_equal(progress_calls[[1]]$progress_pct, 100)
  expect_equal(progress_calls[[1]]$claim_token, "claim-run")
  expect_equal(call_order, c("complete", "after_success"))
})

test_that("async_job_worker_run_claimed_job treats event writes as best-effort", {
  runtime <- load_async_job_worker_runtime()
  completed <- NULL
  fail_calls <- list()

  runtime$async_job_repository_append_event <- function(...) {
    stop("event store unavailable")
  }
  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
    1L
  }
  runtime$async_job_repository_complete <- function(job_id, result_json, claim_token, conn = NULL) {
    completed <<- list(
      job_id = job_id,
      result = jsonlite::fromJSON(result_json, simplifyVector = TRUE),
      claim_token = claim_token
    )
    1L
  }
  runtime$async_job_repository_fail <- function(job_id, error_code, error_message, claim_token, next_attempt_at = NULL, conn = NULL) { # nolint: line_length_linter
    fail_calls[[length(fail_calls) + 1L]] <<- list(
      job_id = job_id,
      error_code = error_code,
      error_message = error_message,
      claim_token = claim_token
    )
    1L
  }

  result <- runtime$async_job_worker_run_claimed_job(
    claimed_job = tibble(
      job_id = "job-safe-events",
      job_type = "hgnc_update",
      request_payload_json = "{}",
      claim_token = "claim-safe-events"
    ),
    state = runtime$async_job_worker_state(),
    worker_config = list(worker_id = "worker-safe", lease_seconds = 60L),
    registry = list(
      hgnc_update = list(
        cancel_mode = "non_interruptible",
        run = function(job, payload, state, worker_config) {
          list(ok = TRUE)
        }
      )
    )
  )

  expect_true(isTRUE(result))
  expect_equal(completed$job_id, "job-safe-events")
  expect_equal(completed$claim_token, "claim-safe-events")
  expect_true(isTRUE(completed$result$ok))
  expect_length(fail_calls, 0L)
})

test_that("async_job_worker_run_claimed_job fails malformed job rows instead of crashing", {
  runtime <- load_async_job_worker_runtime()
  fail_calls <- list()
  completed_calls <- 0L

  runtime$async_job_repository_append_event <- function(job_id, event_type, event_message = NULL, event_payload = NULL, conn = NULL) { # nolint: line_length_linter
    1L
  }
  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
    1L
  }
  runtime$async_job_repository_fail <- function(job_id, error_code, error_message, claim_token, next_attempt_at = NULL, conn = NULL) { # nolint: line_length_linter
    fail_calls[[length(fail_calls) + 1L]] <<- list(
      job_id = job_id,
      error_code = error_code,
      error_message = error_message,
      claim_token = claim_token
    )
    1L
  }
  runtime$async_job_repository_complete <- function(job_id, result_json, claim_token, conn = NULL) {
    completed_calls <<- completed_calls + 1L
    1L
  }

  unknown_result <- runtime$async_job_worker_run_claimed_job(
    claimed_job = tibble(
      job_id = "job-unknown-handler",
      job_type = "unknown_job_type",
      request_payload_json = "{}",
      claim_token = "claim-unknown-handler"
    ),
    state = runtime$async_job_worker_state(),
    worker_config = list(worker_id = "worker-malformed", lease_seconds = 60L),
    registry = list()
  )

  invalid_json_result <- runtime$async_job_worker_run_claimed_job(
    claimed_job = tibble(
      job_id = "job-invalid-json",
      job_type = "hgnc_update",
      request_payload_json = "{bad-json",
      claim_token = "claim-invalid-json"
    ),
    state = runtime$async_job_worker_state(),
    worker_config = list(worker_id = "worker-malformed", lease_seconds = 60L),
    registry = list(
      hgnc_update = list(
        cancel_mode = "non_interruptible",
        run = function(job, payload, state, worker_config) list(ok = TRUE)
      )
    )
  )

  expect_false(isTRUE(unknown_result))
  expect_false(isTRUE(invalid_json_result))
  expect_equal(completed_calls, 0L)
  expect_length(fail_calls, 2L)
  expect_equal(fail_calls[[1]]$job_id, "job-unknown-handler")
  expect_match(fail_calls[[1]]$error_message, "No durable async job handler registered")
  expect_equal(fail_calls[[2]]$job_id, "job-invalid-json")
})

test_that("async_job_worker_sync_drain_signal flips the worker into shutdown mode", {
  runtime <- load_async_job_worker_runtime()
  state <- runtime$async_job_worker_state()
  drain_file <- tempfile("async-job-worker-drain-")

  on.exit(unlink(drain_file, force = TRUE), add = TRUE)
  file.create(drain_file)

  runtime$async_job_worker_sync_drain_signal(
    state = state,
    worker_config = list(drain_file = drain_file)
  )

  expect_true(isTRUE(state$draining))
  expect_true(isTRUE(state$shutdown_requested))
})

test_that("worker main exits cleanly when drain is requested or lifetime bounds are reached", {
  runtime <- load_async_job_worker_runtime()

  drain_state <- runtime$async_job_worker_state()
  drain_state$draining <- TRUE
  drain_claims <- 0L

  result_state <- runtime$async_job_worker_main(
    worker_config = list(
      worker_id = "worker-drain",
      hostname = "host-drain",
      lease_seconds = 60L,
      idle_sleep_seconds = 0,
      max_jobs_per_worker = 10L,
      max_worker_lifetime_seconds = 600L,
      queues = "default"
    ),
    state = drain_state,
    registry = list(),
    claim_fn = function(...) {
      drain_claims <<- drain_claims + 1L
      tibble()
    },
    sleep_fn = function(seconds) invisible(seconds),
    now_fn = function() as.POSIXct("2026-04-23 12:00:00", tz = "UTC")
  )

  expect_identical(result_state, drain_state)
  expect_equal(drain_claims, 0L)

  lifetime_state <- runtime$async_job_worker_state(
    started_at = as.POSIXct("2026-04-23 12:00:00", tz = "UTC")
  )
  lifetime_claims <- 0L
  tick_times <- as.POSIXct(
    c("2026-04-23 12:00:00", "2026-04-23 12:00:02"),
    tz = "UTC"
  )
  tick_index <- 0L

  lifetime_result <- runtime$async_job_worker_main(
    worker_config = list(
      worker_id = "worker-life",
      hostname = "host-life",
      lease_seconds = 60L,
      idle_sleep_seconds = 0,
      max_jobs_per_worker = 10L,
      max_worker_lifetime_seconds = 1L,
      queues = "default"
    ),
    state = lifetime_state,
    registry = list(),
    claim_fn = function(...) {
      lifetime_claims <<- lifetime_claims + 1L
      tibble()
    },
    sleep_fn = function(seconds) invisible(seconds),
    now_fn = function() {
      tick_index <<- min(tick_index + 1L, length(tick_times))
      tick_times[[tick_index]]
    }
  )

  expect_identical(lifetime_result, lifetime_state)
  expect_equal(lifetime_claims, 1L)
})
