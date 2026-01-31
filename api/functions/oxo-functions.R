# functions/oxo-functions.R

require(jsonlite) # For parsing JSON data
require(magrittr) # For using the pipe operator
require(dplyr) # For data manipulation
require(tidyr) # For converting data to tibble format
require(stringr) # For string manipulation

#' Retrieve mappings from an ontology ID using the OXO API.
#'
#' This function queries the OXO API to get mappings for a given ontology ID.
#' It includes retry logic for handling intermittent server errors.
#'
#' @param ontology_id The ontology ID for which to retrieve mappings.
#'
#' @return A tibble containing mappings for the given ontology ID, with columns
#'   for each ontology and their corresponding values.
#'
#' @examples
#' oxo_mapping_from_ontology_id("OMIM:100100")
#'
#' @export
oxo_mapping_from_ontology_id <- function(ontology_id) {
  url <- paste0("https://www.ebi.ac.uk/spot/oxo/api/mappings?fromId=", ontology_id)

  # Exponential backoff retry strategy for intermittent OXO API failures
  # Handles Neo4j connection issues on OXO backend (internal server errors)
  # Implements: max 5 retries, exponential backoff (0.2s, 0.4s, 0.8s, 1.6s, 3.2s)
  max_retries <- 5
  retry_count <- 0
  base_delay <- 0.2

  oxo_request <- tryCatch(fromJSON(url), error = function(e) {
    return(NA)
  })

  while (all(is.na(oxo_request)) && retry_count < max_retries) {
    retry_count <- retry_count + 1
    delay <- base_delay * (2^(retry_count - 1))
    message(sprintf("OXO API retry %d/%d after %.1fs delay", retry_count, max_retries, delay))
    Sys.sleep(delay)
    oxo_request <- tryCatch(fromJSON(url), error = function(e) {
      return(NA)
    })
  }

  # If still failed after retries, log and return NA
  if (all(is.na(oxo_request))) {
    warning(sprintf("OXO API failed after %d retries for ID: %s", max_retries, ontology_id))
  }

  oxo_request_tibble <- as_tibble(oxo_request$`_embedded`$mappings$fromTerm$curie)

  if (length(oxo_request_tibble) == 0) {
    mappings_from_omim_id <- NA
  } else {
    mappings_from_omim_id <- oxo_request_tibble %>%
      mutate(ontology = str_remove(value, pattern = ":.+")) %>%
      unique() %>%
      group_by(ontology) %>%
      arrange(value) %>%
      mutate(value = paste0(value, collapse = ";")) %>%
      unique() %>%
      ungroup() %>%
      arrange(ontology) %>%
      pivot_wider(names_from = ontology, values_from = value)
  }

  return(mappings_from_omim_id)
}
