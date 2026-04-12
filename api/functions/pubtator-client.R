# functions/pubtator-client.R
#### PubTator BioCJSON API client: rate limiting, URL construction, data fetching
#### Split from pubtator-functions.R (D3 refactor)

require(jsonlite)
require(logger)
log_threshold(INFO)

#------------------------------------------------------------------------------
# PubTator API Rate Limiting Configuration
# NCBI E-utilities rate limit: 3 req/s without API key, 10 req/s with key.
# Reference: https://www.ncbi.nlm.nih.gov/books/NBK25497/#chapter2.Usage_Guidelines_and_Requiremen
#------------------------------------------------------------------------------
PUBTATOR_RATE_LIMIT_DELAY <- 0.35 # seconds between requests (~2.86 req/s, under NCBI 3 req/s limit)
PUBTATOR_MAX_PMIDS_PER_REQUEST <- 100 # batch size for PMID fetches
PUBTATOR_MAX_RETRIES <- 3
PUBTATOR_BACKOFF_BASE <- 2 # exponential backoff base (seconds)

#' Execute API call with rate limiting and exponential backoff
#'
#' @param api_func Function to execute
#' @param ... Arguments to pass to api_func
#' @param max_retries Maximum retry attempts (default: PUBTATOR_MAX_RETRIES)
#' @return Result of api_func or NULL on failure
pubtator_rate_limited_call <- function(api_func, ..., max_retries = PUBTATOR_MAX_RETRIES) {
  retries <- 0
  while (retries <= max_retries) {
    tryCatch(
      {
        # Rate limiting delay before each request
        if (retries > 0) {
          backoff_time <- PUBTATOR_BACKOFF_BASE^retries + runif(1, 0, 1)
          log_info("Retry {retries}/{max_retries}, backing off {round(backoff_time, 1)}s...")
          Sys.sleep(backoff_time)
        }
        result <- api_func(...)
        Sys.sleep(PUBTATOR_RATE_LIMIT_DELAY) # Rate limit after successful call
        return(result)
      },
      error = function(e) {
        retries <<- retries + 1
        if (retries > max_retries) {
          log_error(skip_formatter(paste(
            "API call failed after", max_retries, "retries:", e$message
          )))
          return(NULL)
        }
        log_warn(skip_formatter(paste(
          "API call failed (attempt", retries, "):", e$message
        )))
      }
    )
  }
  return(NULL)
}

#------------------------------------------------------------------------------
# Retrieve Total Number of Pages from PubTator API v3
#------------------------------------------------------------------------------
#' Retrieve Total Number of Pages from PubTator API v3 for a Given Query
#'
#' This function contacts the PubTator API v3 and retrieves the total number of pages
#' of results available for a specific query. Useful for planning pagination.
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
#' @export
pubtator_v3_total_pages_from_query <- function(query,
                                               api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                               endpoint_search = "search/",
                                               query_parameter = "?text=") {
  url_search <- paste0(api_base_url, endpoint_search, query_parameter, query, "&page=1")
  log_info("Fetching total pages for query: {query} with URL: {url_search}")

  tryCatch(
    {
      response_search <- fromJSON(URLencode(url_search), flatten = TRUE)
      total_pages <- response_search$total_pages
      log_info("Successfully retrieved total_pages = {total_pages} for query: {query}")
      return(total_pages)
    },
    error = function(e) {
      warning_msg <- paste(
        "Failed to fetch the total pages for the query:",
        query, "Error:", e$message
      )
      log_warn(warning_msg)
      warning(warning_msg)
      return(NULL)
    }
  )
}

#------------------------------------------------------------------------------
# Fetch PMIDs and Associated Data from PubTator API v3
#------------------------------------------------------------------------------
#' Fetch PMIDs and Associated Data from PubTator API v3 Based on Query
#'
#' This function queries the PubTator v3 API to retrieve PubMed IDs (PMIDs) and
#' specific metadata columns (id, pmid, doi, title, journal, date, score, text_hl)
#' based on a given query string. It iterates through pages of results, starting
#' from a specified page, up to a maximum number of pages, handling pagination
#' and implementing retry logic.
#'
#' @param query Character: The search query string for PubTator.
#' @param start_page Numeric: The starting page number for the API response (pagination).
#' @param max_pages Numeric: Maximum number of pages to iterate through.
#' @param max_retries Numeric: Maximum number of retries if failure.
#' @param sort Character: The sorting parameter (e.g., "date desc").
#' @param api_base_url Character: Base URL of the PubTator API.
#' @param endpoint_search Character: API endpoint for the search query.
#' @param query_parameter Character: URL parameter for the search query.
#'
#' @return A tibble containing columns: id, pmid, doi, title, journal, date, score, text_hl (if present).
#'         Returns NULL if no records found.
#' @export
pubtator_v3_pmids_from_request <- function(query,
                                           start_page = 1,
                                           max_pages = 10,
                                           max_retries = 3,
                                           sort = "date desc",
                                           api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                           endpoint_search = "search/",
                                           query_parameter = "?text=",
                                           progress_fn = NULL) {
  log_info(
    "Starting to fetch PMIDs for query: {query}, from page {start_page} to {start_page + max_pages - 1}"
  )

  # Helper to report progress (safe no-op if no function provided)
  report_progress <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress_fn) && is.function(progress_fn)) {
      tryCatch(
        progress_fn(step, message, current = current, total = total),
        error = function(e) NULL
      )
    }
  }

  all_data <- tibble::tibble()
  end_page <- start_page + max_pages - 1

  for (page in start_page:end_page) {
    url_search <- paste0(
      api_base_url,
      endpoint_search,
      query_parameter,
      query,
      "&page=", page,
      "&sort=", sort
    )
    log_info("Fetching page {page} of PubTator results: {url_search}")

    retries <- 0
    success <- FALSE
    while (retries <= max_retries && !success) {
      tryCatch(
        {
          # Rate limiting: 2.5s between requests (~24 req/min, under 30/min limit)
          if (page > start_page || retries > 0) {
            delay <- if (retries > 0) {
              PUBTATOR_BACKOFF_BASE^retries + runif(1, 0, 1)
            } else {
              PUBTATOR_RATE_LIMIT_DELAY
            }
            log_info("Rate limiting: waiting {round(delay, 1)}s...")
            Sys.sleep(delay)
          }

          response_search <- jsonlite::fromJSON(URLencode(url_search), flatten = TRUE)

          page_data <- response_search$results %>%
            tibble::as_tibble() %>%
            dplyr::select(
              dplyr::any_of(c(
                "id",
                "pmid",
                "doi",
                "title",
                "journal",
                "date",
                "score",
                "text_hl"
              ))
            )

          all_data <- dplyr::bind_rows(all_data, page_data)
          log_info(
            "Page {page}/{end_page} fetched successfully; found {nrow(page_data)} records (total: {nrow(all_data)})."
          )
          success <- TRUE

          # Report progress for each page
          report_progress("fetch", sprintf("Fetched page %d/%d (%d publications)", page, end_page, nrow(all_data)),
                          current = page, total = end_page)

          if (page >= response_search$total_pages) {
            log_info("Reached the last available page {page} for query: {query}.")
            return(all_data) # Early return when all pages fetched
          }
        },
        error = function(e) {
          retries <<- retries + 1
          warning_msg <- paste(
            "Error fetching PMIDs at page", page,
            "Attempt:", retries, "/", max_retries,
            "Error:", e$message
          )
          log_warn(skip_formatter(warning_msg))

          if (retries > max_retries) {
            final_warning <- paste(
              "Failed to fetch PMIDs at page", page, "after",
              max_retries, "attempts."
            )
            log_warn(final_warning)
            warning(final_warning)
          }
        }
      )
    }
  }

  log_info(
    "Completed fetching PMIDs for query: {query}, total records = {nrow(all_data)}."
  )
  if (nrow(all_data) == 0) {
    return(NULL)
  } else {
    return(all_data)
  }
}


#------------------------------------------------------------------------------
# Fetch & Process Annotations Data from PubTator API v3 Based on PMIDs
#------------------------------------------------------------------------------
#' Fetch & Process Annotations Data from PubTator API v3 Based on PMIDs
#'
#' Given a list of PMIDs, fetch annotations via BioCJSON API.
#'
#' @param pmids Vector of PubMed IDs
#' @param max_pmids_per_request numeric
#' @param max_retries numeric
#' @param api_base_url ...
#' @param endpoint_annotations ...
#'
#' @return list of doc objects
#' @export
pubtator_v3_data_from_pmids <- function(pmids,
                                        max_pmids_per_request = 100,
                                        max_retries = 3,
                                        api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                        endpoint_annotations = "publications/export/biocjson") {
  if (is.null(pmids) || length(pmids) == 0) {
    log_info("No PMIDs supplied; returning NULL.")
    return(NULL)
  }

  log_info(
    "Fetching annotations for {length(pmids)} PMIDs in batches of {max_pmids_per_request}."
  )

  all_docs_df <- NULL
  pmid_groups <- split(pmids, ceiling(seq_along(pmids) / max_pmids_per_request))
  total_groups <- length(pmid_groups)

  for (group_idx in seq_along(pmid_groups)) {
    group <- pmid_groups[[group_idx]]
    url_annotations <- paste0(
      api_base_url, endpoint_annotations,
      "?pmids=", paste(group, collapse = ",")
    )
    log_info(
      "Fetching annotations batch {group_idx}/{total_groups} ({length(group)} PMIDs)..."
    )

    retries <- 0
    success <- FALSE
    while (retries <= max_retries && !success) {
      tryCatch(
        {
          # Rate limiting: delay between batches
          if (group_idx > 1 || retries > 0) {
            delay <- if (retries > 0) {
              PUBTATOR_BACKOFF_BASE^retries + runif(1, 0, 1)
            } else {
              PUBTATOR_RATE_LIMIT_DELAY
            }
            log_info("Rate limiting: waiting {round(delay, 1)}s...")
            Sys.sleep(delay)
          }

          batch_df <- pubtator_parse_biocjson(URLencode(url_annotations))

          if (!is.null(batch_df) && nrow(batch_df) > 0) {
            if (is.null(all_docs_df)) {
              all_docs_df <- batch_df
            } else {
              all_docs_df <- dplyr::bind_rows(all_docs_df, batch_df)
            }
          }

          success <- TRUE
          total_so_far <- if (is.null(all_docs_df)) 0L else nrow(all_docs_df)
          log_info(
            "Batch {group_idx}/{total_groups} complete. Total docs: {total_so_far}."
          )
        },
        error = function(e) {
          retries <<- retries + 1
          warning_msg <- paste(
            "Error fetching batch", group_idx,
            "Attempt:", retries, "/", max_retries,
            "Error:", e$message
          )
          log_warn(skip_formatter(warning_msg))

          if (retries > max_retries) {
            final_warn <- paste(
              "Failed to fetch data for PMIDs group after",
              max_retries, "attempts:", paste(group, collapse = ",")
            )
            log_warn(final_warn)
            warning(final_warn)
          } else {
            log_info("Retrying in 1 second...")
            Sys.sleep(1)
          }
        }
      )
    }
  }

  total_final <- if (is.null(all_docs_df)) 0L else nrow(all_docs_df)
  log_info("Completed fetching annotations for all PMIDs => doc count = {total_final}.")
  return(all_docs_df)
}
