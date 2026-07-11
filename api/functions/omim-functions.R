# functions/omim-functions.R
# OMIM data processing functions using genemap2.txt and mim2gene.txt
#
# Provides:
# - Validation of OMIM data before database insertion
# - Deprecation tracking (moved/removed mim2gene entries) and the entity
#   impact query used by the ontology-safeguard workflow
# - disease_ontology_set dataset build from parsed genemap2 data
#
# Credential handling (OMIM_DOWNLOAD_KEY) and file acquisition
# (mim2gene/genemap2/HPO downloads with 1-day TTL caching) live in the
# sibling functions/omim-download-functions.R; parse_genemap2()/
# parse_mim2gene() live in functions/omim-parser-functions.R. Both were
# extracted from this file (WP #346, Wave 4 Task 10) to keep it under the
# 600-line soft ceiling; behavior is unchanged.

require(tidyverse)

# Guard-source the extracted download + parser modules. load_modules.R (API +
# durable worker) and setup_workers.R (mirai pool) both source only this
# file, so this keeps the download -> parser -> (rest of this file) load
# order without either bootstrap list needing a new entry, and mirrors the
# comparisons-functions.R guard-source pattern so direct-source unit tests
# (which `source()` only this file) still get every OMIM function. Checked
# with exists(..., mode = "function") — unlike base::get(), exists() is not
# masked by the config package in the fully-loaded API/worker environment.
# Resolve this file's own directory from the active source() frame so the
# siblings load regardless of cwd (testthat runs from tests/testthat/, where the
# bare cwd-relative candidates below do not resolve).
.omim_self_dir <- NULL
for (.omim_i in seq_len(sys.nframe())) {
  .omim_of <- sys.frame(.omim_i)$ofile
  if (!is.null(.omim_of)) {
    .omim_self_dir <- dirname(.omim_of)
    break
  }
}

if (!exists("download_genemap2", mode = "function")) {
  for (.omim_download_path in c(
    if (!is.null(.omim_self_dir)) file.path(.omim_self_dir, "omim-download-functions.R"),
    "functions/omim-download-functions.R",
    "/app/functions/omim-download-functions.R")) {
    if (file.exists(.omim_download_path)) {
      source(.omim_download_path, local = FALSE)
      break
    }
  }
}

if (!exists("parse_genemap2", mode = "function")) {
  for (.omim_parser_path in c(
    if (!is.null(.omim_self_dir)) file.path(.omim_self_dir, "omim-parser-functions.R"),
    "functions/omim-parser-functions.R",
    "/app/functions/omim-parser-functions.R")) {
    if (file.exists(.omim_parser_path)) {
      source(.omim_parser_path, local = FALSE)
      break
    }
  }
}


#' Validate OMIM data for database insertion
#'
#' Checks that all required fields are present and validates data integrity
#' before inserting into the database.
#'
#' @param omim_data Tibble with OMIM data prepared for database insertion
#' @return List with: valid (logical), errors (list of error messages),
#'   message (summary string)
#'
#' @details
#' Per CONTEXT.md, validation is strict - aborts if ANY entry fails validation.
#'
#' Required fields checked:
#' - disease_ontology_id: Must not be NA
#' - hgnc_id: Must not be NA (for entries with gene associations)
#' - disease_ontology_name: Must not be NA
#'
#' Also checks for duplicate disease_ontology_id_version values.
#'
#' @examples
#' \dontrun{
#'   validation <- validate_omim_data(omim_ontology_set)
#'   if (!validation$valid) {
#'     stop(validation$message)
#'   }
#' }
#'
#' @export
validate_omim_data <- function(omim_data) {
  errors <- list()

  # Check for missing disease_ontology_id
  missing_id <- omim_data %>%
    filter(is.na(disease_ontology_id)) %>%
    nrow()

  if (missing_id > 0) {
    errors$missing_disease_ontology_id <- sprintf(
      "%d entries missing disease_ontology_id",
      missing_id
    )
  }

  # Check for missing disease_ontology_name
  missing_name_data <- omim_data %>%
    filter(is.na(disease_ontology_name))
  missing_name <- nrow(missing_name_data)

  if (missing_name > 0) {
    mim_numbers <- missing_name_data$disease_ontology_id %>%
      head(10) %>%
      paste(collapse = ", ")
    errors$missing_disease_ontology_name <- sprintf(
      "%d entries missing disease_ontology_name (e.g., %s%s)",
      missing_name,
      mim_numbers,
      if (missing_name > 10) "..." else ""
    )
  }

  # Check for missing hgnc_id (only for entries that should have one)
  # Note: Some OMIM entries don't have gene associations - this is expected
  # Only flag if hgnc_id is explicitly required by the caller

  # Check for duplicate disease_ontology_id_version
  if ("disease_ontology_id_version" %in% names(omim_data)) {
    duplicates <- omim_data %>%
      count(disease_ontology_id_version) %>%
      filter(n > 1)

    if (nrow(duplicates) > 0) {
      dup_ids <- duplicates$disease_ontology_id_version %>%
        head(10) %>%
        paste(collapse = ", ")
      errors$duplicate_id_version <- sprintf(
        "%d duplicate disease_ontology_id_version values (e.g., %s%s)",
        nrow(duplicates),
        dup_ids,
        if (nrow(duplicates) > 10) "..." else ""
      )
    }
  }

  # Build validation result
  valid <- length(errors) == 0
  message <- if (valid) {
    sprintf("Validation passed: %d entries", nrow(omim_data))
  } else {
    sprintf(
      "Validation failed: %d errors\n- %s",
      length(errors),
      paste(unlist(errors), collapse = "\n- ")
    )
  }

  return(list(
    valid = valid,
    errors = errors,
    message = message
  ))
}


#' Get deprecated MIM numbers
#'
#' Extracts MIM numbers that are marked as "moved/removed" in mim2gene.txt.
#' These represent deprecated or obsolete OMIM entries.
#'
#' @param mim2gene_data Tibble from parse_mim2gene() with include_moved_removed=TRUE
#' @return Character vector of deprecated MIM numbers
#'
#' @details
#' As of 2026-01-24, there are approximately 1,383 moved/removed entries.
#' These should be checked against existing entities in the database and
#' flagged for curator re-review.
#'
#' @examples
#' \dontrun{
#'   mim_data <- parse_mim2gene("data/mim2gene.txt", include_moved_removed = TRUE)
#'   deprecated <- get_deprecated_mim_numbers(mim_data)
#' }
#'
#' @export
get_deprecated_mim_numbers <- function(mim2gene_data) {
  deprecated <- mim2gene_data %>%
    filter(mim_entry_type == "moved/removed") %>%
    pull(mim_number)

  return(deprecated)
}


#' Check entities for deprecation
#'
#' Queries the disease_ontology_set table to find any entries that match
#' deprecated MIM numbers. These entities should be flagged for curator review.
#'
#' @param pool Database connection pool
#' @param deprecated_mim_numbers Character vector of deprecated MIM numbers
#' @return Tibble with affected entities: entity_id, disease_ontology_id, current status
#'
#' @details
#' Uses dplyr to query the database. Returns entities that are using
#' OMIM IDs that have been marked as moved/removed in OMIM.
#'
#' Curators should review these entities and consider:
#' - Finding a MONDO equivalent
#' - Updating to a new OMIM ID if the entry was moved
#' - Flagging as obsolete if the entry was removed
#'
#' @examples
#' \dontrun{
#'   deprecated_mims <- get_deprecated_mim_numbers(mim2gene_data)
#'   affected <- check_entities_for_deprecation(pool, deprecated_mims)
#' }
#'
#' @export
check_entities_for_deprecation <- function(pool, deprecated_mim_numbers) {
  # Build OMIM IDs with prefix
  deprecated_omim_ids <- paste0("OMIM:", deprecated_mim_numbers)

  # Query for affected entities
  # Join disease_ontology_set with ndd_entity to find affected entities
  affected_entities <- tbl(pool, "disease_ontology_set") %>%
    filter(disease_ontology_id %in% !!deprecated_omim_ids) %>%
    select(
      disease_ontology_id_version,
      disease_ontology_id,
      disease_ontology_name
    ) %>%
    collect()

  # If there are affected entries, join with entity view to get entity IDs
  if (nrow(affected_entities) > 0) {
    entity_usage <- tbl(pool, "ndd_entity_view") %>%
      filter(disease_ontology_id_version %in% !!affected_entities$disease_ontology_id_version) %>%
      dplyr::select(
        entity_id,
        disease_ontology_id_version,
        symbol,
        hgnc_id,
        category,
        ndd_phenotype
      ) %>%
      collect()

    # Combine information
    result <- dplyr::left_join(
      entity_usage,
      affected_entities,
      by = "disease_ontology_id_version"
    )

    return(result)
  }

  # Return empty tibble if no affected entities
  return(tibble(
    entity_id = integer(),
    disease_ontology_id_version = character(),
    symbol = character(),
    hgnc_id = character(),
    category = character(),
    ndd_phenotype = integer(),
    disease_ontology_id = character(),
    disease_ontology_name = character()
  ))
}


#' Build OMIM ontology set from genemap2 data
#'
#' Creates disease_ontology_set entries from parsed genemap2 data with inheritance
#' mode normalization, HGNC ID lookup, and duplicate MIM versioning. This function
#' replaces the mim2gene + JAX API workflow, using genemap2's richer phenotype data
#' which includes inheritance mode information.
#'
#' @param genemap2_parsed Tibble from parse_genemap2() with columns: Approved_Symbol,
#'   disease_ontology_name, disease_ontology_id (or MIM_Number),
#'   hpo_mode_of_inheritance_term_name, Mapping_key
#' @param hgnc_list Tibble with columns: symbol, hgnc_id
#' @param moi_list Tibble with columns: hpo_mode_of_inheritance_term_name,
#'   hpo_mode_of_inheritance_term
#' @return Tibble matching disease_ontology_set schema
#'
#' @details
#' Creates the following columns:
#' - disease_ontology_id_version: OMIM:{mim_number} or OMIM:{mim_number}_{version}
#' - disease_ontology_id: OMIM:{mim_number}
#' - disease_ontology_name: From genemap2 Phenotypes column
#' - disease_ontology_source: "mim2gene" (for MONDO SSSOM compatibility)
#' - disease_ontology_date: Current date
#' - disease_ontology_is_specific: TRUE (OMIM entries are specific)
#' - hgnc_id: From HGNC lookup
#' - hpo_mode_of_inheritance_term: From MOI mapping
#'
#' Inheritance mode normalization:
#' Maps genemap2's 15 short forms (e.g., "Autosomal dominant") to full HPO term names
#' (e.g., "Autosomal dominant inheritance"). Unknown modes become NA with a warning.
#'
#' Versioning logic (ONTO-04):
#' - If MIM number appears once: OMIM:123456
#' - If MIM number appears multiple times: OMIM:123456_1, OMIM:123456_2, etc.
#' - Versioning occurs AFTER inheritance expansion and deduplication
#'
#' MONDO compatibility (ONTO-05):
#' - disease_ontology_source MUST be "mim2gene" (not "genemap2" or "morbidmap")
#' - This ensures add_mondo_mappings_to_ontology() can find and map entries
#'
#' @examples
#' \dontrun{
#'   genemap2_data <- parse_genemap2("data/genemap2.txt")
#'   omim_set <- build_omim_from_genemap2(
#'     genemap2_data,
#'     hgnc_list,
#'     moi_list
#'   )
#' }
#'
#' @export
build_omim_from_genemap2 <- function(genemap2_parsed, hgnc_list, moi_list) { # nolint: line_length_linter
  current_date <- format(Sys.Date(), "%Y-%m-%d")

  # Ensure disease_ontology_id exists (handle both MIM_Number and disease_ontology_id)
  if ("MIM_Number" %in% names(genemap2_parsed) &&
      !("disease_ontology_id" %in% names(genemap2_parsed))) {
    genemap2_parsed <- genemap2_parsed %>%
      mutate(disease_ontology_id = paste0("OMIM:", MIM_Number))
  }

  # Join with HGNC list for hgnc_id
  combined <- genemap2_parsed %>%
    left_join(
      hgnc_list %>% dplyr::select(symbol, hgnc_id),
      by = c("Approved_Symbol" = "symbol")
    )

  # Expand and normalize inheritance modes
  # Store original values before normalization for warning detection
  combined <- combined %>%
    separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%
    mutate(
      hpo_mode_of_inheritance_term_name = str_replace_all(
        hpo_mode_of_inheritance_term_name, "\\?", ""
      )
    ) %>%
    mutate(
      original_moi = hpo_mode_of_inheritance_term_name,
      hpo_mode_of_inheritance_term_name = case_when(
        hpo_mode_of_inheritance_term_name == "Autosomal dominant" ~
          "Autosomal dominant inheritance",
        hpo_mode_of_inheritance_term_name == "Autosomal recessive" ~
          "Autosomal recessive inheritance",
        hpo_mode_of_inheritance_term_name == "Digenic dominant" ~
          "Digenic inheritance",
        hpo_mode_of_inheritance_term_name == "Digenic recessive" ~
          "Digenic inheritance",
        hpo_mode_of_inheritance_term_name == "Isolated cases" ~
          "Sporadic",
        hpo_mode_of_inheritance_term_name == "Mitochondrial" ~
          "Mitochondrial inheritance",
        hpo_mode_of_inheritance_term_name == "Multifactorial" ~
          "Multifactorial inheritance",
        hpo_mode_of_inheritance_term_name == "Pseudoautosomal dominant" ~
          "X-linked dominant inheritance",
        hpo_mode_of_inheritance_term_name == "Pseudoautosomal recessive" ~
          "X-linked recessive inheritance",
        hpo_mode_of_inheritance_term_name == "Somatic mosaicism" ~
          "Somatic mosaicism",
        hpo_mode_of_inheritance_term_name == "Somatic mutation" ~
          "Somatic mutation",
        hpo_mode_of_inheritance_term_name == "X-linked" ~
          "X-linked inheritance",
        hpo_mode_of_inheritance_term_name == "X-linked dominant" ~
          "X-linked dominant inheritance",
        hpo_mode_of_inheritance_term_name == "X-linked recessive" ~
          "X-linked recessive inheritance",
        hpo_mode_of_inheritance_term_name == "Y-linked" ~
          "Y-linked inheritance",
        TRUE ~ hpo_mode_of_inheritance_term_name
      )
    )

  # Check for unmapped inheritance terms and warn
  unmapped <- combined %>%
    filter(!is.na(original_moi) & is.na(hpo_mode_of_inheritance_term_name)) %>%
    pull(original_moi) %>%
    unique()

  if (length(unmapped) > 0) {
    warning(sprintf(
      "Unmapped inheritance terms found: %s",
      paste(unmapped, collapse = ", ")
    ))
  }

  # Remove temporary column
  combined <- combined %>%
    dplyr::select(-original_moi)

  # Join with moi_list to get HPO term IDs
  combined <- combined %>%
    left_join(moi_list, by = c("hpo_mode_of_inheritance_term_name"))

  # Select, deduplicate, and apply versioning
  result <- combined %>%
    dplyr::select(
      disease_ontology_id, hgnc_id, disease_ontology_name,
      hpo_mode_of_inheritance_term
    ) %>%
    unique() %>%
    arrange(disease_ontology_id, hgnc_id, disease_ontology_name,
            hpo_mode_of_inheritance_term) %>%
    group_by(disease_ontology_id) %>%
    mutate(n = 1, count = n(), version = cumsum(n)) %>%
    ungroup() %>%
    mutate(disease_ontology_id_version = case_when(
      count == 1 ~ disease_ontology_id,
      count >= 1 ~ paste0(disease_ontology_id, "_", version)
    )) %>%
    dplyr::select(-n, -count, -version)

  # Add metadata columns and select final schema
  result <- result %>%
    mutate(
      disease_ontology_source = "mim2gene",  # For MONDO SSSOM compatibility
      disease_ontology_date = current_date,
      disease_ontology_is_specific = TRUE
    ) %>%
    dplyr::select(
      disease_ontology_id_version, disease_ontology_id, disease_ontology_name,
      disease_ontology_source, disease_ontology_date, disease_ontology_is_specific,
      hgnc_id, hpo_mode_of_inheritance_term
    )

  return(result)
}
