# functions/variation-provenance-repository.R
#
# Read access to variation_ontology_assertion / variation_ontology_evidence.
#
# Identity is (entity_id, vario_id, modifier_id): the curated table's own
# uniqueness includes modifier_id, and 'present' vs 'absent' are different
# claims. This module never reads or writes
# ndd_review_variation_ontology_connect.

#' Fetch provenance rows for one entity
#'
#' One row per evidence record. evidence_json is deliberately excluded so the
#' public endpoint stays small; it is served by a separate detail route.
#'
#' @param pool Database connection pool.
#' @param entity_id Integer entity id.
#' @return Tibble.
#' @export
provenance_for_entity <- function(pool, entity_id) {
  # Bind to a differently-named local instead of shadowing the `entity_id`
  # column with the function argument of the same name. Both forms compile
  # to identical SQL (`WHERE (entity_id = <value>)`, verified empirically
  # against dbplyr::lazy_frame()) because `!!` splices the argument's value
  # as a literal before the column reference is resolved against the table
  # -- but the shadowed form reads as though the filter could recurse on
  # itself, so prefer the explicit local for clarity.
  target_entity_id <- as.integer(entity_id)

  assertions <- pool %>%
    dplyr::tbl("variation_ontology_assertion") %>%
    dplyr::filter(
      entity_id == !!target_entity_id,
      state %in% c("active_unconfirmed", "confirmed")
    ) %>%
    dplyr::select(assertion_id, entity_id, vario_id, modifier_id, state)

  evidence <- pool %>%
    dplyr::tbl("variation_ontology_evidence") %>%
    dplyr::select(assertion_id, source_type, source_key,
                  evidence_strength, evidence_summary)

  assertions %>%
    dplyr::left_join(evidence, by = "assertion_id") %>%
    dplyr::select(-assertion_id) %>%
    dplyr::collect()
}

#' Build the (entity_id, vario_id, modifier_id) read-side identity key
#'
#' The READ-side counterpart of `.variation_provenance_identity_key()` in
#' functions/variation-provenance-reconcile.R. The two MUST normalize
#' identically: the write path reconciles stored assertions against a
#' submission on its key, and this one decides which SERVED term a stored
#' assertion belongs to. Every disagreement between them resolves as "no
#' assertion found for this term", which the API contract defines as
#' CURATOR-AUTHORED -- so a normalization drift here does not merely lose a
#' join, it fabricates curator attribution for a machine-derived annotation,
#' the exact failure this feature exists to prevent. Keep the two in sync.
#'
#' Implemented locally rather than by calling the reconcile module's helper,
#' deliberately. The shapes differ (that key is 2-part, entity-scoped by its
#' own query; this one carries `entity_id` as a third part because
#' `attach_provenance()` joins a terms tibble that is not intrinsically
#' single-entity), so reuse would be partial at best. Decisively:
#' tests/testthat/test-unit-variation-provenance-endpoints.R sources ONLY this
#' file plus the services above it, and runs `attach_provenance()` for real, so
#' a call into functions/variation-provenance-reconcile.R would make this read
#' path unloadable on its own and break that test's isolation.
#'
#' What is normalized, and why:
#'
#' * `vario_id` is upper-cased (and trimmed), mirroring the write path.
#'   `variation_ontology_list.vario_id` is `utf8mb4_0900_ai_ci`, i.e. case-
#'   INsensitive, so the FK happily accepts an assertion stored as
#'   `vario:0017` against a term served as `VariO:0017`. A case-SENSITIVE
#'   comparison would then find no assertion for that served term and render it
#'   `provenance: null` / curator-authored on `GET /api/entity/<id>/variation`
#'   -- while the sibling `.../variation/<vario_id>/<modifier_id>/evidence`
#'   route, which resolves in SQL and is therefore case-INsensitive, still
#'   returns that term's machine-derived evidence. The two surfaces would
#'   contradict each other. The companion backfill lives in a different
#'   repository and may store non-canonical casing, so this direction is
#'   reachable, not theoretical. Applied to BOTH sides of the comparison, so
#'   one normalization here suffices. VariO ids are ASCII, so `toupper()` is
#'   locale-safe.
#' * `entity_id`/`modifier_id` are coerced with `as.integer()`, and
#'   deliberately NOT routed through `as.character()` first the way the write
#'   path's helper is: `as.character(100000)` renders `"1e+05"` for a double
#'   while `as.integer(100000)` renders `"100000"`, so an `as.character()`
#'   first pass would REINTRODUCE the double/integer mismatch risk that arises
#'   when `terms$entity_id` arrives as a double (e.g. after a JSON round-trip)
#'   while `provenance$entity_id` is an integer straight from DBI.
#'   `as.integer()` already normalizes a double, an integer and a character
#'   `"1"` alike, so it accepts the same inputs without that hazard.
#'
#' A zero-length input yields `character(0)` (every coercion in the chain is
#' length-preserving), which is what keeps `provenance = NULL` a supported
#' degenerate input that resolves every term to `NULL`.
#'
#' @param entity_id Entity id vector (double, integer or character).
#' @param vario_id VariO CURIE vector; case and surrounding space irrelevant.
#' @param modifier_id Modifier id vector (double, integer or character).
#' @return Character vector of normalized join keys.
#' @keywords internal
.variation_provenance_read_key <- function(entity_id, vario_id, modifier_id) {
  paste(
    as.integer(entity_id),
    toupper(trimws(as.character(vario_id))),
    as.integer(modifier_id),
    sep = "|"
  )
}

#' Attach provenance to a terms tibble
#'
#' Pure join on the full identity. Terms without an assertion get NULL, which
#' the API contract defines as curator-authored. Multiple evidence rows collapse
#' into a `sources` array ordered by strength descending then source_key
#' ascending, so rendering order is stable.
#'
#' An assertion that has no evidence rows at all (the left-join NA row that
#' `provenance_for_entity()` genuinely produces for a suggested/
#' active_unconfirmed assertion whose evidence has not been written yet)
#' still gets a non-NULL provenance carrying its `state`, but with an EMPTY
#' `sources` list rather than a single all-NA phantom entry -- `sources` is
#' rendered directly to API clients, and a phantom entry with no usable
#' fields would be worse than no entry. The signal used to detect "no
#' evidence at all" is `source_key` being NA: the evidence table's
#' `source_key` is never NA for a real evidence row, so NA there can only
#' come from the left join finding no match. A real evidence row with an
#' unrecorded `evidence_strength` (source_key present, strength NA) is a
#' different case and IS kept in `sources`.
#'
#' BOTH sides of the join are built by `.variation_provenance_read_key()`, so
#' they are normalized identically by construction -- including the
#' case-insensitive `vario_id` handling that keeps this read path in agreement
#' with the write path and with the SQL-resolved evidence route. See that
#' helper for what is normalized and why each part is what it is.
#'
#' Fails loudly (a classed `stop()`, not a warning) when `terms` is missing
#' any identity column, or when a non-NULL `provenance` is missing any
#' column this function reads. Without this guard, `paste()` on a missing
#' column silently contributes `""` to the join key (verified:
#' `paste(c(1L, 2L), c("a", "b"), integer(0), sep = "|")` gives
#' `c("1|a|", "2|b|")`), which matches no `prov_key` -- so a caller typo or
#' a column-rename refactor would make EVERY term render as `NULL` /
#' curator-authored with no error and no NA, which is exactly the
#' fabricated-provenance failure mode this feature exists to prevent. A
#' zero-ROW `provenance` (e.g. `provenance[0, ]`) still has all its column
#' NAMES, so this is a column-presence check, not a row-count check, and a
#' legitimately empty provenance table is unaffected. `provenance = NULL`
#' (no provenance available at all) is intentionally exempt from this
#' check -- it is a supported degenerate input distinct from "malformed
#' non-NULL provenance", and already causes every term to resolve to `NULL`
#' with no error (verified pre-fix behaviour, preserved on purpose).
#'
#' @param terms Tibble with entity_id, vario_id and modifier_id columns.
#' @param provenance Tibble as returned by provenance_for_entity(), or NULL.
#' @return `terms` with an added list-column `provenance`.
#' @export
attach_provenance <- function(terms, provenance) {
  required_terms_cols <- c("entity_id", "vario_id", "modifier_id")
  missing_terms_cols <- setdiff(required_terms_cols, names(terms))
  if (length(missing_terms_cols) > 0) {
    stop("attach_provenance(): `terms` is missing required column(s): ",
         paste(missing_terms_cols, collapse = ", "))
  }

  required_provenance_cols <- c("entity_id", "vario_id", "modifier_id", "state",
                                "source_type", "source_key", "evidence_strength",
                                "evidence_summary")
  if (!is.null(provenance)) {
    missing_provenance_cols <- setdiff(required_provenance_cols, names(provenance))
    if (length(missing_provenance_cols) > 0) {
      stop("attach_provenance(): `provenance` is missing required column(s): ",
           paste(missing_provenance_cols, collapse = ", "))
    }
  }

  prov_key <- .variation_provenance_read_key(
    provenance$entity_id, provenance$vario_id, provenance$modifier_id
  )
  term_key <- .variation_provenance_read_key(
    terms$entity_id, terms$vario_id, terms$modifier_id
  )

  terms$provenance <- lapply(term_key, function(k) {
    idx <- which(prov_key == k)
    if (length(idx) == 0) return(NULL)

    # idx[1] carries the assertion's state regardless of whether any
    # evidence row joined -- state comes from the assertion, not evidence.
    state <- provenance$state[idx[1]]

    # Real evidence rows have a non-NA source_key; a left-join miss (no
    # evidence at all for this assertion) is the only way source_key is NA.
    real_idx <- idx[!is.na(provenance$source_key[idx])]

    if (length(real_idx) == 0) {
      return(list(state = state, max_strength = NA_integer_, sources = list()))
    }

    strength <- provenance$evidence_strength[real_idx]
    ordering <- order(-ifelse(is.na(strength), -1L, strength),
                      provenance$source_key[real_idx])
    ordered_idx <- real_idx[ordering]

    sources <- lapply(ordered_idx, function(i) {
      list(
        source_type = provenance$source_type[i],
        source_key  = provenance$source_key[i],
        strength    = provenance$evidence_strength[i],
        summary     = provenance$evidence_summary[i]
      )
    })

    # as.integer() on the non-NA branch keeps the type stable: max() alone
    # returns whatever type `strength` arrives as (double if
    # evidence_strength ever arrives as a double), which would disagree
    # with the NA_integer_ branch and the documented integer contract.
    max_strength <- if (all(is.na(strength))) {
      NA_integer_
    } else {
      as.integer(max(strength, na.rm = TRUE))
    }

    list(
      state        = state,
      max_strength = max_strength,
      sources      = sources
    )
  })

  terms
}
