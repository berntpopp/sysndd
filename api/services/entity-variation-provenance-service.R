# api/services/entity-variation-provenance-service.R
#
# READ surface for variation-ontology provenance (#608).
#
# Three things live here:
#   1. svc_variation_attach_provenance() -- the PURE presentation pass that the
#      existing public read (svc_entity_variation(), entity-read-endpoint-
#      service.R) applies to its curated term set.
#   2. svc_entity_variation_evidence()   -- GET /entity/<id>/variation/
#      <vario_id>/<modifier_id>/evidence, the full evidence payload for ONE
#      assertion.
#   3. svc_entity_variation_suggestions() -- GET /entity/<id>/variation/
#      suggestions, the `suggested` assertions for the curation form.
#
# INERTNESS (the release gate, spec 7.1)
# --------------------------------------
# The backfill that populates variation_ontology_assertion /
# variation_ontology_evidence lives in a different repository and has not run
# yet. Absence of an assertion row MEANS "curator-authored", so with zero
# assertion rows the public read must be indistinguishable from its pre-#608
# self: `provenance` null on every term and no other field touched. That is
# asserted by the first test in
# api/tests/testthat/test-unit-variation-provenance-endpoints.R.
#
# WHY THERE IS NO tryCatch AROUND THE PROVENANCE READ
# ---------------------------------------------------
# Deliberate. A swallowed provenance-read failure would render every term as
# `provenance: null`, i.e. would present machine-derived annotations as
# curator-authored -- exactly the fabrication this feature exists to prevent.
# A failing provenance read must surface as an error, not as a confident lie.
# Migration 047 is EXPECTED_LATEST_MIGRATION and migrations are applied (and
# fail loudly) at API startup, so the tables are present wherever the API runs.
#
# JSON SERIALIZATION CONTRACT
# ---------------------------
# The routes serialize with `list(na="string", null="null")`. Both arguments are
# load-bearing and were verified empirically against jsonlite/plumber 1.3.x:
#   * WITHOUT null="null", a NULL list-column element serializes as `{}`, not
#     `null` -- so the "provenance is null for curator-authored terms" contract
#     would silently become `"provenance":{}`.
#   * WITH na="string", an NA_integer_ inside a nested list serializes as the
#     STRING "NA" -- so an unrecorded evidence strength would appear as
#     `"strength":["NA"]` in a numeric field. Every unrecorded scalar is
#     therefore normalized from NA to NULL here (see .svc_vp_na_to_null()) and
#     then rendered as JSON `null` by null="null".
# Scalars still serialize as length-1 ARRAYS (plumber's json serializer does not
# auto-unbox); that is the repo-wide convention, see AGENTS.md, and frontend
# callers already unwrap. `sources` / `evidence` are genuine JSON arrays.
#
# CHEAPNESS
# ---------
# Every function here is DB-only: no external calls, no analysis, no LLM. Each
# route issues exactly ONE parameterized query; grouping/ordering is done in R
# on the already-fetched rows. The public read adds exactly one query per
# request, never one per term.

# States the PUBLIC surface may reveal. Mirrors provenance_for_entity()
# (functions/variation-provenance-repository.R): `suggested` and `rejected` are
# curation workflow state and must never leak on an unauthenticated route.
VARIATION_PROVENANCE_PUBLIC_STATES <- c("active_unconfirmed", "confirmed")

# The one state the Curator-only suggestions route serves.
VARIATION_PROVENANCE_SUGGESTED_STATE <- "suggested"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' Turn a length-1 NA into NULL, leave everything else alone.
#'
#' Used so `na="string"` never renders an unrecorded numeric as the literal
#' string "NA"; combined with `null="null"` the field becomes JSON `null`.
#'
#' @param x A scalar (or NULL).
#' @return `x`, or NULL when `x` is a length-1 NA / zero-length.
#' @noRd
.svc_vp_na_to_null <- function(x) {
  if (length(x) == 0L) {
    return(NULL)
  }
  if (length(x) == 1L && is.na(x)) {
    return(NULL)
  }
  x
}

#' Parse a MySQL JSON column value into an R structure.
#'
#' `evidence_json` is declared `JSON` in migration 047, so MySQL itself
#' guarantees the stored text parses; the tryCatch is belt-and-braces for a
#' restore-drifted column. `simplifyVector = FALSE` keeps arrays as arrays on
#' the round trip instead of collapsing a length-1 array to a scalar.
#'
#' @param x Character scalar (or NA).
#' @return A list, or NULL when absent/unparseable.
#' @noRd
.svc_vp_parse_json <- function(x) {
  if (length(x) != 1L || is.na(x) || !nzchar(x)) {
    return(NULL)
  }
  tryCatch(
    jsonlite::fromJSON(x, simplifyVector = FALSE),
    error = function(e) NULL
  )
}

#' Render an evidence row's `created_at` as a string, or NULL.
#'
#' `variation_ontology_evidence.created_at` is a MySQL `DATETIME`, which carries
#' NO timezone. The value is therefore rendered WITHOUT a zone designator: an
#' appended `Z` would assert a UTC instant the column cannot back, and this
#' surface's whole premise is that a field states only what the payload records.
#' The client shows the DATE part, which is what the import batch meaningfully
#' pins down.
#'
#' The driver returns `DATETIME` as POSIXct; a character value (a restore-drifted
#' column, or a stubbed test row) is passed through with its separator
#' normalized, so both shapes yield the same wire format.
#'
#' @param x POSIXct or character scalar (NA/NULL allowed).
#' @return `"YYYY-MM-DDTHH:MM:SS"`, or NULL when absent.
#' @noRd
.svc_vp_format_timestamp <- function(x) {
  if (length(x) != 1L || all(is.na(x))) {
    return(NULL)
  }
  if (inherits(x, "POSIXt")) {
    return(format(x, "%Y-%m-%dT%H:%M:%S"))
  }
  value <- trimws(as.character(x))
  if (!nzchar(value)) {
    return(NULL)
  }
  sub(" ", "T", value, fixed = TRUE)
}

#' Order indices strength-descending, then source_key ascending.
#'
#' Byte-identical ordering rule to attach_provenance() so the compact `sources`
#' array on the public read and the full `evidence` array on the detail routes
#' can never disagree about which source comes first. NA strength sorts last.
#'
#' @param strength Integer vector (NA allowed).
#' @param source_key Character vector.
#' @return Integer permutation.
#' @noRd
.svc_vp_evidence_order <- function(strength, source_key) {
  order(-ifelse(is.na(strength), -1L, as.integer(strength)), source_key)
}

#' Build the full evidence records for one assertion's rows.
#'
#' A LEFT JOIN against an assertion with no evidence yields exactly one row
#' whose `source_key` is NA; `source_key` is NOT NULL in the evidence table, so
#' NA there can only mean "no evidence row matched". Those phantom rows are
#' dropped, yielding an empty array rather than one all-null entry.
#'
#' BOTH callers must select every column read here. `evidence_created_at` is
#' aliased rather than selected bare because the suggestions query also selects
#' the ASSERTION's `a.created_at`, and two same-named columns in one result set
#' collide. A caller that forgets the column does not degrade gracefully --
#' `rows$evidence_created_at` is NULL and `NULL[[i]]` errors "subscript out of
#' bounds" -- which is deliberate: silently omitting provenance is the failure
#' direction this whole surface exists to avoid.
#'
#' @param rows Tibble/data.frame of joined assertion+evidence rows.
#' @return Unnamed list of evidence records (possibly empty).
#' @noRd
.svc_vp_evidence_records <- function(rows) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(list())
  }
  real <- rows[!is.na(rows$source_key), , drop = FALSE]
  if (nrow(real) == 0L) {
    return(list())
  }

  ordered <- real[.svc_vp_evidence_order(real$evidence_strength, real$source_key), ,
                  drop = FALSE]

  lapply(seq_len(nrow(ordered)), function(i) {
    list(
      source_type       = .svc_vp_na_to_null(as.character(ordered$source_type[[i]])),
      source_key        = .svc_vp_na_to_null(as.character(ordered$source_key[[i]])),
      batch_id          = .svc_vp_na_to_null(as.character(ordered$batch_id[[i]])),
      source_version    = .svc_vp_na_to_null(as.character(ordered$source_version[[i]])),
      evidence_summary  = .svc_vp_na_to_null(as.character(ordered$evidence_summary[[i]])),
      evidence_strength = .svc_vp_na_to_null(as.integer(ordered$evidence_strength[[i]])),
      evidence_json     = .svc_vp_parse_json(as.character(ordered$evidence_json[[i]])),
      created_at        = .svc_vp_format_timestamp(ordered$evidence_created_at[[i]])
    )
  })
}

#' Maximum recorded evidence strength across rows, or NULL.
#'
#' @param strength Integer vector (NA allowed).
#' @return Integer scalar, or NULL when nothing is recorded.
#' @noRd
.svc_vp_max_strength <- function(strength) {
  if (length(strength) == 0L || all(is.na(strength))) {
    return(NULL)
  }
  as.integer(max(as.integer(strength), na.rm = TRUE))
}


# ---------------------------------------------------------------------------
# Path/query parameter validation
# ---------------------------------------------------------------------------

#' Validate an entity id path parameter
#'
#' @param sysndd_id Raw path parameter (plumber hands these over as character).
#' @return Integer entity id.
#' @export
svc_variation_entity_id_param <- function(sysndd_id) {
  raw <- suppressWarnings(trimws(as.character(sysndd_id[[1L]])))
  if (length(raw) != 1L || is.na(raw) || !grepl("^[0-9]+$", raw)) {
    stop_for_bad_request("entity id must be a positive integer.")
  }
  value <- suppressWarnings(as.integer(raw))
  if (is.na(value)) {
    stop_for_bad_request("entity id must be a positive integer.")
  }
  value
}

#' Validate a modifier id path parameter
#'
#' Rejects anything that is not a bare non-negative integer -- `"1.5"`,
#' `"0x1"`, `"1;DROP"`, an out-of-range value that would silently become NA.
#'
#' @param modifier_id Raw path parameter.
#' @return Integer modifier id.
#' @export
svc_variation_modifier_id_param <- function(modifier_id) {
  raw <- suppressWarnings(trimws(as.character(modifier_id[[1L]])))
  if (length(raw) != 1L || is.na(raw) || !grepl("^[0-9]+$", raw)) {
    stop_for_bad_request("modifier_id must be a non-negative integer.")
  }
  value <- suppressWarnings(as.integer(raw))
  if (is.na(value)) {
    stop_for_bad_request("modifier_id must be a non-negative integer.")
  }
  value
}

#' Normalize a vario_id path parameter
#'
#' `vario_id` is a CURIE (`VariO:0017`). Verified empirically against plumber
#' 1.3.x: a raw colon inside a single path segment routes fine, but plumber does
#' NOT percent-decode path parameters -- `VariO%3A0017` arrives verbatim. So the
#' value is URL-decoded here and both encodings resolve to the same id. The
#' shape check is deliberately conservative (CURIE-ish characters only, bounded
#' length) so a hostile value can never reach a log line or a lookup; the value
#' is bound as a query parameter regardless, never interpolated into SQL.
#'
#' @param vario_id Raw path parameter.
#' @return Character vario_id.
#' @export
svc_variation_vario_id_param <- function(vario_id) {
  raw <- suppressWarnings(as.character(vario_id[[1L]]))
  if (length(raw) != 1L || is.na(raw) || !nzchar(raw) || nchar(raw) > 64L) {
    stop_for_bad_request("vario_id must be a variation-ontology CURIE.")
  }

  # URLdecode() only *warns* on a malformed escape (verified: URLdecode("a%")
  # warns "out-of-range values treated as 0" and returns garbage), so treat a
  # warning as a hard rejection instead of letting the garbage through.
  decoded <- tryCatch(
    withCallingHandlers(
      utils::URLdecode(raw),
      warning = function(w) stop_for_bad_request("vario_id is not URL-decodable.")
    ),
    error = function(e) {
      if (inherits(e, "error_400")) stop(e)
      stop_for_bad_request("vario_id is not URL-decodable.")
    }
  )

  if (!grepl("^[A-Za-z][A-Za-z0-9]*:[A-Za-z0-9._-]+$", decoded) || nchar(decoded) > 32L) {
    stop_for_bad_request("vario_id must be a variation-ontology CURIE.")
  }

  decoded
}


# ---------------------------------------------------------------------------
# 1. Public read: the pure presentation pass
# ---------------------------------------------------------------------------

#' Attach JSON-ready provenance to a curated variation-term tibble
#'
#' PURE. Wraps attach_provenance() (functions/variation-provenance-repository.R)
#' and then normalizes each block for the route's serializer: unrecorded scalars
#' become NULL so they render as JSON `null` rather than the string "NA".
#'
#' A term with no assertion row stays NULL -> serialized as `provenance: null`
#' -> "curator-authored". The compact block deliberately carries only
#' `state` / `max_strength` / `sources[{source_type, source_key, strength,
#' summary}]`; the full payload (batch_id, source_version, evidence_json) is
#' served by svc_entity_variation_evidence() so this hot path stays small.
#'
#' @param terms Tibble with entity_id, vario_id, modifier_id (plus any other
#'   columns, which are preserved untouched and in order).
#' @param provenance Tibble as returned by provenance_for_entity(), or NULL.
#' @return `terms` with an added `provenance` list-column.
#' @export
svc_variation_attach_provenance <- function(terms, provenance) {
  with_provenance <- attach_provenance(terms, provenance)

  with_provenance$provenance <- lapply(with_provenance$provenance, function(block) {
    if (is.null(block)) {
      return(NULL)
    }
    list(
      state        = block$state,
      max_strength = .svc_vp_na_to_null(block$max_strength),
      sources      = lapply(block$sources, function(src) {
        list(
          source_type = .svc_vp_na_to_null(src$source_type),
          source_key  = .svc_vp_na_to_null(src$source_key),
          strength    = .svc_vp_na_to_null(src$strength),
          summary     = .svc_vp_na_to_null(src$summary)
        )
      })
    )
  })

  with_provenance
}


# ---------------------------------------------------------------------------
# 2. GET /entity/<id>/variation/<vario_id>/<modifier_id>/evidence
# ---------------------------------------------------------------------------

#' Full evidence payload for one variation-ontology assertion
#'
#' PUBLIC, DB-only, one query. The entity is resolved through `ndd_entity_view`
#' inside the SAME statement, so an entity that is not publicly visible can
#' never produce a row -- and the assertion state is gated to
#' VARIATION_PROVENANCE_PUBLIC_STATES, so a `suggested`/`rejected` assertion is
#' likewise invisible here.
#'
#' A missing entity, a non-public entity, an unknown assertion and a
#' non-public-state assertion all raise the SAME 404 with the SAME message, so a
#' caller cannot use this route to probe which of them it hit. An assertion that
#' exists but has no evidence rows yet returns 200 with `evidence: []` -- that
#' assertion is already visible via the public variation read, so this leaks
#' nothing new.
#'
#' @param sysndd_id Entity id (path parameter).
#' @param vario_id Variation-ontology CURIE (path parameter).
#' @param modifier_id Modifier id (path parameter).
#' @param pool Database connection pool.
#' @return `list(entity_id, vario_id, modifier_id, state, evidence)`.
#' @export
svc_entity_variation_evidence <- function(sysndd_id, vario_id, modifier_id, pool) {
  entity_id <- svc_variation_entity_id_param(sysndd_id)
  vario <- svc_variation_vario_id_param(vario_id)
  modifier <- svc_variation_modifier_id_param(modifier_id)

  rows <- db_execute_query(
    paste(
      "SELECT a.entity_id, a.vario_id, a.modifier_id, a.state,",
      "       e.evidence_id, e.source_type, e.source_key, e.batch_id,",
      "       e.source_version, e.evidence_summary, e.evidence_strength,",
      "       e.evidence_json, e.created_at AS evidence_created_at",
      "  FROM variation_ontology_assertion a",
      "  JOIN ndd_entity_view v ON v.entity_id = a.entity_id",
      "  LEFT JOIN variation_ontology_evidence e",
      "         ON e.assertion_id = a.assertion_id",
      " WHERE a.entity_id = ?",
      "   AND a.vario_id = ?",
      "   AND a.modifier_id = ?",
      "   AND a.state IN ('active_unconfirmed', 'confirmed')",
      " ORDER BY (e.evidence_strength IS NULL) ASC, e.evidence_strength DESC,",
      "          e.source_key ASC, e.evidence_id ASC",
      sep = "\n"
    ),
    list(entity_id, vario, modifier),
    conn = pool
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    # One message for every miss -- see the roxygen note above.
    stop_for_not_found("No variation-ontology provenance found for the requested term.")
  }

  list(
    entity_id   = as.integer(rows$entity_id[[1L]]),
    vario_id    = as.character(rows$vario_id[[1L]]),
    modifier_id = as.integer(rows$modifier_id[[1L]]),
    state       = as.character(rows$state[[1L]]),
    evidence    = .svc_vp_evidence_records(rows)
  )
}


# ---------------------------------------------------------------------------
# 3. GET /entity/<id>/variation/suggestions
# ---------------------------------------------------------------------------

#' Suggested variation-ontology assertions for one entity, with their evidence
#'
#' Curator-gated (the handler calls `require_role(req, res, "Curator")`).
#' Suggestions are candidate terms a machine source proposed and no curator has
#' acted on yet: they are NOT part of the curated set, so they are deliberately
#' NOT folded into the public variation response.
#'
#' The FULL evidence records (including `evidence_json`) are inlined here rather
#' than behind the detail route, because that route is public and state-gated to
#' the served states -- a suggested assertion is invisible there by design. The
#' per-entity suggestion count is small (a handful of candidate terms), so this
#' stays cheap.
#'
#' The entity is resolved through `ndd_entity_view` in the same statement, so a
#' deactivated/non-public entity yields an empty array rather than curation
#' workflow data.
#'
#' @param sysndd_id Entity id (path parameter).
#' @param pool Database connection pool.
#' @return Unnamed list of suggestion objects (an empty list serializes as `[]`).
#' @export
svc_entity_variation_suggestions <- function(sysndd_id, pool) {
  entity_id <- svc_variation_entity_id_param(sysndd_id)

  rows <- db_execute_query(
    paste(
      "SELECT a.assertion_id, a.entity_id, a.vario_id, l.vario_name,",
      "       a.modifier_id, a.state, a.created_at, a.updated_at,",
      "       e.evidence_id, e.source_type, e.source_key, e.batch_id,",
      "       e.source_version, e.evidence_summary, e.evidence_strength,",
      "       e.evidence_json, e.created_at AS evidence_created_at",
      "  FROM variation_ontology_assertion a",
      "  JOIN ndd_entity_view v ON v.entity_id = a.entity_id",
      "  LEFT JOIN variation_ontology_list l ON l.vario_id = a.vario_id",
      "  LEFT JOIN variation_ontology_evidence e",
      "         ON e.assertion_id = a.assertion_id",
      " WHERE a.entity_id = ?",
      "   AND a.state = 'suggested'",
      " ORDER BY a.vario_id ASC, a.modifier_id ASC,",
      "          (e.evidence_strength IS NULL) ASC, e.evidence_strength DESC,",
      "          e.source_key ASC, e.evidence_id ASC",
      sep = "\n"
    ),
    list(entity_id),
    conn = pool
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(list())
  }

  # Group by assertion_id, ordered by (vario_id, modifier_id) so the response
  # order never depends on the driver's row order.
  assertion_ids <- as.integer(rows$assertion_id)
  first_row <- vapply(unique(assertion_ids), function(id) which(assertion_ids == id)[[1L]],
                      integer(1))
  ordering <- order(as.character(rows$vario_id[first_row]),
                    as.integer(rows$modifier_id[first_row]))

  lapply(first_row[ordering], function(i) {
    id <- assertion_ids[[i]]
    group <- rows[assertion_ids == id, , drop = FALSE]

    list(
      entity_id    = as.integer(group$entity_id[[1L]]),
      vario_id     = as.character(group$vario_id[[1L]]),
      vario_name   = .svc_vp_na_to_null(as.character(group$vario_name[[1L]])),
      modifier_id  = as.integer(group$modifier_id[[1L]]),
      state        = as.character(group$state[[1L]]),
      max_strength = .svc_vp_max_strength(group$evidence_strength[!is.na(group$source_key)]),
      evidence     = .svc_vp_evidence_records(group)
    )
  })
}
