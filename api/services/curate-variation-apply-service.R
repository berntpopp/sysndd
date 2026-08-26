# api/services/curate-variation-apply-service.R
#
# The curation queue's two write actions (#612 Phase 6).
#
# THE ASYMMETRY IS THE WHOLE DESIGN
# ---------------------------------
# `provenance_for_entity()` (functions/variation-provenance-repository.R) filters
# the public read to state IN ('active_unconfirmed','confirmed'). Writing
# `rejected` onto an `active_unconfirmed` assertion drops it out of that filter
# WHILE THE TERM IS STILL SERVED, so the entity card renders it as
# CURATOR-AUTHORED -- the exact fabrication this feature exists to prevent.
# Therefore:
#
#   Confirm  requires state == 'active_unconfirmed' AND served
#   Dismiss  requires state == 'suggested'          AND NOT served
#
# The other direction of each pair would have to ADD or REMOVE a curated term,
# which is a review write and must go through review_write_mutate(). The queue
# links out to the entity for those. This module NEVER writes
# ndd_review_variation_ontology_connect -- it only reads it, through
# variation_provenance_served_terms_for_entity(), to learn what is served.
#
# CONCURRENCY
# -----------
# Re-deriving state and served membership on the server is necessary but not
# sufficient. A dismiss could read `suggested + not served`, a concurrent review
# write could add and approve that term, and the dismiss could then commit
# `rejected` onto a now-served assertion. So one batch is one transaction that:
#
#   1. SELECTs its assertion rows FOR UPDATE, ordered by assertion_id so two
#      concurrent batches take their locks in the same order and cannot deadlock;
#   2. re-reads served membership WHILE HOLDING those row locks;
#   3. writes with `... WHERE assertion_id = ? AND state = ?`, the state being
#      the one observed under the lock. A 0-row result means someone else got
#      there first, and is reported as `state_changed` rather than retried.
#
# This serializes against review_write_mutate(), whose reconciliation UPDATEs the
# very same assertion row for any term it adds or removes.
#
# REPORTING
# ---------
# Every skipped item is returned with its reason. "10 of 12 confirmed, 2 not
# served" is the honest answer; a silent partial success on a provenance surface
# is precisely the failure mode this feature exists to avoid.

CURATE_VARIATION_APPLY_ACTIONS <- c("confirm", "dismiss")
CURATE_VARIATION_APPLY_MAX_ITEMS <- 100L


#' Normalize the submitted batch into a list of records.
#'
#' THE SHAPE THAT ACTUALLY ARRIVES OVER HTTP. Plumber parses a request body with
#' `jsonlite::fromJSON(simplifyVector = TRUE)`, which collapses a uniform JSON
#' array of objects into a **data.frame**. `req$argsBody$items` is therefore a
#' data.frame whose `[[i]]` is a COLUMN -- an atomic vector, never a record --
#' so `.svc_cva_identity()` rejected every well-formed batch with
#' "items[1] must be an object", and `length()` counted COLUMNS rather than
#' items. Both queue actions were unusable from any real client.
#'
#' It stayed green because every test hand-built a list of lists, which is the
#' `simplifyVector = FALSE` shape. Exactly the trap documented for the
#' force-apply payload tables in `functions/async-job-force-apply-payload.R`;
#' accept both shapes here rather than depend on a parser setting.
#'
#' A non-collapsible array (mixed types) still arrives as a plain list, so it is
#' passed through untouched and the per-item validation below still rejects any
#' element that is not an object.
#' @noRd
.svc_cva_normalize_items <- function(items) {
  if (!is.data.frame(items)) {
    return(items)
  }
  if (nrow(items) == 0L) {
    return(list())
  }
  lapply(seq_len(nrow(items)), function(row) as.list(items[row, , drop = FALSE]))
}


#' Normalize one submitted identity, or raise a 400.
#'
#' A malformed identity is a client error, not an item to drop quietly: a caller
#' that mistyped a modifier must not read "0 applied" as "nothing to do".
#' @noRd
.svc_cva_identity <- function(entry, index) {
  bad <- function(field) {
    stop_for_bad_request(
      sprintf("items[%d].%s is missing or malformed.", index, field)
    )
  }
  if (!is.list(entry)) {
    stop_for_bad_request(sprintf("items[%d] must be an object.", index))
  }

  entity_raw <- trimws(as.character(entry$entity_id %||% "")[[1L]])
  if (!grepl("^[0-9]+$", entity_raw)) bad("entity_id")

  vario <- trimws(as.character(entry$vario_id %||% "")[[1L]])
  if (!grepl("^[A-Za-z][A-Za-z0-9]*:[A-Za-z0-9._-]+$", vario) || nchar(vario) > 32L) {
    bad("vario_id")
  }

  modifier_raw <- trimws(as.character(entry$modifier_id %||% "")[[1L]])
  if (!grepl("^[0-9]+$", modifier_raw)) bad("modifier_id")

  list(
    entity_id = as.integer(entity_raw),
    vario_id = vario,
    modifier_id = as.integer(modifier_raw)
  )
}

#' Identity key, case-normalized on vario_id.
#'
#' `variation_ontology_list.vario_id` collates case-insensitively in MySQL, so a
#' case variant names the SAME assertion. A case-sensitive comparison here would
#' report `not_served` for a term the entity does serve -- the same normalization
#' and the same reason as .variation_provenance_identity_key().
#' @noRd
.svc_cva_key <- function(vario_id, modifier_id) {
  paste0(toupper(as.character(vario_id)), "|", as.integer(modifier_id))
}

#' @noRd
.svc_cva_skip <- function(identity, reason) {
  list(
    entity_id = identity$entity_id,
    vario_id = identity$vario_id,
    modifier_id = identity$modifier_id,
    reason = reason
  )
}


#' Confirm or dismiss a batch of queued assertions
#'
#' @param items List of `{entity_id, vario_id, modifier_id}` objects, 1-100.
#' @param action `"confirm"` or `"dismiss"`.
#' @param review_user_id Acting curator. REQUIRED for `confirm`, which stamps
#'   attribution; unused by `dismiss`.
#' @param db Pool or caller-owned connection.
#' @return `list(requested, applied, skipped)`.
#' @export
svc_curate_variation_apply <- function(items, action, review_user_id, db) {
  if (length(action) != 1L || !action %in% CURATE_VARIATION_APPLY_ACTIONS) {
    stop_for_bad_request(
      paste0("action must be one of: ",
             paste(CURATE_VARIATION_APPLY_ACTIONS, collapse = ", "), ".")
    )
  }
  # BEFORE any length()/[[ ]] use: a data.frame's length() is its COLUMN count.
  items <- .svc_cva_normalize_items(items)

  if (is.null(items) || !is.list(items) || length(items) == 0L) {
    stop_for_bad_request("items must be a non-empty array.")
  }
  if (length(items) > CURATE_VARIATION_APPLY_MAX_ITEMS) {
    stop_for_bad_request(
      sprintf("items must contain at most %d entries.", CURATE_VARIATION_APPLY_MAX_ITEMS)
    )
  }

  # Attribution is validated BEFORE the lock: migration 047's
  # chk_confirmed_attribution forbids a confirmed row with a NULL confirmed_by,
  # so a malformed user id would otherwise surface as an opaque constraint
  # violation in the middle of the transaction.
  acting_user <- NA_integer_
  if (identical(action, "confirm")) {
    acting_user <- suppressWarnings(as.integer(
      trimws(as.character(review_user_id %||% NA)[[1L]])
    ))
    if (length(acting_user) != 1L || is.na(acting_user)) {
      stop_for_bad_request("A valid acting user id is required to confirm an assertion.")
    }
  }

  identities <- lapply(seq_along(items), function(i) .svc_cva_identity(items[[i]], i))

  db_with_savepoint_or_transaction(db, "curate_variation_apply", fn = function(conn) {
    .svc_cva_run(identities, action, acting_user, conn)
  })
}


#' The locked batch body. Never opens a transaction of its own.
#' @noRd
.svc_cva_run <- function(identities, action, acting_user, conn) {
  # One bound triple per item: DBI binds one scalar per `?`, so the values are
  # flattened in placeholder order -- never passed as a list of triples.
  placeholders <- paste(rep("(?, ?, ?)", length(identities)), collapse = ", ")
  values <- unlist(
    lapply(identities, function(id) list(id$entity_id, id$vario_id, id$modifier_id)),
    recursive = FALSE
  )

  locked <- db_execute_query(
    paste0(
      "SELECT a.assertion_id, a.entity_id, a.vario_id, a.modifier_id, a.state\n",
      "  FROM variation_ontology_assertion a\n",
      " WHERE (a.entity_id, a.vario_id, a.modifier_id) IN (", placeholders, ")\n",
      " ORDER BY a.assertion_id\n",
      "   FOR UPDATE"
    ),
    values,
    conn = conn
  )

  by_key <- list()
  if (!is.null(locked) && nrow(locked) > 0L) {
    for (i in seq_len(nrow(locked))) {
      key <- paste0(
        as.integer(locked$entity_id[[i]]), "#",
        .svc_cva_key(locked$vario_id[[i]], locked$modifier_id[[i]])
      )
      by_key[[key]] <- list(
        assertion_id = as.integer(locked$assertion_id[[i]]),
        state = as.character(locked$state[[i]])
      )
    }
  }

  # Served membership is re-read WHILE the row locks are held, once per distinct
  # entity rather than once per item.
  served_by_entity <- list()
  for (entity_id in unique(vapply(identities, function(id) id$entity_id, integer(1)))) {
    terms <- variation_provenance_served_terms_for_entity(entity_id, conn = conn)
    served_by_entity[[as.character(entity_id)]] <-
      .svc_cva_key(terms$vario_id, terms$modifier_id)
  }

  applied <- 0L
  skipped <- list()

  for (identity in identities) {
    key <- paste0(identity$entity_id, "#",
                  .svc_cva_key(identity$vario_id, identity$modifier_id))
    row <- by_key[[key]]

    if (is.null(row)) {
      skipped[[length(skipped) + 1L]] <- .svc_cva_skip(identity, "not_found")
      next
    }

    required_state <- if (identical(action, "confirm")) "active_unconfirmed" else "suggested"
    if (!identical(row$state, required_state)) {
      skipped[[length(skipped) + 1L]] <- .svc_cva_skip(identity, "wrong_state")
      next
    }

    is_served <- .svc_cva_key(identity$vario_id, identity$modifier_id) %in%
      (served_by_entity[[as.character(identity$entity_id)]] %||% character())

    if (identical(action, "confirm") && !is_served) {
      skipped[[length(skipped) + 1L]] <- .svc_cva_skip(identity, "not_served")
      next
    }
    if (identical(action, "dismiss") && isTRUE(is_served)) {
      skipped[[length(skipped) + 1L]] <- .svc_cva_skip(identity, "served")
      next
    }

    affected <- if (identical(action, "confirm")) {
      db_execute_statement(
        "UPDATE variation_ontology_assertion
            SET state = 'confirmed', confirmed_by = ?, confirmed_at = NOW()
          WHERE assertion_id = ? AND state = ?",
        list(acting_user, row$assertion_id, row$state),
        conn = conn
      )
    } else {
      db_execute_statement(
        "UPDATE variation_ontology_assertion
            SET state = 'rejected'
          WHERE assertion_id = ? AND state = ?",
        list(row$assertion_id, row$state),
        conn = conn
      )
    }

    if (identical(as.integer(affected), 0L)) {
      # Someone else changed this row between the lock and the write. Report it
      # rather than retrying: the winner's decision stands.
      skipped[[length(skipped) + 1L]] <- .svc_cva_skip(identity, "state_changed")
    } else {
      applied <- applied + 1L
    }
  }

  list(
    requested = length(identities),
    applied = as.integer(applied),
    skipped = skipped
  )
}
