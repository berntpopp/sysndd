# tests/testthat/test-unit-disease-mapping-endpoint.R
#
# Unit tests for disease cross-ontology mapping read path (WP-D).
# Pure tests (no DB / no network) — runs on host.

library(testthat)
library(tibble)

source_api_file("functions/disease-ontology-mapping-repository.R", local = FALSE)

# ---------------------------------------------------------------------------
# D1 tests: disease_mapping_group_rows (pure function)
# ---------------------------------------------------------------------------

test_that("disease_mapping_group_rows groups by prefix in allowlist order", {
  rows <- tibble::tibble(
    target_prefix = c("Orphanet", "MONDO", "OMIM"),
    target_id     = c("Orphanet:530983", "MONDO:0032745", "OMIM:618524"),
    target_label  = c("Some disease", NA_character_, "OMIM label"),
    predicate     = c("exactMatch", "exactMatch", NA_character_),
    source        = c("mondo_sssom", "mondo_sssom", "sysndd_native")
  )
  result <- disease_mapping_group_rows(rows)

  expect_named(result, c("mappings", "mondo_id"))
  expect_equal(result$mondo_id, "MONDO:0032745")

  # Groups ordered by allowlist: MONDO first, then Orphanet, then OMIM
  group_names <- names(result$mappings)
  expect_equal(group_names[1], "MONDO")
  expect_equal(group_names[2], "Orphanet")
  expect_equal(group_names[3], "OMIM")

  # Each entry has the right fields
  mondo_entry <- result$mappings$MONDO[[1]]
  expect_equal(mondo_entry$id, "MONDO:0032745")
  expect_equal(mondo_entry$predicate, "exactMatch")
  expect_equal(mondo_entry$source, "mondo_sssom")

  # Orphanet entry has label
  orphanet_entry <- result$mappings$Orphanet[[1]]
  expect_equal(orphanet_entry$label, "Some disease")

  # OMIM entry has null predicate (NA becomes null in JSON)
  omim_entry <- result$mappings$OMIM[[1]]
  expect_true(is.na(omim_entry$predicate) || is.null(omim_entry$predicate))
})

test_that("disease_mapping_group_rows returns NULL mondo_id when no MONDO group", {
  rows <- tibble::tibble(
    target_prefix = c("OMIM"),
    target_id     = c("OMIM:618524"),
    target_label  = c(NA_character_),
    predicate     = c(NA_character_),
    source        = c("sysndd_native")
  )
  result <- disease_mapping_group_rows(rows)
  expect_null(result$mondo_id)
  expect_true("OMIM" %in% names(result$mappings))
})

test_that("disease_mapping_group_rows with empty rows returns empty", {
  rows <- tibble::tibble(
    target_prefix = character(0),
    target_id     = character(0),
    target_label  = character(0),
    predicate     = character(0),
    source        = character(0)
  )
  result <- disease_mapping_group_rows(rows)
  expect_null(result$mondo_id)
  expect_equal(result$mappings, list())
})

# ---------------------------------------------------------------------------
# D3 test: ontology_endpoints.R select() includes new projection columns
# ---------------------------------------------------------------------------

test_that("ontology_endpoints.R select() includes the new projection columns", {
  ontology_path <- file.path(get_api_dir(), "endpoints", "ontology_endpoints.R")
  if (!file.exists(ontology_path)) skip("ontology_endpoints.R not found")
  src <- readLines(ontology_path, warn = FALSE)
  for (col in c("UMLS", "MedGen", "NCIT", "GARD", "ontology_mapping_release")) {
    expect_true(
      any(grepl(paste0("\\b", col, "\\b"), src)),
      info = paste("Column", col, "missing from ontology_endpoints.R select()")
    )
  }
})
