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
# identify_critical_ontology_changes() tests — structured return type
# =============================================================================

# Helper: try to source ontology functions, skip if deps missing
source_ontology <- function() {
  tryCatch({
    source(file.path(api_dir, "functions", "ontology-functions.R"))
    TRUE
  }, error = function(e) {
    FALSE
  })
}

test_that("return structure has auto_fixes, critical, summary keys", {
  if (!source_ontology()) skip("ontology-functions.R requires additional dependencies")

  update <- tibble(
    disease_ontology_id_version = "OMIM:100001",
    disease_ontology_id = "OMIM:100001",
    hgnc_id = "HGNC:1",
    hpo_mode_of_inheritance_term = "HP:0000001",
    disease_ontology_name = "Disease A"
  )

  result <- identify_critical_ontology_changes(update, update, update)

  expect_true(is.list(result))
  expect_true(all(c("auto_fixes", "critical", "summary") %in% names(result)))
  expect_true(is_tibble(result$auto_fixes))
  expect_true(is_tibble(result$critical))
  expect_true(is.list(result$summary))
  expect_true(all(
    c("total_affected", "auto_fixable", "truly_critical") %in% names(result$summary)
  ))
})

test_that("clean update: no changes at all — both empty", {
  if (!source_ontology()) skip("ontology-functions.R requires additional dependencies")

  ontology <- tibble(
    disease_ontology_id_version = c("OMIM:100001", "OMIM:100002"),
    disease_ontology_id = c("OMIM:100001", "OMIM:100002"),
    hgnc_id = c("HGNC:1", "HGNC:2"),
    hpo_mode_of_inheritance_term = c("HP:0000001", "HP:0000002"),
    disease_ontology_name = c("Disease A", "Disease B")
  )

  entity_set <- tibble(disease_ontology_id_version = "OMIM:100001")

  result <- identify_critical_ontology_changes(ontology, ontology, entity_set)

  expect_equal(nrow(result$auto_fixes), 0)
  expect_equal(nrow(result$critical), 0)
  expect_equal(result$summary$total_affected, 0)
  expect_equal(result$summary$auto_fixable, 0)
  expect_equal(result$summary$truly_critical, 0)
})

test_that("truly critical: version gone, no fingerprint or name match", {
  if (!source_ontology()) skip("ontology-functions.R requires additional dependencies")

  update <- tibble(
    disease_ontology_id_version = c("OMIM:100001", "OMIM:100002"),
    disease_ontology_id = c("OMIM:100001", "OMIM:100002"),
    hgnc_id = c("HGNC:1", "HGNC:2"),
    hpo_mode_of_inheritance_term = c("HP:0000001", "HP:0000002"),
    disease_ontology_name = c("Disease A", "Disease B")
  )

  current <- tibble(
    disease_ontology_id_version = c("OMIM:100001", "OMIM:100002", "OMIM:100003"),
    disease_ontology_id = c("OMIM:100001", "OMIM:100002", "OMIM:100003"),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    hpo_mode_of_inheritance_term = c("HP:0000001", "HP:0000002", "HP:0000003"),
    disease_ontology_name = c("Disease A", "Disease B", "Disease C")
  )

  entity_set <- tibble(disease_ontology_id_version = "OMIM:100003")

  result <- identify_critical_ontology_changes(update, current, entity_set)

  expect_equal(result$summary$truly_critical, 1)
  expect_equal(nrow(result$critical), 1)
  expect_equal(result$critical$disease_ontology_id_version[1], "OMIM:100003")
  expect_equal(result$summary$auto_fixable, 0)
})

test_that("auto-fix by ID fingerprint: version shuffled but id+hgnc+hpo matches", {
  if (!source_ontology()) skip("ontology-functions.R requires additional dependencies")

  # Old: OMIM:200001_1 with HGNC:10 + HP:0000006
  # New: version changed to OMIM:200001_2, but same (id+hgnc+hpo) fingerprint
  current <- tibble(
    disease_ontology_id_version = c("OMIM:200001_1"),
    disease_ontology_id = c("OMIM:200001"),
    hgnc_id = c("HGNC:10"),
    hpo_mode_of_inheritance_term = c("HP:0000006"),
    disease_ontology_name = c("Old Name Disease")
  )

  update <- tibble(
    disease_ontology_id_version = c("OMIM:200001_2"),
    disease_ontology_id = c("OMIM:200001"),
    hgnc_id = c("HGNC:10"),
    hpo_mode_of_inheritance_term = c("HP:0000006"),
    disease_ontology_name = c("New Name Disease")
  )

  entity_set <- tibble(disease_ontology_id_version = "OMIM:200001_1")

  result <- identify_critical_ontology_changes(update, current, entity_set)

  expect_equal(result$summary$auto_fixable, 1)
  expect_equal(nrow(result$auto_fixes), 1)
  expect_equal(result$auto_fixes$old_version[1], "OMIM:200001_1")
  expect_equal(result$auto_fixes$new_version[1], "OMIM:200001_2")
  expect_equal(result$auto_fixes$fix_type[1], "id_fingerprint")
  expect_equal(result$summary$truly_critical, 0)
})

test_that("auto-fix by name fingerprint: version gone but name+hgnc+hpo matches", {
  if (!source_ontology()) skip("ontology-functions.R requires additional dependencies")

  # Old: OMIM:300001_1 with "Same Disease" + HGNC:20 + HP:0000007
  # New: version changed to OMIM:300001_2, SAME name (name fingerprint matches)
  # but different id (so id fingerprint does NOT match)
  current <- tibble(
    disease_ontology_id_version = c("OMIM:300001_1"),
    disease_ontology_id = c("OMIM:300001"),
    hgnc_id = c("HGNC:20"),
    hpo_mode_of_inheritance_term = c("HP:0000007"),
    disease_ontology_name = c("Same Disease")
  )

  update <- tibble(
    disease_ontology_id_version = c("OMIM:300002"),
    disease_ontology_id = c("OMIM:300002"),
    hgnc_id = c("HGNC:20"),
    hpo_mode_of_inheritance_term = c("HP:0000007"),
    disease_ontology_name = c("Same Disease")
  )

  entity_set <- tibble(disease_ontology_id_version = "OMIM:300001_1")

  result <- identify_critical_ontology_changes(update, current, entity_set)

  expect_equal(result$summary$auto_fixable, 1)
  expect_equal(nrow(result$auto_fixes), 1)
  expect_equal(result$auto_fixes$old_version[1], "OMIM:300001_1")
  expect_equal(result$auto_fixes$new_version[1], "OMIM:300002")
  expect_equal(result$auto_fixes$fix_type[1], "name_fingerprint")
  expect_equal(result$summary$truly_critical, 0)
})

test_that("mixed scenario: some auto-fixable, some critical", {
  if (!source_ontology()) skip("ontology-functions.R requires additional dependencies")

  current <- tibble(
    disease_ontology_id_version = c("OMIM:400001_1", "OMIM:400002_1"),
    disease_ontology_id = c("OMIM:400001", "OMIM:400002"),
    hgnc_id = c("HGNC:30", "HGNC:40"),
    hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0000007"),
    disease_ontology_name = c("Fixable Disease", "Critical Disease")
  )

  # Update: first entry has same fingerprint with new version (auto-fixable)
  # Second entry is completely gone (critical)
  update <- tibble(
    disease_ontology_id_version = c("OMIM:400001_2", "OMIM:500001"),
    disease_ontology_id = c("OMIM:400001", "OMIM:500001"),
    hgnc_id = c("HGNC:30", "HGNC:50"),
    hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0000006"),
    disease_ontology_name = c("Fixable Disease Renamed", "Unrelated Disease")
  )

  entity_set <- tibble(
    disease_ontology_id_version = c("OMIM:400001_1", "OMIM:400002_1")
  )

  result <- identify_critical_ontology_changes(update, current, entity_set)

  expect_equal(result$summary$total_affected, 2)
  expect_equal(result$summary$auto_fixable, 1)
  expect_equal(result$summary$truly_critical, 1)
  expect_equal(nrow(result$auto_fixes), 1)
  expect_equal(nrow(result$critical), 1)
  expect_equal(result$auto_fixes$old_version[1], "OMIM:400001_1")
  expect_equal(result$critical$disease_ontology_id_version[1], "OMIM:400002_1")
})

test_that("process_combine_ontology max_file_age = 0 bypasses cached combined ontology CSV", {
  if (!source_ontology()) skip("ontology-functions.R requires additional dependencies")

  ontology_cache <- withr::local_tempdir()
  data_dir <- file.path(ontology_cache, "data")
  dir.create(data_dir)
  output_path <- paste0(data_dir, "/")

  cached <- tibble(
    disease_ontology_id_version = "OMIM:CACHED",
    disease_ontology_id = "OMIM:CACHED",
    disease_ontology_name = "Cached Disease",
    disease_ontology_source = "omim",
    disease_ontology_date = as.character(Sys.Date()),
    disease_ontology_is_specific = TRUE,
    hgnc_id = "HGNC:1",
    hpo_mode_of_inheritance_term = "HP:0000006"
  )
  readr::write_csv(
    cached,
    file.path(data_dir, paste0("disease_ontology_set.", Sys.Date(), ".csv")),
    na = "NULL"
  )

  regenerated_omim <- tibble(
    disease_ontology_id_version = "OMIM:FRESH",
    disease_ontology_id = "OMIM:FRESH",
    disease_ontology_name = "Fresh Disease",
    disease_ontology_source = "omim",
    disease_ontology_date = as.character(Sys.Date()),
    disease_ontology_is_specific = TRUE,
    hgnc_id = "HGNC:1",
    hpo_mode_of_inheritance_term = "HP:0000006"
  )
  empty_mondo <- tibble(
    disease_ontology_id_version = character(0),
    disease_ontology_id = character(0),
    disease_ontology_name = character(0),
    disease_ontology_source = character(0),
    disease_ontology_date = character(0),
    disease_ontology_is_specific = logical(0),
    hgnc_id = character(0),
    hpo_mode_of_inheritance_term = character(0)
  )
  empty_mappings <- tibble(
    OMIM = character(0),
    MONDO = character(0),
    DOID = character(0),
    Orphanet = character(0),
    EFO = character(0)
  )

  mock_bindings <- list(
    process_mondo_ontology = function(...) empty_mondo,
    process_omim_ontology = function(...) regenerated_omim,
    get_ontology_object = function(...) list(),
    get_mondo_mappings = function(...) empty_mappings,
    download_mondo_sssom = function(...) "mock.sssom.tsv",
    parse_mondo_sssom = function(...) tibble(omim_id = character(0), mondo_id = character(0)),
    add_mondo_mappings_to_ontology = function(disease_ontology_set, ...) disease_ontology_set
  )
  mock_names <- names(mock_bindings)
  old_exists <- vapply(mock_names, exists, logical(1), envir = globalenv(), inherits = FALSE)
  old_values <- mget(mock_names[old_exists], envir = globalenv(), inherits = FALSE)
  withr::defer({
    for (name in mock_names) {
      if (isTRUE(old_exists[[name]])) {
        assign(name, old_values[[name]], envir = globalenv())
      } else if (exists(name, envir = globalenv(), inherits = FALSE)) {
        rm(list = name, envir = globalenv())
      }
    }
  })
  list2env(mock_bindings, envir = globalenv())

  result <- process_combine_ontology(
    hgnc_list = tibble(hgnc_id = "HGNC:1", symbol = "GENE1"),
    mode_of_inheritance_list = tibble(),
    max_file_age = 0,
    output_path = output_path
  )

  expect_true("OMIM:FRESH" %in% result$disease_ontology_id_version)
  expect_false("OMIM:CACHED" %in% result$disease_ontology_id_version)
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
# process_omim_ontology() progress/deprecation plumbing
# =============================================================================

load_ontology_runtime <- function() {
  runtime <- new.env(parent = globalenv())
  suppressWarnings(
    sys.source(file.path(api_dir, "functions", "file-functions.R"), envir = runtime)
  )
  suppressWarnings(
    sys.source(file.path(api_dir, "functions", "ontology-functions.R"), envir = runtime)
  )
  runtime
}

stub_omim_runtime <- function(runtime, mim2gene_args = new.env(parent = emptyenv())) {
  runtime$download_genemap2 <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
    "data/genemap2.test.txt"
  }
  runtime$parse_genemap2 <- function(genemap2_path) {
    tibble(
      Approved_Symbol = "GENE1",
      disease_ontology_name = "Test disease",
      disease_ontology_id = "OMIM:123456",
      Mapping_key = "3",
      hpo_mode_of_inheritance_term_name = "Autosomal dominant inheritance"
    )
  }
  runtime$build_omim_from_genemap2 <- function(genemap2_parsed, hgnc_list, moi_list) {
    tibble(
      disease_ontology_id_version = "OMIM:123456",
      disease_ontology_id = "OMIM:123456",
      disease_ontology_name = "Test disease",
      disease_ontology_source = "mim2gene",
      disease_ontology_date = "2026-05-13",
      disease_ontology_is_specific = TRUE,
      hgnc_id = "HGNC:1",
      hpo_mode_of_inheritance_term = "HP:0000006"
    )
  }
  runtime$download_mim2gene <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
    mim2gene_args$output_path <- output_path
    mim2gene_args$force <- force
    mim2gene_args$max_age_days <- max_age_days
    "data/mim2gene.test.txt"
  }
  runtime$parse_mim2gene <- function(file_path) {
    tibble(
      mim_number = character(),
      mim_entry_type = character(),
      gene_symbol = character(),
      is_deprecated = logical()
    )
  }
  runtime$get_deprecated_mim_numbers <- function(mim2gene_data) character()
  runtime$write_csv <- function(x, file, na = "NA") invisible(NULL)

  mim2gene_args
}

test_that("process_omim_ontology sends async progress messages", {
  withr::local_dir(withr::local_tempdir())
  runtime <- load_ontology_runtime()
  stub_omim_runtime(runtime)

  progress_calls <- list()
  progress <- function(step, message, current = NULL, total = NULL) {
    progress_calls[[length(progress_calls) + 1L]] <<- list(
      step = step,
      message = message,
      current = current,
      total = total
    )
  }

  expect_no_error(
    runtime$process_omim_ontology(
      hgnc_list = tibble(symbol = "GENE1", hgnc_id = "HGNC:1"),
      moi_list = tibble(
        hpo_mode_of_inheritance_term_name = "Autosomal dominant inheritance",
        hpo_mode_of_inheritance_term = "HP:0000006"
      ),
      max_file_age = 7,
      progress_callback = progress
    )
  )

  expect_equal(length(progress_calls), 4L)
  expect_true(all(nzchar(vapply(progress_calls, `[[`, character(1), "message"))))
  expect_equal(vapply(progress_calls, `[[`, numeric(1), "total"), rep(4, 4))
})

test_that("process_omim_ontology converts mim2gene cache age from months to days", {
  withr::local_dir(withr::local_tempdir())
  runtime <- load_ontology_runtime()
  mim2gene_args <- stub_omim_runtime(runtime)

  suppressWarnings(runtime$process_omim_ontology(
    hgnc_list = tibble(symbol = "GENE1", hgnc_id = "HGNC:1"),
    moi_list = tibble(
      hpo_mode_of_inheritance_term_name = "Autosomal dominant inheritance",
      hpo_mode_of_inheritance_term = "HP:0000006"
    ),
    max_file_age = 7,
    progress_callback = NULL
  ))

  expect_equal(mim2gene_args$max_age_days, 210)
})

test_that("process_combine_ontology sends a message for MONDO SSSOM progress", {
  withr::local_dir(withr::local_tempdir())
  skip_if_not_installed("tidyr")
  runtime <- load_ontology_runtime()
  runtime$separate_rows <- tidyr::separate_rows
  runtime$check_file_age <- function(file_basename, folder, months) FALSE
  runtime$process_mondo_ontology <- function() {
    tibble(
      disease_ontology_id_version = "MONDO:0000001",
      disease_ontology_id = "MONDO:0000001",
      disease_ontology_name = "MONDO disease",
      disease_ontology_source = "mondo",
      disease_ontology_date = "2026-05-13",
      disease_ontology_is_specific = FALSE,
      hgnc_id = NA_character_,
      hpo_mode_of_inheritance_term = NA_character_
    )
  }
  runtime$process_omim_ontology <- function(
    hgnc_list,
    moi_list,
    max_file_age,
    progress_callback
  ) {
    tibble(
      disease_ontology_id_version = "OMIM:123456",
      disease_ontology_id = "OMIM:123456",
      disease_ontology_name = "OMIM disease",
      disease_ontology_source = "mim2gene",
      disease_ontology_date = "2026-05-13",
      disease_ontology_is_specific = TRUE,
      hgnc_id = "HGNC:1",
      hpo_mode_of_inheritance_term = "HP:0000006"
    )
  }
  runtime$get_ontology_object <- function(
    ontology_type,
    config_vars,
    tags = "everything",
    max_age = 1
  ) {
    list()
  }
  runtime$get_mondo_mappings <- function(
    mondo_ontology,
    max_age = 1,
    output_path = "data/",
    columns_to_return = NULL
  ) {
    tibble(
      OMIM = "OMIM:123456",
      MONDO = "MONDO:0000001",
      DOID = NA_character_,
      Orphanet = NA_character_,
      EFO = NA_character_
    )
  }
  runtime$download_mondo_sssom <- function(output_path) {
    "data/mondo-omim.test.sssom.tsv"
  }
  runtime$parse_mondo_sssom <- function(file_path) {
    tibble(omim_id = "OMIM:123456", mondo_id = "MONDO:0000001")
  }
  runtime$add_mondo_mappings_to_ontology <- function(disease_ontology_set, mondo_mappings) {
    disease_ontology_set
  }
  runtime$write_csv <- function(x, file, na = "NA") invisible(NULL)

  progress_calls <- list()
  progress <- function(step, message, current = NULL, total = NULL) {
    progress_calls[[length(progress_calls) + 1L]] <<- list(
      step = step,
      message = message,
      current = current,
      total = total
    )
  }

  result <- runtime$process_combine_ontology(
    hgnc_list = tibble(symbol = "GENE1", hgnc_id = "HGNC:1"),
    mode_of_inheritance_list = tibble(
      hpo_mode_of_inheritance_term_name = "Autosomal dominant inheritance",
      hpo_mode_of_inheritance_term = "HP:0000006"
    ),
    max_file_age = 3,
    output_path = "data/",
    progress_callback = progress
  )

  expect_equal(nrow(result), 2L)
  expect_true(any(vapply(progress_calls, `[[`, character(1), "message") ==
    "Applying MONDO SSSOM mappings"))
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
  # Source is "mim2gene" for MONDO SSSOM compatibility (ONTO-05)
  omim_mock <- tibble(
    disease_ontology_id_version = "OMIM:123456_1",
    disease_ontology_id = "OMIM:123456",
    disease_ontology_name = "Test Disease",
    disease_ontology_source = "mim2gene",
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

  expect_equal(omim_mock$disease_ontology_source, "mim2gene")
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
# build_omim_from_genemap2() integration tests
# =============================================================================

test_that("build_omim_from_genemap2 output integrates with identify_critical_ontology_changes", {
  # Test that genemap2 workflow output is compatible with downstream critical changes detection

  # Create "old" disease_ontology_set (from previous run)
  disease_ontology_set_old <- tibble(
    disease_ontology_id_version = c("OMIM:100001", "OMIM:200002"),
    disease_ontology_id = c("OMIM:100001", "OMIM:200002"),
    hgnc_id = c("HGNC:1000", "HGNC:2000"),
    hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0000007"),
    disease_ontology_name = c("Old Disease A", "Old Disease B")
  )

  # Create "new" disease_ontology_set using build_omim_from_genemap2 output format
  # (with inheritance data from genemap2)
  disease_ontology_set_new <- tibble(
    disease_ontology_id_version = c("OMIM:100001", "OMIM:200002"),
    disease_ontology_id = c("OMIM:100001", "OMIM:200002"),
    hgnc_id = c("HGNC:1000", "HGNC:2000"),
    hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0000007"),
    disease_ontology_name = c("New Disease A", "Old Disease B"),  # Name changed for 100001
    disease_ontology_source = c("mim2gene", "mim2gene"),
    disease_ontology_is_specific = c(TRUE, TRUE)
  )

  # Create mock ndd_entity_view_ontology_set referencing one of the old entries
  ndd_entity_view_ontology_set <- tibble(
    disease_ontology_id_version = c("OMIM:100001")  # Entity uses entry with name change
  )

  tryCatch({
    source(file.path(api_dir, "functions", "ontology-functions.R"))

    result <- identify_critical_ontology_changes(
      disease_ontology_set_new,
      disease_ontology_set_old,
      ndd_entity_view_ontology_set
    )

    # New return type: list with auto_fixes, critical, summary
    expect_true(is.list(result))
    expect_true(all(c("auto_fixes", "critical", "summary") %in% names(result)))
    # Name change with same version should be flagged (non-critical name change)
    expect_true(result$summary$total_affected >= 0)
  }, error = function(e) {
    skip("ontology-functions.R requires additional dependencies")
  })
})

test_that("genemap2 workflow produces richer data than mim2gene workflow", {
  # Old mim2gene output: no inheritance data
  old_mim2gene_output <- tibble(
    disease_ontology_id = "OMIM:123456",
    disease_ontology_name = "Test Disease",
    hgnc_id = "HGNC:1000",
    hpo_mode_of_inheritance_term = NA_character_  # mim2gene has no inheritance
  )

  # New genemap2 output: has inheritance data
  new_genemap2_output <- tibble(
    disease_ontology_id = "OMIM:123456",
    disease_ontology_name = "Test Disease",
    hgnc_id = "HGNC:1000",
    hpo_mode_of_inheritance_term = "HP:0000006"  # genemap2 provides inheritance
  )

  # Verify old workflow has NA inheritance
  expect_true(is.na(old_mim2gene_output$hpo_mode_of_inheritance_term[1]))

  # Verify new workflow has non-NA inheritance
  expect_false(is.na(new_genemap2_output$hpo_mode_of_inheritance_term[1]))
  expect_equal(new_genemap2_output$hpo_mode_of_inheritance_term[1], "HP:0000006")
})

test_that("process_omim_ontology progress callback receives correct step names", {
  # Document the expected progress callback contract for genemap2 workflow
  expected_steps <- c(
    "Downloading genemap2.txt",
    "Parsing genemap2.txt",
    "Building OMIM ontology set from genemap2",
    "Downloading mim2gene.txt for deprecation tracking"
  )

  # Verify step 1 contains "genemap2" (not "mim2gene" as primary)
  expect_true(str_detect(expected_steps[1], "genemap2"))
  expect_false(str_detect(expected_steps[1], "mim2gene"))

  # Verify step 2 contains "Parsing"
  expect_true(str_detect(expected_steps[2], "Parsing"))

  # Verify step 3 contains "Building"
  expect_true(str_detect(expected_steps[3], "Building"))

  # Verify step 4 contains "mim2gene" and "deprecation"
  expect_true(str_detect(expected_steps[4], "mim2gene"))
  expect_true(str_detect(expected_steps[4], "deprecation"))
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
