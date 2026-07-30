# api/tests/testthat/test-unit-variation-provenance-endpoints.R
#
# The API READ surface for variation-ontology provenance (#608, task 5).
#
# WHY THE FIRST TEST IN THIS FILE IS A RELEASE GATE
# -------------------------------------------------
# The backfill that populates variation_ontology_assertion /
# variation_ontology_evidence lives in a different repository and has not run
# yet. Absence of an assertion row MEANS "curator-authored" -- so shipping a
# provenance read surface while rows are missing would positively present
# machine-derived annotations as curator-authored. The design therefore makes
# backfill coverage a release gate (spec 7.1), and this file's first test is the
# code-side half of that gate: with ZERO assertion rows the curated variation
# response must be inert -- every `provenance` null, no other field changed, no
# field dropped, added or reordered.
#
# TEST STRATEGY (no database)
# ---------------------------
# Every DB seam is injected, so these are true unit tests. Fixtures and the
# seam-shadowing builders live in helper-variation-provenance-endpoints.R:
#   * svc_entity_variation() -- its enclosing environment is shadowed so
#     `tbl()`, `primary_approved_reviews()` and `provenance_for_entity()` return
#     fixtures. attach_provenance() and the JSON-readiness pass run FOR REAL, so
#     the join and the ordering under test are the production ones.
#   * the two new routes' services -- `db_execute_query()` is shadowed with a
#     recorder, so the emitted SQL and its bound params are asserted directly.
#   * the routing-order test builds a plumber router from the REAL decorator
#     list in endpoints/entity_endpoints.R, in the real declared order, so it
#     fails if the suggestions route is ever moved below a dynamic route that
#     would capture "suggestions" as a path param.
#
# The real-database proof of the write/read round trip lives in
# test-integration-review-write-atomicity.R and the migration smoke test in
# test-unit-variation-provenance-migration.R; this file deliberately does not
# create or drop the provenance tables, so it cannot race those files.

library(testthat)
suppressMessages(library(dplyr))
library(tibble)

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/variation-provenance-repository.R", local = FALSE)
source_api_file("services/entity-variation-provenance-service.R", local = FALSE)
source_api_file("services/entity-read-endpoint-service.R", local = FALSE)


# ===========================================================================
# 1. RELEASE GATE -- zero assertion rows must leave the public read inert
# ===========================================================================

test_that("RELEASE GATE: with zero assertion rows the variation response is inert (provenance null on every term, nothing else changed)", { # nolint: line_length_linter
  svc <- vpe_variation_service(svc_entity_variation, provenance = vpe_empty_provenance())

  out <- svc(VPE_ENTITY_ID, current_review = TRUE,
             approved_review_ids = NULL, pool = "STUB_POOL")

  # (a) The curated columns are byte-identical to the pre-change result:
  #     same columns, same order, same values, same types.
  expect_identical(names(out),
                   c("entity_id", "vario_id", "vario_name", "modifier_id", "provenance"))
  curated <- dplyr::select(out, -provenance)
  expect_identical(as.data.frame(curated), as.data.frame(vpe_pre_change_terms()))

  # (b) Every term is curator-authored.
  expect_true(all(vapply(out$provenance, is.null, logical(1))))

  # (c) And that survives the route's own serializer as JSON `null` -- NOT the
  #     `{}` that jsonlite emits for a NULL list element without null="null".
  json <- vpe_json(out)
  expect_false(grepl('"provenance":{}', json, fixed = TRUE))
  expect_equal(lengths(regmatches(json, gregexpr('"provenance":null', json, fixed = TRUE))),
               4L)

  # (d) Dropping the provenance key reproduces the pre-change payload exactly.
  expect_identical(vpe_json(curated), vpe_json(vpe_pre_change_terms()))
})

test_that("RELEASE GATE: the inert response never invents a state or a source", {
  svc <- vpe_variation_service(svc_entity_variation, provenance = vpe_empty_provenance())
  json <- vpe_json(svc(VPE_ENTITY_ID, TRUE, NULL, "STUB_POOL"))

  for (token in c("suggested", "active_unconfirmed", "confirmed", "rejected",
                  "sources", "max_strength", "source_key")) {
    expect_false(grepl(token, json, fixed = TRUE),
                 info = paste("inert response must not contain:", token))
  }
})


# ===========================================================================
# 2-5. provenance on the existing public read
# ===========================================================================

test_that("a curator-authored term (no assertion row) has provenance null", {
  svc <- vpe_variation_service(svc_entity_variation, provenance = vpe_provenance())
  out <- svc(VPE_ENTITY_ID, TRUE, NULL, "STUB_POOL")

  row <- which(out$vario_id == "VariO:0001" & out$modifier_id == 1L)
  expect_length(row, 1L)
  expect_null(out$provenance[[row]])
  expect_true(grepl('"vario_id":"VariO:0001","vario_name":"variation","modifier_id":1,"provenance":null', # nolint: line_length_linter
                    vpe_json(out), fixed = TRUE))
})

test_that("a machine-derived term reports state, max_strength and a deterministically ordered sources array", { # nolint: line_length_linter
  svc <- vpe_variation_service(svc_entity_variation, provenance = vpe_provenance())
  out <- svc(VPE_ENTITY_ID, TRUE, NULL, "STUB_POOL")

  prov <- out$provenance[[which(out$vario_id == "VariO:0017" & out$modifier_id == 1L)]]
  expect_equal(prov$state, "active_unconfirmed")
  expect_equal(prov$max_strength, 3L)
  expect_length(prov$sources, 2L)
  # strength DESC, then source_key ASC
  expect_equal(prov$sources[[1]]$source_key, "synopsis")
  expect_equal(prov$sources[[1]]$strength, 3L)
  expect_equal(prov$sources[[1]]$source_type, "literature")
  expect_equal(prov$sources[[1]]$summary, "Matched 'truncating variants' in synopsis")
  expect_equal(prov$sources[[2]]$source_key, "clinvar")
  expect_equal(prov$sources[[2]]$strength, 1L)

  # sources must be a JSON ARRAY even when there is exactly one source.
  single <- out$provenance[[which(out$vario_id == "VariO:0015")]]
  expect_equal(single$state, "confirmed")
  expect_length(single$sources, 1L)
  expect_true(grepl('"sources":[{', vpe_json(out), fixed = TRUE))
})

test_that("present and absent for the same vario_id get independent provenance", {
  svc <- vpe_variation_service(svc_entity_variation, provenance = vpe_provenance())
  out <- svc(VPE_ENTITY_ID, TRUE, NULL, "STUB_POOL")

  present <- out$provenance[[which(out$vario_id == "VariO:0017" & out$modifier_id == 1L)]]
  absent  <- out$provenance[[which(out$vario_id == "VariO:0017" & out$modifier_id == 5L)]]

  expect_false(identical(present, absent))
  expect_length(present$sources, 2L)
  expect_length(absent$sources, 1L)
  expect_equal(absent$sources[[1]]$source_key, "clinvar")
  # The 'absent' claim's single source has no recorded strength...
  expect_null(absent$max_strength)
  expect_null(absent$sources[[1]]$strength)
  expect_null(absent$sources[[1]]$summary)
  # ...and an unrecorded numeric must serialize as null, never the string "NA".
  json <- vpe_json(out)
  expect_false(grepl('"strength":["NA"]', json, fixed = TRUE))
  expect_false(grepl('"max_strength":["NA"]', json, fixed = TRUE))
  expect_true(grepl('"max_strength":null', json, fixed = TRUE))
})

test_that("a term whose assertion has no evidence rows yet keeps its state with an empty sources array", { # nolint: line_length_linter
  prov <- tibble::tibble(
    entity_id = VPE_ENTITY_ID, vario_id = "VariO:0015", modifier_id = 1L,
    state = "active_unconfirmed",
    source_type = NA_character_, source_key = NA_character_,
    evidence_strength = NA_integer_, evidence_summary = NA_character_
  )
  svc <- vpe_variation_service(svc_entity_variation, provenance = prov)
  out <- svc(VPE_ENTITY_ID, TRUE, NULL, "STUB_POOL")

  block <- out$provenance[[which(out$vario_id == "VariO:0015")]]
  expect_equal(block$state, "active_unconfirmed")
  expect_length(block$sources, 0L)
  expect_true(grepl('"sources":[]', vpe_json(out), fixed = TRUE))
})

test_that("the full evidence payload is never inlined on the hot variation response", {
  svc <- vpe_variation_service(svc_entity_variation, provenance = vpe_provenance())
  out <- svc(VPE_ENTITY_ID, TRUE, NULL, "STUB_POOL")
  json <- vpe_json(out)

  for (token in c("evidence_json", "batch_id", "source_version", "evidence_id",
                  "assertion_id", "evidence_summary")) {
    expect_false(grepl(token, json, fixed = TRUE),
                 info = paste("hot path must not carry:", token))
  }
  prov <- out$provenance[[which(out$vario_id == "VariO:0017" & out$modifier_id == 1L)]]
  expect_setequal(names(prov), c("state", "max_strength", "sources"))
  expect_setequal(names(prov$sources[[1]]),
                  c("source_type", "source_key", "strength", "summary"))
})

test_that("provenance costs exactly ONE query per request, not one per term", {
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  calls$entity_id <- integer()

  svc <- vpe_variation_service(svc_entity_variation, provenance = vpe_provenance(),
                               provenance_calls = calls)
  out <- svc(VPE_ENTITY_ID, TRUE, NULL, "STUB_POOL")

  expect_equal(nrow(out), 4L)      # four terms...
  expect_equal(calls$n, 1L)        # ...one provenance query
  expect_equal(as.integer(calls$entity_id), VPE_ENTITY_ID)
})

test_that("the legacy current_review = FALSE branch also carries provenance", {
  svc <- vpe_variation_service(svc_entity_variation, provenance = vpe_provenance())
  out <- svc(VPE_ENTITY_ID, current_review = FALSE,
             approved_review_ids = 11L, pool = "STUB_POOL")

  expect_true("provenance" %in% names(out))
  expect_equal(out$provenance[[which(out$vario_id == "VariO:0015")]]$state, "confirmed")
})

test_that("an entity with no curated variation terms returns an empty set, not an error", {
  svc <- vpe_variation_service(
    svc_entity_variation,
    provenance = vpe_empty_provenance(),
    connect_rows = vpe_connect_rows()[0, ]
  )
  out <- svc(VPE_ENTITY_ID, TRUE, NULL, "STUB_POOL")
  expect_equal(nrow(out), 0L)
  expect_true("provenance" %in% names(out))
})


# ===========================================================================
# Path-parameter validation
# ===========================================================================

test_that("modifier_id must be an integer; anything else is a 400", {
  expect_identical(svc_variation_modifier_id_param("5"), 5L)
  expect_identical(svc_variation_modifier_id_param(list("1")), 1L)
  expect_identical(svc_variation_modifier_id_param(1L), 1L)

  for (bad in list("abc", "1.5", "", "1;DROP", "0x1", "99999999999999", NA_character_)) {
    err <- tryCatch(svc_variation_modifier_id_param(bad), error = function(e) e)
    expect_s3_class(err, "error_400")
  }
})

test_that("vario_id survives a raw colon and a percent-encoded colon identically", {
  expect_identical(svc_variation_vario_id_param("VariO:0017"), "VariO:0017")
  expect_identical(svc_variation_vario_id_param("VariO%3A0017"), "VariO:0017")
  expect_identical(svc_variation_vario_id_param(list("VariO:0017")), "VariO:0017")
})

test_that("a malformed vario_id is a 400, not a silently mangled lookup", {
  for (bad in list("", "VariO:0017 OR 1=1", "a b", "VariO:0017'", NA_character_,
                   paste(rep("V", 200), collapse = ""))) {
    err <- tryCatch(svc_variation_vario_id_param(bad), error = function(e) e)
    expect_s3_class(err, "error_400")
  }
})

test_that("a non-integer entity id is a 400", {
  err <- tryCatch(svc_variation_entity_id_param("abc"), error = function(e) e)
  expect_s3_class(err, "error_400")
  expect_identical(svc_variation_entity_id_param("2097"), 2097L)
})


# ===========================================================================
# 6. Evidence detail route service
# ===========================================================================

test_that("the evidence route returns the full payloads for exactly the requested assertion", {
  rec <- vpe_recorder()
  fn <- vpe_with_query(svc_entity_variation_evidence, vpe_evidence_rows(), rec)

  out <- fn(VPE_ENTITY_ID, "VariO:0017", "1", pool = "STUB_POOL")

  expect_equal(out$entity_id, VPE_ENTITY_ID)
  expect_equal(out$vario_id, "VariO:0017")
  expect_equal(out$modifier_id, 1L)
  expect_equal(out$state, "active_unconfirmed")
  expect_length(out$evidence, 2L)
  # strength DESC -- the fixture deliberately arrives weakest-first.
  expect_equal(out$evidence[[1]]$source_key, "synopsis")
  expect_equal(out$evidence[[1]]$evidence_strength, 3L)
  expect_equal(out$evidence[[1]]$batch_id, "b-2026-07-01")
  expect_equal(out$evidence[[2]]$source_key, "clinvar")
  # evidence_json is served parsed, not as an opaque string.
  expect_true(is.list(out$evidence[[1]]$evidence_json))
  expect_equal(out$evidence[[1]]$evidence_json$matched[[1]], "truncating variants")

  # ONE query, and the full identity is bound as parameters, never interpolated.
  expect_length(rec$sql, 1L)
  expect_equal(unname(unlist(rec$params[[1]])), c("2097", "VariO:0017", "1"))
  expect_false(grepl("VariO:0017", rec$sql[[1]], fixed = TRUE))
})

test_that("the evidence route is scoped to the public entity surface and the served states", {
  rec <- vpe_recorder()
  fn <- vpe_with_query(svc_entity_variation_evidence, vpe_evidence_rows(), rec)
  fn(VPE_ENTITY_ID, "VariO:0017", "1", pool = "STUB_POOL")

  sql <- rec$sql[[1]]
  # The entity must be resolved through ndd_entity_view IN THE SAME QUERY, so a
  # non-public entity can never yield a row at all.
  expect_match(sql, "ndd_entity_view", fixed = TRUE)
  # And a 'suggested'/'rejected' assertion must never surface on this PUBLIC
  # route -- it mirrors provenance_for_entity()'s state gate.
  expect_match(sql, "'active_unconfirmed'", fixed = TRUE)
  expect_match(sql, "'confirmed'", fixed = TRUE)
  expect_false(grepl("'suggested'", sql, fixed = TRUE))
})

test_that("an unknown entity and an unknown assertion are indistinguishable 404s", {
  empty <- vpe_evidence_rows()[0, ]

  err_unknown_entity <- tryCatch(
    vpe_with_query(svc_entity_variation_evidence, empty)(
      424242L, "VariO:0017", "1", pool = "STUB_POOL"),
    error = function(e) e
  )
  err_unknown_assertion <- tryCatch(
    vpe_with_query(svc_entity_variation_evidence, empty)(
      VPE_ENTITY_ID, "VariO:0099", "1", pool = "STUB_POOL"),
    error = function(e) e
  )

  expect_s3_class(err_unknown_entity, "error_404")
  expect_s3_class(err_unknown_assertion, "error_404")
  # Byte-identical message: the caller cannot tell which of the two it hit.
  expect_identical(conditionMessage(err_unknown_entity),
                   conditionMessage(err_unknown_assertion))
  # And the message must not echo back the requested identifiers.
  expect_false(grepl("424242", conditionMessage(err_unknown_entity), fixed = TRUE))
  expect_false(grepl("VariO:0099", conditionMessage(err_unknown_assertion), fixed = TRUE))
})

test_that("an assertion that exists but has no evidence rows yet returns an empty evidence array", {
  out <- vpe_with_query(svc_entity_variation_evidence, vpe_evidence_rows_no_evidence())(
    VPE_ENTITY_ID, "VariO:0017", "1", pool = "STUB_POOL")

  expect_equal(out$state, "active_unconfirmed")
  expect_length(out$evidence, 0L)
  expect_true(grepl('"evidence":[]', vpe_json(out), fixed = TRUE))
})


# ===========================================================================
# 7. Suggestions route service
# ===========================================================================

test_that("the suggestions route groups evidence per suggested assertion", {
  rec <- vpe_recorder()
  fn <- vpe_with_query(svc_entity_variation_suggestions, vpe_suggestion_rows(), rec)

  out <- fn(VPE_ENTITY_ID, pool = "STUB_POOL")

  expect_length(out, 2L)
  keys <- vapply(out, function(s) paste0(s$vario_id, "|", s$modifier_id), character(1))
  # The suggestion list itself is deterministically ordered by vario_id, then
  # modifier_id -- never by whatever row order the driver happened to return.
  expect_identical(keys, c("VariO:0015|1", "VariO:0017|1"))
  expect_equal(out[[1]]$max_strength, 4L)

  multi <- out[[which(keys == "VariO:0017|1")]]
  expect_equal(multi$state, "suggested")
  expect_equal(multi$vario_name, "nonsynonymous variation")
  expect_equal(multi$max_strength, 3L)
  expect_length(multi$evidence, 2L)
  expect_equal(multi$evidence[[1]]$source_key, "synopsis")  # strength DESC
  expect_equal(multi$evidence[[2]]$source_key, "clinvar")
  expect_true(is.list(multi$evidence[[1]]$evidence_json))

  # ONE query, entity id bound, scoped to the public entity surface and to
  # `suggested` only (a confirmed/active row must never appear here).
  expect_length(rec$sql, 1L)
  expect_identical(unname(unlist(rec$params[[1]])), VPE_ENTITY_ID)
  expect_match(rec$sql[[1]], "ndd_entity_view", fixed = TRUE)
  expect_match(rec$sql[[1]], "'suggested'", fixed = TRUE)
})

test_that("an entity with no suggestions returns an empty JSON array", {
  out <- vpe_with_query(svc_entity_variation_suggestions, vpe_suggestion_rows()[0, ])(
    VPE_ENTITY_ID, pool = "STUB_POOL")
  expect_length(out, 0L)
  expect_identical(vpe_json(out), "[]")
})


# ===========================================================================
# Endpoint handlers -- decorator surface and the Curator role gate
# ===========================================================================

test_that("both new routes are declared with the expected paths and serializers", {
  src <- vpe_entity_source()

  sug_idx <- grep("^#\\*\\s+@get\\s+/<sysndd_id>/variation/suggestions\\s*$", src)
  evi_idx <- grep(
    "^#\\*\\s+@get\\s+/<sysndd_id>/variation/<vario_id>/<modifier_id>/evidence\\s*$", src)
  expect_length(sug_idx, 1L)
  expect_length(evi_idx, 1L)

  # null="null" is load-bearing: without it jsonlite renders a NULL list element
  # as `{}` and the release gate's `"provenance":null` contract breaks.
  var_idx <- grep("^#\\*\\s+@get\\s+/<sysndd_id>/variation\\s*$", src)
  expect_length(var_idx, 1L)
  for (idx in c(var_idx, sug_idx, evi_idx)) {
    window <- paste(src[max(1L, idx - 20L):idx], collapse = "\n")
    expect_match(window, 'null="null"', fixed = TRUE)
  }
})

test_that("the suggestions handler self-gates at Curator and refuses before touching the DB", {
  denied <- new.env(parent = emptyenv())
  denied$service_called <- FALSE

  env <- new.env(parent = globalenv())
  env$pool <- "STUB_POOL"
  env$require_role <- function(req, res, min_role) {
    res$status <- 403L
    stop(error_forbidden(sprintf("This action requires %s privileges.", min_role)))
  }
  env$svc_entity_variation_suggestions <- function(...) {
    denied$service_called <- TRUE
    list()
  }

  handler <- vpe_extract_handler(
    "^#\\*\\s+@get\\s+/<sysndd_id>/variation/suggestions\\s*$", env)
  res <- vpe_mock_res()

  # Anonymous / Reviewer callers are forwarded by require_auth, so the handler
  # itself must refuse them.
  err <- tryCatch(handler(req = list(PATH_INFO = "/2097/variation/suggestions"),
                          res = res, sysndd_id = "2097"),
                  error = function(e) e)
  expect_s3_class(err, "error_403")
  expect_match(conditionMessage(err), "Curator")
  expect_equal(res$status, 403L)
  expect_false(denied$service_called)
})

test_that("the suggestions handler delegates to the service for a Curator caller", {
  seen <- new.env(parent = emptyenv())
  seen$args <- NULL

  env <- new.env(parent = globalenv())
  env$pool <- "STUB_POOL"
  env$require_role <- function(req, res, min_role) {
    seen$min_role <- min_role
    invisible(TRUE)
  }
  env$svc_entity_variation_suggestions <- function(sysndd_id, pool) {
    seen$args <- list(sysndd_id = sysndd_id, pool = pool)
    list("ok")
  }

  handler <- vpe_extract_handler(
    "^#\\*\\s+@get\\s+/<sysndd_id>/variation/suggestions\\s*$", env)
  out <- handler(req = list(user_role = "Curator"), res = vpe_mock_res(),
                 sysndd_id = "2097")

  expect_equal(seen$min_role, "Curator")
  expect_equal(seen$args$sysndd_id, "2097")
  expect_equal(out, list("ok"))
})

test_that("the public evidence handler is NOT role-gated and delegates to the service", {
  seen <- new.env(parent = emptyenv())

  env <- new.env(parent = globalenv())
  env$pool <- "STUB_POOL"
  env$require_role <- function(req, res, min_role) {
    stop("the public evidence route must not call require_role()")
  }
  env$svc_entity_variation_evidence <- function(sysndd_id, vario_id, modifier_id, pool) {
    seen$args <- list(sysndd_id, vario_id, modifier_id)
    list("ok")
  }

  handler <- vpe_extract_handler(
    "^#\\*\\s+@get\\s+/<sysndd_id>/variation/<vario_id>/<modifier_id>/evidence\\s*$", env)
  out <- handler(sysndd_id = "2097", vario_id = "VariO:0017", modifier_id = "1")

  expect_equal(out, list("ok"))
  expect_equal(seen$args, list("2097", "VariO:0017", "1"))
})


# ===========================================================================
# 8. Declaration order -- /variation/suggestions must not be shadowed
# ===========================================================================

test_that("GET /<id>/variation/suggestions is not shadowed by the dynamic vario_id route", {
  skip_if_not_installed("plumber")
  pr <- vpe_route_probe_router()

  expect_match(vpe_dispatch(pr, "/2097/variation/suggestions"),
               "/<sysndd_id>/variation/suggestions", fixed = TRUE)
  expect_match(vpe_dispatch(pr, "/2097/variation/VariO:0017/1/evidence"),
               "/<sysndd_id>/variation/<vario_id>/<modifier_id>/evidence", fixed = TRUE)
  expect_match(vpe_dispatch(pr, "/2097/variation"),
               "/<sysndd_id>/variation\"", fixed = TRUE)
})

test_that("the suggestions route is declared before the dynamic vario_id route", {
  src <- vpe_entity_source()
  sug_idx <- grep("^#\\*\\s+@get\\s+/<sysndd_id>/variation/suggestions\\s*$", src)[[1]]
  evi_idx <- grep(
    "^#\\*\\s+@get\\s+/<sysndd_id>/variation/<vario_id>/<modifier_id>/evidence\\s*$",
    src)[[1]]
  expect_lt(sug_idx, evi_idx)
})

test_that("a CURIE with a raw colon survives plumber path routing", {
  skip_if_not_installed("plumber")
  # Empirical basis for using a path param rather than a query param: plumber
  # 1.3.x matches a colon inside a single path segment, but it does NOT
  # percent-decode path params -- hence svc_variation_vario_id_param()'s
  # URLdecode(). Both encodings must reach the same vario_id.
  tmp <- tempfile(fileext = ".R")
  writeLines(c(
    "#* @get /<sysndd_id>/variation/<vario_id>/<modifier_id>/evidence",
    "function(sysndd_id, vario_id, modifier_id) list(vario_id = vario_id)"
  ), tmp)
  pr <- plumber::pr(tmp)

  expect_match(vpe_dispatch(pr, "/2097/variation/VariO:0017/1/evidence"),
               "VariO:0017", fixed = TRUE)
  expect_match(vpe_dispatch(pr, "/2097/variation/VariO%3A0017/1/evidence"),
               "VariO%3A0017", fixed = TRUE)
  expect_identical(
    svc_variation_vario_id_param("VariO%3A0017"),
    svc_variation_vario_id_param("VariO:0017")
  )
})


# ===========================================================================
# Module registration
# ===========================================================================

test_that("the new provenance endpoint service module is registered for runtime loading", {
  # BLOCKING handoff requirement: without this line, svc_entity_variation()
  # cannot resolve svc_variation_attach_provenance() at runtime and the public
  # variation route 500s. Add it to bootstrap/load_modules.R's service_files
  # list immediately before "services/entity-read-endpoint-service.R".
  bootstrap <- paste(
    readLines(file.path(get_api_dir(), "bootstrap", "load_modules.R"), warn = FALSE),
    collapse = "\n")
  expect_match(bootstrap, "services/entity-variation-provenance-service.R", fixed = TRUE)
})
