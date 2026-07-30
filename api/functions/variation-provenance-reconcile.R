# functions/variation-provenance-reconcile.R
#
# Write reconciliation for variation-ontology provenance assertions (#608).
#
# WHY THIS EXISTS
# ---------------
# SysNDD's curation forms prefill their variation-ontology picker from the
# entity's existing terms, so a curator editing one sentence of synopsis gets
# every existing term pre-checked, and saving rewrites all of them onto a new,
# curator-attributed review. No user action distinguishes "I read the papers and
# agree" from "I did not notice the pre-checked box" -- which is how
# machine-imported annotations silently become curator-authored. Three frontend
# surfaces do this prefill-and-resubmit (useEntityInfo.ts, useReviewForm.ts,
# useReviewApprovalActions.ts) and only two route submission through the shared
# tag helper, so correctness CANNOT depend on a client sending the right field.
# The server reconciles the previous assertion set against the submitted set.
#
# ARCHITECTURE: pure planner + thin applier
# -----------------------------------------
#   variation_provenance_plan_reconciliation()   PURE -- no SQL, no side effects
#   variation_provenance_assertions_for_entity() SQL read
#   variation_provenance_apply_reconciliation()  SQL write
#   variation_provenance_reconcile_for_review()  orchestrator
#
# This module NEVER touches ndd_review_variation_ontology_connect (the curated
# write path in functions/ontology-repository.R is untouched) and never opens a
# transaction -- it only ever uses the `conn` handed to it, so it behaves
# identically under db_with_transaction() and under the caller-owned
# SAVEPOINT review_write_mutation branch used by with_test_db_transaction().
#
# THE STATE MACHINE -- this table is the specification
# ---------------------------------------------------
# Identity is (vario_id, modifier_id) within one entity_id, compared
# case-INSENSITIVELY (see .variation_provenance_identity_key). Rows marked
# (spec) are the design spec's own section 5.3 rows; the rest are the documented
# extensions that make the machine total.
#
# | Submitted? | Previous state     | provenance_action      | New state                      | Attribution            |
# |------------|--------------------|------------------------|--------------------------------|------------------------|
# | yes        | active_unconfirmed | absent / not "confirm" | active_unconfirmed (unchanged) | --              (spec) |
# | yes        | active_unconfirmed | "confirm"              | confirmed                      | confirmed_by/at (spec) |
# | yes        | suggested          | any                    | confirmed                      | confirmed_by/at        |
# | yes        | confirmed          | any                    | confirmed (unchanged)          | DO NOT re-stamp        |
# | yes        | rejected           | any                    | confirmed                      | confirmed_by/at        |
# | yes        | (no assertion row) | any                    | no row created                 | --              (spec) |
# | no         | active_unconfirmed | --                     | rejected                       | --              (spec) |
# | no         | suggested          | --                     | rejected                       | --              (spec) |
# | no         | confirmed          | --                     | confirmed (unchanged)          | --                     |
# | no         | rejected           | --                     | rejected (unchanged)           | --                     |
#
# The two rejection rows additionally require `apply_rejections = TRUE`; the
# confirmation rows always apply. See the planner's @param apply_rejections for
# the rule and why it exists.
#
# Why each extension is what it is
# --------------------------------
# * submitted + suggested -> confirmed. A `suggested` assertion is not in the
#   curated set, so no prefill surface can pre-check it (all three prefill from
#   the entity's current terms). It can only appear in a submission because a
#   curator deliberately added it -- an affirmative act, so it earns attribution.
#   Server-authoritative, so it works for a client that sends no action field.
# * submitted + confirmed -> unchanged. Re-saving must not overwrite the original
#   curator's attribution with the current saver's; the confirmation is
#   historical. Structural rather than conditional: from_state == to_state, so
#   the row never reaches the applier.
# * submitted + rejected -> confirmed. A curator who previously declined and is
#   now asserting performed a fresh affirmative act; fresh attribution, and the
#   suppression lifts.
# * omitted + confirmed -> unchanged. Rejection is deliberately limited to
#   active_unconfirmed/suggested. A confirmed row for a removed term is invisible
#   (the read path joins on the full identity against the terms actually served)
#   and its history survives a re-add. Do not "improve" this into a rejection.
# * omitted + rejected -> unchanged. Already suppressed.
#
# THE two regression assertions for the original bug: (a) row 1 -- a save with no
# provenance_action leaves an active_unconfirmed assertion active_unconfirmed;
# (b) the apply_rejections rule -- a draft save never rejects. Confirmation is an
# act, not a side effect; removal is public, not a draft.
#
# INERTNESS
# ---------
# With zero assertion rows for the entity, reconciliation is a strict no-op: no
# UPDATE, no INSERT, not even a plan built. The backfill that populates these
# tables lives in a different repository and has not run yet, so this path is
# provably inert on production traffic today.

#' The ONLY provenance_action value that confirms.
#'
#' Anything else -- absent, NULL, NA, empty, a different verb, or a different
#' capitalisation -- falls through to "no action". Fail-closed on purpose: an
#' unrecognised action must never be read as a confirmation.
VARIATION_PROVENANCE_CONFIRM_ACTION <- "confirm"


#' Empty reconciliation plan with the exact column contract
#'
#' @return Zero-row tibble(assertion_id integer, from_state character,
#'   to_state character, needs_attribution logical).
#' @export
variation_provenance_empty_plan <- function() {
  tibble::tibble(
    assertion_id      = integer(),
    from_state        = character(),
    to_state          = character(),
    needs_attribution = logical()
  )
}


#' Build the (vario_id, modifier_id) identity key
#'
#' Both halves are normalized so an identity R considers different but the
#' DATABASE considers the same can never split. A stored assertion whose key
#' fails to match the submission looks OMITTED, so it transitions to `rejected`,
#' drops out of the read path's `state IN ('active_unconfirmed','confirmed')`
#' filter, and the still-served term then presents as curator-authored -- the
#' exact fabrication this module exists to prevent.
#'
#' * `vario_id` is upper-cased. `variation_ontology_list.vario_id` is
#'   `utf8mb4_0900_ai_ci` (see migration 047's charset ruling), i.e. case-
#'   INsensitive, so `review_write_validate_lookup_ids()` accepts a submitted
#'   `vario:0017` and the connect row is written -- while a case-SENSITIVE R
#'   comparison would not match the stored `VariO:0017`. Applied to both sides of
#'   every comparison, so one normalization here suffices. VariO ids are ASCII, so
#'   `toupper()` is locale-safe.
#' * `modifier_id` is coerced to integer so a submitted `"1"` (Plumber/jsonlite
#'   can hand numbers over as strings) matches a stored `1L`.
#'
#' @keywords internal
.variation_provenance_identity_key <- function(vario_id, modifier_id) {
  paste(
    toupper(trimws(as.character(vario_id))),
    suppressWarnings(as.integer(trimws(as.character(modifier_id)))),
    sep = "|"
  )
}


#' Coerce a term/action table to a data frame carrying the required columns
#'
#' Accepts a data.frame/tibble (including the zero-row case) or a list that
#' `tibble::as_tibble()` can widen. A genuinely EMPTY input is always fine.
#'
#' An UNPARSEABLE input is not. For `previous`/`actions`, degrading it to zero
#' rows is the safe direction. For `submitted` it is the destructive one: empty
#' means "the curator removed every term", so an unparseable payload would reject
#' every active_unconfirmed/suggested assertion for the entity. That caller passes
#' `strict = TRUE` and gets a loud, classed failure instead.
#'
#' @param strict Raise `variation_provenance_unparseable_input` instead of
#'   degrading an unparseable (as opposed to empty) input to zero rows.
#' @keywords internal
.variation_provenance_as_rows <- function(x, required, strict = FALSE) {
  empty <- function() {
    out <- tibble::tibble(.rows = 0L)
    for (name in required) {
      out[[name]] <- character()
    }
    out
  }
  degrade <- function() {
    if (strict) {
      rlang::abort(
        message = paste(
          "Unparseable variation-ontology term set; refusing to reconcile",
          "provenance rather than treating it as an empty submission."
        ),
        class = "variation_provenance_unparseable_input"
      )
    }
    empty()
  }

  if (is.null(x) || length(x) == 0L) {
    return(empty())
  }
  if (!is.data.frame(x)) {
    if (!is.list(x)) {
      return(degrade())
    }
    x <- tryCatch(tibble::as_tibble(x), error = function(error) NULL)
    if (is.null(x) || !is.data.frame(x)) {
      return(degrade())
    }
  }
  if (nrow(x) == 0L) {
    return(empty())
  }

  for (name in required) {
    if (!name %in% names(x)) {
      x[[name]] <- NA
    }
  }
  x
}


#' Identity keys of the submitted term set
#'
#' `strict = TRUE`: an unparseable submitted set must never be mistaken for an
#' empty one, because empty drives rejection.
#'
#' @keywords internal
.variation_provenance_submitted_keys <- function(submitted) {
  submitted <- .variation_provenance_as_rows(
    submitted, c("vario_id", "modifier_id"), strict = TRUE
  )
  if (nrow(submitted) == 0L) {
    return(character(0))
  }
  unique(.variation_provenance_identity_key(submitted$vario_id, submitted$modifier_id))
}


#' Identity keys whose submitted action is an explicit confirmation
#'
#' A confirmation anywhere among duplicate entries for one identity confirms
#' that identity -- taking the union of keys makes duplicate submissions
#' idempotent for free.
#'
#' @keywords internal
.variation_provenance_confirm_keys <- function(actions) {
  actions <- .variation_provenance_as_rows(
    actions, c("vario_id", "modifier_id", "provenance_action")
  )
  if (nrow(actions) == 0L) {
    return(character(0))
  }

  action <- trimws(as.character(actions$provenance_action))
  confirms <- !is.na(action) & action == VARIATION_PROVENANCE_CONFIRM_ACTION
  if (!any(confirms)) {
    return(character(0))
  }

  unique(.variation_provenance_identity_key(
    actions$vario_id[confirms], actions$modifier_id[confirms]
  ))
}


#' Plan the state transitions for one entity's assertions (PURE)
#'
#' Implements the state-machine table in this file's header verbatim. Contains
#' no SQL and no side effects.
#'
#' Only genuine transitions are returned: a row whose new state equals its old
#' state is dropped, so the applier can never issue a pointless UPDATE (and, for
#' the submitted + confirmed row, can never re-stamp attribution).
#'
#' @param previous Tibble with assertion_id, vario_id, modifier_id, state --
#'   ALL states for the entity, as returned by
#'   variation_provenance_assertions_for_entity().
#' @param submitted Tibble with vario_id, modifier_id (duplicates allowed).
#' @param actions Optional tibble with vario_id, modifier_id,
#'   provenance_action, as returned by
#'   review_write_extract_provenance_actions(). NULL means "the client sent no
#'   provenance fields at all", which is the common case today.
#' @param apply_rejections Whether the omitted-term rejection edges (rows 7 and
#'   8) apply. Confirmation edges are NEVER gated by this.
#'
#'   THE RULE: **confirmation transitions always apply; rejection transitions
#'   apply only when the save actually determines the entity's served term set.**
#'
#'   Assertions are entity-scoped, but the publicly served terms come from the
#'   PRIMARY APPROVED review. A Reviewer's draft POST that omits a term -- or that
#'   omits `variation_ontology` entirely, which normalizes to a zero-row set and
#'   so omits EVERYTHING -- is not a statement about the served set. Applying rows
#'   7/8 to it would reject every assertion for the entity while the approved
#'   review keeps serving those very terms, so they would present as
#'   curator-authored; rows 9/10 make the omitted branch terminal, so an abandoned
#'   draft would suppress provenance permanently. Rows 7/8 and the spec's primary
#'   goal contradict each other here, and the goal governs. Deferring rejection is
#'   also more faithful to rows 7/8's purpose ("makes removal correct for every
#'   surface"): removal becomes real when it becomes public. `review_write_mutate()`
#'   computes the flag, so the planner stays pure and never queries the DB for it.
#' @return Tibble(assertion_id, from_state, to_state, needs_attribution).
#' @export
variation_provenance_plan_reconciliation <- function(previous, submitted, actions = NULL,
                                                    apply_rejections = TRUE) {
  previous <- .variation_provenance_as_rows(
    previous, c("assertion_id", "vario_id", "modifier_id", "state")
  )
  if (nrow(previous) == 0L) {
    return(variation_provenance_empty_plan())
  }

  from_state <- as.character(previous$state)
  # A NULL/NA stored state cannot occur (the column is a NOT NULL ENUM), but an
  # NA here would poison every logical index below with NAs, which R refuses in
  # subscripted assignment. Map it to "" so every branch evaluates FALSE and
  # the row is simply left alone.
  from_state[is.na(from_state)] <- ""

  previous_keys <- .variation_provenance_identity_key(
    previous$vario_id, previous$modifier_id
  )
  is_submitted <- previous_keys %in% .variation_provenance_submitted_keys(submitted)
  confirm_requested <- previous_keys %in% .variation_provenance_confirm_keys(actions)

  to_state <- from_state
  # Submitted branch (rows 1-5). Never gated: an affirmative act is always
  # honoured, on a draft save exactly as on an approved one.
  to_state[is_submitted & from_state == "suggested"] <- "confirmed"
  to_state[is_submitted & from_state == "rejected"] <- "confirmed"
  to_state[is_submitted & from_state == "active_unconfirmed" & confirm_requested] <- "confirmed"
  # Omitted branch (rows 7-10; confirmed and rejected are deliberately absent),
  # gated on the save determining the served term set -- see @param
  # apply_rejections. A non-logical/NA flag is treated as FALSE: the safe
  # direction is to leave the assertion alone.
  if (isTRUE(apply_rejections)) {
    to_state[!is_submitted & from_state %in% c("active_unconfirmed", "suggested")] <- "rejected"
  }

  changed <- to_state != from_state

  tibble::tibble(
    assertion_id      = as.integer(previous$assertion_id)[changed],
    from_state        = from_state[changed],
    to_state          = to_state[changed],
    needs_attribution = to_state[changed] == "confirmed" & from_state[changed] != "confirmed"
  )
}


#' Read every assertion for one entity
#'
#' Deliberately UNFILTERED by state. The public read path
#' (functions/variation-provenance-repository.R) correctly filters to
#' state IN ('active_unconfirmed','confirmed'), but the state machine needs the
#' `suggested` and `rejected` rows too: a submitted rejected term must be
#' liftable back to confirmed, and a submitted suggested term must be
#' confirmable. Filtering here would silently break both.
#'
#' @param entity_id Integer entity id.
#' @param conn Database connection or pool. Passed straight through; this
#'   function never opens a transaction.
#' @return Tibble(assertion_id integer, vario_id character,
#'   modifier_id integer, state character).
#' @export
variation_provenance_assertions_for_entity <- function(entity_id, conn = NULL) {
  rows <- db_execute_query(
    "SELECT assertion_id, vario_id, modifier_id, state
       FROM variation_ontology_assertion
      WHERE entity_id = ?",
    list(as.integer(entity_id)),
    conn = conn
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(tibble::tibble(
      assertion_id = integer(), vario_id = character(),
      modifier_id = integer(), state = character()
    ))
  }

  tibble::tibble(
    assertion_id = as.integer(rows$assertion_id),
    vario_id     = as.character(rows$vario_id),
    modifier_id  = as.integer(rows$modifier_id),
    state        = as.character(rows$state)
  )
}


#' Apply a reconciliation plan (thin SQL)
#'
#' One UPDATE per planned transition, on the caller's connection, with no
#' transaction of its own. Attribution (confirmed_by / confirmed_at) is stamped
#' only for transitions INTO confirmed from a different state.
#'
#' @param plan Tibble as returned by variation_provenance_plan_reconciliation().
#' @param review_user_id Integer id of the saving user. Required only when the
#'   plan contains a confirmation.
#' @param conn Database connection or pool.
#' @return Integer count of rows updated.
#' @export
variation_provenance_apply_reconciliation <- function(plan, review_user_id, conn = NULL) {
  if (is.null(plan) || !is.data.frame(plan) || nrow(plan) == 0L) {
    return(0L)
  }

  needs_attribution <- as.logical(plan$needs_attribution)
  needs_attribution[is.na(needs_attribution)] <- FALSE

  user_id <- NA_integer_
  if (any(needs_attribution)) {
    user_id <- suppressWarnings(as.integer(review_user_id))
    if (length(user_id) != 1L || is.na(user_id)) {
      # migration 047's chk_confirmed_attribution forbids a confirmed row with
      # a NULL confirmed_by, so proceeding would surface as an opaque
      # constraint violation mid-transaction. Fail with a named class instead.
      rlang::abort(
        message = paste(
          "review_user_id is required to attribute a confirmed",
          "variation-ontology assertion."
        ),
        class = "variation_provenance_attribution_error"
      )
    }
  }

  updated <- 0L
  for (index in seq_len(nrow(plan))) {
    assertion_id <- as.integer(plan$assertion_id[[index]])
    to_state <- as.character(plan$to_state[[index]])

    affected <- if (needs_attribution[[index]]) {
      db_execute_statement(
        "UPDATE variation_ontology_assertion
            SET state = ?, confirmed_by = ?, confirmed_at = NOW()
          WHERE assertion_id = ?",
        list(to_state, user_id, assertion_id),
        conn = conn
      )
    } else {
      db_execute_statement(
        "UPDATE variation_ontology_assertion
            SET state = ?
          WHERE assertion_id = ?",
        list(to_state, assertion_id),
        conn = conn
      )
    }

    updated <- updated + as.integer(affected)
  }

  updated
}


#' Reconcile one entity's assertions against a submitted term set
#'
#' The orchestrator review_write_mutate() calls, on the review-save
#' transaction's connection. Never opens a transaction of its own.
#'
#' Inertness fast path: an entity with no assertion rows returns 0L before any
#' plan is built and without issuing a single write statement.
#'
#' @param entity_id Integer entity id.
#' @param submitted Normalized submitted terms (vario_id, modifier_id).
#' @param actions Optional provenance actions, as returned by
#'   review_write_extract_provenance_actions().
#' @param review_user_id Integer id of the saving user.
#' @param conn Database connection or pool.
#' @param apply_rejections Whether this save determines the entity's served term
#'   set, and may therefore reject omitted terms. Passed straight to the planner;
#'   the caller decides (review_write_mutate()), so this stays a pure passthrough.
#' @return Integer count of assertion rows updated.
#' @export
variation_provenance_reconcile_for_review <- function(entity_id, submitted, actions,
                                                      review_user_id, conn = NULL,
                                                      apply_rejections = TRUE) {
  previous <- variation_provenance_assertions_for_entity(entity_id, conn = conn)
  if (nrow(previous) == 0L) {
    return(0L)
  }

  plan <- variation_provenance_plan_reconciliation(
    previous = previous, submitted = submitted, actions = actions,
    apply_rejections = apply_rejections
  )
  if (nrow(plan) == 0L) {
    return(0L)
  }

  variation_provenance_apply_reconciliation(
    plan, review_user_id = review_user_id, conn = conn
  )
}
