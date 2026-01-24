# test-unit-mondo-functions.R
# Unit tests for api/functions/mondo-functions.R
#
# These tests cover MONDO SSSOM parsing and mapping functions.
# Tests use mock data to avoid network calls and external dependencies.

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/mondo-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(withr)
library(readr)
library(dplyr)
library(stringr)
library(tibble)

# Source file-functions first (dependency)
source(file.path(api_dir, "functions/file-functions.R"))

# Source functions being tested
source(file.path(api_dir, "functions/mondo-functions.R"))


# ============================================================================
# Helper: Create mock SSSOM file
# ============================================================================

create_mock_sssom_file <- function(file_path, include_comments = TRUE) {
  sssom_content <- character()

  if (include_comments) {
    sssom_content <- c(
      "# curie_map:",
      "#   MONDO: http://purl.obolibrary.org/obo/MONDO_",
      "#   OMIM: https://omim.org/entry/",
      "# mapping_set_id: http://purl.obolibrary.org/obo/mondo/mappings/mondo_exactmatch_omim.sssom.tsv"
    )
  }

  # Add header and data rows (tab-separated)
  sssom_content <- c(
    sssom_content,
    "subject_id\tpredicate_id\tobject_id\tmapping_justification",
    "MONDO:0000001\tskos:exactMatch\tOMIM:100100\tsemapv:LexicalMatching",
    "MONDO:0000002\tskos:exactMatch\tOMIM:100200\tsemapv:LexicalMatching",
    "MONDO:0000003\tskos:exactMatch\tOMIM:100300\tsemapv:ManualMappingCuration",
    "MONDO:0000004\tskos:exactMatch\tOMIM:100400\tsemapv:LexicalMatching",
    "MONDO:0000005\tskos:exactMatch\tOMIM:100400\tsemapv:ManualMappingCuration",
    "HP:0000001\tskos:exactMatch\tOMIM:999999\tsemapv:Other"
  )

  writeLines(sssom_content, file_path)
  return(file_path)
}


# ============================================================================
# parse_mondo_sssom() Tests
# ============================================================================

test_that("parse_mondo_sssom ignores comment lines", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv", include_comments = TRUE)

    result <- parse_mondo_sssom(sssom_file)

    # Should have parsed data rows, ignoring # comments
    expect_true(nrow(result) > 0)
    expect_false(any(grepl("^#", result$mondo_id)))
    expect_false(any(grepl("curie_map", result$mondo_id)))
  })
})

test_that("parse_mondo_sssom filters for MONDO and OMIM only", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")

    result <- parse_mondo_sssom(sssom_file)

    # All subject_id should start with MONDO:
    expect_true(all(str_detect(result$mondo_id, "^MONDO:")))

    # All object_id should start with OMIM:
    expect_true(all(str_detect(result$omim_id, "^OMIM:")))

    # HP:0000001 row should be filtered out
    expect_false(any(str_detect(result$mondo_id, "^HP:")))
  })
})

test_that("parse_mondo_sssom returns correct column names", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")

    result <- parse_mondo_sssom(sssom_file)

    expect_true("mondo_id" %in% names(result))
    expect_true("omim_id" %in% names(result))
    expect_equal(length(names(result)), 2)
  })
})

test_that("parse_mondo_sssom preserves duplicate OMIM IDs with different MONDO IDs", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")

    result <- parse_mondo_sssom(sssom_file)

    # OMIM:100400 maps to both MONDO:0000004 and MONDO:0000005
    omim_100400_mappings <- result |>
      filter(omim_id == "OMIM:100400")

    expect_equal(nrow(omim_100400_mappings), 2)
    expect_true("MONDO:0000004" %in% omim_100400_mappings$mondo_id)
    expect_true("MONDO:0000005" %in% omim_100400_mappings$mondo_id)
  })
})

test_that("parse_mondo_sssom errors on missing file", {
  expect_error(
    parse_mondo_sssom("nonexistent_file.sssom.tsv"),
    "SSSOM file not found"
  )
})

test_that("parse_mondo_sssom works without comment lines", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv", include_comments = FALSE)

    result <- parse_mondo_sssom(sssom_file)

    # Should still work with raw TSV (no # comments)
    expect_true(nrow(result) > 0)
    expect_true(all(str_detect(result$mondo_id, "^MONDO:")))
  })
})


# ============================================================================
# get_mondo_for_omim() Tests
# ============================================================================

test_that("get_mondo_for_omim returns single match", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    result <- get_mondo_for_omim("OMIM:100100", mappings)

    expect_equal(result, "MONDO:0000001")
  })
})

test_that("get_mondo_for_omim returns semicolon-separated for multiple matches", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    result <- get_mondo_for_omim("OMIM:100400", mappings)

    # Should return both MONDO IDs, semicolon-separated
    expect_true(grepl(";", result))
    expect_true(grepl("MONDO:0000004", result))
    expect_true(grepl("MONDO:0000005", result))
  })
})

test_that("get_mondo_for_omim returns NA for no match", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    result <- get_mondo_for_omim("OMIM:999888", mappings)

    expect_true(is.na(result))
  })
})

test_that("get_mondo_for_omim handles NULL input", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    expect_true(is.na(get_mondo_for_omim(NULL, mappings)))
  })
})

test_that("get_mondo_for_omim handles NA input", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    expect_true(is.na(get_mondo_for_omim(NA, mappings)))
  })
})

test_that("get_mondo_for_omim handles empty string input", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    expect_true(is.na(get_mondo_for_omim("", mappings)))
  })
})


# ============================================================================
# add_mondo_mappings_to_ontology() Tests
# ============================================================================

test_that("add_mondo_mappings_to_ontology adds mondo_equivalent column", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    # Create mock disease_ontology_set
    ontology_set <- tibble::tibble(
      disease_ontology_id_version = c("OMIM:100100", "OMIM:100200"),
      disease_ontology_id = c("OMIM:100100", "OMIM:100200"),
      disease_ontology_source = c("mim2gene", "mim2gene")
    )

    result <- add_mondo_mappings_to_ontology(ontology_set, mappings)

    expect_true("mondo_equivalent" %in% names(result))
    expect_equal(result$mondo_equivalent[1], "MONDO:0000001")
    expect_equal(result$mondo_equivalent[2], "MONDO:0000002")
  })
})

test_that("add_mondo_mappings_to_ontology only maps mim2gene entries", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    # Create mock disease_ontology_set with mixed sources
    ontology_set <- tibble::tibble(
      disease_ontology_id_version = c("OMIM:100100", "MONDO:0000999"),
      disease_ontology_id = c("OMIM:100100", "MONDO:0000999"),
      disease_ontology_source = c("mim2gene", "mondo")
    )

    result <- add_mondo_mappings_to_ontology(ontology_set, mappings)

    # mim2gene entry should have mapping
    expect_equal(result$mondo_equivalent[1], "MONDO:0000001")

    # mondo entry should have NA (not mim2gene source)
    expect_true(is.na(result$mondo_equivalent[2]))
  })
})

test_that("add_mondo_mappings_to_ontology returns NA for unmapped OMIM", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    # Create mock with OMIM that doesn't have MONDO mapping
    ontology_set <- tibble::tibble(
      disease_ontology_id_version = c("OMIM:888888"),
      disease_ontology_id = c("OMIM:888888"),
      disease_ontology_source = c("mim2gene")
    )

    result <- add_mondo_mappings_to_ontology(ontology_set, mappings)

    expect_true(is.na(result$mondo_equivalent[1]))
  })
})

test_that("add_mondo_mappings_to_ontology handles empty ontology set", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    ontology_set <- tibble::tibble(
      disease_ontology_id_version = character(),
      disease_ontology_id = character(),
      disease_ontology_source = character()
    )

    result <- add_mondo_mappings_to_ontology(ontology_set, mappings)

    expect_equal(nrow(result), 0)
  })
})

test_that("add_mondo_mappings_to_ontology handles multiple MONDO matches", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    # OMIM:100400 maps to two MONDO IDs
    ontology_set <- tibble::tibble(
      disease_ontology_id_version = c("OMIM:100400"),
      disease_ontology_id = c("OMIM:100400"),
      disease_ontology_source = c("mim2gene")
    )

    result <- add_mondo_mappings_to_ontology(ontology_set, mappings)

    # Should have semicolon-separated MONDO IDs
    expect_true(grepl(";", result$mondo_equivalent[1]))
    expect_true(grepl("MONDO:0000004", result$mondo_equivalent[1]))
    expect_true(grepl("MONDO:0000005", result$mondo_equivalent[1]))
  })
})

test_that("add_mondo_mappings_to_ontology errors on missing columns", {
  withr::with_tempdir({
    sssom_file <- create_mock_sssom_file("test.sssom.tsv")
    mappings <- parse_mondo_sssom(sssom_file)

    # Create invalid ontology set (missing required columns)
    ontology_set <- tibble::tibble(
      some_column = c("value")
    )

    expect_error(
      add_mondo_mappings_to_ontology(ontology_set, mappings),
      "Missing required columns"
    )
  })
})


# ============================================================================
# download_mondo_sssom() Tests (Unit - No Network)
# ============================================================================

test_that("download_mondo_sssom returns cached file when recent", {
  withr::with_tempdir({
    # Create a "recent" cached file
    today <- format(Sys.Date(), "%Y-%m-%d")
    cached_file <- paste0("mondo-omim.", today, ".sssom.tsv")
    create_mock_sssom_file(cached_file)

    # Should return cached file without downloading
    result <- download_mondo_sssom(output_path = getwd(), force = FALSE)

    expect_true(file.exists(result))
    expect_true(grepl("mondo-omim", result))
    expect_true(grepl(today, result))
  })
})

test_that("download_mondo_sssom creates output directory if missing", {
  withr::with_tempdir({
    new_dir <- "new/nested/directory"

    # Function should create directory
    expect_false(dir.exists(new_dir))

    # Skip actual download but verify directory creation
    # Note: This would normally make a network call without mocking
    skip("Requires network access for full test")

    result <- download_mondo_sssom(output_path = new_dir)
    expect_true(dir.exists(new_dir))
  })
})

# Note: Full integration tests for download_mondo_sssom would require
# either mocking httr2 or actual network access. Network tests are
# intentionally skipped as unit tests focus on pure functions.
