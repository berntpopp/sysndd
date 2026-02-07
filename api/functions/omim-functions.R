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

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_perform()

  if (resp_status(response) != 200) {
    stop(sprintf("Failed to download mim2gene.txt: HTTP %d", resp_status(response)))
  }

  # Write to file
  writeBin(resp_body_raw(response), output_file)

  return(output_file)
}


#' Get OMIM download API key from environment variable
#'
#' Retrieves the OMIM download API key from the OMIM_DOWNLOAD_KEY environment
#' variable. Stops with an informative error message if the variable is not set.
#'
#' @return Character string, the OMIM download API key
#'
#' @details
#' The OMIM download key is required for authenticated downloads of genemap2.txt.
#' Set the environment variable in one of these ways:
#' - Add to .env file: OMIM_DOWNLOAD_KEY=your_key_here
#' - Docker Compose: environment: - OMIM_DOWNLOAD_KEY=${OMIM_DOWNLOAD_KEY}
#' - R session: Sys.setenv(OMIM_DOWNLOAD_KEY = "your_key_here")
#'
#' @examples
#' \dontrun{
#'   api_key <- get_omim_download_key()
#' }
#'
#' @export
get_omim_download_key <- function() {
  api_key <- Sys.getenv("OMIM_DOWNLOAD_KEY", "")
  if (api_key == "") {
    stop(
      "OMIM_DOWNLOAD_KEY environment variable not set.\n",
      "Add to .env file: OMIM_DOWNLOAD_KEY=your_key_here\n",
      "Or set in Docker Compose: environment: - OMIM_DOWNLOAD_KEY=${OMIM_DOWNLOAD_KEY}"
    )
  }
  return(api_key)
}


#' Download genemap2.txt from OMIM
#'
#' Downloads the genemap2.txt file from OMIM using an authenticated download URL.
#' Uses httr2 with retry logic for reliability. Checks file age before downloading
#' with 1-day TTL (time-to-live) caching.
#'
#' @param output_path Character string, directory to save the file (default: "data/")
#' @param force Logical, if TRUE downloads even if recent file exists (default: FALSE)
#' @param max_age_days Integer, maximum age in days before re-downloading (default: 1)
#' @return Character string, path to the downloaded/existing file
#'
#' @details
#' Uses OMIM_DOWNLOAD_KEY environment variable for authentication (see get_omim_download_key()).
#' Downloaded files are named genemap2.YYYY-MM-DD.txt.
#'
#' Caching behavior:
#' - Uses check_file_age_days() for 1-day TTL checking
#' - Returns cached file if it exists and is less than max_age_days old
#' - Downloads fresh file if cache is expired or force=TRUE
#'
#' Retry logic (same as download_mim2gene):
#' - max_tries: 3
#' - max_seconds: 60
#' - backoff: exponential (2^x seconds)
#' - timeout: 30 seconds per request
#'
#' @examples
#' \dontrun{
#'   # Use cached file if < 1 day old
#'   file_path <- download_genemap2()
#'
#'   # Force fresh download
#'   file_path <- download_genemap2(force = TRUE)
#' }
#'
#' @export
download_genemap2 <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists
  if (!force && check_file_age_days("genemap2", output_path, max_age_days)) {
    existing_file <- get_newest_file("genemap2", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[OMIM] Using cached genemap2.txt: %s", existing_file))
      return(existing_file)
    }
  }

  # Get API key
  api_key <- get_omim_download_key()

  # Download from OMIM with authenticated URL
  url <- sprintf("https://data.omim.org/downloads/%s/genemap2.txt", api_key)
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "genemap2.", current_date, ".txt")

  # Ensure output directory exists
  if (!dir_exists(output_path)) {
    dir_create(output_path)
  }

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_perform()

  if (resp_status(response) != 200) {
    stop(sprintf("Failed to download genemap2.txt: HTTP %d", resp_status(response)))
  }

  # Write to file
  writeBin(resp_body_raw(response), output_file)

  message(sprintf("[OMIM] Downloaded genemap2.txt to %s", output_file))

  return(output_file)
}


#' Download phenotype.hpoa from HPO
#'
#' Downloads the phenotype.hpoa file from the Human Phenotype Ontology using an
#' authenticated or public URL. Uses httr2 with retry logic for reliability.
#' Checks file age before downloading with 1-day TTL (time-to-live) caching.
#'
#' @param url Character string, the phenotype.hpoa download URL (from comparisons_config)
#' @param output_path Character string, directory to save the file (default: "data/")
#' @param force Logical, if TRUE downloads even if recent file exists (default: FALSE)
#' @param max_age_days Integer, maximum age in days before re-downloading (default: 1)
#' @return Character string, path to the downloaded/existing file
#'
#' @details
#' The phenotype.hpoa file contains disease-phenotype associations from HPO.
#' Downloaded files are named phenotype_hpoa.YYYY-MM-DD.txt.
#'
#' Caching behavior:
#' - Uses check_file_age_days() for 1-day TTL checking
#' - Returns cached file if it exists and is less than max_age_days old
#' - Downloads fresh file if cache is expired or force=TRUE
#'
#' Retry logic (same as download_genemap2):
#' - max_tries: 3
#' - max_seconds: 60
#' - backoff: exponential (2^x seconds)
#' - timeout: 30 seconds per request
#'
#' @examples
#' \dontrun{
#'   # Use cached file if < 1 day old
#'   url <- "http://purl.obolibrary.org/obo/hp/hpoa/phenotype.hpoa"
#'   file_path <- download_hpoa(url)
#'
#'   # Force fresh download
#'   file_path <- download_hpoa(url, force = TRUE)
#' }
#'
#' @export
download_hpoa <- function(url, output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists
  if (!force && check_file_age_days("phenotype_hpoa", output_path, max_age_days)) {
    existing_file <- get_newest_file("phenotype_hpoa", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[HPO] Using cached phenotype.hpoa: %s", existing_file))
      return(existing_file)
    }
  }

  # Download from HPO
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "phenotype_hpoa.", current_date, ".txt")

  # Ensure output directory exists
  if (!dir_exists(output_path)) {
    dir_create(output_path)
  }

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_perform()

  if (resp_status(response) != 200) {
    stop(sprintf("Failed to download phenotype.hpoa: HTTP %d", resp_status(response)))
  }

  # Write to file
  writeBin(resp_body_raw(response), output_file)

  message(sprintf("[HPO] Downloaded phenotype.hpoa to %s", output_file))

  return(output_file)
}


#' Parse genemap2.txt file from OMIM
#'
#' Reads and parses the genemap2.txt file, extracting disease names, MIM numbers,
#' mapping keys, and inheritance modes from the Phenotypes column. Uses position-based
#' column mapping for defensive handling of column name variations.
#'
#' @param genemap2_path Character string, path to the genemap2.txt file
#' @return Tibble with columns: Approved_Symbol, disease_ontology_name,
#'   disease_ontology_id, Mapping_key, hpo_mode_of_inheritance_term_name
#'
#' @details
#' The genemap2.txt file has no header row (uses # comment lines). Columns are
#' mapped by position (14 columns expected). The Phenotypes column (X13) uses
#' multi-stage parsing with negative lookaheads to extract:
#' - Disease name (may contain nested parentheses)
#' - Disease MIM number (6-digit code)
#' - Mapping key (1-4, indicates evidence level)
#' - Mode of inheritance (normalized to HPO terms)
#'
#' Multiple phenotypes per gene are separated by "; " (semicolon-space).
#' Multiple inheritance modes per phenotype are separated by ", " (comma-space).
#' Question marks ("?") in inheritance modes indicate uncertain inheritance and are removed.
#'
#' Inheritance term normalization maps 14 OMIM terms to standardized HPO vocabulary:
#' - "Autosomal dominant" -> "Autosomal dominant inheritance"
#' - "Autosomal recessive" -> "Autosomal recessive inheritance"
#' - "Digenic dominant" -> "Digenic inheritance"
#' - "Digenic recessive" -> "Digenic inheritance"
#' - "Isolated cases" -> "Sporadic"
#' - "Mitochondrial" -> "Mitochondrial inheritance"
#' - "Multifactorial" -> "Multifactorial inheritance"
#' - "Pseudoautosomal dominant" -> "X-linked dominant inheritance"
#' - "Pseudoautosomal recessive" -> "X-linked recessive inheritance"
#' - "Somatic mosaicism" -> "Somatic mosaicism"
#' - "Somatic mutation" -> "Somatic mutation"
#' - "X-linked" -> "X-linked inheritance"
#' - "X-linked dominant" -> "X-linked dominant inheritance"
#' - "X-linked recessive" -> "X-linked recessive inheritance"
#' - "Y-linked" -> "Y-linked inheritance"
#'
#' @examples
#' \dontrun{
#'   genemap_data <- parse_genemap2("data/genemap2.2026-02-07.txt")
#' }
#'
#' @export
parse_genemap2 <- function(genemap2_path) {
  # Read genemap2.txt (skip comment lines)
  raw_data <- readr::read_tsv(
    genemap2_path,
    col_names = FALSE,
    comment = "#",
    show_col_types = FALSE
  )

  # Defensive column count check
  if (ncol(raw_data) != 14) {
    stop(sprintf(
      "genemap2.txt column count mismatch. Expected 14, got %d. OMIM may have changed file format.",
      ncol(raw_data)
    ))
  }

  # Position-based column mapping
  genemap_data <- raw_data %>%
    dplyr::select(
      Chromosome = X1,
      Genomic_Position_Start = X2,
      Genomic_Position_End = X3,
      Cyto_Location = X4,
      Computed_Cyto_Location = X5,
      MIM_Number = X6,
      Gene_Symbols = X7,
      Gene_Name = X8,
      Approved_Symbol = X9,
      Entrez_Gene_ID = X10,
      Ensembl_Gene_ID = X11,
      Comments = X12,
      Phenotypes = X13,
      Mouse_Gene_Symbol_ID = X14
    ) %>%
    # Select relevant columns for Phenotypes parsing
    dplyr::select(Approved_Symbol, Phenotypes) %>%
    # Split multiple phenotypes (semicolon-separated)
    tidyr::separate_rows(Phenotypes, sep = "; ") %>%
    # Extract inheritance mode (after last closing paren)
    tidyr::separate(
      Phenotypes,
      c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"),
      "\\), (?!.+\\))",
      fill = "right"
    ) %>%
    # Extract mapping key (last opening paren before inheritance)
    tidyr::separate(
      disease_ontology_name,
      c("disease_ontology_name", "Mapping_key"),
      "\\((?!.+\\()",
      fill = "right"
    ) %>%
    # Clean closing paren from mapping key
    dplyr::mutate(Mapping_key = stringr::str_replace_all(Mapping_key, "\\)", "")) %>%
    # Extract disease MIM number (6-digit code before mapping key)
    tidyr::separate(
      disease_ontology_name,
      c("disease_ontology_name", "MIM_Number"),
      ", (?=[0-9]{6})",
      fill = "right"
    ) %>%
    # Clean whitespace
    dplyr::mutate(
      Mapping_key = stringr::str_replace_all(Mapping_key, " ", ""),
      MIM_Number = stringr::str_replace_all(MIM_Number, " ", "")
    ) %>%
    # Filter entries without disease MIM number
    dplyr::filter(!is.na(MIM_Number)) %>%
    # Filter entries without gene symbol
    dplyr::filter(!is.na(Approved_Symbol)) %>%
    # Create OMIM ID with prefix
    dplyr::mutate(disease_ontology_id = paste0("OMIM:", MIM_Number)) %>%
    # Split multiple inheritance modes (comma-separated)
    tidyr::separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%
    # Remove question marks (uncertain inheritance)
    dplyr::mutate(
      hpo_mode_of_inheritance_term_name = stringr::str_replace_all(
        hpo_mode_of_inheritance_term_name,
        "\\?",
        ""
      )
    ) %>%
    # Remove MIM_Number column (now in disease_ontology_id)
    dplyr::select(-MIM_Number) %>%
    # Deduplicate
    unique() %>%
    # Normalize inheritance terms to HPO vocabulary
    dplyr::mutate(hpo_mode_of_inheritance_term_name = dplyr::case_when(
      hpo_mode_of_inheritance_term_name == "Autosomal dominant" ~ "Autosomal dominant inheritance",
      hpo_mode_of_inheritance_term_name == "Autosomal recessive" ~ "Autosomal recessive inheritance",
      hpo_mode_of_inheritance_term_name == "Digenic dominant" ~ "Digenic inheritance",
      hpo_mode_of_inheritance_term_name == "Digenic recessive" ~ "Digenic inheritance",
      hpo_mode_of_inheritance_term_name == "Isolated cases" ~ "Sporadic",
      hpo_mode_of_inheritance_term_name == "Mitochondrial" ~ "Mitochondrial inheritance",
      hpo_mode_of_inheritance_term_name == "Multifactorial" ~ "Multifactorial inheritance",
      hpo_mode_of_inheritance_term_name == "Pseudoautosomal dominant" ~ "X-linked dominant inheritance",
      hpo_mode_of_inheritance_term_name == "Pseudoautosomal recessive" ~ "X-linked recessive inheritance",
      hpo_mode_of_inheritance_term_name == "Somatic mosaicism" ~ "Somatic mosaicism",
      hpo_mode_of_inheritance_term_name == "Somatic mutation" ~ "Somatic mutation",
      hpo_mode_of_inheritance_term_name == "X-linked" ~ "X-linked inheritance",
      hpo_mode_of_inheritance_term_name == "X-linked dominant" ~ "X-linked dominant inheritance",
      hpo_mode_of_inheritance_term_name == "X-linked recessive" ~ "X-linked recessive inheritance",
      hpo_mode_of_inheritance_term_name == "Y-linked" ~ "Y-linked inheritance",
      TRUE ~ hpo_mode_of_inheritance_term_name
    ))

  return(genemap_data)
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

  result <- mim_data %>%
    filter(mim_entry_type %in% entry_types_to_include) %>%
    mutate(is_deprecated = mim_entry_type == "moved/removed") %>%
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

  tryCatch(
    {
      response <- request(url) %>%
        req_retry(
          max_tries = 5,
          max_seconds = 120,
          backoff = ~ 2^.x,
          is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
        ) %>%
        req_timeout(30) %>%
        req_error(is_error = ~FALSE) %>%
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
    },
    error = function(e) {
      warning(sprintf(
        "Failed to fetch disease name for OMIM:%s - %s",
        mim_number, e$message
      ))
      return(NA_character_)
    }
  )
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


#' Build OMIM ontology set for database
#'
#' Combines mim2gene data with disease names from JAX API, matches gene symbols
#' to HGNC IDs, and creates versioned disease_ontology_id entries.
#'
#' @param mim2gene_data Tibble from parse_mim2gene()
#' @param disease_names Tibble from fetch_all_disease_names()
#' @param hgnc_list Tibble with columns: symbol, hgnc_id
#' @param moi_list Tibble with mode of inheritance terms (hpo_mode_of_inheritance_term_name, hpo_mode_of_inheritance_term) # nolint: line_length_linter
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
  phenotype_data <- mim2gene_data %>%
    filter(!is_deprecated)

  # Join with disease names
  combined <- phenotype_data %>%
    left_join(disease_names, by = "mim_number")

  # Match gene symbols to HGNC IDs
  # Note: mim2gene phenotype entries often have NA gene_symbol
  combined <- combined %>%
    left_join(
      hgnc_list %>% select(symbol, hgnc_id),
      by = c("gene_symbol" = "symbol")
    )

  # Create disease_ontology_id
  combined <- combined %>%
    mutate(disease_ontology_id = paste0("OMIM:", mim_number))

  # Apply versioning for duplicate MIM numbers (same MIM with different genes/MOI)
  # First, arrange to ensure consistent ordering
  combined <- combined %>%
    arrange(disease_ontology_id, hgnc_id)

  # Add version numbers
  combined <- combined %>%
    group_by(disease_ontology_id) %>%
    mutate(
      n = 1,
      count = n(),
      version = cumsum(n)
    ) %>%
    ungroup() %>%
    mutate(
      disease_ontology_id_version = case_when(
        count == 1 ~ disease_ontology_id,
        TRUE ~ paste0(disease_ontology_id, "_", version)
      )
    ) %>%
    select(-n, -count, -version)

  # Add remaining columns
  result <- combined %>%
    mutate(
      disease_ontology_name = disease_name,
      disease_ontology_source = "mim2gene",
      disease_ontology_date = current_date,
      disease_ontology_is_specific = TRUE,
      # hpo_mode_of_inheritance_term is NA for mim2gene
      # (mim2gene.txt doesn't include MOI information)
      hpo_mode_of_inheritance_term = NA_character_
    ) %>%
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
