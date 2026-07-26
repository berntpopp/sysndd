# services/analysis-snapshot-refresh-service.R
#
# Shared snapshot refresh submission (#420). One submit path backs the startup
# bootstrap (start_sysndd_api.R), the admin endpoint
# (endpoints/admin_analysis_snapshot_endpoints.R), and the operator script
# (scripts/refresh-analysis-snapshots.R). Keep this the single source of
# submission logic. Reuses read/shape helpers from analysis-snapshot-service.R
# (service_analysis_snapshot_scalar_value / _time_string / _record_counts),
# preset helpers from functions/analysis-snapshot-presets.R, and the cheap
# manifest probes from functions/analysis-snapshot-repository.R; all are loaded
# into the global environment so they resolve at call time.

#' Max attempts for a submitted `analysis_snapshot_refresh` job (#440).
#'
#' Heavy snapshot builds (especially `functional_clusters`' recursive STRING
#' enrichment) can outrun their worker lease under startup contention. The
#' stale-lease reaper (`async_job_repository_recover_stale`) requeues an expired
#' lease while `attempt_count < max_attempts`, so > 1 makes the bootstrap
#' self-healing instead of leaving a permanently-failed `LEASE_EXPIRED` snapshot.
ANALYSIS_SNAPSHOT_REFRESH_MAX_ATTEMPTS <- 3L

#' Whether the startup snapshot bootstrap is enabled.
#'
#' Config gate (issue #420), implemented as an env var to match the repo's
#' sidecar/env conventions. Default enabled; set
#' `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP=false` to disable.
#' @export
analysis_snapshot_bootstrap_enabled <- function() {
  raw <- trimws(Sys.getenv("ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP", "true"))
  if (!nzchar(raw)) {
    return(TRUE)
  }
  tolower(raw) %in% c("true", "1", "yes", "on")
}

#' Parse a non-negative-integer env var, falling back to a default.
#'
#' Blank, non-numeric, or negative values yield the default. `0` is a valid
#' value (used to disable staggering).
#'
#' @param name Env var name.
#' @param default Integer default.
#' @return Non-negative integer.
#' @keywords internal
.analysis_snapshot_int_env <- function(name, default) {
  raw <- trimws(Sys.getenv(name, ""))
  if (!nzchar(raw)) {
    return(as.integer(default))
  }
  val <- suppressWarnings(as.integer(raw))
  if (is.na(val) || val < 0L) {
    return(as.integer(default))
  }
  val
}

#' Seconds to delay HEAVY presets' first claim-eligibility during the startup
#' bootstrap (#447).
#'
#' Light presets are never delayed. `0` disables staggering (current behavior).
#' Default 120s. Read at call time so a restart picks up an env change.
#' @export
analysis_snapshot_bootstrap_stagger_seconds <- function() {
  .analysis_snapshot_int_env("ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS", 120L)
}

#' Submit analysis_snapshot_refresh jobs for supported presets.
#'
#' For each target preset: normalize params (canonical parameter_hash), and
#' unless `force` skip presets that already have an active public-ready snapshot,
#' then submit a durable `analysis_snapshot_refresh` job (dedup-safe). Per-preset
#' failures are isolated and reported, never thrown.
#'
#' @param analysis_type Optional single preset; NULL = all supported presets.
#' @param force When TRUE, submit even when a current snapshot exists.
#' @param presets Optional preset list (defaults to the supported presets).
#' @param submit_fn Injectable job-submit fn (default `async_job_service_submit`).
#' @param exists_fn Injectable skip predicate: returns TRUE when a *current*
#'   public-ready snapshot already exists, so the refresh is skipped. Defaults to
#'   `analysis_snapshot_public_current`, which treats stale / source-version
#'   mismatched snapshots as NOT current so they re-enqueue and self-heal on
#'   startup (the #420/#440 self-heal only covered `snapshot_missing`).
#' @param conn Optional DB connection/pool.
#' @param stagger When TRUE, offset HEAVY presets' `scheduled_at` so they are not
#'   claim-eligible at the same instant as the light presets (startup bootstrap
#'   only). The operator/admin `force` refresh path leaves this FALSE so a manual
#'   rebuild is never delayed.
#' @param now Clock injection point (default `Sys.time()`); the stagger base.
#' @param stagger_seconds Heavy-preset offset in seconds; NULL resolves the env
#'   default via `analysis_snapshot_bootstrap_stagger_seconds()`.
#' @return Structured summary list.
#' @export
service_analysis_snapshot_submit_refresh <- function(analysis_type = NULL,
                                                     force = FALSE,
                                                     presets = NULL,
                                                     submit_fn = async_job_service_submit,
                                                     exists_fn = analysis_snapshot_public_current,
                                                     conn = NULL,
                                                     stagger = FALSE,
                                                     now = Sys.time(),
                                                     stagger_seconds = NULL) {
  stagger <- isTRUE(stagger)
  if (is.null(stagger_seconds)) {
    stagger_seconds <- analysis_snapshot_bootstrap_stagger_seconds()
  }
  stagger_seconds <- as.integer(stagger_seconds)
  if (is.null(presets)) {
    presets <- analysis_snapshot_supported_presets()
  }
  if (!is.null(analysis_type)) {
    analysis_type <- as.character(analysis_type[[1]])
    presets <- Filter(function(p) identical(p$analysis_type, analysis_type), presets)
    if (length(presets) == 0L) {
      analysis_snapshot_unsupported_parameter(
        sprintf("Unsupported analysis snapshot type: %s", analysis_type),
        fields = list(analysis_type = analysis_type)
      )
    }
  }

  force <- isTRUE(force)
  results <- list()
  submitted <- 0L
  reused <- 0L
  skipped <- 0L
  failed <- 0L

  for (preset in presets) {
    normalized <- analysis_snapshot_normalize_params(preset$analysis_type, preset$params)
    at <- normalized$analysis_type
    ph <- normalized$parameter_hash

    if (!force) {
      already <- tryCatch(exists_fn(at, ph, conn = conn), error = function(e) FALSE)
      if (isTRUE(already)) {
        skipped <- skipped + 1L
        results[[length(results) + 1L]] <- list(
          analysis_type = at, parameter_hash = ph,
          action = "skipped_existing", job_id = NA_character_,
          message = "public-ready snapshot already present"
        )
        next
      }
    }

    # Stagger heavy presets behind the cheap ones at first-start (#447). Light
    # presets stay eligible immediately; the operator force path never staggers.
    sched <- now
    if (stagger && stagger_seconds > 0L &&
        identical(analysis_snapshot_preset_weight(at), "heavy")) {
      sched <- now + stagger_seconds
    }

    outcome <- tryCatch(
      submit_fn(
        job_type = "analysis_snapshot_refresh",
        request_payload = list(analysis_type = at, params = normalized$params),
        queue_name = "default",
        priority = 50L,
        max_attempts = ANALYSIS_SNAPSHOT_REFRESH_MAX_ATTEMPTS,
        scheduled_at = sched,
        conn = conn
      ),
      error = function(e) list(.error = conditionMessage(e))
    )

    if (!is.null(outcome$.error)) {
      failed <- failed + 1L
      results[[length(results) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph,
        action = "error", job_id = NA_character_, message = outcome$.error
      )
      next
    }

    job_id <- tryCatch(as.character(outcome$job$job_id[[1]]), error = function(e) NA_character_)
    if (isTRUE(outcome$duplicate)) {
      reused <- reused + 1L
      results[[length(results) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph,
        action = "reused", job_id = job_id,
        message = "existing queued/running job reused"
      )
    } else {
      submitted <- submitted + 1L
      results[[length(results) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph,
        action = "submitted", job_id = job_id, message = "refresh job submitted"
      )
    }
  }

  list(
    requested = length(presets),
    submitted = submitted,
    reused = reused,
    skipped = skipped,
    failed = failed,
    force = force,
    results = results
  )
}

#' Per-preset public snapshot status overview.
#'
#' @param presets Optional preset list (defaults to the supported presets).
#' @param manifest_fn Injectable manifest read (default `analysis_snapshot_public_manifest`).
#' @param conn Optional DB connection/pool.
#' @return list(presets = list(per-preset state), summary = counts).
#' @export
service_analysis_snapshot_status <- function(presets = NULL,
                                             manifest_fn = analysis_snapshot_public_manifest,
                                             conn = NULL) {
  if (is.null(presets)) {
    presets <- analysis_snapshot_supported_presets()
  }
  preset_states <- list()
  total <- 0L
  available <- 0L
  missing <- 0L
  stale <- 0L
  mismatch <- 0L

  for (preset in presets) {
    normalized <- analysis_snapshot_normalize_params(preset$analysis_type, preset$params)
    at <- normalized$analysis_type
    ph <- normalized$parameter_hash
    manifest <- tryCatch(manifest_fn(at, ph, conn = conn), error = function(e) NULL)
    total <- total + 1L

    if (is.null(manifest)) {
      missing <- missing + 1L
      preset_states[[length(preset_states) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph, state = "missing",
        generated_at = NA_character_, activated_at = NA_character_,
        stale_after = NA_character_, source_data_version = NA_character_,
        row_counts = NULL
      )
      next
    }

    status_code <- service_analysis_snapshot_scalar_value(manifest$status_code, "available")
    state <- switch(status_code,
      available = "available",
      snapshot_stale = "stale",
      source_version_mismatch = "source_version_mismatch",
      snapshot_missing = "missing",
      status_code
    )
    if (identical(state, "available")) {
      available <- available + 1L
    } else if (identical(state, "stale")) {
      stale <- stale + 1L
    } else if (identical(state, "source_version_mismatch")) {
      mismatch <- mismatch + 1L
    } else if (identical(state, "missing")) {
      missing <- missing + 1L
    }

    preset_states[[length(preset_states) + 1L]] <- list(
      analysis_type = at,
      parameter_hash = ph,
      state = state,
      generated_at = service_analysis_snapshot_time_string(
        service_analysis_snapshot_scalar_value(manifest$generated_at)
      ),
      activated_at = service_analysis_snapshot_time_string(
        service_analysis_snapshot_scalar_value(manifest$activated_at)
      ),
      stale_after = service_analysis_snapshot_time_string(
        service_analysis_snapshot_scalar_value(manifest$stale_after)
      ),
      source_data_version = service_analysis_snapshot_scalar_value(
        manifest$source_data_version, NA_character_
      ),
      row_counts = service_analysis_snapshot_record_counts(manifest)
    )
  }

  list(
    presets = preset_states,
    summary = list(
      total = total, available = available, missing = missing,
      stale = stale, mismatch = mismatch
    )
  )
}

#' In-process state for the serve-time snapshot self-heal throttle.
#'
#' A single GLOBAL epoch (not per-preset): a source-data change flips the
#' `analysis_snapshot_source_data_version()` hash for ALL presets at once, so one
#' enqueue-all refresh covers every public analysis page. Package-private env so
#' the throttle survives across requests in the same R process. Each API instance
#' (api-1, api-2) throttles independently; job-level dedup makes the worst-case
#' cross-instance double-enqueue harmless.
#' @keywords internal
.analysis_snapshot_selfheal_state <- new.env(parent = emptyenv())
.analysis_snapshot_selfheal_state$last_submit_epoch <- NULL

#' Whether the serve-time snapshot self-heal is enabled (default TRUE).
#'
#' Disable with `ANALYSIS_SNAPSHOT_SELFHEAL_ON_SERVE=false` (e.g. to fall back to
#' the startup-only bootstrap). Read at call time so a restart picks up a change.
#' @export
analysis_snapshot_selfheal_enabled <- function() {
  raw <- trimws(Sys.getenv("ANALYSIS_SNAPSHOT_SELFHEAL_ON_SERVE", "true"))
  if (!nzchar(raw)) {
    return(TRUE)
  }
  tolower(raw) %in% c("true", "1", "yes", "on")
}

#' Minimum seconds between serve-time self-heal enqueues (per process). Default 60.
#'
#' Bounds how often a polling frontend re-runs the (DB-touching) submit loop while
#' a rebuild is in flight. Read at call time.
#' @export
analysis_snapshot_selfheal_throttle_seconds <- function() {
  .analysis_snapshot_int_env("ANALYSIS_SNAPSHOT_SELFHEAL_THROTTLE_SECONDS", 60L)
}

#' Serve-time self-heal: enqueue a snapshot refresh when a public endpoint is
#' asked for a snapshot that is missing / stale / source-version- or
#' schema-mismatched.
#'
#' ROOT CAUSE this closes: before this, the startup bootstrap
#' (`analysis_snapshot_bootstrap_on_startup()`) was the ONLY thing that
#' re-enqueued a non-current snapshot. A data edit AFTER API startup flips the
#' source-data-version hash, so every public analysis endpoint (GeneNetworks,
#' PhenotypeFunctionalCorrelation, ...) returned a PERMANENT HTTP 503
#' ("This analysis is being prepared and will appear here shortly") with nothing
#' actually preparing it, until the next API restart. This makes the promise
#' true: the first request that observes staleness kicks off the SAME dedup-safe,
#' all-preset refresh the bootstrap runs, so subsequent client polls converge to
#' HTTP 200.
#'
#' Contract:
#'   - Best-effort and NON-throwing: `service_analysis_snapshot_read()` invokes
#'     this purely for its side effect and still returns its 503. Any failure
#'     here is swallowed (a self-heal error must never turn a 503 into a 500).
#'   - Throttled to at most one enqueue per `throttle_seconds` per process, keyed
#'     GLOBALLY, so a polling frontend does not run the submit loop on every
#'     request.
#'   - Enqueues ALL non-current presets (`force = FALSE`, no stagger), mirroring
#'     the proven startup bootstrap so cluster + correlation lineage rebuild
#'     consistently (the correlation presets' recorded dependencies stay pinned
#'     to current cluster snapshots). Job-level dedup collapses duplicate submits.
#'
#' @param analysis_type The preset that was requested (recorded for logging; the
#'   enqueue covers all presets by design).
#' @param submit_fn Injectable submit path (default the shared submit).
#' @param enabled_fn Injectable enable gate (default `analysis_snapshot_selfheal_enabled`).
#' @param throttle_seconds Injectable throttle window; NULL resolves the env default.
#' @param state Injectable throttle-state env (default the package-private env).
#' @param now Clock injection point (default `Sys.time()`).
#' @return Invisibly TRUE when an enqueue was attempted this call; FALSE when
#'   throttled or disabled.
#' @export
service_analysis_snapshot_selfheal_on_serve <- function(
    analysis_type = NULL,
    submit_fn = service_analysis_snapshot_submit_refresh,
    enabled_fn = analysis_snapshot_selfheal_enabled,
    throttle_seconds = NULL,
    state = .analysis_snapshot_selfheal_state,
    now = Sys.time()) {
  tryCatch(
    {
      if (!isTRUE(enabled_fn())) {
        return(invisible(FALSE))
      }

      if (is.null(throttle_seconds)) {
        throttle_seconds <- analysis_snapshot_selfheal_throttle_seconds()
      }
      now_epoch <- as.numeric(now)
      last <- state$last_submit_epoch
      if (!is.null(last) && length(last) == 1L && is.finite(last) &&
        (now_epoch - last) < as.numeric(throttle_seconds)) {
        return(invisible(FALSE))
      }
      # Claim the throttle window BEFORE the (slower) submit so concurrent
      # requests in the same process do not all pile into the submit loop.
      state$last_submit_epoch <- now_epoch

      summary <- tryCatch(
        submit_fn(force = FALSE, stagger = FALSE),
        error = function(e) {
          message(sprintf("[snapshot-selfheal] submit failed: %s", conditionMessage(e)))
          NULL
        }
      )
      if (!is.null(summary)) {
        message(sprintf(
          paste0(
            "[snapshot-selfheal] serve-time refresh triggered by '%s': ",
            "submitted %d, reused %d, skipped %d, failed %d"
          ),
          analysis_type %||% "unknown",
          summary$submitted %||% 0L, summary$reused %||% 0L,
          summary$skipped %||% 0L, summary$failed %||% 0L
        ))
      }
      invisible(TRUE)
    },
    error = function(e) {
      tryCatch(
        message(sprintf("[snapshot-selfheal] unexpected error: %s", conditionMessage(e))),
        error = function(e2) NULL
      )
      invisible(FALSE)
    }
  )
}

#' Startup bootstrap: enqueue refresh jobs for missing presets (idempotent).
#'
#' Mirrors `pubtatornidd_bootstrap_enrichment()`. No-op when disabled; never
#' throws (callable directly in API startup).
#'
#' @param submit_refresh_fn Injectable submit fn (default the shared submit).
#' @param enabled_fn Injectable gate (default `analysis_snapshot_bootstrap_enabled`).
#' @return Invisibly TRUE when at least one preset was missing, FALSE otherwise.
#' @export
analysis_snapshot_bootstrap_on_startup <- function(
    submit_refresh_fn = service_analysis_snapshot_submit_refresh,
    enabled_fn = analysis_snapshot_bootstrap_enabled) {
  if (!isTRUE(enabled_fn())) {
    message("[snapshot-bootstrap] disabled via ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP; skipping")
    return(invisible(FALSE))
  }

  summary <- tryCatch(
    submit_refresh_fn(force = FALSE, stagger = TRUE),
    error = function(e) {
      message(sprintf("[snapshot-bootstrap] skipped: %s", conditionMessage(e)))
      NULL
    }
  )
  if (is.null(summary)) {
    return(invisible(FALSE))
  }

  # "needs refresh" = missing OR stale OR source-version mismatched (anything the
  # staleness-aware skip probe does not consider current).
  needs_refresh <- summary$requested - summary$skipped
  if (needs_refresh > 0L) {
    message(sprintf(
      "[snapshot-bootstrap] %d/%d presets need refresh -> submitted %d refresh jobs (reused %d, failed %d)",
      needs_refresh, summary$requested, summary$submitted, summary$reused, summary$failed
    ))
  } else {
    message("[snapshot-bootstrap] all presets current, nothing to do")
  }
  invisible(needs_refresh > 0L)
}
