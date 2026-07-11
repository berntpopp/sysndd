# api/services/admin-nddscore-endpoint-service.R
#
# Service layer for the Administrator NDDScore family extracted from
# api/endpoints/admin_endpoints.R (issue #346, Wave 3).
#
# NDDScore is an ML prediction layer, separate from curated SysNDD evidence,
# never a curation status (AGENTS.md). These endpoints only report import
# status / Zenodo metadata / submit the durable `nddscore_import` job; the
# `require_role(req, res, "Administrator")` gate stays inline in the endpoint
# shell. Reuses the `.nddscore_admin_*` helpers already extracted to
# functions/nddscore-admin-endpoint-helpers.R (sourced before services/*).

#' GET /admin/nddscore/status body.
#' @export
svc_admin_nddscore_status <- function(req, res, limit = 10L,
                                       release_fn = nddscore_repo_current_release,
                                       history_fn = async_job_service_history) {
  limit <- suppressWarnings(as.integer(limit))
  if (is.na(limit) || limit < 1L) {
    limit <- 10L
  }
  limit <- min(limit, 100L)

  release <- release_fn()
  jobs <- history_fn(limit = 100L, include_result = TRUE)
  if (.nddscore_admin_has_rows(jobs)) {
    jobs <- jobs[jobs$job_type == "nddscore_import", , drop = FALSE]
    jobs <- utils::head(jobs, limit)
  }

  list(
    active_release = if (.nddscore_admin_has_rows(release)) {
      as.list(release[1L, , drop = FALSE])
    } else {
      NULL
    },
    active_release_available = .nddscore_admin_has_rows(release),
    recent_jobs = .nddscore_admin_tibble_rows(jobs),
    meta = list(
      job_type = "nddscore_import",
      default_record_id = nddscore_default_zenodo_record_id(),
      count = if (.nddscore_admin_has_rows(jobs)) nrow(jobs) else 0L,
      limit = limit
    )
  )
}

#' GET /admin/nddscore/zenodo body.
#' @export
svc_admin_nddscore_zenodo <- function(req, res, record_id = NULL,
                                       zenodo_fn = nddscore_fetch_zenodo_metadata,
                                       release_fn = nddscore_repo_current_release) {
  record_id <- as.character(
    .nddscore_admin_scalar(record_id, nddscore_default_zenodo_record_id())
  )
  zenodo <- zenodo_fn(record_id)
  release <- release_fn()
  active_release <- if (.nddscore_admin_has_rows(release)) {
    as.list(release[1L, , drop = FALSE])
  } else {
    NULL
  }

  comparison <- if (.nddscore_admin_has_rows(release)) {
    list(
      active_release_available = TRUE,
      record_id_matches = identical(
        as.character(release$source_record_id[[1]]),
        as.character(zenodo$record_id)
      ),
      version_matches = identical(
        as.character(release$version[[1]]),
        as.character(zenodo$version)
      ),
      archive_name_matches = identical(
        as.character(release$source_archive_name[[1]]),
        as.character(zenodo$archive_name)
      ),
      archive_checksum_matches = identical(
        as.character(release$source_archive_checksum[[1]]),
        as.character(zenodo$archive_md5)
      )
    )
  } else {
    list(active_release_available = FALSE)
  }

  list(
    record_id = record_id,
    zenodo = zenodo,
    active_release = active_release,
    comparison = comparison,
    matches_active = isTRUE(comparison$record_id_matches) &&
      isTRUE(comparison$version_matches) &&
      isTRUE(comparison$archive_name_matches) &&
      isTRUE(comparison$archive_checksum_matches)
  )
}

#' POST /admin/nddscore/import body.
#'
#' Submits a durable `nddscore_import` job; 409 when one is already running
#' (duplicate), otherwise 202.
#'
#' @export
svc_admin_nddscore_import <- function(req, res,
                                       submit_fn = async_job_service_submit) {
  body <- .nddscore_admin_request_body(req)
  record_id <- as.character(
    .nddscore_admin_scalar(body$record_id, nddscore_default_zenodo_record_id())
  )
  validate_only <- .nddscore_admin_bool(body$validate_only, FALSE)

  submitted <- submit_fn(
    job_type = "nddscore_import",
    request_payload = list(
      record_id = record_id,
      validate_only = validate_only
    ),
    submitted_by = req$user_id %||% NULL
  )

  job <- submitted$job
  job_id <- job$job_id[[1]]
  status_url <- .nddscore_admin_job_status_url(job_id)

  res$status <- if (isTRUE(submitted$duplicate)) 409L else 202L
  res$setHeader("Location", status_url)
  res$setHeader("Retry-After", "5")

  list(
    job_id = job_id,
    status = if (isTRUE(submitted$duplicate)) "already_running" else "accepted",
    job_status = job$status[[1]],
    status_url = status_url
  )
}
