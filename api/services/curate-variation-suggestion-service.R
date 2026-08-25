# api/services/curate-variation-suggestion-service.R
#
# The cross-entity curation queue over UNCONFIRMED machine-derived
# variation-ontology assertions (#612, design spec section 6.4).
#
# WHY THE QUEUE SPANS TWO STATES
# ------------------------------
# The #608 design named a queue over `state = 'suggested'`. The February 2026
# backfill then wrote every one of its 8,083 rows `active_unconfirmed`, so a
# suggested-only queue would render an EMPTY PAGE while the ~1,981-item
# weak-evidence backlog it exists to make tractable sits in the other state.
# The queue therefore spans ('active_unconfirmed', 'suggested'), with `state`
# as a facet.
#
# WHAT `served` AND `moved` MEAN
# ------------------------------
# * `served`  -- the term is currently on the entity's primary approved review
#   with an active connect row, i.e. the public entity card shows it today.
#   Computed by the SAME rule svc_entity_variation() uses, so the queue can
#   never disagree with the page a curator would open.
# * `moved`   -- the assertion has evidence whose `origin_review_id` (migration
#   049) is not a currently primary-approved review of that entity: a curator
#   review has displaced the import while the machine evidence underneath is
#   unchanged. 95 such rows exist in production, and this is that column's first
#   consumer. `origin_review_id` deliberately carries no foreign key, so a
#   vanished origin review also reads as moved -- correctly, since the import's
#   review no longer serves.
#
# CHEAPNESS AND SAFETY
# --------------------
# DB-only: no external calls, no analysis, no LLM. Two statements per request
# (a count and a page), never one per row. Every filter value is BOUND; the only
# interpolated fragments are chosen from closed allowlists. Entities resolve
# through `ndd_entity_view` inside the statement, so a non-public entity can
# never reach the page.
#
# This file READS `ndd_review_variation_ontology_connect` to derive `served`. It
# never writes it -- the curated write path in functions/ontology-repository.R
# remains the sole writer, and test-unit-variation-connect-write-guard.R
# enforces that across api/functions, api/services and api/endpoints.

# The two states an unconfirmed machine-derived assertion can be in.
CURATE_VARIATION_QUEUE_STATES <- c("active_unconfirmed", "suggested")

# Sort keys. Interpolated, so they may only ever come from this vector.
CURATE_VARIATION_QUEUE_SORTS <- c("strength_desc", "strength_asc", "entity_asc")

CURATE_VARIATION_PAGE_SIZE_DEFAULT <- 25L
CURATE_VARIATION_PAGE_SIZE_MAX <- 100L
CURATE_VARIATION_QUERY_MAX_CHARS <- 64L
CURATE_VARIATION_STRENGTH_MAX <- 4L


# ---------------------------------------------------------------------------
# Parameter validation
# ---------------------------------------------------------------------------

#' Coerce a query parameter to a single non-blank string, or NULL.
#' @noRd
.svc_cvs_scalar <- function(value) {
  if (is.null(value) || length(value) == 0L) {
    return(NULL)
  }
  raw <- trimws(as.character(value[[1L]]))
  if (is.na(raw) || !nzchar(raw)) {
    return(NULL)
  }
  raw
}

#' Validate a value against a closed allowlist.
#'
#' A rejected value is a 400, never a silent fallback to the default: a filter
#' that is quietly ignored shows a curator a page they did not ask for and lets
#' them act on it.
#' @noRd
.svc_cvs_allowed <- function(value, allowed, name) {
  raw <- .svc_cvs_scalar(value)
  if (is.null(raw)) {
    return(NULL)
  }
  if (!raw %in% allowed) {
    stop_for_bad_request(
      paste0(name, " must be one of: ", paste(allowed, collapse = ", "), ".")
    )
  }
  raw
}

#' Coerce a bounded integer parameter, rejecting anything un-coercible.
#' @noRd
.svc_cvs_integer <- function(value, name, min_value, max_value, default = NULL) {
  raw <- .svc_cvs_scalar(value)
  if (is.null(raw)) {
    return(default)
  }
  parsed <- suppressWarnings(as.integer(raw))
  if (is.na(parsed) || !grepl("^-?[0-9]+$", raw)) {
    stop_for_bad_request(paste0(name, " must be an integer."))
  }
  if (parsed < min_value || parsed > max_value) {
    stop_for_bad_request(
      sprintf("%s must be between %d and %d.", name, min_value, max_value)
    )
  }
  parsed
}

#' Validate and normalize the queue's query parameters
#'
#' @param state Optional assertion state facet.
#' @param source_key Optional evidence source key.
#' @param max_strength Optional exact 0-4 strength facet.
#' @param moved Optional `"true"` to restrict to laundered rows.
#' @param q Optional gene symbol or entity id search.
#' @param sort Optional sort key from CURATE_VARIATION_QUEUE_SORTS.
#' @param page 1-based page number.
#' @param page_size Rows per page, capped at 100.
#' @return Named list of validated parameters.
#' @export
svc_curate_variation_suggestion_params <- function(state = NULL, source_key = NULL,
                                                   max_strength = NULL, moved = NULL,
                                                   q = NULL, sort = NULL,
                                                   page = NULL, page_size = NULL) {
  source_raw <- .svc_cvs_scalar(source_key)
  if (!is.null(source_raw) && !grepl("^[A-Za-z0-9_-]{1,64}$", source_raw)) {
    stop_for_bad_request("source_key must be a bare source identifier.")
  }

  query_raw <- .svc_cvs_scalar(q)
  if (!is.null(query_raw) && nchar(query_raw) > CURATE_VARIATION_QUERY_MAX_CHARS) {
    stop_for_bad_request(
      sprintf("q must be at most %d characters.", CURATE_VARIATION_QUERY_MAX_CHARS)
    )
  }

  page_value <- .svc_cvs_integer(page, "page", 0L, .Machine$integer.max, default = 1L)
  size_value <- .svc_cvs_integer(
    page_size, "page_size", 0L, .Machine$integer.max,
    default = CURATE_VARIATION_PAGE_SIZE_DEFAULT
  )

  list(
    state        = .svc_cvs_allowed(state, CURATE_VARIATION_QUEUE_STATES, "state"),
    source_key   = source_raw,
    max_strength = .svc_cvs_integer(
      max_strength, "max_strength", 0L, CURATE_VARIATION_STRENGTH_MAX
    ),
    # Only an explicit "true" narrows the page. Anything else is "no filter",
    # never a partial match on a typo.
    moved        = identical(tolower(.svc_cvs_scalar(moved) %||% ""), "true"),
    q            = query_raw,
    sort         = .svc_cvs_allowed(sort, CURATE_VARIATION_QUEUE_SORTS, "sort") %||%
      "strength_desc",
    page         = max(1L, page_value),
    page_size    = min(CURATE_VARIATION_PAGE_SIZE_MAX, max(1L, size_value))
  )
}


# ---------------------------------------------------------------------------
# SQL fragments
# ---------------------------------------------------------------------------

#' The `served` predicate for an assertion alias.
#'
#' Byte-identical rule to svc_entity_variation()
#' (services/entity-read-endpoint-service.R): an ACTIVE connect row on a
#' PRIMARY, APPROVED review. Migrations 051-053 enforce (review_id, entity_id)
#' agreement on the connect table, so joining by review_id alone is sound.
#' @noRd
.svc_cvs_served_sql <- function(a) {
  paste0(
    "EXISTS (SELECT 1 FROM ndd_review_variation_ontology_connect c ",
    "JOIN ndd_entity_review r ON r.review_id = c.review_id ",
    "WHERE c.entity_id = ", a, ".entity_id AND c.vario_id = ", a, ".vario_id ",
    "AND c.modifier_id = ", a, ".modifier_id AND c.is_active = 1 ",
    "AND r.is_primary = 1 AND r.review_approved = 1)"
  )
}

#' The `moved` predicate for an assertion alias.
#' @noRd
.svc_cvs_moved_sql <- function(a, evidence_alias, review_alias) {
  paste0(
    "EXISTS (SELECT 1 FROM variation_ontology_evidence ", evidence_alias, " ",
    "WHERE ", evidence_alias, ".assertion_id = ", a, ".assertion_id ",
    "AND ", evidence_alias, ".origin_review_id IS NOT NULL ",
    "AND NOT EXISTS (SELECT 1 FROM ndd_entity_review ", review_alias, " ",
    "WHERE ", review_alias, ".review_id = ", evidence_alias, ".origin_review_id ",
    "AND ", review_alias, ".entity_id = ", a, ".entity_id ",
    "AND ", review_alias, ".is_primary = 1 AND ", review_alias, ".review_approved = 1))"
  )
}

#' Build the shared WHERE fragment plus its bound parameters.
#'
#' Returned for a given set of table aliases so the outer read and the paging
#' subquery can carry the SAME predicate text -- SQL cannot reference a
#' same-SELECT alias such as `moved` in a WHERE clause, so it must be repeated
#' rather than referenced.
#' @noRd
.svc_cvs_filters <- function(params, a, v, evidence_alias, review_alias) {
  clauses <- character()
  values <- list()

  clauses <- c(clauses, paste0(a, ".state IN ('active_unconfirmed', 'suggested')"))

  if (!is.null(params$state)) {
    clauses <- c(clauses, paste0(a, ".state = ?"))
    values <- c(values, list(params$state))
  }
  if (!is.null(params$source_key)) {
    clauses <- c(clauses, paste0(
      "EXISTS (SELECT 1 FROM variation_ontology_evidence ", evidence_alias, "s ",
      "WHERE ", evidence_alias, "s.assertion_id = ", a, ".assertion_id ",
      "AND ", evidence_alias, "s.source_key = ?)"
    ))
    values <- c(values, list(params$source_key))
  }
  if (!is.null(params$max_strength)) {
    clauses <- c(clauses, paste0(
      "(SELECT MAX(", evidence_alias, "m.evidence_strength) ",
      "FROM variation_ontology_evidence ", evidence_alias, "m ",
      "WHERE ", evidence_alias, "m.assertion_id = ", a, ".assertion_id) = ?"
    ))
    values <- c(values, list(params$max_strength))
  }
  if (isTRUE(params$moved)) {
    clauses <- c(clauses, .svc_cvs_moved_sql(a, paste0(evidence_alias, "v"), review_alias))
  }
  if (!is.null(params$q)) {
    clauses <- c(clauses, paste0("(", v, ".symbol LIKE ? OR ", a, ".entity_id = ?)"))
    entity_id <- suppressWarnings(as.integer(params$q))
    values <- c(values, list(paste0("%", params$q, "%"),
                             if (is.na(entity_id)) -1L else entity_id))
  }

  list(sql = paste(clauses, collapse = "\n   AND "), params = values)
}

#' The ORDER BY for a validated sort key, over a given set of expressions.
#'
#' Used TWICE per request, and both uses are load-bearing:
#'
#'  1. inside the paging subquery, to choose WHICH assertions are on this page;
#'  2. on the outer query, to preserve that order in the response.
#'
#' A JOIN does not inherit its derived table's ordering, so an outer ORDER BY
#' that starts with anything else silently discards the requested sort -- which
#' is exactly what an early draft did: "weakest first" returned the strongest
#' row first because the outer clause led with assertion_id. The unit tests
#' asserted the ORDER BY text and could not see it; the integration test could.
#'
#' Unrecorded strength sorts LAST in BOTH directions, mirroring
#' .svc_vp_evidence_order() on the entity-scoped surface: `null` means NOT
#' RECORDED, and floating those rows to the top of "weakest first" would put the
#' least informative rows in front of the actual weak-evidence backlog.
#'
#' @param sort A key from CURATE_VARIATION_QUEUE_SORTS (already allowlisted).
#' @param strength SQL expression yielding the row's max evidence strength.
#' @param a Assertion table/derived-table alias for the entity_asc ordering.
#' @noRd
.svc_cvs_order_sql <- function(sort, strength, a) {
  switch(
    sort,
    strength_desc = paste0("(", strength, " IS NULL) ASC, ", strength, " DESC"),
    strength_asc  = paste0("(", strength, " IS NULL) ASC, ", strength, " ASC"),
    entity_asc    = paste0(a, ".entity_id ASC, ", a, ".vario_id ASC, ", a, ".modifier_id ASC")
  )
}


# ---------------------------------------------------------------------------
# The listing
# ---------------------------------------------------------------------------

#' One page of the curation queue
#'
#' @param params Validated parameters from
#'   svc_curate_variation_suggestion_params().
#' @param pool Database connection or pool.
#' @return `list(meta = list(page, page_size, total), data = <list of rows>)`.
#' @export
svc_curate_variation_suggestions <- function(params, pool) {
  count_filters <- .svc_cvs_filters(params, "a", "v", "e", "r")
  count_rows <- db_execute_query(
    paste(
      "SELECT COUNT(DISTINCT a.assertion_id) AS total",
      "  FROM variation_ontology_assertion a",
      "  JOIN ndd_entity_view v ON v.entity_id = a.entity_id",
      paste0(" WHERE ", count_filters$sql),
      sep = "\n"
    ),
    count_filters$params,
    conn = pool
  )
  total <- if (is.null(count_rows) || nrow(count_rows) == 0L) {
    0L
  } else {
    as.integer(count_rows$total[[1L]])
  }

  # The paging subquery repeats the same predicate under its own aliases, then
  # the outer query joins back to fan out one row per evidence record.
  page_filters <- .svc_cvs_filters(params, "pa", "pv", "pe", "pr")
  offset <- (params$page - 1L) * params$page_size

  rows <- db_execute_query(
    paste(
      "SELECT a.assertion_id, a.entity_id, v.symbol, v.disease_ontology_name,",
      "       a.vario_id, l.vario_name, a.modifier_id, a.state,",
      paste0("       ", .svc_cvs_served_sql("a"), " AS served,"),
      paste0("       ", .svc_cvs_moved_sql("a", "e2", "r2"), " AS moved,"),
      "       e.evidence_id, e.source_type, e.source_key, e.batch_id,",
      "       e.evidence_strength, e.evidence_summary",
      "  FROM variation_ontology_assertion a",
      "  JOIN ndd_entity_view v ON v.entity_id = a.entity_id",
      "  LEFT JOIN variation_ontology_list l ON l.vario_id = a.vario_id",
      "  LEFT JOIN variation_ontology_evidence e ON e.assertion_id = a.assertion_id",
      "  JOIN (SELECT pa.assertion_id, MAX(pe.evidence_strength) AS page_strength",
      "          FROM variation_ontology_assertion pa",
      "          JOIN ndd_entity_view pv ON pv.entity_id = pa.entity_id",
      "          LEFT JOIN variation_ontology_evidence pe",
      "                 ON pe.assertion_id = pa.assertion_id",
      paste0("         WHERE ", page_filters$sql),
      "         GROUP BY pa.assertion_id",
      paste0("         ORDER BY ",
             .svc_cvs_order_sql(params$sort, "MAX(pe.evidence_strength)", "pa"),
             ", pa.assertion_id ASC"),
      "         LIMIT ? OFFSET ?) page ON page.assertion_id = a.assertion_id",
      # Repeat the page's ordering FIRST: a JOIN does not inherit its derived
      # table's order, so leading with anything else discards the caller's sort.
      paste0(" ORDER BY ",
             .svc_cvs_order_sql(params$sort, "page.page_strength", "a"),
             ", a.assertion_id ASC,"),
      "          (e.evidence_strength IS NULL) ASC, e.evidence_strength DESC,",
      "          e.source_key ASC, e.evidence_id ASC",
      sep = "\n"
    ),
    # ONLY the paging subquery's params: the outer query carries no WHERE of its
    # own -- it is constrained entirely by the JOIN to `page` -- so binding the
    # filters twice is a "Number of params don't match" error at run time. The
    # unit tests mock db_execute_query and cannot see that; the integration test
    # and the real-schema smoke below can.
    c(page_filters$params, list(as.integer(params$page_size), as.integer(offset))),
    conn = pool
  )

  list(
    meta = list(
      page = as.integer(params$page),
      page_size = as.integer(params$page_size),
      total = total
    ),
    data = .svc_cvs_shape_rows(rows, params$sort)
  )
}

#' Group joined assertion+evidence rows into one object per assertion.
#'
#' Mirrors svc_entity_variation_suggestions(): a LEFT JOIN against an assertion
#' with no evidence yields exactly one row whose `source_key` is NA, and
#' `source_key` is NOT NULL in the evidence table, so NA there can only mean "no
#' evidence row matched". Those phantom rows become an empty array rather than
#' one all-null entry.
#' @noRd
.svc_cvs_shape_rows <- function(rows, sort) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(list())
  }

  assertion_ids <- as.integer(rows$assertion_id)
  first_row <- vapply(unique(assertion_ids),
                      function(id) which(assertion_ids == id)[[1L]],
                      integer(1))

  lapply(first_row, function(i) {
    group <- rows[assertion_ids == assertion_ids[[i]], , drop = FALSE]
    real <- group[!is.na(group$source_key), , drop = FALSE]

    evidence <- if (nrow(real) == 0L) {
      list()
    } else {
      ordered <- real[
        .svc_vp_evidence_order(real$evidence_strength, as.character(real$source_key)), ,
        drop = FALSE
      ]
      lapply(seq_len(nrow(ordered)), function(j) {
        list(
          source_type = .svc_vp_na_to_null(as.character(ordered$source_type[[j]])),
          source_key  = .svc_vp_na_to_null(as.character(ordered$source_key[[j]])),
          batch_id    = .svc_vp_na_to_null(as.character(ordered$batch_id[[j]])),
          strength    = .svc_vp_na_to_null(as.integer(ordered$evidence_strength[[j]])),
          summary     = .svc_vp_na_to_null(as.character(ordered$evidence_summary[[j]]))
        )
      })
    }

    strengths <- if (nrow(real) == 0L) integer() else as.integer(real$evidence_strength)

    list(
      entity_id             = as.integer(group$entity_id[[1L]]),
      symbol                = .svc_vp_na_to_null(as.character(group$symbol[[1L]])),
      disease_ontology_name = .svc_vp_na_to_null(
        as.character(group$disease_ontology_name[[1L]])
      ),
      vario_id              = as.character(group$vario_id[[1L]]),
      vario_name            = .svc_vp_na_to_null(as.character(group$vario_name[[1L]])),
      modifier_id           = as.integer(group$modifier_id[[1L]]),
      state                 = as.character(group$state[[1L]]),
      served                = isTRUE(as.integer(group$served[[1L]]) == 1L),
      moved                 = isTRUE(as.integer(group$moved[[1L]]) == 1L),
      max_strength          = .svc_vp_max_strength(strengths),
      evidence              = evidence
    )
  })
}
