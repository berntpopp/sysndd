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
#' @param exists_fn Injectable existence probe (default `analysis_snapshot_public_exists`).
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
                                                     exists_fn = analysis_snapshot_public_exists,
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

  missing <- summary$requested - summary$skipped
  if (missing > 0L) {
    message(sprintf(
      "[snapshot-bootstrap] %d/%d presets missing -> submitted %d refresh jobs (reused %d, failed %d)",
      missing, summary$requested, summary$submitted, summary$reused, summary$failed
    ))
  } else {
    message("[snapshot-bootstrap] all presets present, nothing to do")
  }
  invisible(missing > 0L)
}
