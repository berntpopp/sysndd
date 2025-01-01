# functions/pubtator-functions.R
#### This file holds analysis functions for PubTator requests

require(tidyverse)
require(jsonlite)
require(logger)

# Set the logging threshold (optional).
# For more advanced configurations, see the logger documentation.
# e.g.: log_threshold(INFO)
log_threshold(INFO)

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
#' @export
pubtator_v3_total_pages_from_query <- function(query,
                                               api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                               endpoint_search = "search/",
                                               query_parameter = "?text=") {
  url_search <- paste0(api_base_url, endpoint_search, query_parameter, query, "&page=1")
  log_info("Fetching total pages for query: {query} with URL: {url_search}")

  tryCatch({
    response_search <- fromJSON(URLencode(url_search), flatten = TRUE)
    total_pages <- response_search$total_pages
    log_info("Successfully retrieved total_pages = {total_pages} for query: {query}")
    return(total_pages)
  }, error = function(e) {
    warning_msg <- paste(
      "Failed to fetch the total pages for the query:",
      query, "Error:", e$message
    )
    log_warn(warning_msg)
    warning(warning_msg)
    return(NULL)
  })
}

#' Fetch PMIDs and Associated Data from PubTator API v3 Based on Query
#'
#' This function queries the PubTator v3 API to retrieve PubMed IDs (PMIDs) and
#' associated metadata (title, journal, date, score, doi, etc.) based on a given query string.
#' It iterates through pages of results, starting from a specified page, up to a
#' maximum number of pages, handling pagination and implementing retry logic.
#'
#' @param query Character: The search query string for PubTator.
#' @param start_page Numeric: The starting page number for the API response (pagination).
#' @param max_pages Numeric: Maximum number of pages to iterate through.
#' @param max_retries Numeric: Maximum number of retries for the API request if failure.
#' @param sort Character: The sorting parameter for the PubTator API (e.g., "date desc").
#' @param api_base_url Character: Base URL of the PubTator API.
#' @param endpoint_search Character: API endpoint for the search query.
#' @param query_parameter Character: URL parameter for the search query.
#'
#' @return A tibble containing PMIDs and associated metadata (pmid, title, journal,
#'   date, score, doi, etc.) if found; NULL otherwise.
#' @export
pubtator_v3_pmids_from_request <- function(query,
                                           start_page = 1,
                                           max_pages = 10,
                                           max_retries = 3,
                                           sort = "date desc",
                                           api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                           endpoint_search = "search/",
                                           query_parameter = "?text=") {
  log_info(
    "Starting to fetch PMIDs for query: {query}, from page {start_page} to {start_page + max_pages - 1}"
  )

  all_data <- tibble()
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
    while (retries <= max_retries) {
      tryCatch({
        response_search <- jsonlite::fromJSON(URLencode(url_search), flatten = TRUE)

        # Convert the 'results' to a tibble. Then select the columns you want.
        # If the API actually includes a column named 'doi', it will appear here.
        # We select pmid, title, journal, date, doi, score, and then optionally
        # any other columns (via 'everything()') if you want to keep them all.
        page_data <- response_search$results %>%
          tibble::as_tibble() %>%
          dplyr::select(
            pmid,
            title,
            journal,
            date,
            score,
            doi,
            dplyr::everything()  # <- comment this out if you only want the named columns
          )

        all_data <- dplyr::bind_rows(all_data, page_data)
        log_info(
          "Page {page} fetched successfully; found {nrow(page_data)} records."
        )

        # If we've reached the last available page, stop.
        if (page >= response_search$total_pages) {
          log_info("Reached the last available page {page} for query: {query}.")
          break
        }
        break

      }, error = function(e) {
        retries <- retries + 1
        warning_msg <- paste(
          "Error fetching PMIDs at page", page,
          "Attempt:", retries, "/", max_retries,
          "Error:", e$message
        )
        log_warn(warning_msg)

        if (retries > max_retries) {
          final_warning <- paste(
            "Failed to fetch PMIDs at page", page, "after",
            max_retries, "attempts."
          )
          log_warn(final_warning)
          warning(final_warning)
          break
        }
      })
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

#' Fetch and Process Annotations Data from PubTator API v3 Based on PMIDs
#'
#' Given a list of PubMed IDs (PMIDs), this function fetches and processes
#' annotations from the PubTator v3 API. It includes a retry mechanism and uses
#' reassemble_pubtator_docs to flatten top-level keys (e.g., "PubTator3").
#'
#' @param pmids Vector: List of PubMed IDs.
#' @param max_pmids_per_request Numeric: Max number of PMIDs per API request.
#' @param max_retries Numeric: Max number of retries for each request.
#' @param api_base_url Character: Base URL of the PubTator API.
#' @param endpoint_annotations Character: Endpoint for fetching annotations.
#'
#' @return A list of doc objects, each with "id" and "passages".
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

  all_documents <- list()
  pmid_groups <- split(pmids, ceiling(seq_along(pmids) / max_pmids_per_request))

  for (group in pmid_groups) {
    url_annotations <- paste0(
      api_base_url, endpoint_annotations,
      "?pmids=", paste(group, collapse = ",")
    )
    log_info(
      "Fetching annotations for PMIDs: {paste(group, collapse=', ')} with URL: {url_annotations}"
    )

    retries <- 0
    success <- FALSE
    while (retries <= max_retries && !success) {
      tryCatch({
        # suppress "incomplete final line" warning
        annotations_content <- suppressWarnings(
          readLines(URLencode(url_annotations))
        )
        parsed_json <- pubtator_v3_parse_nonstandard_json(annotations_content)

        docs <- reassemble_pubtator_docs(parsed_json)
        all_documents <- c(all_documents, docs)

        success <- TRUE
        log_info(
          "Successfully fetched data for {length(group)} PMIDs. " %+%
          "Total doc count so far: {length(all_documents)}."
        )
      }, error = function(e) {
        retries <- retries + 1
        warning_msg <- paste(
          "Error fetching data for PMIDs:", paste(group, collapse = ","),
          "Attempt:", retries, "/", max_retries,
          "Error:", e$message
        )
        log_warn(warning_msg)

        if (retries > max_retries) {
          final_warn <- paste(
            "Failed to fetch data for PMIDs group after",
            max_retries, "attempts:", paste(group, collapse = ", ")
          )
          log_warn(final_warn)
          warning(final_warn)
        } else {
          log_info("Retrying in 1 second...")
          Sys.sleep(1)
        }
      })
    }
  }

  log_info(
    "Completed fetching annotations for all PMIDs. Final doc count = {length(all_documents)}."
  )
  return(all_documents)
}

#' Reassemble (flatten) the PubTator-Parsed JSON into a list of doc objects
#'
#' If top-level is "PubTator3", we take doc objects from there. Otherwise, we look
#' for numeric keys. Each doc object has an 'id' (copied from '_id' if needed) and
#' 'passages', optionally 'relations', etc.
#'
#' @param parsed_json The object from pubtator_v3_parse_nonstandard_json
#' @return A list of doc objects, each with an 'id' and 'passages'
#' @export
reassemble_pubtator_docs <- function(parsed_json) {
  if (is.null(parsed_json) || length(parsed_json) == 0) {
    return(list())
  }

  # If top-level is "PubTator3"
  if ("PubTator3" %in% names(parsed_json)) {
    docs <- parsed_json[["PubTator3"]]
    docs_fixed <- lapply(docs, fix_doc_id)
    return(docs_fixed)
  }

  # Otherwise, we might have numeric keys like "1", "2", ...
  result <- list()
  for (key in names(parsed_json)) {
    sub_item <- parsed_json[[key]]
    if (!is.null(sub_item) && "PubTator3" %in% names(sub_item)) {
      docs <- sub_item[["PubTator3"]]
      docs_fixed <- lapply(docs, fix_doc_id)
      result <- c(result, docs_fixed)
    } else {
      # single doc
      doc_fixed <- fix_doc_id(sub_item)
      result <- c(result, list(doc_fixed))
    }
  }
  return(result)
}

#' Ensure a single doc has an 'id'
#'
#' If doc has '_id' but not 'id', copy '_id' => 'id'
#'
#' @param doc A doc object from PubTator
#' @return The same doc, guaranteed to have doc$id
#' @export
fix_doc_id <- function(doc) {
  if (is.null(doc)) {
    return(list())
  }
  if (!"id" %in% names(doc) && "_id" %in% names(doc)) {
    doc$id <- doc$`_id`
  }
  doc
}

#' Parse Non-standard JSON Content
#'
#' Restructures non-standard JSON into valid JSON, then parses it.
#'
#' @param json_content Character vector of lines from the API response.
#' @return Parsed JSON object (list). NULL if error.
#' @export
pubtator_v3_parse_nonstandard_json <- function(json_content) {
  tryCatch({
    if (is.null(json_content) || length(json_content) == 0) {
      log_warn("pubtator_v3_parse_nonstandard_json received NULL or empty json_content.")
      return(NULL)
    }

    # Combine, split by "} "
    json_strings <- strsplit(paste(json_content, collapse = " "), "} ")[[1]]
    if (is.null(json_strings)) {
      log_warn("Failed to split JSON content.")
      return(NULL)
    }
    json_strings <- ifelse(grepl("}$", json_strings), json_strings,
                           paste0(json_strings, "}"))

    # Reassemble into valid JSON
    json_with_ids <- paste0('"', seq_along(json_strings), '":', json_strings,
                            collapse = ", ")
    valid_json_string <- paste0("{", json_with_ids, "}")

    parsed_json <- fromJSON(valid_json_string)
    return(parsed_json)
  }, error = function(e) {
    warning_msg <- paste(
      "Error in parsing JSON content:", e$message
    )
    log_warn(warning_msg)
    warning(warning_msg)
    return(NULL)
  })
}

#' Flatten a PubTator object (returned by pubtator_v3_data_from_pmids) => row per annotation
#'
#' This function builds (pmid, annotations) pairs from your doc objects, then
#' flattens each annotation row by row, expanding infons columns to top-level.
#' It removes the 'locations' column, keeps 'text', and renames 'infons.identifier'
#' etc. => 'identifier', etc.
#'
#' @param master_obj The nested object from pubtator_v3_data_from_pmids().
#' @return A tibble with columns: pmid, id, text, type, identifier, ...
#' @export
flatten_pubtator_passages <- function(master_obj) {
  # Step A: create (pmid, annotations)
  base_tib <- build_pmid_annotations_table(master_obj)
  log_info("base_tib has {nrow(base_tib)} rows. Now flatten each row's annotation DF...")

  if (nrow(base_tib) == 0) {
    log_warn("No rows in base_tib => returning empty tibble.")
    return(base_tib)
  }

  # Step B: unify each row's `annotations` => flatten
  base_tib2 <- base_tib %>%
    mutate(
      annotations = purrr::map2(annotations, dplyr::row_number(), function(ann_list, row_i) {
        if (!is.data.frame(ann_list) || nrow(ann_list) == 0) {
          log_info("Row {row_i}: annotation list is not a DF or empty => returning empty tibble.")
          return(tibble())
        }
        log_info("Row {row_i}: annotation DF => {nrow(ann_list)} rows, {ncol(ann_list)} cols.")
        log_info("Structure of ann_list:\n{paste(capture.output(str(ann_list)), collapse='\n')}")

        out_list <- vector("list", nrow(ann_list))
        for (i in seq_len(nrow(ann_list))) {
          single_row <- ann_list[i, , drop = FALSE]
          out_list[[i]] <- flatten_annotation_row(single_row)
        }
        ann_list_char <- dplyr::bind_rows(out_list)
        ann_list_char
      })
    )

  log_info("Done normalizing each row's annotation DF. Now unnest => expand each annotation as a row.")

  # Step C: unnest => each annotation row is expanded
  result <- base_tib2 %>%
    tidyr::unnest(annotations, keep_empty = TRUE) %>%
    # remove only "locations" column, keep "text"
    dplyr::select(-dplyr::any_of(c("locations"))) %>%
    # rename columns that start with "infons." => remove that prefix
    dplyr::rename_with(~ gsub("^infons\\.", "", .x), dplyr::starts_with("infons."))

  log_info(
    "Flatten complete. {nrow(result)} rows, columns: {paste(names(result), collapse=', ')}"
  )
  return(result)
}

#' Build (pmid, annotations) dropping passage_index, row_index, passage_type
build_pmid_annotations_table <- function(master_obj) {
  if (!is.list(master_obj)) {
    log_warn("master_obj is not a list => returning empty tibble.")
    return(tibble(pmid=character(), annotations=list()))
  }
  if (!all(c("id","passages") %in% names(master_obj))) {
    log_warn("master_obj missing 'id' or 'passages' => returning empty tibble.")
    return(tibble(pmid=character(), annotations=list()))
  }

  pmids_vec <- master_obj$id
  pass_list <- master_obj$passages
  if (!is.vector(pmids_vec) || !is.list(pass_list) || length(pmids_vec)!=length(pass_list)) {
    log_warn("length mismatch => returning empty tibble.")
    return(tibble(pmid=character(), annotations=list()))
  }

  all_rows <- list()
  for (i in seq_along(pmids_vec)) {
    pmid_str <- as.character(pmids_vec[i])
    pass_df  <- pass_list[[i]]
    if (!is.data.frame(pass_df)) {
      log_warn("passages[[{i}]] is not data.frame => skipping.")
      next
    }
    for (row_i in seq_len(nrow(pass_df))) {
      ann_list <- NULL
      if ("annotations" %in% names(pass_df)) {
        ann_list <- pass_df$annotations[[row_i]]
      }
      row_obj <- list(
        pmid=pmid_str,
        annotations=list(ann_list %||% list())
      )
      all_rows <- append(all_rows, list(row_obj))
    }
  }

  if (length(all_rows)==0) {
    return(tibble(pmid=character(), annotations=list()))
  }
  tib_out <- dplyr::bind_rows(all_rows)
  return(tib_out)
}

#' Flatten a single annotation row:
#'   - If 'infons' is a data frame with 1 row, expand each column => infons.xyz
#'   - Else store 'infons' as JSON
#'   - Convert numeric or sub-df columns (e.g. 'locations') to JSON
flatten_annotation_row <- function(one_annot) {
  stopifnot(nrow(one_annot) == 1)

  log_info("flatten_annotation_row: columns: {paste(names(one_annot), collapse=', ')}")

  if ("infons" %in% names(one_annot)) {
    infons_val <- one_annot[["infons"]]
    if (is.data.frame(infons_val) && nrow(infons_val) == 1) {
      # expand each column => infons.xyz
      for (cn in names(infons_val)) {
        infons_val[[cn]] <- as.character(infons_val[[cn]])
      }
      names(infons_val) <- paste0("infons.", names(infons_val))
      one_annot[["infons"]] <- NULL
      one_annot <- cbind(one_annot, infons_val)
    } else {
      # fallback to JSON
      one_annot[["infons"]] <- safe_as_json(infons_val)
    }
  }

  # unify everything else
  for (colname in names(one_annot)) {
    colval <- one_annot[[colname]][[1]]
    if (is.null(colval)) {
      one_annot[[colname]] <- ""
    } else if (is.atomic(colval)) {
      one_annot[[colname]] <- as.character(colval)
    } else if (is.data.frame(colval)) {
      one_annot[[colname]] <- safe_as_json(colval)
    } else if (is.list(colval)) {
      one_annot[[colname]] <- safe_as_json(colval)
    } else {
      one_annot[[colname]] <- as.character(colval)
    }
  }

  # ensure entire row is character
  for (cn in names(one_annot)) {
    one_annot[[cn]] <- as.character(one_annot[[cn]])
  }
  out <- tibble::as_tibble(one_annot)
  return(out)
}

#' Convert object to JSON (or fallback to as.character)
safe_as_json <- function(x) {
  if (is.null(x)) return("")
  if (is.atomic(x) && length(x)==1) {
    return(as.character(x))
  }
  out <- tryCatch({
    jsonlite::toJSON(x, auto_unbox=TRUE)
  }, error=function(e){
    as.character(x)
  })
  return(out)
}
