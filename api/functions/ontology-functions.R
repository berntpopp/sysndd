require(ontologyIndex) # Needed to read ontology files
require(tidyverse)     # For data manipulation


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
get_mondo_mappings <- function(mondo_ontology, max_age, output_path, columns_to_return = c("OMIM", "MONDO", "DOID", "Orphanet")) {
  csv_file_name <- paste0(output_path, "mondo_ontology_mapping_", format(Sys.Date(), "%Y-%m-%d"), ".csv")

  # Check if file exists and is not too old
  if (file.exists(csv_file_name) && !check_file_age(csv_file_name, max_age)) {
    mappings_tibble <- read_csv(csv_file_name, na = "NULL") # Load the existing tibble
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

# Helper function to check the age of a file
check_file_age <- function(file_path, max_age_months) {
  file_age_days <- as.numeric(difftime(Sys.Date(), file.mtime(file_path), units = "days"))
  return(file_age_days > (max_age_months * 30))
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

  # TODO: use the get_ontology_object fucntion and a list of mondo identifiers to compute this table
  mondo_terms <- read_delim(mondo_file, "\t", col_names = TRUE) %>%
    mutate(disease_ontology_source = "mondo") %>%
    mutate(disease_ontology_date = omim_file_date) %>%
    mutate(disease_ontology_is_specific = FALSE) %>%
    mutate(hgnc_id = NA) %>%
    mutate(hpo_mode_of_inheritance_term = NA) %>%
    mutate(disease_ontology_id_version = disease_ontology_id) %>%
    select(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, disease_ontology_source, disease_ontology_date, disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term)
}


#' Process OMIM Ontology Data
#'
#' This function processes the OMIM ontology data using the HGNC gene list and mode of inheritance list.
#' It downloads and loads the OMIM genemap2 file, then reformats it for further analysis.
#'
#' @param hgnc_list A list or tibble of HGNC gene symbols and corresponding identifiers.
#' @param moi_list A list or tibble of mode of inheritance terms.
#' @param max_file_age Integer, maximum age of the file in months before re-downloading.
#' @return A tibble containing processed data from the OMIM ontology.
#'
#' @examples
#' \dontrun{
#'   hgnc_list <- read_csv("path/to/hgnc_list.csv")
#'   moi_list <- read_csv("path/to/moi_list.csv")
#'   processed_omim_data <- process_omim_ontology(hgnc_list, moi_list)
#' }
#'
#' @export
process_omim_ontology <- function(hgnc_list, moi_list, max_file_age = 3) {
  # TODO: add an initial check to see if the result file already exists and is not too old, return this file if it exists
  # TODO: add a flag to recalculate the file even if it exists

  # Download and load OMIM genemap2 file
  if (check_file_age("genemap2", "data", max_file_age)) {
    genemap2 <- read_delim(get_newest_file("genemap2", "data"), "\t", escape_double = FALSE, col_names = FALSE, comment = "#", trim_ws = TRUE, show_col_types = FALSE) %>%
    select(Chromosome = X1,  Genomic_Position_Start = X2, Genomic_Position_End = X3, Cyto_Location = X4, Computed_Cyto_Location = X5, MIM_Number = X6, Gene_Symbols = X7, Gene_Name = X8, Approved_Symbol = X9, Entrez_Gene_ID = X10, Ensembl_Gene_ID = X11, Comments = X12, Phenotypes = X13, Mouse_Gene_Symbol_ID = X14)
  } else {
    omim_file_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

    genemap2_link <- as_tibble(read_lines("data/omim_links/omim_links.txt")) %>%
      mutate(file_name = str_remove(value, "https.+\\/")) %>%
      mutate(file_name = str_remove(file_name, "\\.txt")) %>%
      filter(file_name == "genemap2")

    download.file(genemap2_link$value[1], paste0("data/", genemap2_link$file_name[1], ".", omim_file_date, ".txt"), mode = "wb")

    genemap2 <- read_delim(get_newest_file("genemap2", "data"), "\t", escape_double = FALSE, col_names = FALSE, comment = "#", trim_ws = TRUE, show_col_types = FALSE) %>%
    select(Chromosome = X1,  Genomic_Position_Start = X2, Genomic_Position_End = X3, Cyto_Location = X4, Computed_Cyto_Location = X5, MIM_Number = X6, Gene_Symbols = X7, Gene_Name = X8, Approved_Symbol = X9, Entrez_Gene_ID = X10, Ensembl_Gene_ID = X11, Comments = X12, Phenotypes = X13, Mouse_Gene_Symbol_ID = X14)
  }

  # Load and reformat OMIM tables

  # use the hgnc_list table to correct the gene symbols
  genemap2_hgnc_non_alt_loci_set <- genemap2 %>%
    filter(!is.na(Phenotypes) & !is.na(Approved_Symbol)) %>%
    select(Approved_Symbol, Phenotypes) %>%
    left_join(hgnc_list, by = c("Approved_Symbol" = "symbol"))

  # use the hgnc_list table to correct the gene symbols
  genemap2_hgnc_existing <- genemap2_hgnc_non_alt_loci_set %>%
    filter(!is.na(hgnc_id))

  # combine the corrected and non-corrected gene symbols
  genemap2_hgnc_corrected <- genemap2_hgnc_non_alt_loci_set %>%
    filter(is.na(hgnc_id)) %>%
    mutate(hgnc_id = paste0("HGNC:", hgnc_id_from_symbol_grouped(Approved_Symbol)))

  # compute the genemap2_hgnc ontology table
  # TODO: lint and simplify this code
  # TODO: make some of this logic a config file (e.g moi term equality mapping)
  genemap2_hgnc <- bind_rows(genemap2_hgnc_existing, genemap2_hgnc_corrected) %>%
    separate_rows(Phenotypes, sep = "; ") %>%
    separate(Phenotypes, c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"), "\\), (?!.+\\))", extra = "drop", fill = "right") %>%
    separate(disease_ontology_name, c("disease_ontology_name", "Mapping_key"), "\\((?!.+\\()", extra = "drop", fill = "right") %>%
    mutate(Mapping_key = str_replace_all(Mapping_key, "\\)", "")) %>%
    separate(disease_ontology_name, c("disease_ontology_name", "MIM_Number"), ", (?=[0-9][0-9][0-9][0-9][0-9][0-9])", extra = "drop", fill = "right") %>%
    mutate(Mapping_key = str_replace_all(Mapping_key, " ", "")) %>%
    mutate(MIM_Number = str_replace_all(MIM_Number, " ", "")) %>%
    filter(!is.na(MIM_Number))  %>%
    mutate(disease_ontology_id = paste0("OMIM:",MIM_Number)) %>%
    separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%
    mutate(hpo_mode_of_inheritance_term_name = str_replace_all(hpo_mode_of_inheritance_term_name, "\\?", "")) %>%
    select(-MIM_Number) %>%
    unique() %>%
    mutate(hpo_mode_of_inheritance_term_name = case_when(hpo_mode_of_inheritance_term_name == "Autosomal dominant" ~ "Autosomal dominant inheritance", 
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
      hpo_mode_of_inheritance_term_name == "Y-linked" ~ "Y-linked inheritance")) %>%
    left_join(moi_list, by=c("hpo_mode_of_inheritance_term_name")) %>%
    select(disease_ontology_id, hgnc_id, disease_ontology_name, hpo_mode_of_inheritance_term) %>%
    arrange(disease_ontology_id, hgnc_id, disease_ontology_name, hpo_mode_of_inheritance_term) %>%
    group_by(disease_ontology_id) %>%
    mutate(n = 1) %>%
    mutate(count = n()) %>%
    mutate(version = cumsum(n)) %>%
    ungroup() %>%
    mutate(disease_ontology_id_version = case_when(count == 1 ~ disease_ontology_id, count >= 1 ~ paste0(disease_ontology_id, "_", version))) %>%
    mutate(disease_ontology_source = "morbidmap") %>%
    mutate(disease_ontology_date = omim_file_date) %>%
    mutate(disease_ontology_is_specific = TRUE) %>%
    select(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, disease_ontology_source, disease_ontology_date, disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term)

    # Define the file path for the CSV file
    csv_file_path <- paste0("results/ontology/genemap2_hgnc.", omim_file_date, ".csv")

    # Save the dataset as a CSV file
    write_csv(genemap2_hgnc, file = csv_file_path, na = "NULL")

    # Return the file path
    return(genemap2_hgnc)
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