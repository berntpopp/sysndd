# functions/syndromicity-snapshot.R
#
# Integration layer for the computed syndromicity measure (#630): turns a set of
# entity ids into the aggregate block, loading the annotation evidence once.
#
# Extracted from the snapshot builder (which would otherwise cross the 600-line
# ceiling) AND shared with services/entity-syndromicity-service.R, which needs
# the identical "members with no annotation rows still count" handling. Two
# copies of that rule would drift, and the direction it would drift in is the
# dangerous one: silently dropping unannotated members inflates `coverage` to a
# constant 1 and hides exactly the selection effect the block exists to expose.

#' Classifier rows for an entity set, with unannotated members made explicit.
#'
#' `syndromicity_classify_entities()` only returns rows for entities that appear
#' in the annotation frame. An entity with no annotation rows at all is still a
#' member of the set and must land in the denominator as
#' `insufficient_annotation`, so it is backfilled here.
#'
#' @param entity_ids Integer vector of member entity ids.
#' @param evidence Optional pre-classified tibble (from a single bulk load); when
#'   supplied, no query is issued.
#' @return tibble in `syndromicity_classify_entities()` shape, one row per id.
#' @export
syndromicity_rows_for_entities <- function(entity_ids, evidence = NULL) {
  ids <- unique(suppressWarnings(as.integer(entity_ids)))
  ids <- ids[!is.na(ids)]

  rows <- if (is.null(evidence)) {
    syndromicity_classify_entities(syndromicity_annotations_for_entities(ids))
  } else {
    evidence[evidence$entity_id %in% ids, , drop = FALSE]
  }

  absent <- setdiff(ids, rows$entity_id)
  if (length(absent) == 0L) {
    return(rows)
  }

  dplyr::bind_rows(rows, tibble::tibble(
    entity_id = as.integer(absent),
    system_count = 0L,
    systems = replicate(length(absent), character(), simplify = FALSE),
    neuro_systems = replicate(length(absent), character(), simplify = FALSE),
    neurological_involvement = FALSE,
    system_count_excl_head_size = 0L,
    present_term_count = 0L,
    equivocal_term_count = 0L,
    call = "insufficient_annotation"
  ))
}

#' The aggregate block for one entity set.
#'
#' @export
syndromicity_aggregate_for_entities <- function(entity_ids, evidence = NULL) {
  syndromicity_aggregate_cluster(
    syndromicity_rows_for_entities(entity_ids, evidence = evidence)
  )
}

#' Attach a per-cluster `syndromicity` column to a clusters tibble.
#'
#' Loads the annotation evidence for the WHOLE snapshot ONCE and classifies it
#' once, rather than querying per cluster: concurrent curation between two reads
#' could otherwise attach metrics derived from a different data state than the
#' membership, and the coherence gate compares partitions only.
#'
#' The resulting column flows through `analysis_snapshot_build_cluster_rows()`
#' into `metadata_json` and back out via
#' `service_analysis_snapshot_shape_clusters()`, so no schema change is needed.
#' `cluster_hash` is a hash of the cluster's sorted entity_id set, so a new
#' column cannot churn it and cached LLM summaries survive.
#'
#' @param clusters Clusters tibble carrying an `identifiers` list-column.
#' @return The same tibble with a `syndromicity` list-column.
#' @export
syndromicity_attach_to_clusters <- function(clusters) {
  member_ids <- lapply(clusters$identifiers, function(ids) {
    if (is.null(ids) || nrow(ids) == 0L) integer() else as.integer(ids$entity_id)
  })

  evidence <- syndromicity_classify_entities(
    syndromicity_annotations_for_entities(unique(unlist(member_ids)))
  )

  clusters$syndromicity <- lapply(member_ids, function(ids) {
    syndromicity_aggregate_for_entities(ids, evidence = evidence)
  })
  clusters
}
