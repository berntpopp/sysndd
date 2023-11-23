#### This file holds analyses functions for PubTator requests


#' Retrieve gene-related data from PubTator based on a given query
#'
#' This function makes a request to the PubTator API to find genes related to a specified query.
#' It constructs the request URL using parameters for API base URL, endpoint, and query formatting.
#' The function includes rate limiting to comply with the API's request frequency policy.
#'
#' @param query Character: The query string to be searched in PubTator.
#' @param page Numeric: The page number for the search results.
#' @param filter_type Character: The type of entity to be filtered from the results.
#'   Defaults to "Gene".
#' @param max_retries Numeric: The maximum number of retries for the API request.
#'   Defaults to 3.
#' @param api_base_url Character: The base URL of the PubTator API.
#'   Defaults to "https://www.ncbi.nlm.nih.gov/research/pubtator-api/publications/".
#' @param endpoint Character: The endpoint to be appended to the base URL for the API request.
#'   Defaults to "search/".
#' @param query_parameter Character: The parameter used in the query part of the URL.
#'   Defaults to "text=".
#' @param rate_limit Numeric: Time interval in seconds to wait between each API request.
#'   This parameter is used to control the frequency of API requests to comply with the PubTator API's rate limit, 
#'   which allows up to 3 requests per second. The default value is set to 0.35 seconds to adhere to this limit.
#'
#' @return A tibble containing the PubMed ID, text, text identifier, text part, source,
#'   and text part count for each entry matching the filter type. Returns NULL if no results found.
#'
#' @examples
#' genes <- pubtator_v2_genes_in_request(query = "BRCA1", page = 10)
#'
#' @export
pubtator_v2_genes_in_request <- function(query,
                                      page,
                                      max_retries = 3,
                                      api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator-api/publications/",
                                      endpoint = "search",
                                      query_parameter = "?q=",
                                      filter_type = "Gene",
                                      rate_limit = 0.35) {
  # define URL
  url <- paste0(api_base_url, endpoint, query_parameter, query, "&page=", page)
  retries <- 0

  # Error handling
  while(retries <= max_retries) {
    tryCatch({
      # Introduce delay for rate limiting
      Sys.sleep(rate_limit)

      # Attempt to get data
      search_request <- fromJSON(URLencode(url), flatten = TRUE)
      break

    }, error = function(e) {
      retries <- retries + 1
      if(retries <= max_retries) {
        warning(paste("Attempt", retries, "failed with error:", e$message, "Retrying..."))
      }
    })
  }

  # If max retries exhausted and still failed, throw an error
  if(retries > max_retries) {
    stop("Failed to fetch data after", max_retries, "attempts. Last error: ", e$message)
  }

  # Continue processing the data by extracting the results as a tibble
  search_results_tibble <- search_request$results %>%
    as_tibble()

  # filter out results with no accessions
  search_results_filtered <- search_results_tibble %>%
    {if (!("accessions" %in% colnames(.))) add_column(., accessions = "NULL") else .} %>%
    filter(accessions != "NULL")

  # if there are results, process them
  if (nrow(search_results_filtered) > 0) {
    search_results <- search_results_filtered %>%
      select(pmid, passages) %>%
      unnest(passages) %>%
      select(pmid, text_part = infons.type, annotations) %>%
      rowwise() %>%
      mutate(empty = is_empty(annotations)) %>%
      ungroup() %>%
      filter(annotations != "NULL" & !empty) %>%
      unnest(annotations, names_repair = "universal") %>%
      select(pmid, text_part, text, type = infons.type, text_identifier = infons.identifier) %>%
      unique() %>%
      filter(type == filter_type) %>%
      group_by(pmid, text, text_identifier) %>%
      summarise(text_part = paste(unique(text_part), collapse = " | "),
        source = paste(unique(type), collapse = " | "),
        text_part_count = n(),
        .groups = "keep") %>%
      ungroup()
  }
  return(search_results)
}


#' Determine the number of pages available for a PubTator query
#'
#' This function queries the PubTator API to determine the total number of pages of results
#' available for a given query.
#'
#' @param query Character: The query string to be searched in PubTator.
#' @param api_base_url Character: The base URL of the PubTator API.
#'   Defaults to "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/".
#' @param endpoint Character: The endpoint to be appended to the base URL for the API request.
#'   Defaults to "search/".
#' @param query_parameter Character: The parameter used in the query part of the URL.
#'   Defaults to "text=".
#'
#' @return Numeric: The total number of pages available for the given query.
#'
#' @examples
#' pages <- pubtator_pages_request(query = "BRCA1")
#'
#' @export
pubtator_pages_request <- function(query,
                                   api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                   endpoint = "search/",
                                   query_parameter = "?text=") {
  url <- paste0(api_base_url, endpoint, query_parameter, query, "&page=", 1)
  search_request <- fromJSON(URLencode(url), flatten = TRUE)

  return(search_request$total_pages)
}