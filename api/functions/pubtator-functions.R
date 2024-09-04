#### This file holds analyses functions for PubTator requests

require(tidyverse)
require(jsonlite)


#' Retrieve Total Number of Pages from PubTator API v3 for a Given Query
#'
#' This function contacts the PubTator API v3 and retrieves the total number of pages
#' of results available for a specific query. This is useful for understanding the scope
#' of the data set and planning pagination strategies when retrieving all data.
#'
#' @param query Character string containing the search query for PubTator.
#' @param api_base_url Character string containing the base URL of the PubTator API.
#'        Default is "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/".
#' @param endpoint_search Character string containing the API endpoint for searching.
#'        Default is "search/".
#' @param query_parameter Character string containing the URL parameter for the search query.
#'        Default is "?text=".
#'
#' @return Numeric value indicating the total number of pages available for the query.
#'         Returns NULL if the request fails.
#'
#' @examples
#' \dontrun{
#'   total_pages <- pubtator_v3_total_pages_from_query("BRCA1")
#' }
#'
#' @export
pubtator_v3_total_pages_from_query <- function(query, 
                                               api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/", 
                                               endpoint_search = "search/", 
                                               query_parameter = "?text=") {
  url_search <- paste0(api_base_url, endpoint_search, query_parameter, query, "&page=1")
  tryCatch({
    response_search <- fromJSON(URLencode(url_search), flatten = TRUE)
    return(response_search$total_pages)
  }, error = function(e) {
    warning("Failed to fetch the total pages for the query: ", query, " Error: ", e$message)
    return(NULL)
  })
}


#' Fetch PMIDs and Associated Data from PubTator API v3 Based on Query
#'
#' This function queries the PubTator v3 API to retrieve PubMed IDs (PMIDs) and associated metadata 
#' (title, journal, date, and score) based on a given query string. It iterates through pages of 
#' results, starting from a specified page, up to a maximum number of pages, handling pagination and 
#' implementing retry logic in case of request failures.
#'
#' @param query Character: The search query string for PubTator.
#' @param start_page Numeric: The starting page number for the API response (for pagination).
#' @param max_pages Numeric: Maximum number of pages to iterate through.
#' @param max_retries Numeric: Maximum number of retries for the API request in case of failure.
#' @param sort Character: The sorting parameter for the PubTator API (e.g., "date desc").
#' @param api_base_url Character: Base URL of the PubTator API.
#' @param endpoint_search Character: API endpoint for the search query.
#' @param query_parameter Character: URL parameter for the search query.
#'
#' @return A tibble containing PMIDs and associated metadata (title, journal, date, score) if found; 
#' NULL otherwise. Each row represents data associated with a specific PMID.
#' @export
pubtator_v3_pmids_from_request <- function(query, start_page = 1, max_pages = 10, max_retries = 3, 
                                           sort = "date desc",
                                           api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                           endpoint_search = "search/", query_parameter = "?text=") {
  all_data <- tibble()
  end_page <- start_page + max_pages - 1
  for (page in start_page:end_page) {
    url_search <- paste0(api_base_url, endpoint_search, query_parameter, query, "&page=", page, "&sort=", sort)
    retries <- 0
    while(retries <= max_retries) {
      tryCatch({
        response_search <- fromJSON(URLencode(url_search), flatten = TRUE)
        page_data <- response_search$results %>%
          as_tibble() %>%
          select(pmid, title, journal, date, score)

        all_data <- bind_rows(all_data, page_data)
        if (page >= response_search$total_pages) {
          break
        }
        break
      }, error = function(e) {
        retries <- retries + 1
        if (retries > max_retries) {
          warning(paste("Failed to fetch PMIDs at page", page, "after", max_retries, "attempts."))
          break
        }
      })
    }
  }
  return(all_data)
}


#' Fetch and Process Annotations Data from PubTator API v3 Based on PMIDs
#'
#' Given a list of PubMed IDs (PMIDs), this function fetches and processes annotations 
#' from the PubTator v3 API. It includes a retry mechanism for API requests.
#'
#' @param pmids Vector: List of PubMed IDs.
#' @param max_pmids_per_request Numeric: Maximum number of PMIDs per API request.
#' @param max_retries Numeric: Maximum number of retries for each API request in case of failure.
#' @param api_base_url Character: Base URL of the PubTator API.
#' @param endpoint_annotations Character: API endpoint for fetching annotations.
#'
#' @return A list containing the processed annotations data if PMIDs are found; NULL otherwise.
#' @export
pubtator_v3_data_from_pmids <- function(pmids, max_pmids_per_request = 100, max_retries = 3,
                                        api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                        endpoint_annotations = "publications/export/biocjson") {
  if (is.null(pmids) || length(pmids) == 0) {
    return(NULL)
  }

  split_pmids <- split(pmids, ceiling(seq_along(pmids) / max_pmids_per_request))
  all_annotations_data <- list()

  for (group in split_pmids) {
    url_annotations <- paste0(api_base_url, endpoint_annotations, "?pmids=", paste(group, collapse = ","))

    retries <- 0
    successful <- FALSE
    while(retries <= max_retries && !successful) {
      tryCatch({
        annotations_content <- readLines(URLencode(url_annotations))
        annotations_data <- pubtator_v3_parse_nonstandard_json(annotations_content)
        all_annotations_data <- c(all_annotations_data, annotations_data)
        successful <- TRUE
      }, error = function(e) {
        retries <- retries + 1
        if (retries > max_retries) {
          warning(paste("Failed to fetch data for PMIDs group after", max_retries, "attempts: ", paste(group, collapse = ", ")))
        } else {
          Sys.sleep(1) # Wait for 1 second before retrying
        }
      })
    }
  }

  return(all_annotations_data)
}


#' Parse Non-standard JSON Content
#'
#' This function is designed to parse non-standard JSON content, typically returned
#' from certain APIs. It restructures the content into valid JSON format and then parses it.
#'
#' @param json_content Character vector: The non-standard JSON content to be parsed.
#'
#' @return A list containing parsed JSON objects. If an error occurs during parsing,
#'   or if the input content is not in the expected format, NULL is returned.
#' @export
pubtator_v3_parse_nonstandard_json <- function(json_content) {
  tryCatch({
    # Check if json_content is not NULL or empty
    if (is.null(json_content) || length(json_content) == 0) {
      warning("json_content is NULL or empty.")
      return(NULL)
    }

    # Split the JSON content
    json_strings <- strsplit(paste(json_content, collapse = " "), "} ")[[1]]
    if (is.null(json_strings)) {
      warning("Failed to split JSON content.")
      return(NULL)
    }
    json_strings <- ifelse(grepl("}$", json_strings), json_strings, paste0(json_strings, "}"))

    # Add identifiers and reassemble into a valid JSON
    json_with_ids <- paste0('"', seq_along(json_strings), '":', json_strings, collapse = ", ")
    valid_json_string <- paste0("{", json_with_ids, "}")

    # Parse the valid JSON
    parsed_json <- fromJSON(valid_json_string)
    return(parsed_json)
  }, error = function(e) {
    warning("Error in parsing JSON content: ", e$message)
    return(NULL)
  })
}


#' Extract ID and Passages as Tibble
#'
#' This function takes parsed JSON data and extracts the 'id' and 'passages',
#' converting them into a tidyverse tibble. Annotations cells with empty lists are excluded.
#'
#' @param parsed_json The parsed JSON data from which to extract information.
#'
#' @return A tibble with columns 'id' and 'annotations'. Returns an empty tibble
#'   if the input is NULL, empty, or if an error occurs during processing, or if annotations are empty.
#'
#' @examples
#' # Assuming `json_data` is your JSON data
#' result <- pubtator_v3_extract_id_and_passages_as_tibble(json_data)
#'
#' @export
pubtator_v3_extract_id_and_passages_as_tibble <- function(parsed_json) {
  # Check if parsed_json is not NULL or empty
  if (is.null(parsed_json) || length(parsed_json) == 0) {
    warning("parsed_json is NULL or empty.")
    return(tibble())
  }

  # Safely extract data with error handling
  tryCatch({
    extracted_data <- lapply(parsed_json, function(x) {
      if ("id" %in% names(x) && "passages" %in% names(x) && length(x$passages) > 0) {
        list(id = x$id, passages = x$passages)
      } else {
        NULL
      }
    })

    # Convert the list to a tibble
    data_tibble <- tibble::enframe(extracted_data, name = NULL, value = "data") %>%
      tidyr::unnest_wider(data) %>%
      dplyr::select(id, passages) %>%
      tidyr::unnest(passages) %>%
      dplyr::select(id, annotations) %>%
      dplyr::filter(!is_empty(annotations))

    return(data_tibble)
  }, error = function(e) {
    warning("Error in extracting data: ", e$message)
    return(tibble())
  })
}


#' Process Annotations Data To Extract Gene Information
#'
#' This function processes annotations data to extract gene and species information,
#' with options for filtering by species and whether a gene name is in uppercase.
#'
#' @param annotations_data The annotations data to be processed.
#' @param filter_species A specific species to filter by (default is "9606").
#' @param filter_uppercase If TRUE, filters to include only gene names in uppercase.
#'
#' @return A tibble with columns 'id', 'gene_name', 'entrez_id', 'species_name',
#'   and 'gene_uppercase'. Returns NULL if an error occurs during processing.
#'
#' @examples
#' # Assuming `annotations_data` is your annotations data
#' results <- pubtator_v3_extract_gene_from_annotations(annotations_data)
#'
#' @export
pubtator_v3_extract_gene_from_annotations <- function(annotations_data, filter_species = "9606", filter_uppercase = TRUE) {
  tryCatch({
    # Extract annotations as a tibble
    annotations_extract <- pubtator_v3_extract_id_and_passages_as_tibble(annotations_data)

    # Process to get genes and species
    annotations_genes_species <- annotations_extract %>% 
      unnest_wider(annotations, names_repair = "check_unique", names_sep = "_") %>%
      select(id, annotations_infons) %>%
      unnest_wider(annotations_infons, names_repair = "check_unique", names_sep = "_") %>%
      select(id, annotations_infons_identifier, annotations_infons_type, annotations_infons_name) %>%
      unnest_longer(c(annotations_infons_identifier, annotations_infons_type, annotations_infons_name)) %>%
      filter(annotations_infons_type %in% c("Gene", "Species")) %>%
      unique()

    # Separate genes and species
    genes <- annotations_genes_species %>%
      filter(annotations_infons_type == "Gene") %>%
      select(id, gene_name = annotations_infons_name, entrez_id = annotations_infons_identifier) %>%
      mutate(gene_uppercase = grepl("^[A-Z0-9-]+$", gene_name),
             entrez_id = stringr::str_extract(entrez_id, "^[^;]+")) %>%
      filter(!stringr::str_detect(gene_name, "^[0-9]+$"))

    species <- annotations_genes_species %>%
      filter(annotations_infons_type == "Species") %>%
      select(id, species_name = annotations_infons_name)

    # Merge genes and species data frames by 'id' and rename 'id' to 'PMID'
    results <- genes %>%
      left_join(species, by = "id", relationship = "many-to-many") %>%
      rename(pmid = id)

    # Apply filters
    if (!is.null(filter_species)) {
      results <- results %>%
        filter(species_name == filter_species)
    }
    if (filter_uppercase) {
      results <- results %>%
        filter(gene_uppercase)
    }

    return(results)
  }, error = function(e) {
    warning("Error in processing annotations: ", e$message)
    return(NULL)
  })
}


# TODO: deprecate this function
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
#' The function includes an internal method `pubtator_v3_parse_nonstandard_json` to handle non-standard JSON 
#' format returned by the PubTator v3 API. This method corrects and parses the JSON data into a list 
#' of R objects. After fetching PMIDs based on the query, the function makes a second API call to 
#' retrieve annotations for these PMIDs. The annotations are then processed and returned as a list.
#'
#' @examples
#' request_data <- pubtator_v3_request(query = '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disorder" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)', page = 1)
#'
#' @export
pubtator_v3_request <- function(query,
                                         page,
                                         max_retries = 3,
                                         api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                         endpoint_search = "search/",
                                         endpoint_annotations = "publications/export/biocjson",
                                         query_parameter = "?text=") {

  # Custom function to parse non-standard JSON
  pubtator_v3_parse_nonstandard_json <- function(json_content) {
    # Split the JSON content
    json_strings <- strsplit(paste(json_content, collapse = " "), "} ")[[1]]
    json_strings <- ifelse(grepl("}$", json_strings), json_strings, paste0(json_strings, "}"))

    # Add identifiers and reassemble into a valid JSON
    json_with_ids <- paste0('"', seq_along(json_strings), '":', json_strings, collapse = ", ")
    valid_json_string <- paste0("{", json_with_ids, "}")

    # Parse the valid JSON
    parsed_json <- tryCatch(fromJSON(valid_json_string), error = function(e) NULL)

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
    annotations_data <- pubtator_v3_parse_nonstandard_json(annotations_content)

    # Process annotations data
    # ...
    # Extract the required data from annotations_data
    # Return the processed data
    return(annotations_data)
  } else {
    return(NULL)  # Return NULL if no PMIDs are found
  }
}


# TODO: make a function that paginates through the results and returns a summarized list of genes and their counts of PMIDs  
# TODO: deprecate this function
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
#' genes <- pubtator_v2_genes_in_request(query = '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)', page = 10)
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


# TODO: deprecate this function
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