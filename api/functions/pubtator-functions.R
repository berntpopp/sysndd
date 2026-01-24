# functions/pubtator-functions.R
#### This file holds analysis functions for PubTator requests
#### Includes transaction handling (rollback) & storing both total_page_number & queried_page_number.

require(tidyverse)
require(jsonlite)
require(logger)
require(DBI)
require(digest) # for hashing
log_threshold(INFO)

# Load database helper functions for repository layer access (if not already loaded)
if (!exists("db_execute_query", mode = "function")) {
  if (file.exists("functions/db-helpers.R")) {
    source("functions/db-helpers.R", local = TRUE)
  }
}

#------------------------------------------------------------------------------
# 1) Retrieve Total Number of Pages from PubTator API v3
#   (unchanged from old code)
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
# 2) generate_query_hash
#   (unchanged logic, just a helper to hash the query)
#------------------------------------------------------------------------------
generate_query_hash <- function(query_string) {
  q_squish <- stringr::str_squish(query_string)
  q_hash <- digest::digest(q_squish, algo = "sha256", serialize = FALSE)
  return(q_hash)
}

#------------------------------------------------------------------------------
# 3) MASTER FUNCTION: pubtator_db_update
#   - wraps DB writes in a transaction
#   - stores total_page_number and queried_page_number
#   - does rollback on error
#------------------------------------------------------------------------------
#' Store PubTator search & annotation results in DB (transaction + rollback on errors)
#'
#' @param db_host,db_port,db_name,db_user,db_password  Connection params
#' @param query          The PubTator query string
#' @param max_pages      Max pages to actually fetch (queried_page_number)
#' @param do_full_update If TRUE, purge old data for that query_hash
#'
#' @return The `query_id` used in the DB, or NULL on error
#' @export
pubtator_db_update <- function(
  db_host,
  db_port,
  db_name,
  db_user,
  db_password,
  query,
  max_pages = 10,
  do_full_update = FALSE
) {
  # A) Retrieve total_pages BEFORE transaction (no DB write needed)
  total_pages <- pubtator_v3_total_pages_from_query(query)
  if (is.null(total_pages) || total_pages == 0) {
    log_warn("No pages found for query: {query}. Aborting.")
    return(NULL) # Early return - no DB operations started
  }

  if (max_pages > total_pages) {
    log_info("max_pages={max_pages} > total_pages={total_pages}, adjusting.")
    max_pages <- total_pages
  }

  # B) Query hash
  q_hash <- generate_query_hash(query)
  log_info("Query hash = {q_hash}")

  # C) Wrap ALL database operations in a single transaction
  result <- tryCatch(
    {
      db_with_transaction({
        # Check if query exists
        existing_query <- db_execute_query(
          "SELECT query_id, queried_page_number, total_page_number, page_size
         FROM pubtator_query_cache WHERE query_hash = ?",
          list(q_hash)
        )

        query_id <- NA_integer_
        old_queried_number <- 0

        if (nrow(existing_query) == 0) {
          # Insert new row
          log_info("No record for query_hash={q_hash}, inserting new row.")
          db_execute_statement(
            "INSERT INTO pubtator_query_cache
            (query_text, query_hash, total_page_number, queried_page_number, page_size)
           VALUES (?, ?, ?, ?, ?)",
            list(query, q_hash, total_pages, max_pages, 10)
          )
          query_id <- db_execute_query("SELECT LAST_INSERT_ID() AS id")$id[1]
        } else {
          # Found existing row
          query_id <- existing_query$query_id[1]
          old_queried_number <- existing_query$queried_page_number[1]
          old_total_number <- existing_query$total_page_number[1]

          log_info("Found existing query_id={query_id}, old_queried_number={old_queried_number}")

          if (do_full_update) {
            log_info("do_full_update=TRUE => removing old records.")
            db_execute_statement(
              "DELETE FROM pubtator_search_cache WHERE query_id = ?",
              list(query_id)
            )
            db_execute_statement(
              "DELETE a FROM pubtator_annotation_cache a
             JOIN pubtator_search_cache s ON a.search_id = s.search_id
             WHERE s.query_id = ?",
              list(query_id)
            )
            db_execute_statement(
              "UPDATE pubtator_query_cache
             SET total_page_number=?, queried_page_number=?, page_size=?
             WHERE query_id=?",
              list(total_pages, max_pages, 10, query_id)
            )
            old_queried_number <- 0
          } else {
            # Partial update check
            if (max_pages <= old_queried_number) {
              log_info("Already up to page={old_queried_number}, no new fetch needed.")
              # Return query_id - transaction will auto-commit
              return(query_id) # Early return WITH commit
            }
            log_info("Partial update: old_queried_number={old_queried_number}, new max_pages={max_pages}")
          }
        }

        # D) Fetch new pages
        start_page <- if (!do_full_update && nrow(existing_query) > 0) {
          existing_query$queried_page_number[1] + 1
        } else {
          1
        }

        if (start_page <= max_pages) {
          df_results <- pubtator_v3_pmids_from_request(
            query = query, start_page = start_page,
            max_pages = (max_pages - start_page + 1)
          )

          if (!is.null(df_results) && nrow(df_results) > 0) {
            log_info("Inserting {nrow(df_results)} rows => pubtator_search_cache")

            df_insert <- df_results %>%
              mutate(
                query_id = query_id,
                id = if (!"id" %in% names(.)) NA_character_ else id,
                date = if ("date" %in% names(.)) sub("T.*", "", date) else NA_character_
              ) %>%
              select(query_id, id, pmid, doi, title, journal, date, score, text_hl)

            for (r in seq_len(nrow(df_insert))) {
              db_execute_statement(
                "INSERT INTO pubtator_search_cache
                (query_id, id, pmid, doi, title, journal, date, score, text_hl)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                unname(as.list(df_insert[r, ]))
              )
            }

            db_execute_statement(
              "UPDATE pubtator_query_cache
             SET queried_page_number=?, total_page_number=? WHERE query_id=?",
              list(max_pages, total_pages, query_id)
            )
          }
        }

        # E) Gather PMIDs and fetch annotations
        pmid_rows <- db_execute_query(
          "SELECT pmid FROM pubtator_search_cache
         WHERE query_id=? AND pmid IS NOT NULL GROUP BY pmid",
          list(query_id)
        )

        if (nrow(pmid_rows) == 0) {
          log_info("No PMIDs in search_cache => skip annotation fetch.")
          return(query_id) # Early return WITH commit
        }

        pmid_vector <- pmid_rows$pmid
        log_info("Found {length(pmid_vector)} PMIDs => fetching annotations...")

        # F) Fetch and insert annotations
        doc_list <- pubtator_v3_data_from_pmids(pmid_vector)
        if (is.null(doc_list) || length(doc_list) == 0) {
          log_warn("No annotation data => skipping annotation_cache insert.")
          return(query_id) # Early return WITH commit
        }

        flat_df <- flatten_pubtator_passages(doc_list) %>%
          mutate(pmid = as.integer(pmid))

        srch_map <- db_execute_query(
          "SELECT search_id, pmid FROM pubtator_search_cache WHERE query_id=?",
          list(query_id)
        )

        flat_df_j <- flat_df %>%
          left_join(srch_map, by = "pmid", relationship = "many-to-many")

        log_info("Inserting {nrow(flat_df_j)} annotation rows")

        df_ann <- flat_df_j %>%
          mutate(valid = if_else(valid == "TRUE", 1, 0, missing = 0)) %>%
          select(
            search_id, pmid, id, text, identifier, type, ncbi_homologene,
            valid, normalized, `database`, normalized_id, biotype, name, accession
          )

        for (r in seq_len(nrow(df_ann))) {
          db_execute_statement(
            "INSERT INTO pubtator_annotation_cache
            (search_id, pmid, id, text, identifier, type, ncbi_homologene, valid,
             normalized, `database`, normalized_id, biotype, name, accession)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            unname(as.list(df_ann[r, ]))
          )
        }

        log_info("All done => returning query_id={query_id}")
        query_id # Return value - transaction auto-commits
      })
    },
    error = function(e) {
      # Transaction auto-rolled back by db_with_transaction
      log_error("pubtator_db_update: Error => {e$message}")
      return(NULL)
    }
  )

  return(result)
}


#------------------------------------------------------------------------------
# 4) pubtator_v3_pmids_from_request
#   (same logic as before, just ensuring columns: id, pmid, doi, etc.)
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
                                           query_parameter = "?text=") {
  log_info(
    "Starting to fetch PMIDs for query: {query}, from page {start_page} to {start_page + max_pages - 1}"
  )

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
    while (retries <= max_retries) {
      tryCatch(
        {
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
            "Page {page} fetched successfully; found {nrow(page_data)} records."
          )

          if (page >= response_search$total_pages) {
            log_info("Reached the last available page {page} for query: {query}.")
            break
          }
          break
        },
        error = function(e) {
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
# 5) pubtator_v3_data_from_pmids
#------------------------------------------------------------------------------
#' Fetch & Process Annotations Data from PubTator API v3 Based on PMIDs
#'
#' Given a list of PMIDs, fetch annotations via pubtator_v3_parse_nonstandard_json.
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

  all_documents <- list()
  pmid_groups <- split(pmids, ceiling(seq_along(pmids) / max_pmids_per_request))

  for (group in pmid_groups) {
    url_annotations <- paste0(
      api_base_url, endpoint_annotations,
      "?pmids=", paste(group, collapse = ",")
    )
    log_info("Fetching annotations for PMIDs: {paste(group, collapse=', ')} => {url_annotations}")

    retries <- 0
    success <- FALSE
    while (retries <= max_retries && !success) {
      tryCatch(
        {
          annotations_content <- suppressWarnings(
            readLines(URLencode(url_annotations))
          )
          parsed_json <- pubtator_v3_parse_nonstandard_json(annotations_content)

          docs <- reassemble_pubtator_docs(parsed_json)
          all_documents <- c(all_documents, docs)

          success <- TRUE
          log_info(
            "Successfully fetched data for {length(group)} PMIDs. doc count so far: {length(all_documents)}."
          )
        },
        error = function(e) {
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

  log_info("Completed fetching annotations for all PMIDs => doc count = {length(all_documents)}.")
  return(all_documents)
}

#------------------------------------------------------------------------------
# 6) reassemble_pubtator_docs
#------------------------------------------------------------------------------
#' Reassemble (flatten) the PubTator-Parsed JSON into a list of doc objects
#'
#' If top-level is "PubTator3", take doc objects from there. Otherwise, loop over numeric keys.
#' Each doc has 'id' (copied from '_id' if needed) + 'passages'.
#'
#' @param parsed_json from pubtator_v3_parse_nonstandard_json
#' @return list of doc objects
#' @export
reassemble_pubtator_docs <- function(parsed_json) {
  if (is.null(parsed_json) || length(parsed_json) == 0) {
    return(list())
  }
  if ("PubTator3" %in% names(parsed_json)) {
    docs <- parsed_json[["PubTator3"]]
    docs_fixed <- lapply(docs, fix_doc_id)
    return(docs_fixed)
  }
  result <- list()
  for (key in names(parsed_json)) {
    sub_item <- parsed_json[[key]]
    if (!is.null(sub_item) && "PubTator3" %in% names(sub_item)) {
      docs <- sub_item[["PubTator3"]]
      docs_fixed <- lapply(docs, fix_doc_id)
      result <- c(result, docs_fixed)
    } else {
      doc_fixed <- fix_doc_id(sub_item)
      result <- c(result, list(doc_fixed))
    }
  }
  return(result)
}

#------------------------------------------------------------------------------
# 7) fix_doc_id
#------------------------------------------------------------------------------
#' Ensure doc has 'id' (if only '_id' present)
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

#------------------------------------------------------------------------------
# 8) pubtator_v3_parse_nonstandard_json
#------------------------------------------------------------------------------
#' Parse Non-standard JSON => reassemble => fromJSON
#' @export
pubtator_v3_parse_nonstandard_json <- function(json_content) {
  tryCatch(
    {
      if (is.null(json_content) || length(json_content) == 0) {
        log_warn("pubtator_v3_parse_nonstandard_json got NULL or empty json_content => returning NULL.")
        return(NULL)
      }
      json_strings <- strsplit(paste(json_content, collapse = " "), "} ")[[1]]
      if (is.null(json_strings)) {
        log_warn("Failed to split JSON content => returning NULL.")
        return(NULL)
      }
      json_strings <- ifelse(grepl("}$", json_strings),
        json_strings,
        paste0(json_strings, "}")
      )
      json_with_ids <- paste0('"', seq_along(json_strings), '":', json_strings,
        collapse = ", "
      )
      valid_json_string <- paste0("{", json_with_ids, "}")
      parsed_json <- fromJSON(valid_json_string)
      return(parsed_json)
    },
    error = function(e) {
      warning_msg <- paste("Error in parsing JSON content:", e$message)
      log_warn(warning_msg)
      warning(warning_msg)
      return(NULL)
    }
  )
}

#------------------------------------------------------------------------------
# 9) flatten_pubtator_passages
#------------------------------------------------------------------------------
#' Flatten a PubTator object => row per annotation
#'
#' @param master_obj from pubtator_v3_data_from_pmids()
#' @return tibble with columns pmid, id, text, type, ...
#' @export
flatten_pubtator_passages <- function(master_obj) {
  base_tib <- build_pmid_annotations_table(master_obj)
  log_info("base_tib has {nrow(base_tib)} rows => flattening annotation DF...")

  if (nrow(base_tib) == 0) {
    log_warn("No rows => returning empty tibble.")
    return(base_tib)
  }

  base_tib2 <- base_tib %>%
    mutate(
      annotations = purrr::map2(annotations, dplyr::row_number(), function(ann_list, row_i) {
        if (!is.data.frame(ann_list) || nrow(ann_list) == 0) {
          log_info("Row {row_i}: annotation list is empty => empty tibble.")
          return(tibble())
        }
        log_info("Row {row_i}: annotation DF => {nrow(ann_list)} rows, {ncol(ann_list)} cols.")
        out_list <- vector("list", nrow(ann_list))
        for (i in seq_len(nrow(ann_list))) {
          single_row <- ann_list[i, , drop = FALSE]
          out_list[[i]] <- flatten_annotation_row(single_row)
        }
        ann_list_char <- dplyr::bind_rows(out_list)
        ann_list_char
      })
    )

  log_info("Done normalizing each row's annotation DF => unnesting annotations.")

  result <- base_tib2 %>%
    tidyr::unnest(annotations, keep_empty = TRUE) %>%
    dplyr::select(-dplyr::any_of(c("locations"))) %>%
    dplyr::rename_with(~ gsub("^infons\\.", "", .x), dplyr::starts_with("infons."))

  log_info("Flatten complete => {nrow(result)} rows, columns: {paste(names(result), collapse=', ')}")
  return(result)
}

#------------------------------------------------------------------------------
# 10) build_pmid_annotations_table
#------------------------------------------------------------------------------
build_pmid_annotations_table <- function(master_obj) {
  if (!is.list(master_obj)) {
    log_warn("master_obj not a list => returning empty tibble.")
    return(tibble(pmid = character(), annotations = list()))
  }
  if (!all(c("id", "passages") %in% names(master_obj))) {
    log_warn("master_obj missing 'id' or 'passages' => empty tibble.")
    return(tibble(pmid = character(), annotations = list()))
  }

  pmids_vec <- master_obj$id
  pass_list <- master_obj$passages
  if (!is.vector(pmids_vec) || !is.list(pass_list) || length(pmids_vec) != length(pass_list)) {
    log_warn("mismatch lengths => empty tibble.")
    return(tibble(pmid = character(), annotations = list()))
  }

  all_rows <- list()
  for (i in seq_along(pmids_vec)) {
    pmid_str <- as.character(pmids_vec[i])
    pass_df <- pass_list[[i]]
    if (!is.data.frame(pass_df)) {
      log_warn("passages[[{i}]] is not a data frame => skip.")
      next
    }
    for (row_i in seq_len(nrow(pass_df))) {
      ann_list <- NULL
      if ("annotations" %in% names(pass_df)) {
        ann_list <- pass_df$annotations[[row_i]]
      }
      row_obj <- list(
        pmid = pmid_str,
        annotations = list(ann_list %||% list())
      )
      all_rows <- append(all_rows, list(row_obj))
    }
  }

  if (length(all_rows) == 0) {
    return(tibble(pmid = character(), annotations = list()))
  }
  tib_out <- dplyr::bind_rows(all_rows)
  return(tib_out)
}

#------------------------------------------------------------------------------
# 11) flatten_annotation_row
#------------------------------------------------------------------------------
flatten_annotation_row <- function(one_annot) {
  stopifnot(nrow(one_annot) == 1)

  log_info("flatten_annotation_row => columns: {paste(names(one_annot), collapse=', ')}")

  if ("infons" %in% names(one_annot)) {
    infons_val <- one_annot[["infons"]]
    if (is.data.frame(infons_val) && nrow(infons_val) == 1) {
      # expand columns => infons.xyz
      for (cn in names(infons_val)) {
        infons_val[[cn]] <- as.character(infons_val[[cn]])
      }
      names(infons_val) <- paste0("infons.", names(infons_val))
      one_annot[["infons"]] <- NULL
      one_annot <- cbind(one_annot, infons_val)
    } else {
      # fallback => JSON
      one_annot[["infons"]] <- safe_as_json(infons_val)
    }
  }

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

  for (cn in names(one_annot)) {
    one_annot[[cn]] <- as.character(one_annot[[cn]])
  }
  out <- tibble::as_tibble(one_annot)
  return(out)
}

#------------------------------------------------------------------------------
# 12) safe_as_json
#------------------------------------------------------------------------------
safe_as_json <- function(x) {
  if (is.null(x)) {
    return("")
  }
  if (is.atomic(x) && length(x) == 1) {
    return(as.character(x))
  }
  out <- tryCatch(
    {
      jsonlite::toJSON(x, auto_unbox = TRUE)
    },
    error = function(e) {
      as.character(x)
    }
  )
  return(out)
}
