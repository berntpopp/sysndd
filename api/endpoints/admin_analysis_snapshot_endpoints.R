## -------------------------------------------------------------------##
# api/endpoints/admin_analysis_snapshot_endpoints.R
#
# Administrator-only HTTP triggers for the durable public analysis snapshots that
# the /api/analysis/* read endpoints serve. Mounted at /api/admin/analysis, so:
#   POST /api/admin/analysis/snapshots/refresh  (submit refresh jobs)
#   GET  /api/admin/analysis/snapshots/status   (per-preset manifest state)
#
# All three snapshot submit paths (startup hook, this endpoint, and the operator
# script scripts/refresh-analysis-snapshots.R) share one function,
# service_analysis_snapshot_submit_refresh(), so submission logic is not
# duplicated. Spec: .planning/superpowers/specs/2026-06-14-analysis-snapshot-bootstrap-design.md
## -------------------------------------------------------------------##

#* Submit analysis snapshot refresh jobs (Administrator only)
#*
#* Idempotently submits `analysis_snapshot_refresh` jobs so the worker rebuilds +
#* activates the durable public-ready snapshots. By default only presets without a
#* current public-ready snapshot are submitted; pass `force=true` to rebuild all.
#* Re-submitting a queued/running refresh returns the existing job (dedup).
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @param analysis_type:str Optional single preset (e.g. "gene_network_edges"). Omit for all supported presets.
#* @param force:bool Optional; rebuild even when a current snapshot exists. Default false.
#*
#* @post /snapshots/refresh
function(req, res, analysis_type = NULL, force = FALSE) {
  require_role(req, res, "Administrator")

  at <- if (is.null(analysis_type) || !nzchar(as.character(analysis_type[[1]]))) {
    NULL
  } else {
    as.character(analysis_type[[1]])
  }
  force_flag <- isTRUE(force) ||
    identical(tolower(as.character(force)[[1]]), "true") ||
    identical(as.character(force)[[1]], "1")

  summary <- service_analysis_snapshot_submit_refresh(analysis_type = at, force = force_flag)

  res$status <- 202L
  summary
}

#* Per-preset analysis snapshot status (Administrator only)
#*
#* Returns the manifest state (missing / available / stale /
#* source_version_mismatch) for each supported analysis preset, with timestamps
#* and stored row counts, so an operator can watch a rebuild progress without DB
#* access.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @get /snapshots/status
function(req, res) {
  require_role(req, res, "Administrator")
  service_analysis_snapshot_status()
}
