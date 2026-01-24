# functions/mondo-functions.R
# MONDO SSSOM mapping functions for OMIM disease equivalence
#
# SSSOM (Simple Standard for Sharing Ontology Mappings) is a W3C standard format.
# The MONDO exactMatch mapping file uses: subject_id=MONDO, object_id=OMIM.

require(tidyverse)
require(readr)
require(stringr)
require(httr2)
require(fs)
require(lubridate)

# Source file-functions for check_file_age and get_newest_file
# Note: These are already loaded via the main API startup


#' Download MONDO SSSOM Mapping File
#'
#' Downloads the MONDO-to-OMIM exactMatch SSSOM file from the Monarch Initiative
#' GitHub repository. Uses caching to avoid repeated downloads - only downloads
#' if the cached file is older than the specified age or force=TRUE.
#'
#' @param output_path Character. Directory path where the SSSOM file will be saved.
#'   Defaults to "data/mondo_mappings/".
#' @param force Logical. If TRUE, forces download even if a recent file exists.
#'   Defaults to FALSE.
#' @param max_age_months Numeric. Maximum age of cached file in months before
#'   re-downloading. Defaults to 1 (30 days).
#'
#' @return Character string with the path to the downloaded/cached SSSOM file.
#'
#' @examples
#' \dontrun{
#'   sssom_path <- download_mondo_sssom()
#'   sssom_path <- download_mondo_sssom(force = TRUE)
#'   sssom_path <- download_mondo_sssom(output_path = "custom/path/")
#' }
#'
#' @importFrom httr2 request req_retry req_perform resp_body_string
#' @importFrom fs dir_create
#'
#' @export
download_mondo_sssom <- function(output_path = "data/mondo_mappings/",
                                 force = FALSE,
                                 max_age_months = 1) {
  # MONDO exactMatch OMIM SSSOM file URL
  sssom_url <- "https://github.com/monarch-initiative/mondo/raw/master/src/ontology/mappings/mondo_exactmatch_omim.sssom.tsv"

  # Create output directory if it doesn't exist
  if (!dir.exists(output_path)) {
    fs::dir_create(output_path, recurse = TRUE)
  }

  # File basename for check_file_age compatibility
  file_basename <- "mondo-omim"

  # Check if recent file exists (unless force=TRUE)
  if (!force && check_file_age(file_basename, output_path, max_age_months)) {
    existing_file <- get_newest_file(file_basename, output_path)
    if (!is.null(existing_file)) {
      return(existing_file)
    }
  }

  # Download the SSSOM file
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- file.path(output_path, paste0(file_basename, ".", current_date, ".sssom.tsv"))

  tryCatch(
    {
      response <- httr2::request(sssom_url) |>
        httr2::req_retry(max_tries = 3, backoff = ~2) |>
        httr2::req_error(is_error = ~FALSE) |>
        httr2::req_perform()

      if (httr2::resp_status(response) == 200) {
        content <- httr2::resp_body_string(response)
        writeLines(content, output_file)
        return(output_file)
      } else {
        stop(paste(
          "Failed to download MONDO SSSOM file. HTTP status:",
          httr2::resp_status(response)
        ))
      }
    },
    error = function(e) {
      stop(paste("Error downloading MONDO SSSOM file:", e$message))
    }
  )
}


#' Parse MONDO SSSOM Mapping File
#'
#' Reads and parses a MONDO SSSOM (Simple Standard for Sharing Ontology Mappings)
#' TSV file. Filters for MONDO-to-OMIM exactMatch mappings and returns a tibble
#' with the mapping relationships.
#'
#' @param file_path Character. Path to the SSSOM TSV file.
#'
#' @return A tibble with columns:
#'   - mondo_id: MONDO identifier (e.g., "MONDO:0000001")
#'   - omim_id: OMIM identifier (e.g., "OMIM:100100")
#'
#' @details
#' SSSOM files contain comment lines starting with "#" that include metadata
#' such as CURIE maps. These are ignored during parsing. The function filters
#' for rows where subject_id starts with "MONDO:" and object_id starts with
#' "OMIM:" to extract only the relevant MONDO-to-OMIM mappings.
#'
#' Note: Some OMIM IDs may map to multiple MONDO IDs. The returned tibble
#' preserves all mappings (one row per mapping).
#'
#' @examples
#' \dontrun{
#'   mappings <- parse_mondo_sssom("data/mondo_mappings/mondo-omim.2026-01-24.sssom.tsv")
#'   head(mappings)
#' }
#'
#' @importFrom readr read_tsv
#' @importFrom dplyr filter select rename
#' @importFrom stringr str_detect
#'
#' @export
parse_mondo_sssom <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(paste("SSSOM file not found:", file_path))
  }

  # Read TSV with comment="#" to skip SSSOM metadata header
  sssom_data <- readr::read_tsv(
    file_path,
    comment = "#",
    col_types = readr::cols(.default = "c"),
    show_col_types = FALSE
  )

  # Validate expected columns exist
  required_cols <- c("subject_id", "object_id")
  missing_cols <- setdiff(required_cols, names(sssom_data))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns in SSSOM file:", paste(missing_cols, collapse = ", ")))
  }

  # Filter for MONDO-to-OMIM mappings
  mondo_omim_mappings <- sssom_data |>
    dplyr::filter(
      stringr::str_detect(subject_id, "^MONDO:"),
      stringr::str_detect(object_id, "^OMIM:")
    ) |>
    dplyr::select(mondo_id = subject_id, omim_id = object_id) |>
    dplyr::distinct()

  return(mondo_omim_mappings)
}


#' Get MONDO ID(s) for an OMIM ID
#'
#' Looks up MONDO identifier(s) for a given OMIM ID in a pre-parsed mapping tibble.
#' Returns all matching MONDO IDs, semicolon-separated if multiple matches exist.
#'
#' @param omim_id Character. The OMIM identifier to look up (e.g., "OMIM:100100").
#' @param mondo_mappings Tibble. The MONDO-OMIM mapping tibble from parse_mondo_sssom().
#'
#' @return Character string with the matching MONDO ID(s). If multiple matches,
#'   they are semicolon-separated (e.g., "MONDO:0000001;MONDO:0000002").
#'   Returns NA_character_ if no match is found.
#'
#' @examples
#' \dontrun{
#'   mappings <- parse_mondo_sssom("data/mondo_mappings/mondo-omim.sssom.tsv")
#'   mondo_id <- get_mondo_for_omim("OMIM:100100", mappings)
#' }
#'
#' @importFrom dplyr filter pull
#'
#' @export
get_mondo_for_omim <- function(omim_id, mondo_mappings) {
  if (is.null(omim_id) || is.na(omim_id) || omim_id == "") {
    return(NA_character_)
  }

  matching_mondos <- mondo_mappings |>
    dplyr::filter(omim_id == !!omim_id) |>
    dplyr::pull(mondo_id)

  if (length(matching_mondos) == 0) {
    return(NA_character_)
  }

  # Return semicolon-separated if multiple matches

  return(paste(unique(matching_mondos), collapse = ";"))
}


#' Add MONDO Mappings to Disease Ontology Set
#'
#' Enriches a disease_ontology_set tibble with MONDO equivalence mappings.
#' For each row where disease_ontology_source == "mim2gene", looks up the
#' corresponding MONDO ID and adds it as a new column.
#'
#' @param disease_ontology_set Tibble. The disease ontology dataset containing
#'   columns including disease_ontology_id_version and disease_ontology_source.
#' @param mondo_mappings Tibble. The MONDO-OMIM mapping tibble from parse_mondo_sssom().
#'
#' @return The input tibble with an additional "mondo_equivalent" column.
#'   - For mim2gene entries: contains MONDO ID(s) or NA if no match
#'   - For non-mim2gene entries: contains NA
#'
#' @details
#' This function handles the integration of MONDO equivalence data into the
#' disease ontology set used by the curation interface. Curators can see
#' suggested MONDO matches for OMIM diseases.
#'
#' Note: The function uses disease_ontology_id (not disease_ontology_id_version)
#' for the lookup, as OMIM IDs in the SSSOM file don't include version suffixes.
#'
#' @examples
#' \dontrun{
#'   mappings <- parse_mondo_sssom("data/mondo_mappings/mondo-omim.sssom.tsv")
#'   ontology_set <- process_combine_ontology(hgnc_list, moi_list)
#'   enriched_set <- add_mondo_mappings_to_ontology(ontology_set, mappings)
#' }
#'
#' @importFrom dplyr mutate case_when rowwise ungroup
#' @importFrom purrr map_chr
#'
#' @export
add_mondo_mappings_to_ontology <- function(disease_ontology_set, mondo_mappings) {
  if (is.null(disease_ontology_set) || nrow(disease_ontology_set) == 0) {
    return(disease_ontology_set)
  }

  # Validate required columns
  required_cols <- c("disease_ontology_id", "disease_ontology_source")
  missing_cols <- setdiff(required_cols, names(disease_ontology_set))
  if (length(missing_cols) > 0) {
    stop(paste(
      "Missing required columns in disease_ontology_set:",
      paste(missing_cols, collapse = ", ")
    ))
  }

  # Add MONDO equivalent column
  # For mim2gene entries, look up MONDO mapping using disease_ontology_id
  # For other sources (e.g., mondo), set to NA
  enriched_set <- disease_ontology_set |>
    dplyr::mutate(
      mondo_equivalent = purrr::map_chr(
        seq_len(dplyr::n()),
        ~ {
          if (disease_ontology_source[.x] == "mim2gene") {
            get_mondo_for_omim(disease_ontology_id[.x], mondo_mappings)
          } else {
            NA_character_
          }
        }
      )
    )

  return(enriched_set)
}
