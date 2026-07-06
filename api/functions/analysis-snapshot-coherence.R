# functions/analysis-snapshot-coherence.R
#
# Snapshot partition-coherence gate (#514).
#
# The clustering snapshot builder derives the SERVED membership from the memoised
# clustering function and the VALIDATION (per-cluster stability + partition metrics)
# from a separate, un-memoised validator. They are coherent-by-construction only when
# both ran the identical seeded clustering on the identical graph. A stale memoise
# disk-cache hit (fixed by the #514 fingerprint) broke that assumption in production:
# the served membership was the pre-#510 text-mining partition while the validation was
# the fresh exp+db partition, and the integer-keyed join then left real clusters with
# `n/a` stability.
#
# This module is the defense-in-depth: BEFORE the builder joins validation onto
# membership, assert that the two describe the SAME partition — the visible membership
# cluster set must equal the validation cluster set, and (functional axis) the channel
# the membership was clustered on must match the channel the validator used. On a
# mismatch the refresh throws, so the prior public-ready snapshot is retained and the
# new one is recorded as failed (observable) rather than published incoherent.
#
# `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` (default "true") gates the hard failure; set it
# to "false" to downgrade to a warning as an operability escape hatch.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

.analysis_snapshot_require_coherence <- function() {
  val <- tolower(trimws(Sys.getenv("ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE", "true")))
  val %in% c("true", "1", "yes", "on")
}

#' Assert that a served membership and its validation describe the same partition.
#'
#' @param membership tibble with an integer `cluster` column (the served visible
#'   clusters, already filtered to >= min_size by the clustering function).
#' @param per_cluster the validator's per-cluster tibble with a `cluster_id` column.
#' @param kind "functional" or "phenotype" (for messages only).
#' @param membership_channel,validation_channel optional channel labels; when both are
#'   supplied they must be identical (functional axis coherence).
#' @param membership_members,validation_members optional named lists (cluster_id ->
#'   member-id character vector) for the served membership and the validated reference
#'   partition. When both are supplied, each shared cluster_id must have the SAME member
#'   set — this proves the two describe the same partition, not merely the same labels
#'   (guards against a stale membership whose cluster-id set happens to coincide).
#' @param require_coherence logical; NULL resolves from
#'   `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE`.
#' @return invisibly, a list(coherent, problems, missing_scores, orphan_scores).
#'   Throws (or warns, per the escape hatch) when incoherent.
#' @export
analysis_snapshot_assert_partition_coherent <- function(membership, per_cluster, kind,
                                                        membership_channel = NULL,
                                                        validation_channel = NULL,
                                                        membership_members = NULL,
                                                        validation_members = NULL,
                                                        require_coherence = NULL) {
  if (is.null(require_coherence)) require_coherence <- .analysis_snapshot_require_coherence()

  membership_ids <- if (is.null(membership) || !("cluster" %in% names(membership))) {
    character(0)
  } else {
    as.character(membership$cluster)
  }
  validation_ids <- if (is.null(per_cluster) || !("cluster_id" %in% names(per_cluster))) {
    character(0)
  } else {
    as.character(per_cluster$cluster_id)
  }

  missing_scores <- setdiff(membership_ids, validation_ids) # served clusters with no stability row
  orphan_scores <- setdiff(validation_ids, membership_ids) # validation clusters not served
  channel_mismatch <- !is.null(membership_channel) && !is.null(validation_channel) &&
    !identical(as.character(membership_channel), as.character(validation_channel))

  problems <- character(0)
  if (length(missing_scores)) {
    problems <- c(problems, sprintf(
      "%d visible %s cluster(s) have no validation/stability score (ids: %s)",
      length(missing_scores), kind, paste(missing_scores, collapse = ", ")
    ))
  }
  if (length(orphan_scores)) {
    problems <- c(problems, sprintf(
      "%d validation %s cluster(s) are not in the served membership (ids: %s)",
      length(orphan_scores), kind, paste(orphan_scores, collapse = ", ")
    ))
  }
  if (channel_mismatch) {
    problems <- c(problems, sprintf(
      "%s membership channel (%s) disagrees with the validation channel (%s)",
      kind, membership_channel, validation_channel
    ))
  }

  # Same-partition proof (not just same labels): for every shared cluster_id the
  # served membership and the validated reference partition must contain the SAME
  # member set. Catches a stale membership whose cluster-id labels coincide with the
  # fresh validation but whose contents differ.
  if (!is.null(membership_members) && !is.null(validation_members)) {
    shared <- intersect(names(membership_members), names(validation_members))
    content_mismatch <- character(0)
    for (cid in shared) {
      a <- unique(as.character(membership_members[[cid]]))
      b <- unique(as.character(validation_members[[cid]]))
      if (!setequal(a, b)) content_mismatch <- c(content_mismatch, cid)
    }
    if (length(content_mismatch)) {
      problems <- c(problems, sprintf(
        "%d %s cluster(s) have membership content that differs from the validated partition (ids: %s)",
        length(content_mismatch), kind, paste(content_mismatch, collapse = ", ")
      ))
    }
  }

  coherent <- length(problems) == 0L
  if (!coherent) {
    msg <- sprintf(
      paste0(
        "Incoherent %s partition snapshot: membership and validation describe ",
        "different partitions: %s. Refusing to publish (#514)."
      ),
      kind, paste(problems, collapse = "; ")
    )
    if (require_coherence) {
      stop(msg, call. = FALSE)
    } else {
      warning(msg, call. = FALSE)
    }
  }

  invisible(list(
    coherent = coherent,
    problems = problems,
    missing_scores = missing_scores,
    orphan_scores = orphan_scores
  ))
}

#' Gate then join the validator's per-cluster scores onto the served membership.
#'
#' Single choke-point for the builder's two clustering presets: it asserts partition
#' coherence FIRST (so an incoherent snapshot can never be published), then performs the
#' `cluster` <-> `cluster_id` left-join, and carries the served membership channel as a
#' `membership_weight_channel` attribute for additive provenance.
#'
#' @param membership tibble from the memoised clustering function (integer `cluster`,
#'   optional `weight_channel` attribute).
#' @param val the validator return list (`per_cluster` tibble + `partition` list).
#' @param kind "functional" or "phenotype".
#' @return the joined clusters tibble (validation columns merged; `cluster_id` dropped).
#' @export
analysis_snapshot_join_validated_clusters <- function(membership, val, kind) {
  membership_channel <- attr(membership, "weight_channel")
  validation_channel <- val$partition$weight_channel

  # Member id space differs per axis: functional clusters over STRING node ids, phenotype
  # clusters over entity ids. Extract the served per-cluster member set (keyed by the same
  # integer cluster label as val$reference_members) for the same-partition proof.
  member_col <- if (identical(kind, "functional")) "STRING_id" else "entity_id"
  membership_members <- NULL
  if (all(c("identifiers", "cluster") %in% names(membership))) {
    membership_members <- stats::setNames(
      lapply(membership$identifiers, function(df) {
        if (is.data.frame(df) && member_col %in% names(df)) {
          as.character(df[[member_col]])
        } else {
          character(0)
        }
      }),
      as.character(membership$cluster)
    )
  }

  analysis_snapshot_assert_partition_coherent(
    membership, val$per_cluster, kind,
    membership_channel = membership_channel,
    validation_channel = validation_channel,
    membership_members = membership_members,
    validation_members = val$reference_members
  )

  joined <- dplyr::left_join(
    dplyr::mutate(membership, cluster_id = as.character(cluster)),
    val$per_cluster,
    by = "cluster_id"
  )
  joined <- dplyr::select(joined, -cluster_id)
  attr(joined, "membership_weight_channel") <- membership_channel %||% NA_character_
  joined
}
