#### This file holds analyses functions for PubTator requests


#' Retrieve Gene-Related Data from PubTator API v3
#'
#' This function queries the PubTator v3 API to retrieve gene-related data based on a given query string.
#' It performs two main steps: firstly, it fetches the PubMed IDs (PMIDs) associated with the query;
#' secondly, it retrieves annotations for these PMIDs.
#'
#' @param query Character: The search query string for PubTator.
#' @param page Numeric: The page number for the API response (for pagination).
#' @param max_retries Numeric: Maximum number of retries for the API request in case of failure. 
#'   Defaults to 3.
#' @param api_base_url Character: Base URL of the PubTator API. 
#'   Defaults to "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/".
#' @param endpoint_search Character: API endpoint for the search query. 
#'   Defaults to "search/".
#' @param endpoint_annotations Character: API endpoint for fetching annotations. 
#'   Defaults to "publications/export/biocjson".
#' @param query_parameter Character: URL parameter for the search query. 
#'   Defaults to "?text=".
#'
#' @return A list containing the processed annotations data if PMIDs are found; NULL otherwise. 
#'   The function internally parses non-standard JSON data from the API response.
#'
#' @details
#' The function includes an internal method `parse_nonstandard_json` to handle non-standard JSON 
#' format returned by the PubTator v3 API. This method corrects and parses the JSON data into a list 
#' of R objects. After fetching PMIDs based on the query, the function makes a second API call to 
#' retrieve annotations for these PMIDs. The annotations are then processed and returned as a list.
#'
#' @examples
#' genes_data <- pubtator_v3_genes_in_request(query = "BRCA1", page = 1)
#'
#' @export
pubtator_v3_genes_in_request <- function(query,
                                         page,
                                         max_retries = 3,
                                         api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                         endpoint_search = "search/",
                                         endpoint_annotations = "publications/export/biocjson",
                                         query_parameter = "?text=") {
  
  # Custom function to parse non-standard JSON
  parse_nonstandard_json <- function(json_content) {
    json_strings <- strsplit(paste(json_content, collapse = " "), "} ")[[1]]
    json_strings <- ifelse(grepl("}$", json_strings), json_strings, paste0(json_strings, "}"))
    parsed_json <- lapply(json_strings, function(x) tryCatch(fromJSON(x), error = function(e) NULL))
    return(parsed_json)
  }

  # Define URL for search
  url_search <- paste0(api_base_url, endpoint_search, query_parameter, query, "&page=", page)
  retries <- 0
  pmids <- NULL

  # Fetch PMIDs
  while(retries <= max_retries && is.null(pmids)) {
    tryCatch({
      response_search <- fromJSON(URLencode(url_search), flatten = TRUE)
      pmids <- response_search$results %>%
        as_tibble() %>%
        pull(pmid)
      break
    }, error = function(e) {
      retries <- retries + 1
      if(retries <= max_retries) {
        warning(paste("Attempt", retries, "failed. Retrying..."))
      }
    })
  }

  if(retries > max_retries) {
    stop("Failed to fetch PMIDs after", max_retries, "attempts.")
  }

  # Fetch and Process Annotations
  if (!is.null(pmids) && length(pmids) > 0) {
    url_annotations <- paste0(api_base_url, endpoint_annotations, "?pmids=", paste(pmids, collapse = ","))
    annotations_content <- readLines(URLencode(url_annotations))
    annotations_data <- parse_nonstandard_json(annotations_content)

    # Process annotations data
    # ...
    # Extract the required data from annotations_data
    # Return the processed data
  } else {
    return(NULL)  # Return NULL if no PMIDs are found
  }
}


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