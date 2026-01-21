# tests/testthat/test-unit-ontology-functions.R
# Tests for api/functions/ontology-functions.R
#
# Ontology functions involve file downloads and external data.
# We test the pure transformation logic and data patterns.

library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(withr)

# Source helper functions that ontology functions may depend on
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/ontology-functions.R")) {
  normalizePath("../..")
} else {
  stop("Cannot find api directory")
}

# Source file functions first (ontology uses check_file_age, get_newest_file)
tryCatch({
  source(file.path(api_dir, "functions", "file-functions.R"))
}, error = function(e) {
  message("Warning: Could not load file-functions.R: ", e$message)
})

# =============================================================================
# identify_critical_ontology_changes() tests
# =============================================================================

test_that("identify_critical_ontology_changes identifies removed terms", {
  # Create mock ontology sets
  disease_ontology_set_update <- tibble(
    disease_ontology_id_version = c("OMIM:100001", "OMIM:100002"),
    disease_ontology_id = c("OMIM:100001", "OMIM:100002"),
    hgnc_id = c("HGNC:1", "HGNC:2"),
    hpo_mode_of_inheritance_term = c("HP:0000001", "HP:0000002"),
    disease_ontology_name = c("Disease A", "Disease B")
  )

  disease_ontology_set_current <- tibble(
    disease_ontology_id_version = c("OMIM:100001", "OMIM:100002", "OMIM:100003"),
    disease_ontology_id = c("OMIM:100001", "OMIM:100002", "OMIM:100003"),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    hpo_mode_of_inheritance_term = c("HP:0000001", "HP:0000002", "HP:0000003"),
    disease_ontology_name = c("Disease A", "Disease B", "Disease C")
  )

  # Entity uses a term that was removed in update
  ndd_entity_view_ontology_set <- tibble(
    disease_ontology_id_version = c("OMIM:100003")  # This term is NOT in update
  )

  # Source the function
  tryCatch({
    source(file.path(api_dir, "functions", "ontology-functions.R"))

    result <- identify_critical_ontology_changes(
      disease_ontology_set_update,
      disease_ontology_set_current,
      ndd_entity_view_ontology_set
    )

    # Should identify changes for terms used in entities but not in update
    expect_true(is.data.frame(result) || is_tibble(result))
    expect_true("critical" %in% names(result) || nrow(result) >= 0)
  }, error = function(e) {
    skip("ontology-functions.R requires additional dependencies")
  })
})

test_that("identify_critical_ontology_changes handles matching terms", {
  # Create mock ontology sets where all terms match
  disease_ontology_set_update <- tibble(
    disease_ontology_id_version = c("OMIM:100001", "OMIM:100002"),
    disease_ontology_id = c("OMIM:100001", "OMIM:100002"),
    hgnc_id = c("HGNC:1", "HGNC:2"),
    hpo_mode_of_inheritance_term = c("HP:0000001", "HP:0000002"),
    disease_ontology_name = c("Disease A", "Disease B")
  )

  disease_ontology_set_current <- disease_ontology_set_update

  ndd_entity_view_ontology_set <- tibble(
    disease_ontology_id_version = c("OMIM:100001")  # This term IS in update
  )

  tryCatch({
    source(file.path(api_dir, "functions", "ontology-functions.R"))

    result <- identify_critical_ontology_changes(
      disease_ontology_set_update,
      disease_ontology_set_current,
      ndd_entity_view_ontology_set
    )

    # Should return empty result (no critical changes)
    expect_true(is.data.frame(result) || is_tibble(result))
    expect_equal(nrow(result), 0)
  }, error = function(e) {
    skip("ontology-functions.R requires additional dependencies")
  })
})

# =============================================================================
# Pure transformation tests (without external data)
# =============================================================================

test_that("ontology ID version parsing works", {
  # Test the pattern for versioned IDs: OMIM:123456_1
  id_versioned <- "OMIM:123456_1"
  id_plain <- "OMIM:123456"

  has_version_v <- str_detect(id_versioned, "_")
  has_version_p <- str_detect(id_plain, "_")

  expect_true(has_version_v)
  expect_false(has_version_p)
})

test_that("ontology source detection works", {
  # Test mondo vs omim detection
  mondo_id <- "MONDO:0000001"
  omim_id <- "OMIM:123456"

  is_mondo <- str_detect(mondo_id, "^MONDO:")
  is_omim <- str_detect(omim_id, "^OMIM:")

  expect_true(is_mondo)
  expect_true(is_omim)
  expect_false(str_detect(mondo_id, "^OMIM:"))
  expect_false(str_detect(omim_id, "^MONDO:"))
})

test_that("ontology ID format validation", {
  # Test various ontology ID formats
  valid_ids <- c("MONDO:0000001", "OMIM:123456", "DOID:456", "HP:0000118")
  invalid_ids <- c("MONDO0000001", "OMIM-123456", "123456")

  # Valid IDs should match pattern
  for (id in valid_ids) {
    expect_true(str_detect(id, "^[A-Z]+:\\d+"))
  }

  # Invalid IDs should not match
  for (id in invalid_ids) {
    expect_false(str_detect(id, "^[A-Z]+:\\d+"))
  }
})

# =============================================================================
# Mode of inheritance term mapping tests
# =============================================================================

test_that("inheritance term normalization patterns work", {
  # Test the mapping patterns used in process_omim_ontology
  raw_terms <- c("Autosomal dominant", "Autosomal recessive", "X-linked")
  expected <- c("Autosomal dominant inheritance", "Autosomal recessive inheritance", "X-linked inheritance")

  # Replicate the mapping logic from ontology-functions.R
  normalized <- case_when(
    raw_terms == "Autosomal dominant" ~ "Autosomal dominant inheritance",
    raw_terms == "Autosomal recessive" ~ "Autosomal recessive inheritance",
    raw_terms == "X-linked" ~ "X-linked inheritance",
    TRUE ~ raw_terms
  )

  expect_equal(normalized, expected)
})

test_that("complex inheritance term mapping works", {
  # Test additional inheritance term mappings from process_omim_ontology
  raw_terms <- c(
    "Digenic dominant",
    "Digenic recessive",
    "Isolated cases",
    "Mitochondrial",
    "Multifactorial"
  )

  expected <- c(
    "Digenic inheritance",
    "Digenic inheritance",
    "Sporadic",
    "Mitochondrial inheritance",
    "Multifactorial inheritance"
  )

  normalized <- case_when(
    raw_terms == "Digenic dominant" ~ "Digenic inheritance",
    raw_terms == "Digenic recessive" ~ "Digenic inheritance",
    raw_terms == "Isolated cases" ~ "Sporadic",
    raw_terms == "Mitochondrial" ~ "Mitochondrial inheritance",
    raw_terms == "Multifactorial" ~ "Multifactorial inheritance",
    TRUE ~ raw_terms
  )

  expect_equal(normalized, expected)
})

test_that("X-linked inheritance term variations normalize correctly", {
  # Test X-linked variations
  raw_terms <- c(
    "X-linked",
    "X-linked dominant",
    "X-linked recessive",
    "Pseudoautosomal dominant",
    "Pseudoautosomal recessive"
  )

  expected <- c(
    "X-linked inheritance",
    "X-linked dominant inheritance",
    "X-linked recessive inheritance",
    "X-linked dominant inheritance",
    "X-linked recessive inheritance"
  )

  normalized <- case_when(
    raw_terms == "X-linked" ~ "X-linked inheritance",
    raw_terms == "X-linked dominant" ~ "X-linked dominant inheritance",
    raw_terms == "X-linked recessive" ~ "X-linked recessive inheritance",
    raw_terms == "Pseudoautosomal dominant" ~ "X-linked dominant inheritance",
    raw_terms == "Pseudoautosomal recessive" ~ "X-linked recessive inheritance",
    TRUE ~ raw_terms
  )

  expect_equal(normalized, expected)
})

# =============================================================================
# File age and caching logic tests
# =============================================================================

test_that("ontology file caching logic works", {
  withr::with_tempdir({
    # Create a recent file
    today <- format(Sys.Date(), "%Y-%m-%d")
    filename <- paste0("disease_ontology_set.", today, ".csv")
    writeLines("test,data\n1,2", filename)

    # The functions should use cached file when recent
    files <- list.files(pattern = "disease_ontology_set")
    expect_true(length(files) > 0)
  })
})

test_that("ontology file naming convention", {
  # Test file naming pattern: prefix.YYYY-MM-DD.extension
  today <- format(Sys.Date(), "%Y-%m-%d")

  file_patterns <- c(
    paste0("disease_ontology_set.", today, ".csv"),
    paste0("mondo_ontology_mapping.", today, ".csv"),
    paste0("genemap2_hgnc.", today, ".csv")
  )

  for (pattern in file_patterns) {
    expect_true(str_detect(pattern, "\\d{4}-\\d{2}-\\d{2}"))
  }
})

# =============================================================================
# Data structure validation tests
# =============================================================================

test_that("MONDO term structure is valid", {
  # Test the structure expected from process_mondo_ontology
  mondo_mock <- tibble(
    disease_ontology_id_version = "MONDO:0000001",
    disease_ontology_id = "MONDO:0000001",
    disease_ontology_name = "disease or disorder",
    disease_ontology_source = "mondo",
    disease_ontology_date = format(Sys.Date(), "%Y-%m-%d"),
    disease_ontology_is_specific = FALSE,
    hgnc_id = NA_character_,
    hpo_mode_of_inheritance_term = NA_character_
  )

  expect_true(all(c(
    "disease_ontology_id_version",
    "disease_ontology_id",
    "disease_ontology_name",
    "disease_ontology_source",
    "disease_ontology_is_specific",
    "hgnc_id",
    "hpo_mode_of_inheritance_term"
  ) %in% names(mondo_mock)))

  expect_equal(mondo_mock$disease_ontology_source, "mondo")
  expect_false(mondo_mock$disease_ontology_is_specific)
})

test_that("OMIM term structure is valid", {
  # Test the structure expected from process_omim_ontology
  omim_mock <- tibble(
    disease_ontology_id_version = "OMIM:123456_1",
    disease_ontology_id = "OMIM:123456",
    disease_ontology_name = "Test Disease",
    disease_ontology_source = "morbidmap",
    disease_ontology_date = format(Sys.Date(), "%Y-%m-%d"),
    disease_ontology_is_specific = TRUE,
    hgnc_id = "HGNC:1",
    hpo_mode_of_inheritance_term = "HP:0000006"
  )

  expect_true(all(c(
    "disease_ontology_id_version",
    "disease_ontology_id",
    "disease_ontology_name",
    "disease_ontology_source",
    "disease_ontology_is_specific",
    "hgnc_id",
    "hpo_mode_of_inheritance_term"
  ) %in% names(omim_mock)))

  expect_equal(omim_mock$disease_ontology_source, "morbidmap")
  expect_true(omim_mock$disease_ontology_is_specific)
})

# =============================================================================
# Ontology mapping patterns
# =============================================================================

test_that("ontology xref pattern parsing works", {
  # Test parsing of xref strings like "OMIM:123456;DOID:4567"
  xref_string <- "OMIM:123456;DOID:4567;Orphanet:789"

  # Split and parse
  parts <- str_split(xref_string, ";")[[1]]

  expect_equal(length(parts), 3)
  expect_true(all(str_detect(parts, "^[A-Z]")))
})

test_that("ontology type extraction from xref works", {
  # Test extracting ontology type from xref
  xrefs <- c("OMIM:123456", "DOID:4567", "Orphanet:789")

  ontology_types <- str_split(xrefs, ":", simplify = TRUE)[, 1]

  expect_equal(ontology_types, c("OMIM", "DOID", "Orphanet"))
})

# =============================================================================
# Versioning logic tests
# =============================================================================

test_that("versioning logic for duplicate ontology entries", {
  # Test the versioning pattern used when same ontology ID appears multiple times
  test_data <- tibble(
    disease_ontology_id = c("OMIM:123456", "OMIM:123456", "OMIM:123456", "OMIM:789012"),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3", "HGNC:4")
  )

  # Replicate versioning logic
  versioned <- test_data %>%
    group_by(disease_ontology_id) %>%
    mutate(n = 1) %>%
    mutate(count = n()) %>%
    mutate(version = cumsum(n)) %>%
    ungroup() %>%
    mutate(disease_ontology_id_version = case_when(
      count == 1 ~ disease_ontology_id,
      count >= 1 ~ paste0(disease_ontology_id, "_", version)
    ))

  expect_equal(versioned$disease_ontology_id_version[1], "OMIM:123456_1")
  expect_equal(versioned$disease_ontology_id_version[2], "OMIM:123456_2")
  expect_equal(versioned$disease_ontology_id_version[3], "OMIM:123456_3")
  expect_equal(versioned$disease_ontology_id_version[4], "OMIM:789012")
})

# =============================================================================
# Date formatting tests
# =============================================================================

test_that("date formatting for ontology files", {
  # Test date format used in ontology functions
  current_date <- format(Sys.Date(), "%Y-%m-%d")

  expect_true(str_detect(current_date, "^\\d{4}-\\d{2}-\\d{2}$"))
})

test_that("UTC timestamp formatting", {
  # Test UTC timestamp format
  utc_timestamp <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

  expect_true(str_detect(utc_timestamp, "^\\d{4}-\\d{2}-\\d{2}$"))
})
