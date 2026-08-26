# functions/syndromicity-repository.R
#
# DB reads for the computed syndromicity measure (#630).
#
# One query per CALL, never one per entity -- a set of entities costs a single
# statement, not N. (The entity endpoint issues a second, separate visibility
# probe only when an entity returns zero annotation rows, to distinguish "not
# public" from "public but unannotated"; that is a distinct call, not a
# per-entity fan-out.) Parameters are BOUND, never interpolated. Entity
# visibility is enforced inside the same statement via `ndd_entity_view`, so a
# non-public entity cannot leak its annotations through this path.
#
# These functions deliberately return ALL active modifiers, not a pre-filtered
# `present`-only set: the classifier needs the `uncertain` / `variable` / `rare`
# rows to report `equivocal_term_count`, and a caller that filtered them away
# first would silently make that field read zero.

#' Annotation rows for a set of entities, from their primary approved reviews.
#'
#' @param entity_ids Integer vector.
#' @param conn Optional DBI connection (to participate in a transaction).
#' @return data.frame with `entity_id`, `phenotype_id`, `modifier_name`.
#' @export
syndromicity_annotations_for_entities <- function(entity_ids, conn = NULL) {
  ids <- unique(suppressWarnings(as.integer(entity_ids)))
  ids <- ids[!is.na(ids)]
  if (length(ids) == 0L) {
    return(data.frame(
      entity_id = integer(),
      phenotype_id = character(),
      modifier_name = character(),
      stringsAsFactors = FALSE
    ))
  }

  placeholders <- paste(rep("?", length(ids)), collapse = ", ")
  sql <- sprintf(
    "SELECT c.entity_id, c.phenotype_id, m.modifier_name
       FROM ndd_review_phenotype_connect c
       JOIN ndd_entity_review r
         ON r.review_id = c.review_id
        AND r.entity_id = c.entity_id
        AND r.is_primary = 1
        AND r.review_approved = 1
       JOIN ndd_entity_view v ON v.entity_id = c.entity_id
       JOIN modifier_list m ON m.modifier_id = c.modifier_id
      WHERE c.is_active = 1
        AND c.entity_id IN (%s)",
    placeholders
  )
  db_execute_query(sql, params = unname(as.list(ids)), conn = conn)
}

#' The entity ids of one cluster in the CURRENT public-ready phenotype snapshot.
#'
#' Pinned to `public_ready` on purpose: a hash belonging to a superseded or draft
#' snapshot must not resolve, or the served syndromicity could describe a
#' partition the public never saw.
#'
#' @param cluster_hash Character scalar.
#' @param conn Optional DBI connection.
#' @return Integer vector; `integer(0)` when the hash is not in the current
#'   public-ready snapshot.
#' @export
syndromicity_cluster_member_ids <- function(cluster_hash, conn = NULL) {
  hash <- as.character(cluster_hash)[1]
  if (is.na(hash) || !nzchar(hash)) {
    return(integer())
  }

  rows <- db_execute_query(
    "SELECT mem.entity_id
       FROM analysis_snapshot_manifest man
       JOIN analysis_snapshot_cluster cl
         ON cl.snapshot_id = man.snapshot_id
        AND cl.cluster_kind = 'phenotype'
       JOIN analysis_snapshot_cluster_member mem
         ON mem.snapshot_id = cl.snapshot_id
        AND mem.cluster_kind = cl.cluster_kind
        AND mem.cluster_id = cl.cluster_id
      WHERE man.analysis_type = 'phenotype_clusters'
        AND man.public_ready = 1
        AND man.status = 'public_ready'
        AND cl.cluster_hash = ?",
    params = list(hash),
    conn = conn
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(integer())
  }
  as.integer(rows$entity_id)
}

#' The FROZEN syndromicity block stored on a cluster in the current
#' public-ready phenotype snapshot.
#'
#' The summary endpoint must serve the same numbers `/phenotype_clustering`
#' serves for the same `cluster_hash`. Recomputing from live annotations would
#' drift the moment curation changed -- the snapshot is a frozen artifact and
#' `cluster_hash` hashes membership only, so two endpoints could report
#' different fractions for the same hash. It also costs two extra round trips on
#' every cache hit.
#'
#' @param cluster_hash Character scalar.
#' @param conn Optional DBI connection.
#' @return The parsed block, or NULL when the hash is not in the current
#'   public-ready snapshot or that snapshot predates the block.
#' @export
syndromicity_stored_block_for_cluster <- function(cluster_hash, conn = NULL) {
  hash <- as.character(cluster_hash)[1]
  if (is.na(hash) || !nzchar(hash)) {
    return(NULL)
  }

  rows <- db_execute_query(
    "SELECT cl.metadata_json
       FROM analysis_snapshot_manifest man
       JOIN analysis_snapshot_cluster cl
         ON cl.snapshot_id = man.snapshot_id
        AND cl.cluster_kind = 'phenotype'
      WHERE man.analysis_type = 'phenotype_clusters'
        AND man.public_ready = 1
        AND man.status = 'public_ready'
        AND cl.cluster_hash = ?
      LIMIT 1",
    params = list(hash),
    conn = conn
  )
  if (is.null(rows) || nrow(rows) == 0L) {
    return(NULL)
  }

  raw <- rows$metadata_json[[1]]
  if (is.null(raw) || is.na(raw) || !nzchar(as.character(raw))) {
    return(NULL)
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(as.character(raw), simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed)) {
    return(NULL)
  }
  parsed$syndromicity
}

#' The live phenotype vocabulary, for the fail-closed registry assertion.
#'
#' @param conn Optional DBI connection.
#' @return Character vector of `phenotype_list.phenotype_id`.
#' @export
syndromicity_vocabulary_ids <- function(conn = NULL) {
  rows <- db_execute_query("SELECT phenotype_id FROM phenotype_list", conn = conn)
  if (is.null(rows) || nrow(rows) == 0L) {
    return(character())
  }
  as.character(rows$phenotype_id)
}
