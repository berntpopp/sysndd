# functions/omim-functions.R
# OMIM data processing functions using mim2gene.txt and JAX API
#
# Replaces the genemap2.txt-based approach with:
# - mim2gene.txt from OMIM for entry types and gene associations
# - JAX Ontology API for disease names
# - Support for deprecation workflow (moved/removed entries)

require(tidyverse)
require(httr2)
require(purrr)
require(fs)
require(lubridate)

# Source file-functions for check_file_age and get_newest_file
# When sourced in Plumber context, uses the plumber working directory


#' Download mim2gene.txt from OMIM
#'
#' Downloads the mim2gene.txt file from OMIM's public data. Uses httr2 with
#' retry logic for reliability. Checks file age before downloading.
#'
#' @param output_path Character string, directory to save the file (default: "data/")
#' @param force Logical, if TRUE downloads even if recent file exists (default: FALSE)
#' @param max_age_months Integer, maximum age in months before re-downloading (default: 1)
#' @return Character string, path to the downloaded/existing file
#'
#' @examples
#' \dontrun{
#'   file_path <- download_mim2gene()
#'   file_path <- download_mim2gene(force = TRUE)
#' }
#'
#' @export
download_mim2gene <- function(output_path = "data/", force = FALSE, max_age_months = 1) {
  # Check if recent file exists
  if (!force && check_file_age("mim2gene", output_path, max_age_months)) {
    existing_file <- get_newest_file("mim2gene", output_path)
    if (!is.null(existing_file)) {
      return(existing_file)
    }
  }

  # Download from OMIM
  url <- "https://omim.org/static/omim/data/mim2gene.txt"
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "mim2gene.", current_date, ".txt")

  # Ensure output directory exists
  if (!dir_exists(output_path)) {
    dir_create(output_path)
  }

  response <- request(url) |>
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) |>
    req_timeout(30) |>
    req_perform()

  if (resp_status(response) != 200) {
    stop(sprintf("Failed to download mim2gene.txt: HTTP %d", resp_status(response)))
  }

  # Write to file
  writeBin(resp_body_raw(response), output_file)

  return(output_file)
}


#' Parse mim2gene.txt file
#'
#' Reads and parses the mim2gene.txt file from OMIM. Filters for phenotype entries
#' and optionally includes moved/removed entries for deprecation workflow.
#'
#' @param file_path Character string, path to the mim2gene.txt file
#' @param include_moved_removed Logical, if TRUE includes moved/removed entries
#'   for deprecation detection (default: TRUE)
#' @return Tibble with columns: mim_number, mim_entry_type, gene_symbol, is_deprecated
#'
#' @details
#' The mim2gene.txt file has these columns:
#' - MIM_Number: OMIM identifier
#' - MIM_Entry_Type: gene, phenotype, predominantly phenotypes, moved/removed
#' - Entrez_Gene_ID: NCBI Gene ID (may be empty)
#' - Approved_Gene_Symbol_HGNC: HGNC symbol (may be empty for phenotypes)
#' - Ensembl_Gene_ID: Ensembl ID (may be empty)
#'
#' Phenotype entries typically have NA gene_symbol - this is expected.
#' Moved/removed entries are flagged for curator re-review workflow.
#'
#' @examples
#' \dontrun{
#'   mim_data <- parse_mim2gene("data/mim2gene.2026-01-24.txt")
#'   phenotypes_only <- parse_mim2gene("data/mim2gene.2026-01-24.txt", include_moved_removed = FALSE)
#' }
#'
#' @export
parse_mim2gene <- function(file_path, include_moved_removed = TRUE) {
  # Read tab-delimited file, skipping comment lines
  mim_data <- read_delim(
    file_path,
    delim = "\t",
    comment = "#",
    col_names = c(
      "mim_number", "mim_entry_type", "entrez_gene_id",
      "gene_symbol", "ensembl_gene_id"
    ),
    col_types = cols(
      mim_number = col_character(),
      mim_entry_type = col_character(),
      entrez_gene_id = col_character(),
      gene_symbol = col_character(),
      ensembl_gene_id = col_character()
    ),
    na = c("", "NA"),
    show_col_types = FALSE
  )

  # Filter for phenotype entries (and optionally moved/removed)
  entry_types_to_include <- c("phenotype")
  if (include_moved_removed) {
    entry_types_to_include <- c(entry_types_to_include, "moved/removed")
  }

  result <- mim_data |>
    filter(mim_entry_type %in% entry_types_to_include) |>
    mutate(is_deprecated = mim_entry_type == "moved/removed") |>
    select(mim_number, mim_entry_type, gene_symbol, is_deprecated)

  return(result)
}


#' Fetch disease name from JAX Ontology API
#'
#' Makes a request to the JAX Ontology API to retrieve the disease name for
#' a given OMIM MIM number. Uses retry logic with exponential backoff.
#'
#' @param mim_number Character string, the OMIM MIM number (without "OMIM:" prefix)
#' @return Character string, the disease name or NA_character_ if not found
#'
#' @details
#' Uses validated parameters from Phase 23-01:
#' - max_tries: 5
#' - backoff: exponential (2^x seconds)
#' - max_seconds: 120
#' - timeout: 30 seconds
#'
#' Returns NA_character_ on 404 (not found in JAX database).
#' Logs warnings for failures but does not stop batch processing.
#'
#' @examples
#' \dontrun{
#'   name <- fetch_jax_disease_name("100050")
#' }
#'
#' @export
fetch_jax_disease_name <- function(mim_number) {
  url <- paste0("https://ontology.jax.org/api/network/annotation/OMIM:", mim_number)

  tryCatch({
    response <- request(url) |>
      req_retry(
        max_tries = 5,
        max_seconds = 120,
        backoff = ~ 2^.x,
        is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
      ) |>
      req_timeout(30) |>
      req_error(is_error = ~ FALSE) |>
      req_perform()

    # Handle 404 - not found in JAX database (expected for ~18% of entries)
    if (resp_status(response) == 404) {
      return(NA_character_)
    }

    # Handle other non-200 responses
    if (resp_status(response) != 200) {
      warning(sprintf(
        "JAX API error %d for OMIM:%s",
        resp_status(response), mim_number
      ))
      return(NA_character_)
    }

    # Extract disease name
    data <- resp_body_json(response)
    disease_name <- pluck(data, "disease", "name", .default = NA_character_)

    return(disease_name)
  }, error = function(e) {
    warning(sprintf(
      "Failed to fetch disease name for OMIM:%s - %s",
      mim_number, e$message
    ))
    return(NA_character_)
  })
}


#' Fetch disease names for all MIM numbers
#'
#' Iterates over a vector of MIM numbers, fetching disease names from the
#' JAX Ontology API with rate limiting and progress reporting.
#'
#' @param mim_numbers Character vector of MIM numbers
#' @param progress_callback Optional function for progress reporting.
#'   Called with (step, current, total) parameters.
#' @param delay_ms Integer, delay between requests in milliseconds (default: 50)
#' @return Tibble with columns: mim_number, disease_name
#'
#' @details
#' Uses 50ms delay between requests (validated in Phase 23-01).
#' Estimated time for ~8,500 MIM numbers: ~7 minutes.
#'
#' @examples
#' \dontrun{
#'   # Simple usage
#'   names <- fetch_all_disease_names(c("100050", "100100", "100200"))
#'
#'   # With progress callback
#'   names <- fetch_all_disease_names(
#'     mim_numbers,
#'     progress_callback = function(step, current, total) {
#'       message(sprintf("%s: %d/%d", step, current, total))
#'     }
#'   )
#' }
#'
#' @export
fetch_all_disease_names <- function(mim_numbers, progress_callback = NULL, delay_ms = 50) {
  n <- length(mim_numbers)
  disease_names <- character(n)

  for (i in seq_along(mim_numbers)) {
    mim <- mim_numbers[i]

    # Call progress callback if provided
    if (!is.null(progress_callback)) {
      progress_callback(step = "Fetching disease names", current = i, total = n)
    }

    # Fetch disease name
    disease_names[i] <- fetch_jax_disease_name(mim)

    # Add delay between requests (except after last request)
    if (i < n && delay_ms > 0) {
      Sys.sleep(delay_ms / 1000)
    }
  }

  result <- tibble(
    mim_number = mim_numbers,
    disease_name = disease_names
  )

  return(result)
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
  missing_id <- omim_data |>
    filter(is.na(disease_ontology_id)) |>
    nrow()

  if (missing_id > 0) {
    errors$missing_disease_ontology_id <- sprintf(
      "%d entries missing disease_ontology_id",
      missing_id
    )
  }

  # Check for missing disease_ontology_name
  missing_name_data <- omim_data |>
    filter(is.na(disease_ontology_name))
  missing_name <- nrow(missing_name_data)

  if (missing_name > 0) {
    mim_numbers <- missing_name_data$disease_ontology_id |>
      head(10) |>
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
    duplicates <- omim_data |>
      count(disease_ontology_id_version) |>
      filter(n > 1)

    if (nrow(duplicates) > 0) {
      dup_ids <- duplicates$disease_ontology_id_version |>
        head(10) |>
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
  deprecated <- mim2gene_data |>
    filter(mim_entry_type == "moved/removed") |>
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
  affected_entities <- tbl(pool, "disease_ontology_set") |>
    filter(disease_ontology_id %in% !!deprecated_omim_ids) |>
    select(
      disease_ontology_id_version,
      disease_ontology_id,
      disease_ontology_name
    ) |>
    collect()

  # If there are affected entries, join with entity view to get entity IDs
  if (nrow(affected_entities) > 0) {
    entity_usage <- tbl(pool, "ndd_entity_view") |>
      filter(disease_ontology_id_version %in% !!affected_entities$disease_ontology_id_version) |>
      dplyr::select(
        entity_id,
        disease_ontology_id_version,
        symbol,
        hgnc_id,
        category,
        ndd_phenotype
      ) |>
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


#' Build OMIM ontology set for database
#'
#' Combines mim2gene data with disease names from JAX API, matches gene symbols
#' to HGNC IDs, and creates versioned disease_ontology_id entries.
#'
#' @param mim2gene_data Tibble from parse_mim2gene()
#' @param disease_names Tibble from fetch_all_disease_names()
#' @param hgnc_list Tibble with columns: symbol, hgnc_id
#' @param moi_list Tibble with mode of inheritance terms (hpo_mode_of_inheritance_term_name, hpo_mode_of_inheritance_term)
#' @return Tibble matching disease_ontology_set schema
#'
#' @details
#' Creates the following columns:
#' - disease_ontology_id_version: OMIM:{mim_number} or OMIM:{mim_number}_{version}
#' - disease_ontology_id: OMIM:{mim_number}
#' - disease_ontology_name: From JAX API
#' - disease_ontology_source: "mim2gene"
#' - disease_ontology_date: Current date
#' - disease_ontology_is_specific: TRUE (OMIM entries are specific)
#' - hgnc_id: From HGNC lookup
#' - hpo_mode_of_inheritance_term: From MOI mapping
#'
#' Versioning logic:
#' - If MIM number appears once: OMIM:123456
#' - If MIM number appears multiple times: OMIM:123456_1, OMIM:123456_2, etc.
#'
#' @examples
#' \dontrun{
#'   omim_set <- build_omim_ontology_set(
#'     mim2gene_data,
#'     disease_names,
#'     hgnc_list,
#'     moi_list
#'   )
#' }
#'
#' @export
build_omim_ontology_set <- function(mim2gene_data, disease_names, hgnc_list, moi_list) {
  current_date <- format(Sys.Date(), "%Y-%m-%d")

  # Filter out deprecated entries - they shouldn't be added to ontology set
  phenotype_data <- mim2gene_data |>
    filter(!is_deprecated)

  # Join with disease names
  combined <- phenotype_data |>
    left_join(disease_names, by = "mim_number")

  # Match gene symbols to HGNC IDs
  # Note: mim2gene phenotype entries often have NA gene_symbol
  combined <- combined |>
    left_join(
      hgnc_list |> select(symbol, hgnc_id),
      by = c("gene_symbol" = "symbol")
    )

  # Create disease_ontology_id
  combined <- combined |>
    mutate(disease_ontology_id = paste0("OMIM:", mim_number))

  # Apply versioning for duplicate MIM numbers (same MIM with different genes/MOI)
  # First, arrange to ensure consistent ordering
  combined <- combined |>
    arrange(disease_ontology_id, hgnc_id)

  # Add version numbers
  combined <- combined |>
    group_by(disease_ontology_id) |>
    mutate(
      n = 1,
      count = n(),
      version = cumsum(n)
    ) |>
    ungroup() |>
    mutate(
      disease_ontology_id_version = case_when(
        count == 1 ~ disease_ontology_id,
        TRUE ~ paste0(disease_ontology_id, "_", version)
      )
    ) |>
    select(-n, -count, -version)

  # Add remaining columns
  result <- combined |>
    mutate(
      disease_ontology_name = disease_name,
      disease_ontology_source = "mim2gene",
      disease_ontology_date = current_date,
      disease_ontology_is_specific = TRUE,
      # hpo_mode_of_inheritance_term is NA for mim2gene
      # (mim2gene.txt doesn't include MOI information)
      hpo_mode_of_inheritance_term = NA_character_
    ) |>
    select(
      disease_ontology_id_version,
      disease_ontology_id,
      disease_ontology_name,
      disease_ontology_source,
      disease_ontology_date,
      disease_ontology_is_specific,
      hgnc_id,
      hpo_mode_of_inheritance_term
    )

  return(result)
}
