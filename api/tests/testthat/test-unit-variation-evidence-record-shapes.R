# test-unit-variation-evidence-record-shapes.R
#
# Cross-repo contract for `variation_ontology_evidence.evidence_json` (#612).
#
# The WRITER lives in sysndd-administration
# (scripts/data-corrections/005-variation-provenance-backfill/provenance_builder.py,
# admin#16); this repository is the READER. A key-name mismatch fails SILENTLY
# there -- an unrecognised key is omitted rather than guessed at -- which is how
# the extdb2 batch rendered `consequence` alone and the synopsis batch rendered
# nothing at all while the dialog reported no problem.
#
# The fixture is the artifact both repositories point at, and it drives the
# TypeScript suite too (variationEvidenceRecords.spec.ts) -- the same one-file,
# two-suite, both-directions pattern as clinvar-significance-vocabulary.json.
#
# R'S STAKE is the WIRE SHAPE the TypeScript normalizer is written against:
# `stored_json` is what the MySQL column holds, `wire_sample` is what a client
# actually receives, and this file proves the first turns into the second. Get
# that wrong and the frontend is written against a payload that never arrives.

source_api_file("services/entity-variation-provenance-service.R", local = FALSE)

fixture <- jsonlite::fromJSON(
  testthat::test_path("fixtures", "variation-evidence-record-shapes.json"),
  simplifyVector = FALSE
)

shape_names <- names(fixture$shapes)

# One joined assertion+evidence row, shaped exactly as the two production
# queries hand it to .svc_vp_evidence_records().
evidence_row <- function(shape) {
  tibble::tibble(
    source_type         = shape$source_type,
    source_key          = shape$source_key,
    batch_id            = paste0(shape$source_key, "-2026-02"),
    source_version      = NA_character_,
    evidence_summary    = "fixture row",
    evidence_strength   = 2L,
    evidence_json       = shape$stored_json,
    evidence_created_at = "2026-08-05 15:31:37"
  )
}

parsed_payload <- function(shape) {
  records <- .svc_vp_evidence_records(evidence_row(shape))
  testthat::expect_length(records, 1L)
  records[[1L]]$evidence_json
}

# The exact serializer arguments the routes declare via
# `#* @serializer json list(na="string", null="null")`. Replicated rather than
# invoked, because plumber is not loaded here; the decorator itself is pinned by
# a separate static assertion at the bottom of this file.
as_wire <- function(payload) {
  jsonlite::fromJSON(
    as.character(jsonlite::toJSON(payload, auto_unbox = FALSE, na = "string", null = "null")),
    simplifyVector = FALSE
  )
}


test_that("the fixture covers the three batches the backfill actually wrote", {
  expect_setequal(shape_names, c("clinvar", "extdb2", "synopsis"))
})


test_that("every shape's stored payload carries exactly its declared container keys", {
  for (name in shape_names) {
    shape <- fixture$shapes[[name]]
    payload <- parsed_payload(shape)
    expect_setequal(names(payload), unlist(shape$container_keys))
  }
})


test_that("every shape's record keys match the fixture in BOTH directions", {
  for (name in shape_names) {
    shape <- fixture$shapes[[name]]
    declared <- unlist(shape$record_keys)
    required <- unlist(shape$required_record_keys)
    if (is.null(required)) required <- character()

    seen <- character()
    for (record in parsed_payload(shape)$records) {
      # No record may carry a key the fixture does not declare -- otherwise the
      # reader has no chance of knowing it exists.
      undeclared <- setdiff(names(record), declared)
      expect_true(
        length(undeclared) == 0L,
        info = paste0(name, ": undeclared key(s) ", paste(undeclared, collapse = ", "))
      )
      expect_true(
        all(required %in% names(record)),
        info = paste0(name, ": missing required key(s) ",
                      paste(setdiff(required, names(record)), collapse = ", "))
      )
      seen <- union(seen, names(record))
    }
    # ...and the fixture may not declare a key no sample record carries, which is
    # what catches a key the writer has since dropped.
    expect_setequal(seen, declared)
  }
})


test_that("clinvar `matched` carries strings, never records", {
  # normalizeMatched() renders these with String(), so a record here would show
  # as "[object Object]". It must stay a text list and must never be folded into
  # the record-container probe.
  shape <- fixture$shapes$clinvar
  matched <- parsed_payload(shape)$matched
  expect_gt(length(matched), 0L)
  for (item in matched) {
    expect_type(item, "character")
    expect_length(item, 1L)
  }
})


test_that("the stored payload serializes to the captured production wire shape", {
  # This is the load-bearing assertion: the TypeScript normalizer is written
  # against `wire_sample`, which was captured verbatim from the production API.
  # If stored -> wire ever stops producing it, the frontend is decoding a
  # payload that no longer arrives.
  for (name in shape_names) {
    shape <- fixture$shapes[[name]]
    expect_equal(as_wire(parsed_payload(shape)), shape$wire_sample, info = name)
  }
})


test_that("a boolean FALSE survives serialization as [false]", {
  # `negated` is the ONLY field in the whole payload whose FALSE value is
  # meaningful: a negated synopsis match is evidence AGAINST the term, which is
  # why the builder scores it 1 instead of 3. Dropping it, or stringifying it to
  # "false", would present a refutation as a confirmation.
  shape <- fixture$shapes$synopsis
  wire <- as.character(jsonlite::toJSON(
    parsed_payload(shape), auto_unbox = FALSE, na = "string", null = "null"
  ))
  expect_true(grepl('"negated":[false]', wire, fixed = TRUE))
  expect_true(grepl('"negated":[true]', wire, fixed = TRUE))
})


test_that("the evidence route still declares the null-preserving serializer", {
  # The wire assertions above replicate the serializer's arguments rather than
  # invoking plumber, so they would stay green if the route lost its decorator.
  # `null="null"` is what keeps `provenance: null` from becoming `{}` -- i.e.
  # what keeps "curator-authored" expressible at all.
  endpoints <- readLines(
    file.path(get_api_dir(), "endpoints", "entity_endpoints.R"),
    warn = FALSE
  )
  serializer_lines <- grep('@serializer json list(na="string", null="null")',
                           endpoints, fixed = TRUE)
  expect_gt(length(serializer_lines), 0L)

  evidence_route <- grep("@get /<sysndd_id>/variation/<vario_id>/<modifier_id>/evidence",
                         endpoints, fixed = TRUE)
  expect_length(evidence_route, 1L)
  # The decorator block sits immediately above its route; require one within the
  # preceding 40 lines rather than anywhere in the file.
  expect_true(any(serializer_lines > evidence_route - 40L & serializer_lines < evidence_route))
})
