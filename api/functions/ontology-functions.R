# functions/ontology-functions.R

require(ontologyIndex) # Needed to read ontology files
require(tidyverse)     # For data manipulation

# Source OMIM and MONDO functions for new data source workflow
# Uses conditional sourcing for portability (Plumber vs standalone execution)
omim_functions_path <- if (file.exists("functions/omim-functions.R")) {
  "functions/omim-functions.R"
} else if (file.exists("api/functions/omim-functions.R")) {
  "api/functions/omim-functions.R"
} else {
  file.path(find.package("api", quiet = TRUE)[1] %||% ".", "functions/omim-functions.R")
}
if (file.exists(omim_functions_path)) source(omim_functions_path)

mondo_functions_path <- if (file.exists("functions/mondo-functions.R")) {
  "functions/mondo-functions.R"
} else if (file.exists("api/functions/mondo-functions.R")) {
  "api/functions/mondo-functions.R"
} else {
  file.path(find.package("api", quiet = TRUE)[1] %||% ".", "functions/mondo-functions.R")
}
if (file.exists(mondo_functions_path)) source(mondo_functions_path)


#' Identify Critical Ontology Changes
#'
#' This function identifies critical changes in ontology sets by comparing the updated
#' ontology set with the current ontology set and a subset of terms used in entities.
#' It returns a tibble of critical changes.
#'
#' @param disease_ontology_set_update Updated disease ontology dataset.
#' @param disease_ontology_set Current disease ontology dataset.
#' @param ndd_entity_view_ontology_set Ontology dataset used in entities.
#' @return A tibble of critical ontology changes.
#'
#' @examples
#' \dontrun{
#'   critical_changes <- identify_critical_ontology_changes(
#'     disease_ontology_set_update,
#'     disease_ontology_set,
#'     ndd_entity_view_ontology_set
#'   )
#' }
#'
#' @export
identify_critical_ontology_changes <- function(disease_ontology_set_update, disease_ontology_set, ndd_entity_view_ontology_set) {
  # Add columns for logic checks in the updated set
  disease_ontology_set_update_extra <- disease_ontology_set_update %>%
    select(disease_ontology_id_version, disease_ontology_id, hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_name) %>%
    mutate(id_hgnc_hpo = paste0(disease_ontology_id, "_", hgnc_id, "_", hpo_mode_of_inheritance_term),
           name_hgnc_hpo = paste0(disease_ontology_name, "_", hgnc_id, "_", hpo_mode_of_inheritance_term),
           has_id_version = str_detect(disease_ontology_id_version, "_")) %>%
    group_by(disease_ontology_id) %>%
    mutate(id_same_name = length(unique(disease_ontology_name))) %>%
    ungroup()

  # Add columns for logic checks in the current set
  disease_ontology_set_current <- disease_ontology_set %>%
    mutate(id_hgnc_hpo = paste0(disease_ontology_id, "_", hgnc_id, "_", hpo_mode_of_inheritance_term),
           name_hgnc_hpo = paste0(disease_ontology_name, "_", hgnc_id, "_", hpo_mode_of_inheritance_term),
           has_id_version = str_detect(disease_ontology_id_version, "_")) %>%
    group_by(disease_ontology_id) %>%
    mutate(id_same_name = length(unique(disease_ontology_name))) %>%
    ungroup()

  # Filter current ontology list for terms used in entities
  disease_ontology_set_current_used <- disease_ontology_set_current %>%
    mutate(used_in_entity = disease_ontology_id_version %in% ndd_entity_view_ontology_set$disease_ontology_id_version) %>%
    filter(used_in_entity) %>%
    select(-used_in_entity)

  # Check for ontology changes that affect existing entities
  # Columns check for:
  # - check_ontology_id_version: exact version match exists in update
  # - check_ontology_name: disease name still exists in update
  # - check_id_fingerprint: (id + hgnc + inheritance) fingerprint match
  # - check_name_fingerprint: (name + hgnc + inheritance) fingerprint match
  disease_ontology_set_current_used_check <- disease_ontology_set_current_used %>%
    mutate(check_ontology_id_version = disease_ontology_id_version %in% disease_ontology_set_update_extra$disease_ontology_id_version,
           check_ontology_name = disease_ontology_name %in% disease_ontology_set_update_extra$disease_ontology_name,
           check_id_fingerprint = id_hgnc_hpo %in% disease_ontology_set_update_extra$id_hgnc_hpo,
           check_name_fingerprint = name_hgnc_hpo %in% disease_ontology_set_update_extra$name_hgnc_hpo)

  disease_ontology_set_current_used_check_filter <- disease_ontology_set_current_used_check %>%
    filter(!check_ontology_id_version | !check_ontology_name)

  # Compute if a mismatch is critical or not
  critical <- disease_ontology_set_current_used_check_filter %>%
    mutate(critical = case_when(
      !has_id_version & check_ontology_id_version & !check_ontology_name ~ FALSE,
      has_id_version & check_ontology_id_version & !check_ontology_name & id_same_name == 1 ~ FALSE,
      TRUE ~ TRUE
    ),
    automatic_assignment_version = !check_ontology_id_version & !check_ontology_name & check_id_fingerprint,
    automatic_assignment_name = !check_ontology_id_version & check_ontology_name) %>%
    filter(critical)

  return(critical)
}


#' Process and Combine Ontology Data
#'
#' This function processes MONDO and OMIM ontology data, combines them, and
#' returns the combined dataset. If a recent CSV file exists, it loads that;
#' otherwise, it regenerates the data and saves it as a CSV file.
#'
#' Uses the new mim2gene.txt + JAX API workflow for OMIM data (replacing genemap2.txt).
#' Also downloads and applies MONDO SSSOM mappings for OMIM-to-MONDO equivalence.
#'
#' @param hgnc_list A tibble containing non-alternative loci gene data (columns: hgnc_id, symbol).
#' @param mode_of_inheritance_list A tibble containing mode of inheritance data.
#' @param max_file_age Integer, maximum age of the file in months before regeneration.
#' @param output_path String, the path where the output CSV file will be stored.
#' @param progress_callback Optional function for async progress reporting.
#'   Called with (step, current, total) parameters.
#' @return A tibble containing the combined ontology dataset.
#'
#' @examples
#' \dontrun{
#'   moi_list <- read_csv("path/to/moi_list.csv")
#'   non_alt_loci_set <- read_csv("path/to/non_alt_loci_set.csv")
#'   combined_ontology_data <- process_combine_ontology(non_alt_loci_set, moi_list, 3, "data/")
#'
#'   # With progress callback (for async jobs)
#'   combined_ontology_data <- process_combine_ontology(
#'     non_alt_loci_set, moi_list, 3, "data/",
#'     progress_callback = function(step, current, total) {
#'       message(sprintf("%s: %d/%d", step, current, total))
#'     }
#'   )
#' }
#'
#' @export
process_combine_ontology <- function(hgnc_list, mode_of_inheritance_list, max_file_age = 3, output_path = "data/", progress_callback = NULL) {
  csv_file_name <- paste0(output_path, "disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")

  # Check if file exists and is not too old
  if (check_file_age("disease_ontology_set", output_path, 1)) {
    return(read_csv(get_newest_file("disease_ontology_set", output_path), na = "NULL")) # Load and return the existing tibble
  } else {
    # Process ontology if file is too old or doesn't exist
    mondo_terms <- process_mondo_ontology()

    # Process OMIM ontology using new mim2gene + JAX API workflow
    omim_terms <- process_omim_ontology(hgnc_list, mode_of_inheritance_list, max_file_age, progress_callback)

    # Get ontology mappings from MONDO OBO file
    config_vars <- list(
      hpo_obo_url = "https://github.com/obophenotype/human-phenotype-ontology/releases/download/v2025-01-16/hp.obo",
      mpo_obo_url = "https://github.com/mgijax/mammalian-phenotype-ontology/releases/download/v2025-01-30/mp.obo",
      mondo_obo_url = "https://github.com/monarch-initiative/mondo/releases/download/v2025-02-04/mondo-base.obo",
      download_path = "data/"
    )
    mondo_ontology <- get_ontology_object("mondo", config_vars)
    mondo_mappings <- get_mondo_mappings(mondo_ontology)

    # make mappings for specific joins
    # this splits columns with multiple values (separated by ";") into multiple rows for OMIM
    # then it groups by OMIM summarizes the other columns (";" separated) ommiting NA values
    mondo_mappings_omim <- mondo_mappings %>%
      filter(OMIM != "NA") %>%
      separate_rows(OMIM, sep = ";") %>%
      unique() %>%
      group_by(OMIM) %>%
      summarize(
        MONDO = ifelse(all(is.na(MONDO)), NA, paste0(na.omit(unique(MONDO)), collapse = ";")),
        DOID = ifelse(all(is.na(DOID)), NA, paste0(na.omit(unique(DOID)), collapse = ";")),
        Orphanet = ifelse(all(is.na(Orphanet)), NA, paste0(na.omit(unique(Orphanet)), collapse = ";")),
        EFO = ifelse(all(is.na(EFO)), NA, paste0(na.omit(unique(EFO)), collapse = ";")),
        .groups = 'drop'
      )

    # Combine data
    omim_terms_mappings <- left_join(omim_terms, mondo_mappings_omim, by = c("disease_ontology_id_version" = "OMIM"))

    mondo_terms_mappings <- left_join(mondo_terms, mondo_mappings, by = c("disease_ontology_id_version" = "MONDO"))

    disease_ontology_set <- bind_rows(mondo_terms_mappings, omim_terms_mappings) %>%
      select(-OMIM) %>%
      mutate(is_active = TRUE, update_date = format(Sys.Date(), "%Y-%m-%d"))

    # Download and apply MONDO SSSOM mappings for OMIM-to-MONDO equivalence
    # This adds mondo_equivalent column for mim2gene entries
    if (!is.null(progress_callback)) {
      progress_callback(step = "Applying MONDO SSSOM mappings", current = 4, total = 4)
    }
    mondo_sssom_file <- download_mondo_sssom(paste0(output_path, "mondo_mappings/"))
    mondo_sssom <- parse_mondo_sssom(mondo_sssom_file)
    disease_ontology_set <- add_mondo_mappings_to_ontology(disease_ontology_set, mondo_sssom)

    # Save the result as a CSV file
    write_csv(disease_ontology_set, file = csv_file_name, na = "NULL")

    # Return the tibble
    return(disease_ontology_set)
  }
}


#' Process MONDO ontology and save the mapping as a CSV file, then return the mapping tibble.
#'
#' This function processes the MONDO ontology to get all descendant terms and their mappings.
#' If a recent CSV file exists, it loads that; otherwise, it saves the data as a CSV file.
#' The function then returns the mappings as a tibble with specified columns.
#'
#' @param mondo_ontology The MONDO ontology object.
#' @param max_age Integer, maximum age of the file in months before regeneration.
#' @param output_path String, the path where the output CSV file will be stored.
#' @param columns_to_return List of column names to return. If NULL, all columns are returned.
#' @return A tibble containing the ontology mapping.
#'
#' @examples
#' \dontrun{
#'   mondo_ontology <- get_ontology_object("mondo", config_vars, 1)
#'   mondo_mappings <- get_mondo_mappings(mondo_ontology, 1, "data/", columns_to_return = c("MONDO", "DOID"))
#' }
#'
#' @export
get_mondo_mappings <- function(mondo_ontology, max_age = 1, output_path = "data/", columns_to_return = c("OMIM", "MONDO", "DOID", "Orphanet", "EFO")) {
  csv_file_name <- paste0(output_path, "mondo_ontology_mapping.", format(Sys.Date(), "%Y-%m-%d"), ".csv")

  # Check if file exists and is not too old
  if (check_file_age("mondo_ontology_mapping", output_path, 1)) {
    mappings_tibble <- read_csv(get_newest_file("mondo_ontology_mapping", output_path), na = "NULL") # Load the existing tibble
  } else {
    # Process ontology if file is too old or doesn't exist
    all_terms <- get_descendants(ontology = mondo_ontology, roots = "MONDO:0000001")
    all_terms_tibble <- all_terms %>%
      tidyr::as_tibble() %>%
      select(MONDO = value)

    all_terms_tibble_mapping <- all_terms_tibble %>%
      rowwise() %>%
      mutate(mappings = list(get_term_property(ontology = mondo_ontology, property = "xref", term = MONDO))) %>%
      ungroup()

    mappings_tibble <- all_terms_tibble_mapping %>%
      unnest(mappings) %>%
      mutate(ontology = str_split(mappings, ":", simplify = TRUE)[,1]) %>%
      pivot_wider(names_from = ontology, values_from = mappings, values_fn = function(x) paste(x, collapse = ";"))

    # Save the result as a CSV file
    write_csv(mappings_tibble, file = csv_file_name, na = "NULL")
  }

  # Return only the specified columns, or all columns if `columns_to_return` is NULL
  if (!is.null(columns_to_return)) {
    return(mappings_tibble %>% select(all_of(columns_to_return)))
  } else {
    return(mappings_tibble)
  }
}


#' Process MONDO Ontology Data
#'
#' This function processes the MONDO ontology data from a specified file.
#' It reads the MONDO terms file and formats it for further use.
#'
#' @param mondo_file The file path to the MONDO terms file.
#' @return A tibble containing processed data from the MONDO ontology.
#'
#' @examples
#' \dontrun{
#'   processed_mondo_data <- process_mondo_ontology("data/mondo_terms/mondo_terms.txt")
#' }
#'
#' @export
process_mondo_ontology <- function(mondo_file = "data/mondo_terms/mondo_terms.txt") {

  # Get current date in YYYY-MM-DD format
  mondo_file_date <- format(Sys.Date(), "%Y-%m-%d")

  # TODO(future): Replace static file with dynamic ontology extraction
  # Use get_ontology_object("mondo", config_vars) and process all MONDO terms
  # dynamically instead of relying on pre-generated mondo_terms.txt file
  # Requires: term extraction logic, property parsing for all MONDO descendants
  mondo_terms <- read_delim(mondo_file, "\t", col_names = TRUE) %>%
    mutate(disease_ontology_source = "mondo") %>%
    mutate(disease_ontology_date = mondo_file_date) %>%
    mutate(disease_ontology_is_specific = FALSE) %>%
    mutate(hgnc_id = NA) %>%
    mutate(hpo_mode_of_inheritance_term = NA) %>%
    mutate(disease_ontology_id_version = disease_ontology_id) %>%
    select(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, disease_ontology_source, disease_ontology_date, disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term)
}


#' Process OMIM Ontology Data
#'
#' This function processes the OMIM ontology data using the new mim2gene.txt + JAX API workflow.
#' It downloads mim2gene.txt from OMIM, fetches disease names from the JAX Ontology API,
#' and builds the OMIM ontology set matching the database schema.
#'
#' Replaces the previous genemap2.txt-based approach.
#'
#' @param hgnc_list A tibble of HGNC gene symbols and corresponding identifiers (columns: hgnc_id, symbol).
#' @param moi_list A tibble of mode of inheritance terms (for compatibility, not used in mim2gene workflow).
#' @param max_file_age Integer, maximum age of the file in months before re-downloading (default: 3).
#' @param progress_callback Optional function for async progress reporting.
#'   Called with (step, current, total) parameters.
#' @return A tibble containing processed data from the OMIM ontology.
#'
#' @examples
#' \dontrun{
#'   hgnc_list <- read_csv("path/to/hgnc_list.csv")
#'   moi_list <- read_csv("path/to/moi_list.csv")
#'   processed_omim_data <- process_omim_ontology(hgnc_list, moi_list)
#'
#'   # With progress callback (for async jobs)
#'   processed_omim_data <- process_omim_ontology(
#'     hgnc_list, moi_list, 3,
#'     progress_callback = function(step, current, total) {
#'       message(sprintf("%s: %d/%d", step, current, total))
#'     }
#'   )
#' }
#'
#' @export
process_omim_ontology <- function(hgnc_list, moi_list, max_file_age = 3, progress_callback = NULL) {
  # Step 1: Download mim2gene.txt
  if (!is.null(progress_callback)) {
    progress_callback(step = "Downloading mim2gene.txt", current = 1, total = 4)
  }
  mim2gene_file <- download_mim2gene("data/", force = FALSE, max_age_months = max_file_age)
  mim2gene_data <- parse_mim2gene(mim2gene_file)

  # Step 2: Fetch disease names from JAX API
  phenotype_mims <- mim2gene_data$mim_number
  if (!is.null(progress_callback)) {
    # Pass through sub-progress to progress_callback
    disease_names <- fetch_all_disease_names(
      phenotype_mims,
      progress_callback = function(step, current, total) {
        progress_callback(
          step = paste0("Fetching disease names: ", current, "/", total),
          current = 2,
          total = 4
        )
      }
    )
  } else {
    disease_names <- fetch_all_disease_names(phenotype_mims)
  }

  # Step 3: Build OMIM ontology set
  if (!is.null(progress_callback)) {
    progress_callback(step = "Building ontology set", current = 3, total = 4)
  }
  omim_terms <- build_omim_ontology_set(mim2gene_data, disease_names, hgnc_list, moi_list)

  # Define the file path for the CSV file
  omim_file_date <- format(Sys.Date(), "%Y-%m-%d")
  csv_file_path <- paste0("results/ontology/omim_mim2gene.", omim_file_date, ".csv")

  # Ensure directory exists
  if (!dir.exists("results/ontology")) {
    dir.create("results/ontology", recursive = TRUE)
  }

  # Save the dataset as a CSV file
  write_csv(omim_terms, file = csv_file_path, na = "NULL")

  # Return the tibble
  return(omim_terms)
}


#' Download and Load an Ontology Based on Provided Parameters
#'
#' This function downloads an ontology file if it's older than a specified age
#' and then loads it into an ontology object. It supports Human Phenotype Ontology (HPO),
#' Mammalian Phenotype Ontology (MPO), and MONDO.
#'
#' @param ontology_type A character string specifying the type of ontology ("hpo", "mpo", or "mondo").
#' @param config_vars List of configuration variables including the URL and file paths for each ontology type.
#' @param tags A character string specifying the type of tags to be extracted from the ontology ("minimal", "default", or "everything").
#' @param max_age Integer, maximum age of the file in months before re-downloading.
#' @return An ontology object loaded with the specified ontology data.
#'
#' @examples
#' \dontrun{
#'   config_vars <- list(
#'     hpo_obo_url = "https://github.com/obophenotype/human-phenotype-ontology/releases/download/v2023-10-09/hp.obo",
#'     mpo_obo_url = "https://github.com/mgijax/mammalian-phenotype-ontology/releases/download/v2023-10-31/mp.obo",
#'     mondo_obo_url = "http://purl.obolibrary.org/obo/mondo.obo",
#'     download_path = "data/"
#'   )
#'   hpo_ontology <- get_ontology_object("hpo", config_vars, "everything", 1)
#' }
#'
#' @export
get_ontology_object <- function(ontology_type, config_vars, tags = "everything", max_age = 1) {
  # Determine file prefix based on ontology type
  file_prefix <- switch(ontology_type,
                        "hpo" = "hpo_obo",
                        "mpo" = "mpo_obo",
                        "mondo" = "mondo_obo",
                        stop("Invalid ontology type"))

  # Check if the current ontology file is older than max_age
  if (check_file_age(file_prefix, config_vars$download_path, max_age)) {
    ontology_filename <- get_newest_file(file_prefix, config_vars$download_path)
  } else {
    # Download a new file if the existing one is too old
    ontology_url <- config_vars[[paste0(ontology_type, "_obo_url")]]
    current_date <- format(Sys.Date(), "%Y-%m-%d")
    ontology_filename <- paste0(config_vars$download_path, file_prefix, ".", current_date, ".obo")
    download.file(ontology_url, ontology_filename, mode = "wb")
  }

  # Load the ontology
  ontology <- get_ontology(
    ontology_filename,
    propagate_relationships = "is_a",
    extract_tags = tags,
    merge_equivalent_terms = TRUE
  )

  return(ontology)
}