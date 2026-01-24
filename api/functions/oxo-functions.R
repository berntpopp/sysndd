# functions/oxo-functions.R

require(jsonlite)  # For parsing JSON data
require(magrittr)  # For using the pipe operator
require(dplyr)     # For data manipulation
require(tidyr)     # For converting data to tibble format
require(stringr)   # For string manipulation

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
oxo_mapping_from_ontology_id <- function(ontology_id)  {

  url <- paste0("https://www.ebi.ac.uk/spot/oxo/api/mappings?fromId=", ontology_id)

  # Retry logic for intermittent OXO API failures
  # Implemented April 2023 due to internal server errors (500)
  # Neo4j connection issues on OXO backend
  # TODO(future): Implement exponential backoff retry strategy
  # Current: fixed 0.2s delay, infinite retries
  # Enhancement: max_retries parameter, exponential backoff (0.2s, 0.4s, 0.8s, 1.6s)
  # based on https://stackoverflow.com/questions/66133261/how-to-make-a-new-request-while-there-is-an-error-fromjson
  oxo_request <- tryCatch(fromJSON(url), error = function(e) {return(NA)})

  while(all(is.na(oxo_request))) {
    Sys.sleep(0.2) #Change as per requirement. 
    oxo_request <- tryCatch(fromJSON(url), error = function(e) {return(NA)})
  }

  oxo_request_tibble <- as_tibble(oxo_request$`_embedded`$mappings$fromTerm$curie)

  if(length(oxo_request_tibble) == 0){
    mappings_from_omim_id <- NA
  } else {
    mappings_from_omim_id <- oxo_request_tibble%>%
      mutate(ontology =  str_remove(value, pattern = ":.+")) %>%
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