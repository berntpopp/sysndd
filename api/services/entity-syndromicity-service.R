# api/services/entity-syndromicity-service.R
#
# READ surface for the computed syndromicity measure (#630).
#
#   1. svc_entity_syndromicity()  -- GET /entity/<id>/syndromicity
#   2. svc_cluster_syndromicity() -- the block attached to
#      GET /analysis/phenotype_cluster_summary, resolved by cluster_hash.
#
# WHY THE PER-ENTITY ROUTE EXISTS
# -------------------------------
# The cluster aggregate is a claim about a set of entities. Without a per-entity
# route the claim is unverifiable: a consumer cannot check why a cluster reports
# 65.8% involvement, or which systems drove it. This route makes every aggregate
# auditable down to the individual gene-disease association, which is the whole
# difference between a computed measure and the model-generated label it
# replaces.
#
# JSON SERIALIZATION CONTRACT
# ---------------------------
# The routes serialize with `list(na="string", null="null")`. `null="null"` is
# load-bearing: without it jsonlite renders a NULL list element as `{}`, so
# `syndromicity: null` -- the contract meaning "this cluster hash is not in the
# current public-ready snapshot" -- would silently become `"syndromicity":{}`.
# Plumber does not auto-unbox, so scalars nested in a list serialize as
# length-1 arrays; clients unwrap field-by-field.
#
# NO tryCatch AROUND THE CLASSIFICATION
# -------------------------------------
# Deliberate, and the same reasoning as the variation-provenance read. The
# registry is fail-closed against the live vocabulary; if a phenotype term is
# unclassified, the correct behaviour is a loud failure, not a syndromicity
# value computed over an incomplete vocabulary and served as fact.

#' Entity-level computed syndromicity.
#'
#' @param entity_id Entity id (integer-like; may arrive as a string).
#' @param res Plumber response object.
#' @return Named list; `status = "missing"` when the entity is not in
#'   `ndd_entity_view` (a non-public or non-existent entity), never a leak.
#' @export
svc_entity_syndromicity <- function(entity_id, res) {
  id <- suppressWarnings(as.integer(entity_id))
  if (is.na(id)) {
    stop_for_bad_request("entity_id must be an integer")
  }

  annotations <- syndromicity_annotations_for_entities(id)

  # An entity with no rows is either absent from ndd_entity_view (not public) or
  # present with no annotations. The repository join enforces visibility, so
  # distinguish the two with an explicit visibility probe rather than guessing.
  if (nrow(annotations) == 0L) {
    visible <- db_execute_query(
      "SELECT entity_id FROM ndd_entity_view WHERE entity_id = ?",
      params = list(id)
    )
    if (is.null(visible) || nrow(visible) == 0L) {
      res$status <- 404L
      return(list(entity_id = id, status = "missing"))
    }
    return(c(
      list(status = "ok"),
      syndromicity_entity_result(tibble::tibble(
        entity_id = id,
        system_count = 0L,
        systems = list(character()),
        neuro_systems = list(character()),
        neurological_involvement = FALSE,
        system_count_with_head_size = 0L,
        present_term_count = 0L,
        equivocal_term_count = 0L,
        call = "insufficient_annotation"
      ))
    ))
  }

  classified <- syndromicity_classify_entities(annotations)
  c(list(status = "ok"), syndromicity_entity_result(classified))
}

#' Cluster-level computed syndromicity, resolved by cluster hash.
#'
#' @param cluster_hash Character scalar.
#' @return The aggregate block, or NULL when the hash is not in the current
#'   public-ready phenotype snapshot (an unknown hash and a superseded one are
#'   indistinguishable, deliberately).
#' @export
svc_cluster_syndromicity <- function(cluster_hash) {
  entity_ids <- syndromicity_cluster_member_ids(cluster_hash)
  if (length(entity_ids) == 0L) {
    return(NULL)
  }
  syndromicity_aggregate_for_entities(entity_ids)
}
