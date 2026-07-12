# functions/pubtatornidd-nightly.R
#
# Orchestrator for the nightly PubtatorNDD refresh.
#
# A dumb cron sidecar (see docker-compose.yml `pubtatornidd-cron` +
# scripts/pubtatornidd_nightly_enqueue.R) enqueues one durable
# `pubtatornidd_nightly` job each night. The durable worker claims it and runs
# this orchestrator, which:
#   1. single-flights via a MySQL advisory lock (GET_LOCK, non-blocking),
#   2. incrementally fetches new publications for the standing NDD query
#      (reusing pubtator_db_update_async; soft page-watermark, <=3 req/s),
#   3. refreshes the per-gene enrichment snapshot,
#   4. refreshes the precomputed gene-summary table when that layer exists
#      (Sprint D extension point; guarded so this file works without it),
#   5. returns a structured run summary (persisted in the job result_json).
#
# All heavy logic, retries, and history live in the durable worker; the sidecar
# only enqueues. The orchestrator is defensive: a per-step failure is captured
# and surfaced (the handler marks the job failed so operators see it), never an
# uncaught crash of the worker loop.

#' Advisory-lock name that serializes nightly PubtatorNDD runs.
#' @keywords internal
.PUBTATORNDD_NIGHTLY_LOCK <- "pubtatornidd_nightly"

#' Try to acquire the nightly single-flight lock (non-blocking)
#'
#' Mirrors the NDDScore import-lock pattern. `GET_LOCK(..., 0)` returns
#' immediately: 1 if acquired, 0 if another connection holds it. The lock auto-
#' releases when the holding connection closes, so a crashed worker cannot
#' deadlock the nightly schedule.
#'
#' @param conn A DBI connection.
#' @return TRUE if the lock was acquired, FALSE otherwise.
#' @export
pubtatornidd_nightly_try_lock <- function(conn) {
  result <- DBI::dbGetQuery(
    conn,
    "SELECT GET_LOCK(?, 0) AS acquired",
    params = unname(list(.PUBTATORNDD_NIGHTLY_LOCK))
  )
  identical(as.integer(result$acquired[[1]]), 1L)
}

#' Release the nightly single-flight lock
#'
#' @param conn A DBI connection (the one that acquired the lock).
#' @return TRUE if the lock was held and released, FALSE otherwise.
#' @export
pubtatornidd_nightly_release_lock <- function(conn) {
  result <- DBI::dbGetQuery(
    conn,
    "SELECT RELEASE_LOCK(?) AS released",
    params = unname(list(.PUBTATORNDD_NIGHTLY_LOCK))
  )
  identical(as.integer(result$released[[1]]), 1L)
}

#' Read the most-recently-cached PubtatorNDD standing query text
#'
#' @param query_fn Query function (injectable for tests). Default
#'   `db_execute_query`.
#' @return The query_text string, or NA when no query is cached.
#' @export
pubtatornidd_nightly_cached_query <- function(query_fn = db_execute_query) {
  rows <- tryCatch(
    query_fn(
      "SELECT query_text
       FROM pubtator_query_cache
       ORDER BY query_date DESC, query_id DESC
       LIMIT 1"
    ),
    error = function(e) NULL
  )
  if (is.null(rows) || nrow(rows) == 0) {
    return(NA_character_)
  }
  as.character(rows$query_text[[1]])
}

#' Resolve which standing query the nightly run should refresh
#'
#' Precedence: an explicit job-payload query, then the
#' `PUBTATORNDD_NIGHTLY_QUERY` env override, then the most-recently-cached query
#' in `pubtator_query_cache`. Returns NA when none is available (the run then
#' reports `no_query` rather than guessing).
#'
#' Pure given `cached_query_fn` (no IO of its own) so it is unit-testable.
#'
#' @param requested_query Query from the job payload (or NULL/"").
#' @param env_query Query from the environment override (or "").
#' @param cached_query_fn Function returning the cached query text (or NA).
#' @return The resolved query string, or NA_character_.
#' @export
pubtatornidd_nightly_resolve_query <- function(requested_query = NULL,
                                               env_query = "",
                                               cached_query_fn = pubtatornidd_nightly_cached_query) {
  if (!is.null(requested_query) && length(requested_query) == 1 &&
        !is.na(requested_query) && nzchar(requested_query)) {
    return(as.character(requested_query))
  }
  if (length(env_query) == 1 && !is.na(env_query) && nzchar(env_query)) {
    return(as.character(env_query))
  }
  cached <- cached_query_fn()
  if (length(cached) == 1 && !is.na(cached) && nzchar(cached)) {
    return(as.character(cached))
  }
  NA_character_
}

#' Read a scalar from a parsed job payload list (NULL-safe)
#' @keywords internal
.pubtatornidd_payload_scalar <- function(payload, key, default = NULL) {
  if (is.null(payload) || is.null(payload[[key]])) {
    return(default)
  }
  value <- payload[[key]]
  if (length(value) == 0) {
    return(default)
  }
  value[[1]]
}

#' Run the nightly PubtatorNDD refresh orchestrator
#'
#' @param pool_obj The global database pool.
#' @param progress_fn Optional progress reporter.
#' @param payload Parsed job payload (may carry `query` / `max_pages`).
#' @return Structured run-summary list. `skipped = TRUE` for the benign
#'   locked/no-query cases (still a job success); `success = FALSE` when a
#'   refresh step failed (the handler turns that into a failed job).
#' @export
pubtatornidd_nightly_run <- function(pool_obj, progress_fn = NULL, payload = list()) {
  report <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress_fn) && is.function(progress_fn)) {
      tryCatch(progress_fn(step, message, current = current, total = total),
               error = function(e) NULL)
    }
  }

  conn <- pool::poolCheckout(pool_obj)
  lock_acquired <- FALSE
  on.exit({
    if (isTRUE(lock_acquired)) {
      tryCatch(pubtatornidd_nightly_release_lock(conn), error = function(e) NULL)
    }
    pool::poolReturn(conn)
  }, add = TRUE)

  report("lock", "Acquiring nightly single-flight lock...", current = 0, total = 1)
  lock_acquired <- pubtatornidd_nightly_try_lock(conn)
  if (!isTRUE(lock_acquired)) {
    return(list(
      status = "completed", success = TRUE, skipped = TRUE, reason = "locked",
      message = "Another PubtatorNDD nightly run is active; skipped this cycle"
    ))
  }

  query <- pubtatornidd_nightly_resolve_query(
    requested_query = .pubtatornidd_payload_scalar(payload, "query"),
    env_query = Sys.getenv("PUBTATORNDD_NIGHTLY_QUERY", "")
  )
  if (is.na(query) || !nzchar(query)) {
    # Benign skip (consistent with the locked case): nothing to refresh, so the
    # job completes successfully. `reason`/`message` make it diagnosable.
    return(list(
      status = "completed", success = TRUE, skipped = TRUE, reason = "no_query",
      message = paste(
        "No PubtatorNDD standing query configured (PUBTATORNDD_NIGHTLY_QUERY)",
        "or cached in pubtator_query_cache; nothing to update"
      )
    ))
  }

  max_pages <- suppressWarnings(as.integer(.pubtatornidd_payload_scalar(
    payload, "max_pages",
    default = as.integer(Sys.getenv("PUBTATORNDD_NIGHTLY_MAX_PAGES", "50"))
  )))
  if (is.na(max_pages) || max_pages <= 0) {
    max_pages <- 50L
  }

  # Step 1: incremental publication update (soft page-watermark; reuses the
  # existing fetch path which only fetches pages not already cached).
  report("update", sprintf("Updating publications for query '%s'...", query),
         current = 0, total = 1)
  # pubtator_db_update_async resolves DB creds at run time (#535 S2b); no
  # in-process db_config marshaling needed.
  update_res <- tryCatch(
    pubtator_db_update_async(
      query = query,
      max_pages = max_pages,
      do_full_update = FALSE,
      progress_fn = progress_fn
    ),
    error = function(e) list(success = FALSE, message = conditionMessage(e))
  )

  # Step 2: refresh the per-gene enrichment snapshot from the updated cache.
  report("enrichment", "Refreshing enrichment snapshot...", current = 0, total = 1)
  enrich_res <- tryCatch(
    pubtator_enrichment_refresh_run(conn = conn, progress_fn = progress_fn,
                                    refreshed_by = NULL),
    error = function(e) list(success = FALSE, message = conditionMessage(e))
  )

  # Step 3 (Sprint D extension point): refresh the precomputed gene-summary
  # table when that layer is present. Guarded so this file works standalone.
  summary_res <- NULL
  if (exists("pubtator_gene_summary_refresh", mode = "function")) {
    report("summary", "Refreshing precomputed gene summary...", current = 0, total = 1)
    summary_res <- tryCatch(
      pubtator_gene_summary_refresh(conn = conn),
      error = function(e) list(success = FALSE, message = conditionMessage(e))
    )
  }

  update_ok <- isTRUE(update_res$success)
  enrich_ok <- isTRUE(enrich_res$success)
  summary_ok <- is.null(summary_res) || isTRUE(summary_res$success)
  overall_ok <- update_ok && enrich_ok && summary_ok

  report("complete", "PubtatorNDD nightly refresh complete", current = 1, total = 1)

  list(
    status = "completed",
    success = overall_ok,
    skipped = FALSE,
    query = query,
    max_pages = max_pages,
    update = list(
      success = update_ok,
      publications_count = .pubtatornidd_payload_scalar(update_res, "publications_count"),
      pages_cached = .pubtatornidd_payload_scalar(update_res, "pages_cached"),
      message = .pubtatornidd_payload_scalar(update_res, "message")
    ),
    enrichment = list(
      success = enrich_ok,
      genes_scored = .pubtatornidd_payload_scalar(enrich_res, "genes_scored"),
      message = .pubtatornidd_payload_scalar(enrich_res, "message")
    ),
    summary = summary_res,
    message = sprintf(
      "PubtatorNDD nightly: update=%s, enrichment=%s%s",
      update_ok, enrich_ok,
      if (is.null(summary_res)) "" else sprintf(", summary=%s", summary_ok)
    )
  )
}

#' Worker entry point for the `pubtatornidd_nightly` durable job
#'
#' Thin adapter the async handler delegates to (mirrors
#' `pubtator_enrichment_job_run`): resolves the global pool + config, runs the
#' orchestrator, and turns a real (non-skip) refresh failure into an error so the
#' job is marked failed. Benign skips (lock held by a concurrent run, or no
#' standing query) complete successfully.
#'
#' @param job The claimed job row (`job_id` used for progress).
#' @param payload Parsed job payload.
#' @param progress_reporter_fn Factory returning a `progress(step, message, ...)`
#'   function for the job.
#' @return The orchestrator result list.
#' @export
pubtatornidd_nightly_job_run <- function(job, payload, progress_reporter_fn) {
  progress <- progress_reporter_fn(job$job_id[[1]])
  progress("init", "Starting PubtatorNDD nightly refresh...", current = 0, total = 1)

  if (!base::exists("pool", envir = .GlobalEnv, inherits = FALSE)) {
    stop("PubtatorNDD nightly refresh requires the global database pool", call. = FALSE)
  }
  if (!base::exists("dw", envir = .GlobalEnv, inherits = FALSE)) {
    stop("PubtatorNDD nightly refresh requires the global config (dw)", call. = FALSE)
  }

  result <- pubtatornidd_nightly_run(
    pool_obj = base::get("pool", envir = .GlobalEnv, inherits = FALSE),
    progress_fn = progress,
    payload = payload
  )

  # Benign skips complete successfully; only a non-skip refresh failure is
  # surfaced as a job failure (observable in job history / alerting).
  if (!isTRUE(result$skipped) && !isTRUE(result$success)) {
    stop(result$message %||% "PubtatorNDD nightly refresh failed", call. = FALSE)
  }

  result
}

#' Bootstrap the PubtatorNDD enrichment snapshot on startup if missing (#421)
#'
#' If no current `pubtator_corpus_stats` snapshot exists, idempotently enqueue a
#' `pubtatornidd_nightly` job so a fresh deploy populates enrichment (and the
#' gene-summary table) without waiting for the nightly cron. Dedup-safe: when a
#' current snapshot already exists this is a no-op, and `async_job_service_submit`
#' dedups by request_hash so a restart while a bootstrap job is queued does not
#' double-enqueue. Never throws (callable directly in API startup).
#'
#' @param query_fn Query function (injectable for tests). Default
#'   `db_execute_query`.
#' @param submit_fn Job-submit function (injectable for tests). Default
#'   `async_job_service_submit`.
#' @param now Clock injection point (default `Sys.time()`); the stagger base.
#' @return Invisibly TRUE when a job was enqueued, FALSE otherwise.
#' @export
pubtatornidd_bootstrap_enrichment <- function(query_fn = db_execute_query,
                                              submit_fn = async_job_service_submit,
                                              now = Sys.time()) {
  rows <- tryCatch(
    query_fn("SELECT COUNT(*) AS n FROM pubtator_corpus_stats WHERE is_current = 1"),
    error = function(e) NULL
  )
  has_current <- !is.null(rows) && nrow(rows) > 0 &&
    !is.na(rows$n[[1]]) && as.integer(rows$n[[1]]) > 0L
  if (isTRUE(has_current)) {
    return(invisible(FALSE))
  }

  # Decouple the nightly from the snapshot bootstrap so they are not
  # claim-eligible at the same instant on a fresh start (#447). Default 240s;
  # `0` disables. Parsed inline to avoid a hard dependency on the snapshot
  # service file being sourced first.
  stagger_raw <- trimws(Sys.getenv("PUBTATORNIDD_BOOTSTRAP_STAGGER_SECONDS", ""))
  stagger_seconds <- suppressWarnings(as.integer(stagger_raw))
  if (!nzchar(stagger_raw) || is.na(stagger_seconds) || stagger_seconds < 0L) {
    stagger_seconds <- 240L
  }

  submitted <- tryCatch(
    submit_fn(
      job_type = "pubtatornidd_nightly",
      request_payload = list(trigger = "startup_bootstrap"),
      scheduled_at = now + stagger_seconds
    ),
    error = function(e) {
      message(sprintf("[pubtatornidd-bootstrap] enqueue failed: %s",
                      conditionMessage(e)))
      NULL
    }
  )
  if (!is.null(submitted)) {
    message(paste(
      "[pubtatornidd-bootstrap] no current enrichment snapshot;",
      "enqueued nightly refresh to populate it"
    ))
  }
  invisible(!is.null(submitted))
}
