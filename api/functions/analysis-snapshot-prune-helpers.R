# functions/analysis-snapshot-prune-helpers.R
#
# Retention / prune helper for public analysis-snapshot manifests. Extracted from
# `analysis-snapshot-repository.R` (#573 round-3 CI1) to keep that file under the
# 600-line ceiling; the logic is unchanged.
#
# `analysis_snapshot_prune()` keeps the newest `keep_public_ready`
# public_ready/superseded rows and deletes superseded rows older than
# `keep_superseded_days` — but NEVER deletes a snapshot a #573 release still
# references (its live reproducibility endpoint would then 503). The
# release-reference lookup (`analysis_release_referenced_snapshot_ids`) is
# `exists()`-guarded for mirai-pool parity: on the legacy mirai worker the release
# repository file is not sourced, so the guard degrades to "no release references"
# (the pre-existing behavior) rather than erroring.
#
# Registered in both `bootstrap/load_modules.R` (API + durable worker + MCP) and
# `bootstrap/setup_workers.R` (mirai `everywhere()`), immediately after
# `analysis-snapshot-repository.R`, because the snapshot builder calls this during
# a refresh on either execution path.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

analysis_snapshot_prune <- function(analysis_type,
                                    parameter_hash,
                                    keep_public_ready = 3L,
                                    keep_superseded_days = 14L,
                                    conn = NULL) {
  keep_public_ready <- max(1L, as.integer(keep_public_ready))
  keep_superseded_days <- max(0L, as.integer(keep_superseded_days))

  keep_rows <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND status IN ('public_ready', 'superseded')
      ORDER BY COALESCE(activated_at, generated_at, created_at) DESC, snapshot_id DESC
      LIMIT ?",
    unname(list(analysis_type, parameter_hash, keep_public_ready)),
    conn = conn
  )
  keep_ids <- as.numeric(keep_rows$snapshot_id %||% numeric())

  cutoff_time <- as.POSIXct(Sys.time() - (keep_superseded_days * 86400), tz = "UTC")
  cutoff <- format(cutoff_time, "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
  candidates <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND status = 'superseded'
        AND COALESCE(superseded_at, updated_at, created_at) < ?",
    unname(list(analysis_type, parameter_hash, cutoff)),
    conn = conn
  )

  # Never prune a snapshot a release (#573) still references (its LIVE
  # reproducibility endpoint would 503). analysis_release_referenced_snapshot_ids()
  # is the single source of truth for this -- do not inline a NOT IN subquery.
  # exists()-guarded for mirai-pool parity (the release repository file is not
  # sourced on the legacy mirai worker), mirroring the lock-name guard.
  referenced_ids <- if (exists("analysis_release_referenced_snapshot_ids", mode = "function")) {
    as.numeric(analysis_release_referenced_snapshot_ids(conn = conn))
  } else {
    numeric()
  }

  delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), union(keep_ids, referenced_ids))
  if (length(delete_ids) == 0L) {
    return(invisible(0L))
  }

  placeholders <- paste(rep("?", length(delete_ids)), collapse = ", ")
  db_execute_statement(
    paste0("DELETE FROM analysis_snapshot_manifest WHERE snapshot_id IN (", placeholders, ")"),
    unname(as.list(delete_ids)),
    conn = conn
  )
}
