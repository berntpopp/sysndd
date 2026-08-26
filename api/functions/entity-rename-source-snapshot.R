# api/functions/entity-rename-source-snapshot.R
#
# The source snapshot an entity rename copies forward, read INSIDE the rename's
# write transaction and under a row lock (#640).
#
# WHY THIS EXISTS
# ---------------
# svc_entity_rename_full() mints a NEW entity and copies the source entity's
# primary review, active status, publications, phenotypes and variation-ontology
# terms onto it. Those five reads used to run on the pool BEFORE the write
# transaction opened, which left a window: an approved review write that
# committed in the gap was copied over by the stale snapshot and silently
# discarded, while the source was deactivated with `replaced_by` pointing at an
# entity that did not reflect it.
#
# Post-#612 the consequence is worse than a lost update.
# variation_provenance_carry_forward_entity() copies each assertion's `state`
# verbatim, so a concurrent removal-and-approval could land a still-served
# connect row (from the stale read) beside a `rejected` assertion (from the
# fresh read) on the new entity. provenance_for_entity() filters the public read
# to ('active_unconfirmed','confirmed'), so that term then renders as
# CURATOR-AUTHORED -- the exact fabrication #608 exists to prevent.
#
# WHY A LOCK, AND WHY THIS ONE
# ----------------------------
# Reading inside the transaction is necessary but not sufficient: InnoDB's
# REPEATABLE READ snapshot is taken at the transaction's first read, while
# writes see the latest committed rows, so a consistent read alone still leaves
# a window. A LOCKING read closes it -- the rename holds the source's review
# rows until it commits, and any concurrent review save or approval for that
# entity blocks behind it (review_write_mutate() and review_approve() both write
# ndd_entity_review, so they contend on exactly these rows).
#
# The lock is deliberately scoped to ONE entity's rows, never the table. This is
# NOT the contention migration 049 avoided: that was a shared parent-row lock on
# ndd_entity_review taken once per each of ~8,083 evidence rows during a bulk
# backfill. A rename is a rare, interactive Curator action touching a handful of
# rows for a single entity.

#' Read and lock everything a rename copies forward.
#'
#' MUST be called with `conn` = the rename's transaction connection. Passing a
#' pool would put the `FOR UPDATE` in its own short transaction, releasing the
#' lock immediately and restoring the race this function exists to close.
#'
#' @param old_entity_id Source entity id.
#' @param conn The rename's open transaction connection.
#' @return list(review, status, publications, phenotypes, vario) of tibbles.
#' @export
svc_entity_rename_load_source <- function(old_entity_id, conn) {
  if (is.null(conn) || inherits(conn, "Pool")) {
    stop(
      "svc_entity_rename_load_source() requires the rename's transaction ",
      "connection; a pool would release the row lock immediately.",
      call. = FALSE
    )
  }

  # Lock EVERY review row of this entity, not just the primary one: an approval
  # can change WHICH row is primary, so locking only `is_primary = 1` would let
  # a concurrent approval promote a different row underneath us.
  db_execute_query(
    "SELECT review_id FROM ndd_entity_review WHERE entity_id = ? FOR UPDATE",
    list(old_entity_id),
    conn = conn
  )

  review <- tibble::as_tibble(db_execute_query(
    paste(
      "SELECT * FROM ndd_entity_review",
      "WHERE entity_id = ? AND is_primary = 1"
    ),
    list(old_entity_id),
    conn = conn
  ))

  status <- tibble::as_tibble(db_execute_query(
    paste(
      "SELECT * FROM ndd_entity_status",
      "WHERE entity_id = ? AND is_active = 1 FOR UPDATE"
    ),
    list(old_entity_id),
    conn = conn
  ))

  if (nrow(status) == 0) {
    # Classed so the caller maps it to the same 409 it returned when this check
    # ran before the transaction, rather than a generic 500.
    rlang::abort(
      message = "Active source status could not be loaded for rename.",
      class = "entity_rename_missing_status_error"
    )
  }

  empty <- tibble::tibble()
  if (nrow(review) == 0) {
    return(list(
      review = review, status = status,
      publications = empty, phenotypes = empty, vario = empty
    ))
  }

  review_id <- review$review_id[[1]]
  select_for_review <- function(sql) {
    tibble::as_tibble(db_execute_query(sql, list(review_id), conn = conn))
  }

  list(
    review = review,
    status = status,
    publications = select_for_review(
      paste(
        "SELECT publication_id, publication_type",
        "FROM ndd_review_publication_join WHERE review_id = ?"
      )
    ),
    phenotypes = select_for_review(
      paste(
        "SELECT phenotype_id, modifier_id",
        "FROM ndd_review_phenotype_connect WHERE review_id = ?"
      )
    ),
    vario = select_for_review(
      paste(
        "SELECT vario_id, modifier_id",
        "FROM ndd_review_variation_ontology_connect WHERE review_id = ?"
      )
    )
  )
}
