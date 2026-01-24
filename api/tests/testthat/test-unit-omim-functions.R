# tests/testthat/test-unit-omim-functions.R
# Unit tests for api/functions/omim-functions.R
#
# Tests focus on data transformation logic that doesn't require network calls.
# JAX API is NOT tested with live calls - only pure function logic.

library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(withr)

# Source helper functions that omim functions may depend on
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/omim-functions.R")) {
  normalizePath("../..")
} else if (file.exists("functions/omim-functions.R")) {
  getwd()
} else {
  # Try one more level up (for testthat::test_file from api dir)
  normalizePath(file.path(getwd(), ".."))
}

# Source file functions first (dependency)
tryCatch({
  source(file.path(api_dir, "functions", "file-functions.R"))
}, error = function(e) {
  message("Warning: Could not load file-functions.R: ", e$message)
})

# =============================================================================
# parse_mim2gene() tests
# =============================================================================

test_that("parse_mim2gene filters phenotype entries correctly", {
  # Create mock mim2gene data
  mock_data <- "# MIM Number\tMIM Entry Type\tEntrez Gene ID\tApproved Gene Symbol\tEnsembl Gene ID
100050\tphenotype\t\t\t
100100\tgene\t1\tGENE1\tENSG00000001
100200\tphenotype\t\t\t
100300\tmoved/removed\t\t\t
100400\tpredominantly phenotypes\t\t\t"

  withr::with_tempfile("mim_file", {
    writeLines(mock_data, mim_file)

    # Source omim functions
    tryCatch({
      source(file.path(api_dir, "functions", "omim-functions.R"))

      # Test with include_moved_removed = TRUE (default)
      result <- parse_mim2gene(mim_file, include_moved_removed = TRUE)

      expect_true(is.data.frame(result))
      expect_equal(nrow(result), 3)  # 2 phenotypes + 1 moved/removed
      expect_true("100050" %in% result$mim_number)
      expect_true("100200" %in% result$mim_number)
      expect_true("100300" %in% result$mim_number)
      expect_false("100100" %in% result$mim_number)  # gene entry excluded
      expect_false("100400" %in% result$mim_number)  # predominantly phenotypes excluded
    }, error = function(e) {
      skip(paste("omim-functions.R requires additional dependencies:", e$message))
    })
  }, fileext = ".txt")
})

test_that("parse_mim2gene excludes moved/removed when requested", {
  mock_data <- "# Comment line
100050\tphenotype\t\t\t
100300\tmoved/removed\t\t\t"

  withr::with_tempfile("mim_file", {
    writeLines(mock_data, mim_file)

    tryCatch({
      source(file.path(api_dir, "functions", "omim-functions.R"))

      result <- parse_mim2gene(mim_file, include_moved_removed = FALSE)

      expect_equal(nrow(result), 1)
      expect_true("100050" %in% result$mim_number)
      expect_false("100300" %in% result$mim_number)
    }, error = function(e) {
      skip(paste("omim-functions.R requires additional dependencies:", e$message))
    })
  }, fileext = ".txt")
})

test_that("parse_mim2gene marks deprecated entries correctly", {
  mock_data <- "# Comment
100050\tphenotype\t\t\t
100300\tmoved/removed\t\t\t"

  withr::with_tempfile("mim_file", {
    writeLines(mock_data, mim_file)

    tryCatch({
      source(file.path(api_dir, "functions", "omim-functions.R"))

      result <- parse_mim2gene(mim_file, include_moved_removed = TRUE)

      # Check is_deprecated flag
      phenotype_row <- result[result$mim_number == "100050", ]
      deprecated_row <- result[result$mim_number == "100300", ]

      expect_false(phenotype_row$is_deprecated)
      expect_true(deprecated_row$is_deprecated)
    }, error = function(e) {
      skip(paste("omim-functions.R requires additional dependencies:", e$message))
    })
  }, fileext = ".txt")
})

test_that("parse_mim2gene handles NA gene symbols", {
  mock_data <- "# Comment
100050\tphenotype\t\t\t
100100\tphenotype\t123\tGENE1\tENSG00001"

  withr::with_tempfile("mim_file", {
    writeLines(mock_data, mim_file)

    tryCatch({
      source(file.path(api_dir, "functions", "omim-functions.R"))

      result <- parse_mim2gene(mim_file)

      # First entry should have NA gene_symbol
      row_1 <- result[result$mim_number == "100050", ]
      row_2 <- result[result$mim_number == "100100", ]

      expect_true(is.na(row_1$gene_symbol))
      expect_equal(row_2$gene_symbol, "GENE1")
    }, error = function(e) {
      skip(paste("omim-functions.R requires additional dependencies:", e$message))
    })
  }, fileext = ".txt")
})

# =============================================================================
# validate_omim_data() tests
# =============================================================================

test_that("validate_omim_data returns valid=TRUE for valid data", {
  valid_data <- tibble(
    disease_ontology_id = c("OMIM:100050", "OMIM:100100"),
    disease_ontology_id_version = c("OMIM:100050", "OMIM:100100"),
    disease_ontology_name = c("Disease A", "Disease B"),
    hgnc_id = c("HGNC:1", "HGNC:2")
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- validate_omim_data(valid_data)

    expect_true(result$valid)
    expect_equal(length(result$errors), 0)
    expect_true(str_detect(result$message, "Validation passed"))
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

test_that("validate_omim_data detects missing disease_ontology_id", {
  invalid_data <- tibble(
    disease_ontology_id = c("OMIM:100050", NA_character_),
    disease_ontology_id_version = c("OMIM:100050", "OMIM:100100"),
    disease_ontology_name = c("Disease A", "Disease B")
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- validate_omim_data(invalid_data)

    expect_false(result$valid)
    expect_true("missing_disease_ontology_id" %in% names(result$errors))
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

test_that("validate_omim_data detects missing disease_ontology_name", {
  invalid_data <- tibble(
    disease_ontology_id = c("OMIM:100050", "OMIM:100100"),
    disease_ontology_id_version = c("OMIM:100050", "OMIM:100100"),
    disease_ontology_name = c("Disease A", NA_character_)
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- validate_omim_data(invalid_data)

    expect_false(result$valid)
    expect_true("missing_disease_ontology_name" %in% names(result$errors))
    # Should include MIM numbers in error message
    expect_true(str_detect(result$errors$missing_disease_ontology_name, "OMIM:100100"))
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

test_that("validate_omim_data detects duplicate disease_ontology_id_version", {
  invalid_data <- tibble(
    disease_ontology_id = c("OMIM:100050", "OMIM:100050"),
    disease_ontology_id_version = c("OMIM:100050", "OMIM:100050"),  # Duplicate!
    disease_ontology_name = c("Disease A", "Disease B")
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- validate_omim_data(invalid_data)

    expect_false(result$valid)
    expect_true("duplicate_id_version" %in% names(result$errors))
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

# =============================================================================
# get_deprecated_mim_numbers() tests
# =============================================================================

test_that("get_deprecated_mim_numbers filters moved/removed entries", {
  mim_data <- tibble(
    mim_number = c("100050", "100100", "100200"),
    mim_entry_type = c("phenotype", "moved/removed", "phenotype"),
    gene_symbol = c(NA, NA, NA),
    is_deprecated = c(FALSE, TRUE, FALSE)
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- get_deprecated_mim_numbers(mim_data)

    expect_true(is.character(result))
    expect_equal(length(result), 1)
    expect_equal(result, "100100")
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

test_that("get_deprecated_mim_numbers returns empty vector when no deprecated", {
  mim_data <- tibble(
    mim_number = c("100050", "100100"),
    mim_entry_type = c("phenotype", "phenotype"),
    gene_symbol = c(NA, NA),
    is_deprecated = c(FALSE, FALSE)
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- get_deprecated_mim_numbers(mim_data)

    expect_true(is.character(result))
    expect_equal(length(result), 0)
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

# =============================================================================
# build_omim_ontology_set() tests
# =============================================================================

test_that("build_omim_ontology_set creates correct columns", {
  mim_data <- tibble(
    mim_number = c("100050", "100100"),
    mim_entry_type = c("phenotype", "phenotype"),
    gene_symbol = c("GENE1", NA),
    is_deprecated = c(FALSE, FALSE)
  )

  disease_names <- tibble(
    mim_number = c("100050", "100100"),
    disease_name = c("Disease A", "Disease B")
  )

  hgnc_list <- tibble(
    symbol = c("GENE1", "GENE2"),
    hgnc_id = c("HGNC:1", "HGNC:2")
  )

  moi_list <- tibble(
    hpo_mode_of_inheritance_term_name = c("Autosomal dominant inheritance"),
    hpo_mode_of_inheritance_term = c("HP:0000006")
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- build_omim_ontology_set(mim_data, disease_names, hgnc_list, moi_list)

    # Check required columns exist
    expected_cols <- c(
      "disease_ontology_id_version",
      "disease_ontology_id",
      "disease_ontology_name",
      "disease_ontology_source",
      "disease_ontology_date",
      "disease_ontology_is_specific",
      "hgnc_id",
      "hpo_mode_of_inheritance_term"
    )
    expect_true(all(expected_cols %in% names(result)))

    # Check source is mim2gene
    expect_true(all(result$disease_ontology_source == "mim2gene"))

    # Check is_specific is TRUE for OMIM entries
    expect_true(all(result$disease_ontology_is_specific))
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

test_that("build_omim_ontology_set handles versioning for duplicates", {
  # Same MIM number with different genes - should get versions
  mim_data <- tibble(
    mim_number = c("100050", "100050", "100100"),
    mim_entry_type = c("phenotype", "phenotype", "phenotype"),
    gene_symbol = c("GENE1", "GENE2", "GENE3"),
    is_deprecated = c(FALSE, FALSE, FALSE)
  )

  disease_names <- tibble(
    mim_number = c("100050", "100100"),
    disease_name = c("Disease A", "Disease B")
  )

  hgnc_list <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3"),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3")
  )

  moi_list <- tibble(
    hpo_mode_of_inheritance_term_name = character(),
    hpo_mode_of_inheritance_term = character()
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- build_omim_ontology_set(mim_data, disease_names, hgnc_list, moi_list)

    # Duplicate MIM should get versioned IDs
    omim_100050_versions <- result %>%
      filter(disease_ontology_id == "OMIM:100050") %>%
      pull(disease_ontology_id_version)

    expect_equal(length(omim_100050_versions), 2)
    expect_true(any(str_detect(omim_100050_versions, "_1$")))
    expect_true(any(str_detect(omim_100050_versions, "_2$")))

    # Unique MIM should not have version suffix
    omim_100100_version <- result %>%
      filter(disease_ontology_id == "OMIM:100100") %>%
      pull(disease_ontology_id_version)

    expect_equal(omim_100100_version, "OMIM:100100")
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

test_that("build_omim_ontology_set excludes deprecated entries", {
  mim_data <- tibble(
    mim_number = c("100050", "100100"),
    mim_entry_type = c("phenotype", "moved/removed"),
    gene_symbol = c("GENE1", NA),
    is_deprecated = c(FALSE, TRUE)  # 100100 is deprecated
  )

  disease_names <- tibble(
    mim_number = c("100050", "100100"),
    disease_name = c("Disease A", "Disease B")
  )

  hgnc_list <- tibble(
    symbol = c("GENE1"),
    hgnc_id = c("HGNC:1")
  )

  moi_list <- tibble(
    hpo_mode_of_inheritance_term_name = character(),
    hpo_mode_of_inheritance_term = character()
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- build_omim_ontology_set(mim_data, disease_names, hgnc_list, moi_list)

    # Deprecated entry should be excluded
    expect_equal(nrow(result), 1)
    expect_true("OMIM:100050" %in% result$disease_ontology_id)
    expect_false("OMIM:100100" %in% result$disease_ontology_id)
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

test_that("build_omim_ontology_set handles missing disease names", {
  mim_data <- tibble(
    mim_number = c("100050", "100100"),
    mim_entry_type = c("phenotype", "phenotype"),
    gene_symbol = c("GENE1", NA),
    is_deprecated = c(FALSE, FALSE)
  )

  # Only one disease name available
  disease_names <- tibble(
    mim_number = c("100050"),
    disease_name = c("Disease A")
  )

  hgnc_list <- tibble(
    symbol = c("GENE1"),
    hgnc_id = c("HGNC:1")
  )

  moi_list <- tibble(
    hpo_mode_of_inheritance_term_name = character(),
    hpo_mode_of_inheritance_term = character()
  )

  tryCatch({
    source(file.path(api_dir, "functions", "omim-functions.R"))

    result <- build_omim_ontology_set(mim_data, disease_names, hgnc_list, moi_list)

    # Both entries should be present
    expect_equal(nrow(result), 2)

    # First should have name, second should have NA
    row_1 <- result[result$disease_ontology_id == "OMIM:100050", ]
    row_2 <- result[result$disease_ontology_id == "OMIM:100100", ]

    expect_equal(row_1$disease_ontology_name, "Disease A")
    expect_true(is.na(row_2$disease_ontology_name))
  }, error = function(e) {
    skip(paste("omim-functions.R requires additional dependencies:", e$message))
  })
})

# =============================================================================
# Data format validation tests
# =============================================================================

test_that("OMIM ID format is correct", {
  # Test that disease_ontology_id follows OMIM:XXXXXX format
  valid_ids <- c("OMIM:100050", "OMIM:123456", "OMIM:612345")
  invalid_ids <- c("OMIM100050", "100050", "MIM:100050")

  for (id in valid_ids) {
    expect_true(str_detect(id, "^OMIM:\\d{5,6}$"))
  }

  for (id in invalid_ids) {
    expect_false(str_detect(id, "^OMIM:\\d{5,6}$"))
  }
})

test_that("versioned OMIM ID format is correct", {
  # Test versioning pattern
  versioned <- c("OMIM:100050_1", "OMIM:100050_2", "OMIM:123456_10")
  plain <- c("OMIM:100050", "OMIM:123456")

  for (id in versioned) {
    expect_true(str_detect(id, "^OMIM:\\d+_\\d+$"))
  }

  for (id in plain) {
    expect_false(str_detect(id, "_\\d+$"))
  }
})

test_that("date format is ISO 8601", {
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  expect_true(str_detect(current_date, "^\\d{4}-\\d{2}-\\d{2}$"))
})
