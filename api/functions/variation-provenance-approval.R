# functions/variation-provenance-approval.R
#
# Approval-time reconciliation for variation-ontology provenance assertions (#612).
#
# WHY A SEPARATE FILE
# -------------------
# variation-provenance-reconcile.R owns the state machine and is near the
# 600-line ceiling; this is the same split that produced
# variation-provenance-carry-forward.R.
#
# WHY THIS EXISTS
# ---------------
# Write reconciliation gates its REJECTION edges on
# review_write_save_determines_served_set() -- a Reviewer's draft omission must
# not suppress provenance for terms the approved review is still serving. But
# review_update() unconditionally sets review_approved = 0
# (functions/review-repository.R), so on the ordinary
# edit-then-approve-separately workflow that gate never opens: the term stops
# being served, yet its assertion stays `active_unconfirmed`. That is the SAFE
# direction -- nothing is ever mis-attributed -- but the suggestion-suppression
# signal is lost, and the curation queue goes on offering a term the entity no
# longer serves.
#
# The principle is the write path's own, applied one step later:
# APPROVAL IS WHEN THE SERVED SET BECOMES REAL.
#
# REJECTION-ONLY, DELIBERATELY
# ----------------------------
# `apply_confirmations = FALSE`. Approving a review is an act on the REVIEW, not
# a per-term reading of machine evidence. Promoting `active_unconfirmed` ->
# `confirmed` here would restore exactly the silent promotion #608 exists to
# stop. Confirmation stays an explicit act, on the review form or in the
# curation queue.
#
# NEVER OPENS A TRANSACTION. It only uses the `conn` handed to it, so its state
# transitions commit or roll back with the approval that triggered them.
#
# NEVER TOUCHES ndd_review_variation_ontology_connect. It only READS that table
# to learn what the entity currently serves; the curated write path in
# functions/ontology-repository.R remains the sole writer.

#' Read one entity's publicly served variation-ontology terms
#'
#' The served set is the terms on the entity's PRIMARY APPROVED reviews with an
#' active connect row -- byte-identical to the rule `svc_entity_variation()`
#' uses (services/entity-read-endpoint-service.R). Dropping any of the three
#' clauses would serve a different set than the entity page does, and the hook
#' would then retire the wrong assertions; the unit test asserts all three onto
#' the SQL text for that reason.
#'
#' Migrations 051-053 enforce `(review_id, entity_id)` agreement on the connect
#' table, so joining a connect row to its review by `review_id` alone is sound.
#'
#' @param entity_id Integer entity id.
#' @param conn Database connection or pool. Passed straight through; this
#'   function never opens a transaction.
#' @return Tibble(vario_id character, modifier_id integer). Possibly zero rows.
#' @export
variation_provenance_served_terms_for_entity <- function(entity_id, conn = NULL) {
  rows <- db_execute_query(
    "SELECT c.vario_id, c.modifier_id
       FROM ndd_review_variation_ontology_connect c
       JOIN ndd_entity_review r ON r.review_id = c.review_id
      WHERE c.entity_id = ?
        AND c.is_active = 1
        AND r.is_primary = 1
        AND r.review_approved = 1",
    list(as.integer(entity_id)),
    conn = conn
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(tibble::tibble(vario_id = character(), modifier_id = integer()))
  }

  tibble::tibble(
    vario_id    = as.character(rows$vario_id),
    modifier_id = as.integer(rows$modifier_id)
  )
}


#' Retire assertions the entity no longer serves, after a review approval
#'
#' Reads the served set AFTER the approval has been applied on `conn`, so it
#' observes the review this transaction just made primary and approved.
#'
#' AN EMPTY SERVED SET IS MEANINGFUL, not a reason to skip. Approval itself
#' creates the primary approved review, so an entity whose approved review
#' carries no variation terms legitimately serves none, and every open assertion
#' for it must be retired. A "skip when empty" guard would strand exactly the
#' assertions the curation queue exists to make tractable.
#'
#' Inertness fast path: an entity with no assertion rows returns 0L before the
#' served-set query is issued, so a database with an empty provenance layer pays
#' one cheap query per approved entity and nothing more.
#'
#' @param entity_id Integer entity id.
#' @param review_user_id Integer id of the approving user. Never used for
#'   attribution here -- no confirmation can be planned -- but passed through so
#'   a future confirmation edge cannot silently abort inside the applier.
#' @param conn Database connection or pool. Never opens a transaction.
#' @return Integer count of assertion rows updated.
#' @export
variation_provenance_reconcile_on_approval <- function(entity_id, review_user_id, conn = NULL) {
  previous <- variation_provenance_assertions_for_entity(entity_id, conn = conn)
  if (nrow(previous) == 0L) {
    return(0L)
  }

  served <- variation_provenance_served_terms_for_entity(entity_id, conn = conn)

  plan <- variation_provenance_plan_reconciliation(
    previous            = previous,
    submitted           = served,
    actions             = NULL,
    apply_rejections    = TRUE,
    apply_confirmations = FALSE
  )
  if (nrow(plan) == 0L) {
    return(0L)
  }

  variation_provenance_apply_reconciliation(
    plan, review_user_id = review_user_id, conn = conn
  )
}
