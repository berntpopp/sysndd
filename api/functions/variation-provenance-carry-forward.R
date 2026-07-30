# functions/variation-provenance-carry-forward.R
#
# Carry-forward of variation-ontology provenance assertions across an entity
# rename (#608). Extracted from variation-provenance-reconcile.R to keep both
# files under the repo's 600-line soft ceiling -- this is a pure code MOVE,
# not a rewrite; the review-save reconciliation state machine (the other half
# of #608) stays in variation-provenance-reconcile.R and this file adds no
# logic beyond what that split required.
#
# WHY THIS EXISTS
# ---------------
# entity-rename-service.R creates a BRAND NEW entity_id for a rename and
# copies the entity's curated variation-ontology connect-table rows onto it,
# but it says nothing about provenance. Provenance assertions are keyed on
# entity_id, so under variation-provenance-reconcile.R's own contract --
# absence of an assertion row means "curator-authored" -- the renamed
# entity's freshly copied terms would all read as curator-authored the
# instant they landed, even though nothing was reconfirmed: a rename only
# relocates rows to a new entity_id, it is not an act of confirmation. That
# is the exact fabrication the #608 provenance feature exists to prevent,
# reopened through a second channel. The fix is a plain, verbatim COPY of the
# old entity's assertion and evidence rows onto the new entity_id, called by
# svc_entity_rename_full() (entity-rename-service.R) inside its own rename
# transaction so the carry commits or rolls back atomically with the rest of
# the rename.
#
# MODULE LOAD ORDER
# ------------------
# bootstrap_load_modules() (api/bootstrap/load_modules.R) sources every entry
# of its `function_files` vector in order with a plain `for` loop, into one
# shared global environment. This file is registered immediately AFTER
# "functions/variation-provenance-reconcile.R" in that vector, which
# guarantees the reconcile module's definitions -- including
# .variation_provenance_identity_key(), the (vario_id, modifier_id) identity
# normalizer the reconcile state machine relies on -- are already bound in
# the global environment before this file is sourced. Do not move this entry
# ahead of variation-provenance-reconcile.R in that vector.

# ===========================================================================
# CARRY-FORWARD ACROSS AN ENTITY RENAME
# ---------------------------------------------------------------------------
# entity-rename-service.R creates a BRAND NEW entity_id for a rename and
# copies the curated connect-table rows onto it, but says nothing about
# provenance. Assertions are keyed on entity_id, so under this module's own
# contract (absence of a row == "curator-authored") the new entity's copied
# terms all read as curator-authored -- the fabrication this feature exists
# to prevent, via a second channel. Fix: a plain, verbatim COPY of the old
# entity's assertion/evidence rows onto the new entity_id.
# ===========================================================================

#' Copy the evidence rows attached to one assertion onto another assertion
#'
#' Idempotent via the destination's own UNIQUE key (assertion_id, source_key,
#' batch_id): a pre-existing destination row is left untouched, not duplicated.
#'
#' @keywords internal
.variation_provenance_carry_forward_evidence <- function(old_assertion_id, new_assertion_id, conn) {
  evidence <- db_execute_query(
    "SELECT source_type, source_key, batch_id, source_version,
            evidence_summary, evidence_strength, evidence_json
       FROM variation_ontology_evidence
      WHERE assertion_id = ?",
    list(old_assertion_id),
    conn = conn
  )

  if (is.null(evidence) || nrow(evidence) == 0L) {
    return(invisible(0L))
  }

  for (index in seq_len(nrow(evidence))) {
    source_key <- evidence$source_key[[index]]
    batch_id <- evidence$batch_id[[index]]

    existing <- db_execute_query(
      "SELECT evidence_id FROM variation_ontology_evidence
        WHERE assertion_id = ? AND source_key = ? AND batch_id = ?",
      list(new_assertion_id, source_key, batch_id),
      conn = conn
    )
    if (!is.null(existing) && nrow(existing) > 0L) {
      next
    }

    db_execute_statement(
      "INSERT INTO variation_ontology_evidence
         (assertion_id, source_type, source_key, batch_id, source_version,
          evidence_summary, evidence_strength, evidence_json)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      list(
        new_assertion_id,
        evidence$source_type[[index]],
        source_key,
        batch_id,
        evidence$source_version[[index]],
        evidence$evidence_summary[[index]],
        evidence$evidence_strength[[index]],
        evidence$evidence_json[[index]]
      ),
      conn = conn
    )
  }

  invisible(nrow(evidence))
}


#' Find-or-create the destination assertion row for one carried-forward row
#'
#' Idempotent via the destination's own UNIQUE key (entity_id, vario_id,
#' modifier_id): a matching row from a prior carry-forward call is reused
#' and NOT overwritten -- a repeat call must not re-stamp anything.
#'
#' @keywords internal
.variation_provenance_carry_forward_assertion <- function(new_entity_id, vario_id, modifier_id,
                                                           state, confirmed_by, confirmed_at,
                                                           rejected_reason, conn) {
  existing <- db_execute_query(
    "SELECT assertion_id FROM variation_ontology_assertion
      WHERE entity_id = ? AND vario_id = ? AND modifier_id = ?",
    list(new_entity_id, vario_id, modifier_id),
    conn = conn
  )
  if (!is.null(existing) && nrow(existing) > 0L) {
    return(as.integer(existing$assertion_id[[1L]]))
  }

  db_execute_statement(
    "INSERT INTO variation_ontology_assertion
       (entity_id, vario_id, modifier_id, state, confirmed_by, confirmed_at, rejected_reason)
     VALUES (?, ?, ?, ?, ?, ?, ?)",
    list(new_entity_id, vario_id, modifier_id, state, confirmed_by, confirmed_at, rejected_reason),
    conn = conn
  )

  as.integer(db_execute_query("SELECT LAST_INSERT_ID() AS id", conn = conn)$id[[1L]])
}

#' Carry forward one entity's provenance assertions (and evidence) to another
#' entity_id
#'
#' Called by svc_entity_rename_full() (entity-rename-service.R) inside its
#' existing rename transaction, on the same connection -- the carry commits
#' or rolls back with the rest of the rename atomically. COPY, not MOVE:
#' `old_entity_id`'s rows are left untouched (it may still be referenced via
#' `ndd_entity.replaced_by`, and its history must survive on its own).
#'
#' Preserves exactly, per assertion: vario_id, modifier_id, state,
#' confirmed_by, confirmed_at, rejected_reason. A `confirmed` row keeps its
#' ORIGINAL curator's attribution -- this function takes no "acting user"
#' parameter at all, so there is no identity it could re-attribute to even by
#' mistake. Per evidence row it preserves source_type, source_key, batch_id,
#' source_version, evidence_summary, evidence_strength, evidence_json,
#' re-attached to the NEW assertion's assertion_id.
#'
#' IDEMPOTENT (safe to call twice): both tables' own UNIQUE keys
#' (`uq_assertion`, `uq_evidence`) are consulted before every insert, so a
#' repeat call reuses what was already carried instead of duplicating.
#' INERT when `old_entity_id` has no assertion rows -- the normal case
#' today, since the backfill has not run. Never opens its own transaction.
#'
#' @param old_entity_id Integer id of the entity being replaced by the rename.
#' @param new_entity_id Integer id of the freshly created entity.
#' @param conn Database connection or pool. Passed straight through.
#' @return Integer count of `old_entity_id`'s assertion rows accounted for on
#'   `new_entity_id` after this call -- the SOURCE row count, so it is
#'   identical across repeat idempotent calls.
#' @export
variation_provenance_carry_forward_entity <- function(old_entity_id, new_entity_id, conn = NULL) {
  old_entity_id <- as.integer(old_entity_id)
  new_entity_id <- as.integer(new_entity_id)

  old_assertions <- db_execute_query(
    "SELECT assertion_id, vario_id, modifier_id, state, confirmed_by, confirmed_at, rejected_reason
       FROM variation_ontology_assertion
      WHERE entity_id = ?",
    list(old_entity_id),
    conn = conn
  )

  if (is.null(old_assertions) || nrow(old_assertions) == 0L) {
    return(0L)
  }

  for (index in seq_len(nrow(old_assertions))) {
    old_assertion_id <- as.integer(old_assertions$assertion_id[[index]])

    new_assertion_id <- .variation_provenance_carry_forward_assertion(
      new_entity_id   = new_entity_id,
      vario_id        = as.character(old_assertions$vario_id[[index]]),
      modifier_id     = as.integer(old_assertions$modifier_id[[index]]),
      state           = as.character(old_assertions$state[[index]]),
      confirmed_by    = old_assertions$confirmed_by[[index]],
      confirmed_at    = old_assertions$confirmed_at[[index]],
      rejected_reason = old_assertions$rejected_reason[[index]],
      conn = conn
    )

    .variation_provenance_carry_forward_evidence(
      old_assertion_id = old_assertion_id,
      new_assertion_id = new_assertion_id,
      conn = conn
    )
  }

  nrow(old_assertions)
}
