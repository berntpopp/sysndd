# Focused review-save coordinator.
#
# Phase A prepares and validates without a write transaction. Phase B performs
# every review-related mutation on one connection, so a late join failure rolls
# back the review, all joins, the re-review marker, and optional approval.

review_write_assert_raw_ontology_fields <- function(terms, id_field) {
  if (is.null(terms) || length(terms) == 0L) {
    return(invisible(TRUE))
  }

  assert_row <- function(row) {
    row_names <- names(row)
    uses_tag <- "value" %in% row_names
    id_value <- if (uses_tag) row$value else row[[id_field]]
    if (is.null(id_value) ||
        (is.list(id_value) && any(vapply(id_value, is.null, logical(1))))) {
      stop_for_bad_request(paste0(id_field, " must be a non-blank ontology identifier."))
    }

    if (!uses_tag && "modifier_id" %in% row_names) {
      modifier_value <- row$modifier_id
      if (is.null(modifier_value) ||
          (is.list(modifier_value) && any(vapply(modifier_value, is.null, logical(1))))) {
        stop_for_bad_request(paste0("modifier_id for ", id_field, " must be an integer."))
      }
    }

    invisible(TRUE)
  }

  if (is.data.frame(terms)) {
    assert_row(terms)
  } else if (is.list(terms)) {
    term_names <- names(terms)
    is_row <- !is.null(term_names) &&
      any(c("value", id_field, "modifier_id") %in% term_names)
    if (is_row) {
      assert_row(terms)
    } else {
      lapply(terms, function(term) {
        if (is.list(term) || is.data.frame(term)) {
          assert_row(term)
        }
        invisible(TRUE)
      })
    }
  }

  invisible(TRUE)
}

review_write_empty_terms <- function(id_field) {
  out <- tibble::tibble(modifier_id = integer())
  out[[id_field]] <- character()
  dplyr::select(out, dplyr::all_of(c(id_field, "modifier_id")))
}

review_write_normalize_ontology <- function(terms, id_field) {
  if (is.null(terms) || length(terms) == 0L) {
    return(review_write_empty_terms(id_field))
  }

  review_write_assert_raw_ontology_fields(terms, id_field)
  terms <- tibble::as_tibble(terms)
  if (nrow(terms) == 0L) {
    return(review_write_empty_terms(id_field))
  }

  if ("value" %in% names(terms)) {
    value <- as.character(terms$value)
    separator <- regexpr("-", value, fixed = TRUE)
    modifier <- ifelse(separator > 0L, substr(value, 1L, separator - 1L), NA_character_)
    ontology_id <- ifelse(separator > 0L, substr(value, separator + 1L, nchar(value)), NA_character_)
  } else {
    if (!id_field %in% names(terms) || !"modifier_id" %in% names(terms)) {
      stop_for_bad_request(
        paste0("Each ontology row requires ", id_field, " and modifier_id.")
      )
    }
    ontology_id <- as.character(terms[[id_field]])
    modifier <- terms$modifier_id
  }

  ontology_id <- trimws(ontology_id)
  if (any(is.na(ontology_id) | !nzchar(ontology_id))) {
    stop_for_bad_request(paste0(id_field, " must be a non-blank ontology identifier."))
  }

  modifier_id <- suppressWarnings(as.integer(trimws(as.character(modifier))))
  if (any(is.na(modifier_id))) {
    stop_for_bad_request(paste0("modifier_id for ", id_field, " must be an integer."))
  }

  out <- tibble::tibble(modifier_id = modifier_id)
  out[[id_field]] <- ontology_id
  dplyr::select(out, dplyr::all_of(c(id_field, "modifier_id")))
}

# --- Variation-ontology provenance actions ---------------------------------
#
# review_write_normalize_ontology() above deliberately reduces each submitted
# term to exactly (vario_id, modifier_id): it is shared with the phenotype path
# (which has no provenance) and its two-column output is the connect-table write
# payload. Widening it would push an unused column into that write and break its
# existing contract.
#
# So the provenance action is read from the RAW submission instead, before
# normalization, by the extractor below. It returns a separate table that only
# the reconciliation consumes; the curated-write payload is unchanged.

#' Zero-row provenance-action table with the exact column contract
#'
#' @keywords internal
review_write_empty_provenance_actions <- function() {
  tibble::tibble(
    vario_id          = character(),
    modifier_id       = integer(),
    provenance_action = character()
  )
}

#' Normalize a raw variation-ontology payload to a list of records
#'
#' The three prefill-and-resubmit frontend surfaces differ, and Plumber's body
#' parser uses jsonlite with `simplifyVector = TRUE`, so the payload arrives as
#' any of: NULL, `list()`, one un-nested record, a list of records, or a
#' data.frame (a uniform JSON array of objects simplifies to exactly that).
#'
#' The data.frame case is the trap: iterating a data.frame walks its COLUMNS
#' (atomic vectors), so `vapply(payload, function(x) x$vario_id, ...)` dies with
#' "$ operator is invalid for atomic vectors" -- see the
#' async-job-force-apply-payload.R note in AGENTS.md. Shape is therefore
#' normalized before any field is touched.
#'
#' @keywords internal
review_write_provenance_records <- function(variation_ontology) {
  if (is.null(variation_ontology) || length(variation_ontology) == 0L) {
    return(list())
  }

  if (is.data.frame(variation_ontology)) {
    return(lapply(
      seq_len(nrow(variation_ontology)),
      function(index) as.list(variation_ontology[index, , drop = FALSE])
    ))
  }

  if (!is.list(variation_ontology)) {
    # A bare vector carries no field names; review_write_normalize_ontology()
    # rejects that shape with a 400, so degrade quietly here.
    return(list())
  }

  record_fields <- c("value", "vario_id", "modifier_id", "provenance_action")
  payload_names <- names(variation_ontology)
  if (!is.null(payload_names) && any(record_fields %in% payload_names)) {
    return(list(variation_ontology))
  }

  variation_ontology
}

#' Read one scalar character field out of a single raw record
#'
#' @keywords internal
review_write_provenance_field <- function(record, field) {
  if (!is.list(record) && !is.data.frame(record)) {
    return(NA_character_)
  }
  if (!field %in% names(record)) {
    return(NA_character_)
  }

  value <- record[[field]]
  if (is.null(value) || length(value) == 0L) {
    return(NA_character_)
  }

  value <- as.character(value[[1L]])
  if (length(value) != 1L || is.na(value)) {
    return(NA_character_)
  }
  value
}

#' Extract per-term provenance actions from the RAW submitted payload
#'
#' Handles every raw shape the payload actually arrives in (see
#' review_write_provenance_records()). A `value` tag
#' `"<modifier_id>-<vario_id>"` is split on the FIRST "-" only -- mirroring the
#' normalizer's own `regexpr("-", value, fixed = TRUE)` approach -- because a
#' VariO id can itself contain a hyphen and numeric coercion of the ontology
#' half is the #600 bug (see app/src/utils/ontologyTags.ts).
#'
#' Rows whose identity is unusable (blank vario_id, non-integer modifier_id) are
#' DROPPED rather than raising: this is a best-effort projection of the payload
#' used only as a lookup keyed by identity, and review_write_normalize_ontology()
#' owns the client-visible 400 for a genuinely malformed submission.
#'
#' Rows with no action are still returned, with `provenance_action = NA`, so the
#' result is a faithful, debuggable projection of the submitted set. Missing,
#' NULL, NA and blank actions all become NA_character_ -- never "confirm".
#' Whitespace is trimmed (consistent with this file's other identifier
#' handling), but case is NOT folded: only the exact string "confirm" confirms,
#' and any other value falls through to "no action" (fail-closed).
#'
#' @param variation_ontology Raw submitted variation-ontology payload.
#' @return Tibble(vario_id character, modifier_id integer,
#'   provenance_action character).
#' @export
review_write_extract_provenance_actions <- function(variation_ontology) {
  records <- review_write_provenance_records(variation_ontology)
  if (length(records) == 0L) {
    return(review_write_empty_provenance_actions())
  }

  parsed <- lapply(records, function(record) {
    tag <- review_write_provenance_field(record, "value")
    if (!is.na(tag)) {
      separator <- regexpr("-", tag, fixed = TRUE)
      if (separator > 0L) {
        modifier <- substr(tag, 1L, separator - 1L)
        ontology_id <- substr(tag, separator + 1L, nchar(tag))
      } else {
        modifier <- NA_character_
        ontology_id <- NA_character_
      }
    } else {
      ontology_id <- review_write_provenance_field(record, "vario_id")
      modifier <- review_write_provenance_field(record, "modifier_id")
    }

    action <- review_write_provenance_field(record, "provenance_action")
    if (!is.na(action)) {
      action <- trimws(action)
      if (!nzchar(action)) {
        action <- NA_character_
      }
    }

    list(
      vario_id = if (is.na(ontology_id)) NA_character_ else trimws(ontology_id),
      modifier_id = suppressWarnings(as.integer(trimws(as.character(modifier)))),
      provenance_action = action
    )
  })

  out <- tibble::tibble(
    vario_id          = vapply(parsed, function(row) row$vario_id, character(1)),
    modifier_id       = vapply(parsed, function(row) row$modifier_id, integer(1)),
    provenance_action = vapply(parsed, function(row) row$provenance_action, character(1))
  )

  usable <- !is.na(out$vario_id) & nzchar(out$vario_id) & !is.na(out$modifier_id)
  out[usable, , drop = FALSE]
}

review_write_validate_required <- function(value, field) {
  if (is.null(value) || length(value) != 1L || is.na(value) ||
      (is.character(value) && !nzchar(trimws(value)))) {
    stop_for_bad_request(paste0(field, " is required."))
  }
  invisible(TRUE)
}

review_write_validate_lookup_ids <- function(ids, table, column, db) {
  if (length(ids) == 0L) {
    return(invisible(TRUE))
  }

  ids <- unique(as.character(ids))
  placeholders <- paste(rep("?", length(ids)), collapse = ", ")
  found <- db_execute_query(
    paste0("SELECT ", column, " FROM ", table, " WHERE ", column, " IN (", placeholders, ")"),
    as.list(ids),
    conn = db
  )[[column]]
  invalid <- setdiff(ids, as.character(found))
  if (length(invalid) > 0L) {
    stop_for_bad_request(
      paste0(column, " contains unknown ontology identifier(s): ", paste(invalid, collapse = ", "))
    )
  }

  invisible(TRUE)
}

review_write_prepare <- function(method, review_data, publications,
                                 phenotypes, variation_ontology,
                                 review_user_id, db) {
  method <- toupper(as.character(method))
  if (!method %in% c("POST", "PUT")) {
    stop_for_bad_request("Review write method must be POST or PUT.")
  }

  review_write_validate_required(review_data$entity_id, "entity_id")
  review_write_validate_required(review_data$synopsis, "synopsis")
  review_write_validate_required(review_user_id, "review_user_id")
  if (identical(method, "PUT")) {
    review_write_validate_required(review_data$review_id, "review_id")
  }

  # Read the provenance actions off the RAW payload BEFORE normalization
  # discards every field except (vario_id, modifier_id).
  variation_provenance_actions <- review_write_extract_provenance_actions(variation_ontology)

  phenotypes <- review_write_normalize_ontology(phenotypes, "phenotype_id")
  variation_ontology <- review_write_normalize_ontology(variation_ontology, "vario_id")
  review_write_validate_lookup_ids(
    phenotypes$phenotype_id, "phenotype_list", "phenotype_id", db
  )
  review_write_validate_lookup_ids(
    variation_ontology$vario_id, "variation_ontology_list", "vario_id", db
  )
  review_write_validate_lookup_ids(
    phenotypes$modifier_id, "modifier_list", "modifier_id", db
  )
  review_write_validate_lookup_ids(
    variation_ontology$modifier_id, "modifier_list", "modifier_id", db
  )

  if (identical(method, "PUT")) {
    owner <- db_execute_query(
      "SELECT entity_id FROM ndd_entity_review WHERE review_id = ?",
      list(as.integer(review_data$review_id)),
      conn = db
    )
    if (nrow(owner) != 1L || owner$entity_id[[1L]] != as.integer(review_data$entity_id)) {
      stop_for_bad_request("review_id does not belong to entity_id.")
    }
  }

  publications <- publication_write_classify_genereviews(publications)
  prepared_publications <- tryCatch(
    publication_write_prepare(publications, db = db),
    publication_fetch_error = function(error) {
      stop_for_bad_request(error$message)
    }
  )

  review_data$entity_id <- as.integer(review_data$entity_id)
  review_data$review_user_id <- as.integer(review_user_id)
  if (!is.null(review_data$review_id)) {
    review_data$review_id <- as.integer(review_data$review_id)
  }

  list(
    method = method,
    review_data = review_data,
    publications = tibble::as_tibble(publications),
    prepared_publications = prepared_publications,
    phenotypes = phenotypes,
    variation_ontology = variation_ontology,
    variation_provenance_actions = variation_provenance_actions
  )
}

#' Does this save determine the entity's publicly served variation-ontology set?
#'
#' Provenance assertions are entity-scoped, but the terms the public sees come
#' from the PRIMARY APPROVED review. Only a save that IS (or is about to become)
#' that review may reject an omitted term's assertion; a Reviewer's draft omission
#' says nothing about the served set, and acting on it would suppress provenance
#' for terms the approved review is still serving -- making them read as
#' curator-authored. See variation_provenance_plan_reconciliation()'s
#' @param apply_rejections for the full rule.
#'
#' TRUE when either:
#'   * `direct_approval` is TRUE -- the handler escalates to Curator and approves
#'     this review in the same transaction, so it becomes the served set. (This is
#'     also the case where rejection is unsurprising: a payload that omits
#'     `variation_ontology` already wipes the connect rows via
#'     `variation_ontology_replace_for_review()` with zero rows.)
#'   * the review row just written is already `is_primary = 1 AND
#'     review_approved = 1` -- i.e. a PUT editing the live served review.
#'
#' Read on `txn_conn` so it observes this transaction's own write. The repo's
#' canonical gate is `primary_approved_reviews()` (functions/review-repository.R);
#' a direct single-row read is used here because it must be transaction-local and
#' scoped to exactly the review being saved.
#'
#' @keywords internal
review_write_save_determines_served_set <- function(review_id, direct_approval, conn) {
  if (isTRUE(direct_approval)) {
    return(TRUE)
  }

  row <- db_execute_query(
    "SELECT is_primary, review_approved FROM ndd_entity_review WHERE review_id = ?",
    list(as.integer(review_id)),
    conn = conn
  )
  if (is.null(row) || nrow(row) != 1L) {
    return(FALSE)
  }

  # A NULL/NA in either column is not an approval; fall to FALSE (leave the
  # assertion alone), which is the non-destructive direction.
  isTRUE(as.integer(row$is_primary[[1L]]) == 1L) &&
    isTRUE(as.integer(row$review_approved[[1L]]) == 1L)
}

#' Project a raw review request body to the columns a save may write
#'
#' `prepared$review_data` is the request body verbatim -- `req$argsBody$review_json`
#' (endpoints/review_endpoints.R) -- so besides `synopsis`/`comment` it ALWAYS
#' carries `literature`, `phenotypes` and `variation_ontology` (the handler reads
#' those three off the very object it forwards here), plus anything else a client
#' chooses to send. Handing that whole object to `review_update()` was #613: its
#' mass-assignment allowlist aborts on the ontology keys, so every PUT save the
#' frontend actually sends rolled back with an opaque 500.
#'
#' Both projections are deliberately NARROWER than the repository write they
#' feed. `review_update()`'s allowlist also permits `is_primary`,
#' `review_approved`, `approving_user_id` and `review_date`; `review_create()`
#' likewise INSERTs the first three whenever the supplied record carries them --
#' legitimately, because `svc_review_update()`, entity creation and the approval
#' path need them. Forwarding a client body into either lets a Reviewer publish an
#' approved primary review without the Curator gate that `/api/review/approve`
#' enforces, and post-#608 that forged row also flips
#' `review_write_save_determines_served_set()`, unlocking the provenance
#' rejection edges. Approval state belongs to the approval path alone
#' (`review_approve()`, which `direct_approval` runs after the row exists), never
#' to a submission. Fix it HERE, at the call site: do not widen the repository
#' allowlists, and do not add a column to either projection without an
#' authorization story for it.
#'
#' Only keys actually PRESENT are returned, so a PUT body that omits `comment`
#' leaves the stored comment untouched (the pre-#613 semantics) and a POST body
#' that omits it falls to the column default. An empty projection is unreachable:
#' `review_write_prepare()` rejects a blank `synopsis` with a 400 and coerces
#' `entity_id`/`review_user_id` itself, so those are always present here.
#'
#' @param review_data Raw review request body (named list).
#' @return Named list containing only the present, writable columns.
#' @keywords internal
review_write_updatable_review_fields <- function(review_data) {
  review_data[intersect(c("synopsis", "comment"), names(review_data))]
}

#' @rdname review_write_updatable_review_fields
#' @keywords internal
review_write_creatable_review_fields <- function(review_data) {
  review_data[intersect(c("entity_id", "review_user_id", "synopsis", "comment"), names(review_data))]
}

review_write_mutate <- function(prepared, txn_conn, re_review,
                                direct_approval, review_user_id) {
  publication_write_persist(prepared$prepared_publications, conn = txn_conn)

  if (identical(prepared$method, "POST")) {
    # #613: pass ONLY the columns a submission may set, never approval state.
    review_id <- review_create(review_write_creatable_review_fields(prepared$review_data), conn = txn_conn)
    message <- "OK. Review created."
  } else {
    review_id <- as.integer(prepared$review_data$review_id)
    # #613: pass ONLY the save-writable columns, never the raw client body.
    review_update(
      review_id,
      review_write_updatable_review_fields(prepared$review_data),
      conn = txn_conn
    )
    message <- "OK. Review updated."
  }

  entity_id <- prepared$review_data$entity_id
  if (nrow(prepared$publications) > 0L) {
    if (identical(prepared$method, "POST")) {
      publication_connect_to_review(review_id, entity_id, prepared$publications, conn = txn_conn)
    } else {
      publication_replace_for_review(review_id, entity_id, prepared$publications, conn = txn_conn)
    }
  } else if (identical(prepared$method, "PUT")) {
    publication_replace_for_review(
      review_id, entity_id,
      tibble::tibble(publication_id = character(), publication_type = character()),
      conn = txn_conn
    )
  }

  if (identical(prepared$method, "POST")) {
    phenotype_connect_to_review(review_id, entity_id, prepared$phenotypes, conn = txn_conn)
    variation_ontology_connect_to_review(
      review_id, entity_id, prepared$variation_ontology, conn = txn_conn
    )
  } else {
    phenotype_replace_for_review(review_id, entity_id, prepared$phenotypes, conn = txn_conn)
    variation_ontology_replace_for_review(
      review_id, entity_id, prepared$variation_ontology, conn = txn_conn
    )
  }

  # Reconcile the entity's provenance assertions against what was actually
  # submitted, on the SAME transaction connection as the curated writes above,
  # so a later failure rolls the state transitions back with everything else.
  #
  # Both POST and PUT reconcile: assertions are entity-scoped, not
  # review-scoped, and the laundering this fixes happens specifically when a
  # NEW review is created for an entity.
  #
  # CONFIRMATIONS always apply. REJECTIONS apply only when this save determines
  # the served term set, so a Reviewer's draft omission cannot suppress
  # provenance for terms the approved review is still serving. The predicate is
  # evaluated HERE (not inside the planner, which stays pure) and after the
  # review row is written, so it observes this transaction's own state.
  #
  # Deliberately NOT exists()-guarded. A missing module must fail loudly rather
  # than silently skip reconciliation, which would silently restore the #608
  # laundering bug; the registration is locked by a static test guard.
  variation_provenance_reconcile_for_review(
    entity_id = entity_id,
    submitted = prepared$variation_ontology,
    actions = prepared$variation_provenance_actions,
    review_user_id = review_user_id,
    conn = txn_conn,
    apply_rejections = review_write_save_determines_served_set(
      review_id, direct_approval, txn_conn
    )
  )

  if (isTRUE(re_review)) {
    review_update_re_review_status(entity_id, review_id, conn = txn_conn)
  }
  if (isTRUE(direct_approval)) {
    review_approve(review_id, review_user_id, approved = TRUE, conn = txn_conn)
  }

  list(review_id = as.integer(review_id), message = message)
}

review_write_run_mutation <- function(prepared, db, mutation_fn,
                                      transaction_runner = db_with_transaction) {
  # Pool -> a real transaction; caller-owned DBIConnection (notably
  # with_test_db_transaction()) -> a SAVEPOINT, because RMariaDB has no nested
  # transaction. That decision now lives in db_with_savepoint_or_transaction()
  # (functions/db-helpers.R), which the approval path and the curation queue
  # share; the savepoint NAME is unchanged.
  db_with_savepoint_or_transaction(
    db, "review_write_mutation",
    fn = function(txn_conn) mutation_fn(prepared, txn_conn),
    transaction_runner = transaction_runner
  )
}

svc_review_write <- function(method, review_data, publications = tibble::tibble(),
                             phenotypes = tibble::tibble(),
                             variation_ontology = tibble::tibble(),
                             re_review = FALSE, direct_approval = FALSE,
                             review_user_id, db,
                             prepare_fn = review_write_prepare,
                             mutation_fn = review_write_mutate,
                             transaction_runner = db_with_transaction) {
  # Keep client-visible ontology-shape failures ahead of every injectable
  # preparation step, external lookup, and transaction boundary.
  review_write_normalize_ontology(phenotypes, "phenotype_id")
  review_write_normalize_ontology(variation_ontology, "vario_id")

  prepared <- prepare_fn(
    method = method,
    review_data = review_data,
    publications = publications,
    phenotypes = phenotypes,
    variation_ontology = variation_ontology,
    review_user_id = review_user_id,
    db = db
  )
  result <- review_write_run_mutation(
    prepared = prepared,
    db = db,
    mutation_fn = function(prepared_data, txn_conn) {
      mutation_fn(
        prepared_data,
        txn_conn,
        re_review = re_review,
        direct_approval = direct_approval,
        review_user_id = review_user_id
      )
    },
    transaction_runner = transaction_runner
  )

  list(
    status = 200L,
    message = as.character(if (is.null(result$message)) "OK. Review stored." else result$message),
    entry = tibble::tibble(review_id = as.integer(result$review_id))
  )
}
