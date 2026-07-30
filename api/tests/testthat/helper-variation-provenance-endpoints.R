# tests/testthat/helper-variation-provenance-endpoints.R
#
# Fixtures and DB-seam stubs for test-unit-variation-provenance-endpoints.R
# (#608, task 5). Extracted into a helper so the test file itself stays under
# the repo's 600-line soft ceiling; testthat auto-loads helper-*.R before every
# test file, and every function here is `vpe_`-prefixed so it cannot collide
# with another file's fixtures.
#
# Nothing here touches a database: the two seams these builders shadow are
# `tbl()` / `primary_approved_reviews()` / `provenance_for_entity()` (for the
# public read) and `db_execute_query()` (for the two new routes). All of them
# are shadowed in a child environment of the function under test, so globalenv
# is never mutated and the production join/ordering code still runs for real.

VPE_ENTITY_ID <- 2097L


# ---------------------------------------------------------------------------
# Curated-read fixtures
# ---------------------------------------------------------------------------

vpe_variation_list <- function() {
  tibble::tibble(
    vario_id   = c("VariO:0001", "VariO:0015", "VariO:0017"),
    vario_name = c("variation", "protein truncation", "nonsynonymous variation")
  )
}

vpe_connect_rows <- function() {
  tibble::tibble(
    review_id   = rep(11L, 4),
    entity_id   = rep(VPE_ENTITY_ID, 4),
    vario_id    = c("VariO:0001", "VariO:0015", "VariO:0017", "VariO:0017"),
    modifier_id = c(1L, 1L, 1L, 5L),
    is_active   = rep(1L, 4)
  )
}

vpe_reviews <- function() {
  tibble::tibble(
    entity_id   = VPE_ENTITY_ID,
    review_id   = 11L,
    synopsis    = "synopsis text",
    review_date = as.Date("2026-01-01"),
    comment     = "a comment"
  )
}

# The exact tibble svc_entity_variation() returned BEFORE provenance existed.
# The release-gate test compares against this, so it must never be regenerated
# from the implementation under test.
vpe_pre_change_terms <- function() {
  tibble::tibble(
    entity_id   = rep(VPE_ENTITY_ID, 4),
    vario_id    = c("VariO:0001", "VariO:0015", "VariO:0017", "VariO:0017"),
    vario_name  = c("variation", "protein truncation",
                    "nonsynonymous variation", "nonsynonymous variation"),
    modifier_id = c(1L, 1L, 1L, 5L)
  )
}

# What provenance_for_entity() returns before the backfill has run: all columns
# present, zero rows.
vpe_empty_provenance <- function() {
  tibble::tibble(
    entity_id = integer(), vario_id = character(), modifier_id = integer(),
    state = character(), source_type = character(), source_key = character(),
    evidence_strength = integer(), evidence_summary = character()
  )
}

# VariO:0001/1 deliberately absent  -> curator-authored.
# VariO:0017/1 has two sources      -> deterministic ordering.
# VariO:0017/5 ('absent' claim)     -> independent provenance, unrecorded strength.
vpe_provenance <- function() {
  tibble::tibble(
    entity_id         = rep(VPE_ENTITY_ID, 4),
    vario_id          = c("VariO:0015", "VariO:0017", "VariO:0017", "VariO:0017"),
    modifier_id       = c(1L, 1L, 1L, 5L),
    state             = c("confirmed", "active_unconfirmed",
                          "active_unconfirmed", "active_unconfirmed"),
    source_type       = c("external_database", "external_database",
                          "literature", "external_database"),
    source_key        = c("clinvar", "clinvar", "synopsis", "clinvar"),
    evidence_strength = c(2L, 1L, 3L, NA_integer_),
    evidence_summary  = c("5 ClinVar records, max 2 stars",
                          "2 ClinVar records, max 1 star",
                          "Matched 'truncating variants' in synopsis",
                          NA_character_)
  )
}

#' Shadow the DB seams of svc_entity_variation()
#'
#' `fn` is passed in explicitly rather than looked up by name: `source_api_file(
#' local = FALSE)` sources into the CALLER's frame (the test file's evaluation
#' environment), not globalenv, so a helper-file closure cannot see it through
#' its own enclosure chain.
#'
#' `provenance_calls` (an environment) records how many times the provenance
#' query ran, so a test can prove it is ONE query per request and not one per
#' term.
vpe_variation_service <- function(fn,
                                  provenance = vpe_empty_provenance(),
                                  connect_rows = vpe_connect_rows(),
                                  variation_list = vpe_variation_list(),
                                  reviews = vpe_reviews(),
                                  provenance_calls = NULL) {
  env <- new.env(parent = environment(fn))
  env$tbl <- function(src, table_name, ...) {
    switch(table_name,
      "ndd_review_variation_ontology_connect" = connect_rows,
      "variation_ontology_list" = variation_list,
      stop("unexpected table in fixture: ", table_name)
    )
  }
  env$primary_approved_reviews <- function(pool, cols = NULL) reviews
  env$provenance_for_entity <- function(pool, entity_id) {
    if (!is.null(provenance_calls)) {
      provenance_calls$n <- provenance_calls$n + 1L
      provenance_calls$entity_id <- c(provenance_calls$entity_id, entity_id)
    }
    provenance
  }
  environment(fn) <- env
  fn
}

#' Serialize exactly as the routes' `json list(na="string", null="null")` does.
vpe_json <- function(x) {
  as.character(jsonlite::toJSON(x, na = "string", null = "null"))
}


# ---------------------------------------------------------------------------
# Route-service fixtures (db_execute_query seam)
# ---------------------------------------------------------------------------

#' Shadow db_execute_query() with a recorder that returns `rows`.
#'
#' `recorder` (an environment with `$sql` / `$params`) captures the emitted SQL
#' and its bound parameters so a test can assert the query is parameterized and
#' issued exactly once.
vpe_with_query <- function(fn, rows, recorder = NULL) {
  env <- new.env(parent = environment(fn))
  env$db_execute_query <- function(sql, params = list(), conn = NULL) {
    if (!is.null(recorder)) {
      recorder$sql <- c(recorder$sql, sql)
      recorder$params <- c(recorder$params, list(params))
    }
    rows
  }
  environment(fn) <- env
  fn
}

vpe_recorder <- function() {
  rec <- new.env(parent = emptyenv())
  rec$sql <- character()
  rec$params <- list()
  rec
}

# Deliberately NOT in the response order: the weaker source is listed first, so
# the strength-descending ordering has to be produced by the code under test
# rather than inherited from the fixture.
vpe_evidence_rows <- function() {
  data.frame(
    evidence_id = c(902L, 901L),
    entity_id = rep(VPE_ENTITY_ID, 2L),
    vario_id = rep("VariO:0017", 2L),
    modifier_id = rep(1L, 2L),
    state = rep("active_unconfirmed", 2L),
    source_type = c("external_database", "literature"),
    source_key = c("clinvar", "synopsis"),
    batch_id = c("b-2026-07-02", "b-2026-07-01"),
    source_version = c("clinvar-2026-06", "synopsis-v1"),
    evidence_summary = c("2 ClinVar records, max 1 star",
                         "Matched 'truncating variants' in synopsis"),
    evidence_strength = c(1L, 3L),
    evidence_json = c('{"records":2,"max_stars":1}',
                      '{"matched":["truncating variants"]}'),
    # Aliased in the query (`e.created_at AS evidence_created_at`) because the
    # suggestions query also selects the assertion's own `a.created_at`. Kept as
    # POSIXct, which is what the driver returns for a MySQL DATETIME.
    evidence_created_at = as.POSIXct(c("2026-02-15 10:23:00", "2026-02-14 08:00:00"),
                                     tz = "UTC"),
    stringsAsFactors = FALSE
  )
}

# The single LEFT-JOIN row an assertion with no evidence rows yet produces.
vpe_evidence_rows_no_evidence <- function() {
  rows <- vpe_evidence_rows()[1, ]
  rows$evidence_id <- NA_integer_
  rows$source_type <- NA_character_
  rows$source_key <- NA_character_
  rows$batch_id <- NA_character_
  rows$source_version <- NA_character_
  rows$evidence_summary <- NA_character_
  rows$evidence_strength <- NA_integer_
  rows$evidence_json <- NA_character_
  rows$evidence_created_at <- as.POSIXct(NA_character_, tz = "UTC")
  rows
}

# Rows for the two suggested assertions are INTERLEAVED and unsorted, so
# grouping has to key on assertion_id (not row adjacency) and the per-assertion
# evidence order has to be produced by the code under test.
vpe_suggestion_rows <- function() {
  data.frame(
    assertion_id = c(51L, 52L, 51L),
    evidence_id = c(801L, 802L, 803L),
    entity_id = rep(VPE_ENTITY_ID, 3L),
    vario_id = c("VariO:0017", "VariO:0015", "VariO:0017"),
    vario_name = c("nonsynonymous variation", "protein truncation",
                   "nonsynonymous variation"),
    modifier_id = c(1L, 1L, 1L),
    state = rep("suggested", 3L),
    source_type = c("external_database", "external_database", "literature"),
    source_key = c("clinvar", "clinvar", "synopsis"),
    batch_id = c("b2", "b3", "b1"),
    source_version = c("v2", "v3", "v1"),
    evidence_summary = c("2 records", "9 records", "synopsis match"),
    evidence_strength = c(1L, 4L, 3L),
    evidence_json = c('{"b":2}', '{"c":3}', '{"a":1}'),
    evidence_created_at = as.POSIXct(
      c("2026-02-15 10:23:00", "2026-02-16 09:00:00", "2026-02-14 08:00:00"),
      tz = "UTC"
    ),
    stringsAsFactors = FALSE
  )
}


# ---------------------------------------------------------------------------
# Endpoint-handler extraction and plumber routing probe
# ---------------------------------------------------------------------------

vpe_entity_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "entity_endpoints.R")
}

vpe_entity_source <- function() {
  readLines(vpe_entity_endpoint_path(), warn = FALSE)
}

#' Eval the top-level function literal following the first line matching
#' `decorator_regex` into `envir` (same idiom as test-endpoint-review.R).
vpe_extract_handler <- function(decorator_regex, envir) {
  src_lines <- vpe_entity_source()
  dec_hits <- grep(decorator_regex, src_lines)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in entity_endpoints.R: ", decorator_regex)
  }
  dec_line <- dec_hits[[1L]]

  parsed <- parse(file = vpe_entity_endpoint_path(), keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  handler_expr <- NULL
  for (i in seq_along(parsed)) {
    if (srcrefs[[i]][1L] > dec_line) {
      handler_expr <- parsed[[i]]
      break
    }
  }
  if (is.null(handler_expr)) {
    stop("No top-level expression found after decorator line ", dec_line)
  }
  eval(handler_expr, envir = envir)
}

vpe_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res
}

#' Build a plumber router from the REAL @get decorator list of
#' entity_endpoints.R, in the REAL declared order, with trivial handlers that
#' report which route matched.
#'
#' Plumber resolves routes in declaration order, so a probe built this way fails
#' the moment `suggestions` is declared after a dynamic route that would capture
#' it as a path param (verified empirically: a `/<sysndd_id>/variation/<vario_id>`
#' route declared first matches `/2097/variation/suggestions` with
#' vario_id = "suggestions").
vpe_route_probe_router <- function() {
  hits <- grep("^#\\*\\s+@get\\s+\\S+\\s*$", vpe_entity_source(), value = TRUE)
  paths <- sub("^#\\*\\s+@get\\s+", "", trimws(hits))

  lines <- unlist(lapply(paths, function(p) {
    c(paste0("#* @get ", p),
      paste0("function(...) list(matched = \"", p, "\")"),
      "")
  }))
  tmp <- tempfile(fileext = ".R")
  writeLines(lines, tmp)
  plumber::pr(tmp)
}

#' Dispatch a bare GET through a plumber router and return the response body.
vpe_dispatch <- function(pr, path) {
  req <- as.environment(list(
    REQUEST_METHOD = "GET", PATH_INFO = path, QUERY_STRING = "",
    rook.input = list(read_lines = function() "",
                      read = function(...) raw(0),
                      rewind = function() NULL),
    HTTP_HOST = "localhost", SERVER_NAME = "localhost", SERVER_PORT = "8000",
    rook.url_scheme = "http", HEADERS = c()
  ))
  pr$call(req)$body
}
