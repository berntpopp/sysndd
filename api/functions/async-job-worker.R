if (!exists("create_async_job_progress_reporter", mode = "function")) {
  progress_candidates <- c(
    "functions/async-job-progress.R",
    "/app/functions/async-job-progress.R"
  )

  for (path in progress_candidates) {
    if (file.exists(path)) {
      source(path, local = FALSE)
      break
    }
  }
}

if (!exists("async_job_get_handler", mode = "function")) {
  network_layout_handler_candidates <- c(
    "functions/async-job-network-layout-handlers.R",
    "/app/functions/async-job-network-layout-handlers.R"
  )
  for (path in network_layout_handler_candidates) {
    if (file.exists(path)) {
      source(path, local = FALSE)
      break
    }
  }

  omim_apply_candidates <- c(
    "functions/async-job-omim-apply.R",
    "/app/functions/async-job-omim-apply.R"
  )

  for (path in omim_apply_candidates) {
    if (file.exists(path)) {
      source(path, local = FALSE)
      break
    }
  }

  handler_candidates <- c(
    "functions/async-job-handlers.R",
    "/app/functions/async-job-handlers.R"
  )

  for (path in handler_candidates) {
    if (file.exists(path)) {
      source(path, local = FALSE)
      break
    }
  }
}

.async_job_worker_uuid <- function() {
  if (requireNamespace("uuid", quietly = TRUE)) {
    return(uuid::UUIDgenerate())
  }

  paste(
    as.integer(as.numeric(Sys.time())),
    sprintf("%06d", sample.int(999999, 1)),
    sep = "-"
  )
}

.async_job_worker_int_env <- function(name, default) {
  value <- suppressWarnings(as.integer(Sys.getenv(name, default)))
  if (is.na(value)) {
    return(as.integer(default))
  }

  value
}

.async_job_worker_num_env <- function(name, default) {
  value <- suppressWarnings(as.numeric(Sys.getenv(name, default)))
  if (is.na(value)) {
    return(as.numeric(default))
  }

  value
}

.async_job_worker_job_field <- function(claimed_job, field) {
  value <- claimed_job[[field]]

  if (is.null(value) || length(value) == 0) {
    return(NULL)
  }

  if (is.list(value)) {
    return(value[[1]])
  }

  value[[1]]
}

.async_job_worker_encode_result <- function(result) {
  jsonlite::toJSON(
    result,
    auto_unbox = TRUE,
    null = "null",
    dataframe = "rows",
    POSIXt = "ISO8601"
  )
}

.async_job_worker_decode_payload <- function(payload_json) {
  if (is.null(payload_json) || !nzchar(payload_json)) {
    return(list())
  }

  jsonlite::fromJSON(payload_json, simplifyVector = TRUE)
}

.async_job_worker_fail_safe <- function(
  fail_fn,
  job_id,
  claim_token,
  error_code,
  error_message
) {
  tryCatch(
    {
      fail_fn(
        job_id = job_id,
        error_code = error_code,
        error_message = error_message,
        claim_token = claim_token
      )
    },
    error = function(error) {
      warning(
        sprintf(
          "Failed to persist async job failure for job %s: %s",
          job_id,
          conditionMessage(error)
        ),
        call. = FALSE
      )
      0L
    }
  )
}

.async_job_worker_append_event_safe <- function(
  append_event_fn,
  job_id,
  event_type,
  event_message = NULL,
  event_payload = NULL
) {
  tryCatch(
    {
      append_event_fn(
        job_id = job_id,
        event_type = event_type,
        event_message = event_message,
        event_payload = event_payload
      )
    },
    error = function(error) {
      warning(
        sprintf(
          "Failed to append async job event '%s' for job %s: %s",
          event_type,
          job_id,
          conditionMessage(error)
        ),
        call. = FALSE
      )
      0L
    }
  )
}

#' Build durable async worker configuration from environment variables
#'
#' @return Named list of worker runtime settings.
#' @export
async_job_worker_config_from_env <- function() {
  hostname <- Sys.info()[["nodename"]]
  hostname <- if (is.null(hostname) || !nzchar(hostname)) "unknown-host" else hostname

  queues <- trimws(strsplit(Sys.getenv("ASYNC_JOB_QUEUES", "default"), ",", fixed = TRUE)[[1]])
  queues <- queues[nzchar(queues)]
  if (length(queues) == 0) {
    queues <- "default"
  }

  list(
    worker_id = sprintf("%s:%s", hostname, .async_job_worker_uuid()),
    hostname = hostname,
    lease_seconds = max(1L, .async_job_worker_int_env("ASYNC_JOB_LEASE_SECONDS", "60")),
    job_run_lease_seconds = max(1L, .async_job_worker_int_env("ASYNC_JOB_RUN_LEASE_SECONDS", "900")),
    idle_sleep_seconds = max(0, .async_job_worker_num_env("ASYNC_JOB_IDLE_SLEEP_SECONDS", "2")),
    max_jobs_per_worker = max(1L, .async_job_worker_int_env("MAX_JOBS_PER_WORKER", "50")),
    max_worker_lifetime_seconds = max(1L, .async_job_worker_int_env("MAX_WORKER_LIFETIME", "3600")),
    queues = queues,
    drain_file = Sys.getenv("ASYNC_JOB_DRAIN_FILE", "/tmp/sysndd_async_worker_drain")
  )
}

.async_job_worker_lease_seconds <- function(worker_config) {
  run_lease <- suppressWarnings(as.integer(worker_config$job_run_lease_seconds))
  default_lease <- suppressWarnings(as.integer(worker_config$lease_seconds))

  if (length(default_lease) != 1L || is.na(default_lease) || default_lease < 1L) {
    default_lease <- 60L
  }

  if (length(run_lease) != 1L || is.na(run_lease) || run_lease < 1L) {
    return(default_lease)
  }

  max(default_lease, run_lease)
}

#' Create mutable state for a durable async worker process
#'
#' @param started_at POSIXct worker start time.
#'
#' @return Environment tracking runtime state.
#' @export
async_job_worker_state <- function(started_at = Sys.time()) {
  state <- new.env(parent = emptyenv())
  state$started_at <- started_at
  state$jobs_processed <- 0L
  state$shutdown_requested <- FALSE
  state$draining <- FALSE
  state$current_job_claim <- NULL
  state
}

#' Request graceful drain for the current worker process
#'
#' @param state Worker state environment.
#' @param shutdown Logical; also set shutdown flag.
#'
#' @return Invisibly returns state.
#' @export
async_job_worker_request_drain <- function(state, shutdown = FALSE) {
  state$draining <- TRUE
  if (isTRUE(shutdown)) {
    state$shutdown_requested <- TRUE
  }

  invisible(state)
}

#' Determine whether the worker should stop before claiming more jobs
#'
#' @param state Worker state environment.
#' @param worker_config Named worker configuration list.
#' @param now Current POSIXct timestamp.
#'
#' @return Logical.
#' @export
async_job_worker_should_exit <- function(state, worker_config, now = Sys.time()) {
  lifetime_seconds <- as.numeric(difftime(now, state$started_at, units = "secs"))
  lifetime_exceeded <- lifetime_seconds >= worker_config$max_worker_lifetime_seconds
  jobs_exceeded <- state$jobs_processed >= worker_config$max_jobs_per_worker
  idle_only <- is.null(state$current_job_claim)

  isTRUE(state$shutdown_requested) ||
    (((isTRUE(state$draining) || lifetime_exceeded || jobs_exceeded) && idle_only))
}

#' Claim one job for this worker if claims are allowed
#'
#' @param state Worker state environment.
#' @param worker_config Named worker configuration list.
#' @param claim_fn Repository claim function.
#'
#' @return Claimed job tibble or NULL when no claim is made.
#' @export
async_job_worker_claim_once <- function(
  state,
  worker_config,
  claim_fn = async_job_repository_claim_next
) {
  if (isTRUE(state$draining) || isTRUE(state$shutdown_requested)) {
    return(NULL)
  }

  claimed <- claim_fn(
    worker_id = worker_config$worker_id,
    worker_hostname = worker_config$hostname,
    worker_pid = as.integer(Sys.getpid()),
    lease_seconds = worker_config$lease_seconds,
    queues = worker_config$queues
  )

  if (is.null(claimed) || nrow(claimed) == 0) {
    return(NULL)
  }

  claimed
}

async_job_worker_sync_drain_signal <- function(state, worker_config) {
  drain_file <- worker_config$drain_file

  if (!is.null(drain_file) && nzchar(drain_file) && file.exists(drain_file)) {
    async_job_worker_request_drain(state, shutdown = TRUE)
  }

  invisible(state)
}

#' Heartbeat the currently running claimed job
#'
#' @param claimed_job Claimed job row.
#' @param worker_config Named worker configuration list.
#' @param heartbeat_fn Repository heartbeat function.
#'
#' @return Integer affected rows.
#' @export
async_job_worker_heartbeat <- function(
  claimed_job,
  worker_config,
  heartbeat_fn = async_job_repository_heartbeat
) {
  heartbeat_fn(
    job_id = .async_job_worker_job_field(claimed_job, "job_id"),
    lease_seconds = .async_job_worker_lease_seconds(worker_config),
    claim_token = .async_job_worker_job_field(claimed_job, "claim_token")
  )
}

#' Release worker-local runtime state for the current process
#'
#' @param state Worker state environment.
#'
#' @return Invisibly returns state.
#' @export
async_job_worker_release_all <- function(state) {
  state$current_job_claim <- NULL
  async_job_worker_clear_claim_context()
  invisible(state)
}

#' Execute one claimed durable async job
#'
#' @param claimed_job Claimed job row.
#' @param state Worker state environment.
#' @param worker_config Named worker configuration list.
#' @param registry Handler registry.
#' @param append_event_fn Repository event writer.
#' @param complete_fn Repository completion writer.
#' @param fail_fn Repository failure writer.
#' @param heartbeat_fn Repository heartbeat writer.
#'
#' @return Invisibly returns TRUE on success, FALSE on failure.
#' @export
async_job_worker_run_claimed_job <- function(
  claimed_job,
  state,
  worker_config,
  registry = async_job_handler_registry,
  append_event_fn = async_job_repository_append_event,
  complete_fn = async_job_repository_complete,
  fail_fn = async_job_repository_fail,
  heartbeat_fn = async_job_repository_heartbeat
) {
  job_id <- .async_job_worker_job_field(claimed_job, "job_id")
  job_type <- .async_job_worker_job_field(claimed_job, "job_type")
  claim_token <- .async_job_worker_job_field(claimed_job, "claim_token")
  payload_json <- .async_job_worker_job_field(claimed_job, "request_payload_json")

  state$current_job_claim <- claimed_job
  async_job_worker_set_claim_context(claimed_job, worker_config = worker_config)

  on.exit({
    state$current_job_claim <- NULL
    async_job_worker_clear_claim_context()
  }, add = TRUE)

  .async_job_worker_append_event_safe(
    append_event_fn = append_event_fn,
    job_id = job_id,
    event_type = "started",
    event_message = sprintf("Worker %s started %s", worker_config$worker_id, job_type)
  )

  tryCatch(
    {
      handler <- async_job_get_handler(job_type, registry = registry)
      payload <- .async_job_worker_decode_payload(payload_json)

      async_job_worker_heartbeat(
        claimed_job = claimed_job,
        worker_config = worker_config,
        heartbeat_fn = heartbeat_fn
      )

      # Zero the per-request external-time accumulator (#344) at the START of
      # each job, mirroring the API preroute hook. Without this the accumulator
      # is never reset in the worker, so external time accrues monotonically
      # across the worker's lifetime; once it crosses
      # EXTERNAL_PROXY_REQUEST_MAX_SECONDS every subsequent external call in
      # every job short-circuits to a degraded 503 (request_budget_exceeded).
      # That is what made the PubtatorNDD enrichment refresh fail at the
      # corpus-size fetch after the worker had already run external-heavy jobs.
      if (exists("external_proxy_request_reset", mode = "function")) {
        external_proxy_request_reset()
      }

      result <- handler$run(
        job = claimed_job,
        payload = payload,
        state = state,
        worker_config = worker_config
      )

      completed_rows <- complete_fn(
        job_id = job_id,
        result_json = .async_job_worker_encode_result(result),
        claim_token = claim_token
      )

      if (length(completed_rows) != 1L || is.na(completed_rows) || completed_rows < 1L) {
        stop(sprintf("Failed to persist completion for async job %s", job_id), call. = FALSE)
      }

      .async_job_worker_append_event_safe(
        append_event_fn = append_event_fn,
        job_id = job_id,
        event_type = "completed",
        event_message = sprintf("Worker %s completed %s", worker_config$worker_id, job_type)
      )

      if (is.function(handler$after_success)) {
        tryCatch(
          {
            handler$after_success(
              result = result,
              job = claimed_job,
              payload = payload,
              state = state,
              worker_config = worker_config
            )
          },
          error = function(error) {
            .async_job_worker_append_event_safe(
              append_event_fn = append_event_fn,
              job_id = job_id,
              event_type = "post_completion_failed",
              event_message = conditionMessage(error)
            )
            warning(
              sprintf(
                "Async post-completion hook failed for job %s: %s",
                job_id,
                conditionMessage(error)
              ),
              call. = FALSE
            )
          }
        )
      }

      invisible(TRUE)
    },
    error = function(error) {
      .async_job_worker_fail_safe(
        fail_fn = fail_fn,
        job_id = job_id,
        claim_token = claim_token,
        error_code = "EXECUTION_ERROR",
        error_message = conditionMessage(error)
      )

      .async_job_worker_append_event_safe(
        append_event_fn = append_event_fn,
        job_id = job_id,
        event_type = "failed",
        event_message = conditionMessage(error)
      )

      invisible(FALSE)
    }
  )
}

#' Run the durable async worker loop
#'
#' @param worker_config Named worker configuration list.
#' @param state Worker state environment.
#' @param registry Handler registry.
#' @param claim_fn Repository claim function.
#' @param sleep_fn Sleep function used when idle.
#' @param now_fn Clock function used for lifetime checks.
#'
#' @return Invisibly returns worker state on exit.
#' @export
async_job_worker_main <- function(
  worker_config = async_job_worker_config_from_env(),
  state = async_job_worker_state(),
  registry = async_job_handler_registry,
  claim_fn = async_job_repository_claim_next,
  recover_stale_fn = async_job_repository_recover_stale,
  sleep_fn = Sys.sleep,
  now_fn = Sys.time
) {
  on.exit(async_job_worker_release_all(state), add = TRUE)

  repeat {
    async_job_worker_sync_drain_signal(state, worker_config)

    if (async_job_worker_should_exit(state, worker_config, now = now_fn())) {
      break
    }

    recover_stale_fn()

    claimed_job <- async_job_worker_claim_once(
      state = state,
      worker_config = worker_config,
      claim_fn = claim_fn
    )

    if (is.null(claimed_job)) {
      sleep_fn(worker_config$idle_sleep_seconds)
      next
    }

    async_job_worker_run_claimed_job(
      claimed_job = claimed_job,
      state = state,
      worker_config = worker_config,
      registry = registry
    )

    state$jobs_processed <- state$jobs_processed + 1L
  }

  invisible(state)
}
