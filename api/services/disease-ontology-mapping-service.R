# services/disease-ontology-mapping-service.R
#
# Shared submit / status / bootstrap for the disease cross-ontology mapping
# refresh (WP-C). One submit path backs the startup bootstrap (start_sysndd_api.R),
# the Administrator endpoints (endpoints/admin_ontology_mapping_endpoints.R), the
# weekly cron enqueue script (scripts/ontology_mapping_refresh_enqueue.R), and the
# C7 re-trigger after an operator ontology-set refresh. Keep this the single
# source of submission logic.
#
# Mirrors services/analysis-snapshot-refresh-service.R (shared submit + status +
# bootstrap) and functions/pubtatornidd-nightly.R (bootstrap + stagger).

#' Max attempts for a submitted `disease_ontology_mapping_refresh` job.
#'
#' Mirrors the snapshot refresh: a heavy build can outrun its worker lease under
#' startup contention; the stale-lease reaper requeues an expired lease while
#' `attempt_count < max_attempts`, so > 1 makes the bootstrap self-healing.
DISEASE_ONTOLOGY_MAPPING_REFRESH_MAX_ATTEMPTS <- 3L

#' Whether the startup mapping-refresh bootstrap is enabled.
#'
#' Env gate, default enabled. Set
#' `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP=false` to disable.
#' @export
disease_ontology_mapping_bootstrap_enabled <- function() {
  raw <- trimws(Sys.getenv("DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP", "true"))
  if (!nzchar(raw)) {
    return(TRUE)
  }
  tolower(raw) %in% c("true", "1", "yes", "on")
}

#' Seconds to delay the bootstrap's first claim-eligibility (#447 stagger).
#'
#' Default 360s so the mapping-refresh bootstrap does not co-launch with the
#' snapshot (120s) and pubtatornidd (240s) bootstraps. `0` disables staggering.
#' Read at call time so a restart picks up an env change.
#' @export
disease_ontology_mapping_bootstrap_stagger_seconds <- function() {
  raw <- trimws(Sys.getenv("DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_STAGGER_SECONDS", ""))
  if (!nzchar(raw)) {
    return(360L)
  }
  val <- suppressWarnings(as.integer(raw))
  if (is.na(val) || val < 0L) {
    return(360L)
  }
  val
}

#' Whether a successful mapping build already exists.
#'
#' Probes `disease_ontology_mapping_meta` for any `status='success'` row. Fails
#' open to FALSE on a DB error (so the bootstrap still tries to enqueue).
#'
#' @param query_fn Injectable query fn (default `db_execute_query`).
#' @return TRUE when at least one successful build is recorded.
#' @export
disease_ontology_mapping_build_exists <- function(query_fn = db_execute_query) {
  rows <- tryCatch(
    query_fn(
      "SELECT 1 AS present FROM disease_ontology_mapping_meta WHERE status = 'success' LIMIT 1"
    ),
    error = function(e) NULL
  )
  !is.null(rows) && nrow(rows) > 0L
}

#' Submit a `disease_ontology_mapping_refresh` job (shared submit path).
#'
#' Unless `force`, skips submission when a successful build already exists (the
#' bootstrap is idempotent). The async submit dedups by request_hash so a queued
#' or running refresh is reused rather than duplicated.
#'
#' @param force When TRUE, submit even when a successful build exists.
#' @param stagger When TRUE (startup bootstrap only), offset `scheduled_at` by
#'   `stagger_seconds` so it is not claim-eligible at the same instant as the
#'   snapshot/pubtatornidd bootstraps. The operator/admin/cron paths leave this
#'   FALSE so a manual rebuild is never delayed.
#' @param submit_fn Injectable job-submit fn (default `async_job_service_submit`).
#' @param exists_fn Injectable existence probe (default
#'   `disease_ontology_mapping_build_exists`).
#' @param conn Optional DB connection/pool.
#' @param now Clock injection point (default `Sys.time()`); the stagger base.
#' @param stagger_seconds Stagger offset in seconds; NULL resolves the env default.
#' @return list(submitted=, duplicate=, skipped=, job_id=, message=).
#' @export
service_disease_ontology_mapping_submit_refresh <- function(
    force = FALSE,
    stagger = FALSE,
    submit_fn = async_job_service_submit,
    exists_fn = disease_ontology_mapping_build_exists,
    conn = NULL,
    now = Sys.time(),
    stagger_seconds = NULL) {
  force <- isTRUE(force)
  stagger <- isTRUE(stagger)
  if (is.null(stagger_seconds)) {
    stagger_seconds <- disease_ontology_mapping_bootstrap_stagger_seconds()
  }
  stagger_seconds <- as.integer(stagger_seconds)

  # Existence-skip is the STARTUP-BOOTSTRAP idempotency guard only (stagger=TRUE):
  # a fresh deploy enqueues exactly one build and a restart with a build present
  # enqueues nothing. The weekly cron and the admin endpoint (stagger=FALSE) must
  # enqueue even when a build exists — the worker then conditional-GETs and
  # no-ops cheaply if the MONDO release is unchanged, and request_hash dedup
  # prevents overlap while one is still queued/running.
  if (!force && stagger) {
    already <- tryCatch(exists_fn(), error = function(e) FALSE)
    if (isTRUE(already)) {
      return(list(
        submitted = FALSE,
        duplicate = FALSE,
        skipped   = TRUE,
        job_id    = NA_character_,
        message   = "successful mapping build already present"
      ))
    }
  }

  sched <- now
  if (stagger && stagger_seconds > 0L) {
    sched <- now + stagger_seconds
  }

  outcome <- submit_fn(
    job_type        = "disease_ontology_mapping_refresh",
    request_payload = list(force = force),
    queue_name      = "default",
    priority        = 50L,
    max_attempts    = DISEASE_ONTOLOGY_MAPPING_REFRESH_MAX_ATTEMPTS,
    scheduled_at    = sched,
    conn            = conn
  )

  job_id <- tryCatch(as.character(outcome$job$job_id[[1]]), error = function(e) NA_character_)
  duplicate <- isTRUE(outcome$duplicate)

  list(
    submitted = !duplicate,
    duplicate = duplicate,
    skipped   = FALSE,
    job_id    = job_id,
    message   = if (duplicate) {
      "existing queued/running refresh reused"
    } else {
      "refresh job submitted"
    }
  )
}

#' Latest mapping-refresh status (provenance overview).
#'
#' Returns the most-recent `disease_ontology_mapping_meta` rows so an operator can
#' watch a rebuild without DB access.
#'
#' @param query_fn Injectable query fn (default `db_execute_query`).
#' @param limit Number of recent rows to return.
#' @return list(latest=, history=, build_exists=).
#' @export
service_disease_ontology_mapping_status <- function(query_fn = db_execute_query, limit = 5L) {
  limit <- as.integer(limit)
  rows <- tryCatch(
    query_fn(
      sprintf(
        paste0(
          "SELECT id, mondo_release_version, status, mondo_term_count, ",
          "mondo_xref_count, mapping_count, disease_covered_count, ",
          "build_started_at, build_finished_at, build_duration_s ",
          "FROM disease_ontology_mapping_meta ",
          "ORDER BY id DESC LIMIT %d"
        ),
        limit
      )
    ),
    error = function(e) NULL
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(list(
      latest       = NULL,
      history      = list(),
      build_exists = FALSE
    ))
  }

  history <- lapply(seq_len(nrow(rows)), function(i) as.list(rows[i, , drop = FALSE]))
  list(
    latest       = history[[1]],
    history      = history,
    build_exists = any(rows$status == "success", na.rm = TRUE)
  )
}

#' Startup bootstrap: enqueue a mapping refresh if none has succeeded yet.
#'
#' Mirrors `analysis_snapshot_bootstrap_on_startup()` / the pubtatornidd
#' bootstrap. No-op when disabled or when a successful build exists; staggered so
#' it does not co-launch with the other startup bootstraps; never throws
#' (callable directly in API startup).
#'
#' @param submit_refresh_fn Injectable submit fn (default the shared submit).
#' @param enabled_fn Injectable gate (default `disease_ontology_mapping_bootstrap_enabled`).
#' @return Invisibly TRUE when a job was enqueued, FALSE otherwise.
#' @export
disease_ontology_mapping_bootstrap_on_startup <- function(
    submit_refresh_fn = service_disease_ontology_mapping_submit_refresh,
    enabled_fn = disease_ontology_mapping_bootstrap_enabled) {
  if (!isTRUE(enabled_fn())) {
    message("[ontology-mapping-bootstrap] disabled via DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP; skipping")
    return(invisible(FALSE))
  }

  outcome <- tryCatch(
    submit_refresh_fn(force = FALSE, stagger = TRUE),
    error = function(e) {
      message(sprintf("[ontology-mapping-bootstrap] skipped: %s", conditionMessage(e)))
      NULL
    }
  )
  if (is.null(outcome)) {
    return(invisible(FALSE))
  }

  if (isTRUE(outcome$skipped)) {
    message("[ontology-mapping-bootstrap] successful build present, nothing to do")
    return(invisible(FALSE))
  }
  if (isTRUE(outcome$duplicate)) {
    message("[ontology-mapping-bootstrap] refresh already queued/running, reused")
  } else {
    message(sprintf("[ontology-mapping-bootstrap] enqueued mapping refresh (job_id=%s)",
                    outcome$job_id))
  }
  invisible(TRUE)
}
