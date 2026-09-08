# functions/async-job-worker-loop.R
#
# Execution and main loop for durable async jobs. Extracted from
# async-job-worker.R to keep both files below the 600-line ceiling.

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

  job_id_str <- if (is.null(job_id) || length(job_id) == 0L) "unknown" else as.character(job_id)
  job_type_str <- if (is.null(job_type) || length(job_type) == 0L) "unknown" else as.character(job_type)
  worker_id_str <- if (is.null(worker_config$worker_id) || length(worker_config$worker_id) == 0L) {
    "unknown"
  } else {
    as.character(worker_config$worker_id)
  }

  state$current_job_claim <- claimed_job
  async_job_worker_set_claim_context(claimed_job, worker_config = worker_config)

  on.exit({
    state$current_job_claim <- NULL
    async_job_worker_clear_claim_context()
  }, add = TRUE)

  start_time <- Sys.time()
  message(sprintf(
    "[async-job] start job_id=%s type=%s worker_id=%s",
    job_id_str,
    job_type_str,
    worker_id_str
  ))

  .async_job_worker_append_event_safe(
    append_event_fn = append_event_fn,
    job_id = job_id,
    event_type = "started",
    event_message = sprintf("Worker %s started %s", worker_id_str, job_type_str)
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
        stop(sprintf("Failed to persist completion for async job %s", job_id_str), call. = FALSE)
      }

      duration_ms <- as.integer(round(as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000))
      message(sprintf(
        "[async-job] completed job_id=%s type=%s duration_ms=%d",
        job_id_str,
        job_type_str,
        duration_ms
      ))

      .async_job_worker_append_event_safe(
        append_event_fn = append_event_fn,
        job_id = job_id,
        event_type = "completed",
        event_message = sprintf("Worker %s completed %s", worker_id_str, job_type_str)
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
                job_id_str,
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
      duration_ms <- as.integer(round(as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000))
      message(sprintf(
        "[async-job] failed job_id=%s type=%s duration_ms=%d error=%s",
        job_id_str,
        job_type_str,
        duration_ms,
        conditionMessage(error)
      ))

      # async_job_transient_error = scheduling condition (snapshot dependency
      # not built yet): fail WITH a retry time, since the claim query only
      # retries failed jobs whose next_attempt_at IS NOT NULL (PR #652).
      transient <- inherits(error, "async_job_transient_error")
      .async_job_worker_fail_safe(
        fail_fn = fail_fn,
        job_id = job_id,
        claim_token = claim_token,
        error_code = if (transient) "TRANSIENT_DEPENDENCY" else "EXECUTION_ERROR",
        error_message = conditionMessage(error),
        next_attempt_at = if (transient) {
          Sys.time() + .async_job_worker_int_env("ASYNC_JOB_TRANSIENT_RETRY_SECONDS", 90L)
        } else {
          NULL
        }
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
#' @param recover_stale_fn Repository stale recovery function.
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

  consecutive_claim_errors <- 0L

  repeat {
    async_job_worker_sync_drain_signal(state, worker_config)

    if (async_job_worker_should_exit(state, worker_config, now = now_fn())) {
      break
    }

    claim_step <- tryCatch(
      {
        recover_stale_fn()

        claimed <- async_job_worker_claim_once(
          state = state,
          worker_config = worker_config,
          claim_fn = claim_fn
        )
        list(ok = TRUE, claimed = claimed)
      },
      error = function(e) {
        list(ok = FALSE, error = e)
      }
    )

    if (!isTRUE(claim_step$ok)) {
      consecutive_claim_errors <- min(consecutive_claim_errors + 1L, 10L)
      backoff <- min(30, max(2, 2 ^ (consecutive_claim_errors - 1L)))
      warning(
        sprintf(
          "[async-worker] Error during recover/claim (consecutive=%d): %s. Backing off for %ds...",
          consecutive_claim_errors,
          conditionMessage(claim_step$error),
          backoff
        ),
        call. = FALSE
      )
      sleep_fn(backoff)
      next
    }

    consecutive_claim_errors <- 0L
    claimed_job <- claim_step$claimed

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
