# test-unit-mondo-index-builder.R
# Unit tests for api/functions/mondo-index-builder.R
# Covers B1 (CURIE normalization), B2 (SSSOM parser), B3 (OBO parser),
# and B4 (xref merge with predicate ranking).

library(testthat)
library(tibble)

source_api_file("functions/mondo-index-builder.R", local = FALSE)

# ---------------------------------------------------------------------------
# B1: CURIE normalization
# ---------------------------------------------------------------------------

test_that("mondo_normalize_curie maps aliases to canonical casing", {
  expect_equal(mondo_normalize_curie("ORPHANET:530983"), "Orphanet:530983")
  expect_equal(mondo_normalize_curie("ORPHA:530983"),    "Orphanet:530983")
  expect_equal(mondo_normalize_curie("MIM:618524"),      "OMIM:618524")
  expect_equal(mondo_normalize_curie("UMLS:C1234567"),   "UMLS:C1234567")  # full CURIE, not bare
  expect_equal(mondo_curie_prefix("DOID:0081234"),       "DOID")
  # correction #7: OMIMPS must NOT become OMIM (stays OMIMPS, dropped by allowlist later)
  expect_equal(mondo_normalize_curie("OMIMPS:618524"),   "OMIMPS:618524")
  expect_false("OMIMPS" %in% MONDO_TARGET_ALLOWLIST)
  expect_true(is.na(mondo_normalize_curie("not-a-curie")))
})

# ---------------------------------------------------------------------------
# B2: SSSOM parser
# ---------------------------------------------------------------------------

test_that("mondo_sssom_parse maps predicates and normalizes targets", {
  fixture_path <- "fixtures/mondo-mini.sssom.tsv"
  if (!file.exists(fixture_path)) {
    testthat::skip(paste("Fixture not found:", fixture_path))
  }
  txt <- readChar(fixture_path, file.info(fixture_path)$size)
  out <- mondo_sssom_parse(txt)

  expect_true(all(c("mondo_id", "target_prefix", "target_id", "predicate") %in% names(out)))

  row <- out[!is.na(out$target_id) & out$target_id == "Orphanet:530983", ]
  expect_equal(unname(row$mondo_id), "MONDO:0032745")
  expect_equal(unname(row$predicate), "exactMatch")
  expect_equal(unname(row$target_prefix), "Orphanet")
})

test_that("mondo_sssom_parse drops non-MONDO subjects", {
  txt <- paste(
    "subject_id\tpredicate_id\tobject_id\tobject_label\tmapping_justification\tconfidence",
    "HP:0000001\tskos:exactMatch\tOMIM:618524\tfoo\tsemapv:Manual\t0.9",
    "MONDO:0032745\tskos:exactMatch\tOMIM:618524\tbar\tsemapv:Manual\t0.9",
    sep = "\n"
  )
  out <- mondo_sssom_parse(txt)
  expect_equal(nrow(out), 1L)
  expect_true(all(grepl("^MONDO:", out$mondo_id)))
})

test_that("mondo_sssom_parse maps unknown predicates to xref", {
  txt <- paste(
    "subject_id\tpredicate_id\tobject_id\tobject_label\tmapping_justification",
    "MONDO:0032745\tskos:relatedMatch\tOMIM:618524\tsome label\tsemapv:Manual",
    sep = "\n"
  )
  out <- mondo_sssom_parse(txt)
  expect_equal(unname(out$predicate), "xref")
})

# ---------------------------------------------------------------------------
# B3: OBO parser
# ---------------------------------------------------------------------------

test_that("mondo_obo_parse extracts version, terms, and xrefs", {
  fixture_path <- "fixtures/mondo-mini.obo"
  if (!file.exists(fixture_path)) {
    testthat::skip(paste("Fixture not found:", fixture_path))
  }
  txt <- readChar(fixture_path, file.info(fixture_path)$size)
  res <- mondo_obo_parse(txt)

  expect_equal(res$version, "2026-05-05")
  expect_true("MONDO:0032745" %in% res$terms$mondo_id)

  obs <- res$terms[res$terms$mondo_id == "MONDO:0000003", ]
  expect_equal(obs$is_obsolete, 1L)
  expect_equal(obs$replaced_by, "MONDO:0032745")

  xr <- res$xrefs[!is.na(res$xrefs$target_id) & res$xrefs$target_id == "OMIM:618524", ]
  expect_equal(xr$mondo_id, "MONDO:0032745")
  expect_equal(xr$predicate, "equivalentTo")  # from {source="MONDO:equivalentTo"}
})

test_that("mondo_obo_parse drops xrefs with prefix not in allowlist", {
  txt <- paste(
    "format-version: 1.2",
    "data-version: releases/2026-01-01",
    "ontology: mondo",
    "",
    "[Term]",
    "id: MONDO:0032745",
    "name: Test",
    "xref: OMIMPS:618524",
    "xref: OMIM:618524",
    sep = "\n"
  )
  res <- mondo_obo_parse(txt)
  expect_false(any(res$xrefs$target_prefix == "OMIMPS", na.rm = TRUE))
  expect_true(any(res$xrefs$target_prefix == "OMIM", na.rm = TRUE))
})

test_that("mondo_obo_parse skips non-MONDO ids", {
  txt <- paste(
    "format-version: 1.2",
    "data-version: releases/2026-01-01",
    "ontology: mondo",
    "",
    "[Term]",
    "id: HP:0000001",
    "name: not a mondo term",
    sep = "\n"
  )
  res <- mondo_obo_parse(txt)
  expect_equal(nrow(res$terms), 0L)
})

# ---------------------------------------------------------------------------
# B4: Merge xrefs with predicate ranking
# ---------------------------------------------------------------------------

test_that("mondo_merge_xrefs picks strongest predicate per (mondo_id,target_prefix,target_id)", {
  obo_xrefs <- tibble::tibble(
    mondo_id     = "MONDO:0032745",
    target_prefix = "OMIM",
    target_id    = "OMIM:618524",
    predicate    = "equivalentTo",
    origin       = "obo_xref",
    source       = NA_character_,
    target_label = NA_character_
  )
  sssom_xrefs <- tibble::tibble(
    mondo_id     = "MONDO:0032745",
    target_prefix = "OMIM",
    target_id    = "OMIM:618524",
    predicate    = "exactMatch",
    origin       = "sssom",
    source       = "semapv:ManualMappingCuration",
    target_label = "CTNNB1 syndrome"
  )
  merged <- mondo_merge_xrefs(obo_xrefs, sssom_xrefs)

  expect_equal(nrow(merged), 1L)
  expect_equal(merged$predicate, "exactMatch")     # exactMatch (rank 0) beats equivalentTo (rank 1)
  expect_equal(merged$target_label, "CTNNB1 syndrome")
})

test_that("mondo_merge_xrefs coalesces target_label from SSSOM when OBO has none", {
  obo_xrefs <- tibble::tibble(
    mondo_id     = "MONDO:0032745",
    target_prefix = "Orphanet",
    target_id    = "Orphanet:530983",
    predicate    = "xref",
    origin       = "obo_xref",
    source       = NA_character_,
    target_label = NA_character_
  )
  sssom_xrefs <- tibble::tibble(
    mondo_id     = "MONDO:0032745",
    target_prefix = "Orphanet",
    target_id    = "Orphanet:530983",
    predicate    = "exactMatch",
    source       = "semapv:Manual",
    target_label = "CTNNB1 syndrome label"
  )
  merged <- mondo_merge_xrefs(obo_xrefs, sssom_xrefs)
  expect_equal(merged$target_label, "CTNNB1 syndrome label")
})

test_that("mondo_merge_xrefs handles empty inputs", {
  empty_obo <- tibble::tibble(
    mondo_id = character(), target_prefix = character(), target_id = character(),
    predicate = character(), origin = character(), source = character(),
    target_label = character()
  )
  empty_sssom <- tibble::tibble(
    mondo_id = character(), target_prefix = character(), target_id = character(),
    predicate = character(), source = character(), target_label = character()
  )
  expect_equal(nrow(mondo_merge_xrefs(empty_obo, empty_sssom)), 0L)
})
