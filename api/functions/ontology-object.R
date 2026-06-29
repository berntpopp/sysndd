# api/functions/ontology-object.R — ontology download/load helper extracted from ontology-functions.R (#470)

#' Download and Load an Ontology Based on Provided Parameters
#'
#' This function downloads an ontology file if it's older than a specified age
#' and then loads it into an ontology object. It supports Human Phenotype Ontology (HPO), # nolint: line_length_linter
#' Mammalian Phenotype Ontology (MPO), and MONDO.
#'
#' @param ontology_type A character string specifying the type of ontology ("hpo", "mpo", or "mondo").
#' @param config_vars List of configuration variables including the URL and file paths for each ontology type.
#' @param tags A character string specifying the type of tags to be extracted from the ontology ("minimal", "default", or "everything"). # nolint: line_length_linter
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
    stop("Invalid ontology type")
  )

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
