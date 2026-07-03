# functions/publication-functions.R
#### This file holds pubmed functions

# load source files if not already loaded
if (!exists("info_from_genereviews_pmid", mode = "function")) {
  if (file.exists("functions/genereviews-functions.R")) {
    source("functions/genereviews-functions.R", local = TRUE)
  }
}

# Load the PubMed XML parser (table_articles_from_xml / parse_pubmed_fetch_xml /
# resolve_pubmed_date / empty_pubmed_article_tibble / table_book_articles_from_xml)
# if not already sourced.
if (!exists("table_articles_from_xml", mode = "function")) {
  if (file.exists("functions/pubmed-xml-parser.R")) {
    source("functions/pubmed-xml-parser.R", local = TRUE)
  }
}

# Load database helper functions for repository layer access (if not already loaded)
if (!exists("db_execute_query", mode = "function")) {
  if (file.exists("functions/db-helpers.R")) {
    source("functions/db-helpers.R", local = TRUE)
  }
}

#' Normalize PMID values for direct NCBI E-utilities requests
#'
#' @param pmid_input Character vector or list of PMID values, with or without
#'   `PMID:` prefixes.
#' @return Character vector of numeric PMID strings.
#' @noRd
normalize_pubmed_ids <- function(pmid_input) {
  if (is.null(pmid_input) || length(pmid_input) == 0) {
    return(character())
  }

  pmids <- as.character(unlist(pmid_input, use.names = FALSE))
  pmids <- stringr::str_trim(pmids)
  pmids <- stringr::str_remove(pmids, stringr::regex("^PMID:", ignore_case = TRUE))
  pmids <- pmids[!is.na(pmids) & nzchar(pmids)]
  pmids
}

#' Attach NCBI E-utilities identity/rate-limit params to a query list
#'
#' Mirrors `genereviews_eutils_query()` (the sibling EUtils module): appends
#' `tool`, and — when configured in the environment — `email` and `api_key`.
#' An NCBI `api_key` raises the per-IP rate limit from the anonymous 3 req/s to
#' 10 req/s, which is what keeps the publication-date backfill from 429-ing large
#' EFetch batches into a whole-job "systemic outage" (#494). Never hardcodes a
#' key; anonymous requests remain valid for low-volume use.
#'
#' @param query Named list of query parameters.
#' @return The query list with `tool`, and `email`/`api_key` when set in env.
#' @noRd
pubmed_eutils_query <- function(query) {
  if (is.null(query$tool)) {
    query$tool <- "sysndd"
  }

  email <- Sys.getenv("NCBI_EUTILS_EMAIL", "")
  if (nzchar(email)) {
    query$email <- email
  }

  api_key <- Sys.getenv("NCBI_API_KEY", "")
  if (nzchar(api_key)) {
    query$api_key <- api_key
  }

  query
}

#' Minimum inter-request interval (seconds) for NCBI E-utilities calls
#'
#' NCBI caps anonymous callers at 3 req/s and keyed callers at 10 req/s. The
#' backfill self-throttles at this interval; with an `NCBI_API_KEY` present it
#' can pace faster (kept conservatively below the 10 req/s ceiling to leave
#' headroom for other NCBI callers sharing the IP, e.g. the pubtator cron).
#'
#' @return Numeric seconds to sleep between E-utilities requests.
#' @noRd
pubmed_min_request_interval <- function() {
  if (nzchar(Sys.getenv("NCBI_API_KEY", ""))) {
    0.15  # ~6.7 req/s, safely under the keyed 10 req/s cap
  } else {
    0.34  # ~2.9 req/s, under the anonymous 3 req/s cap
  }
}

#' Count matching PubMed records for one PMID via ESearch
#'
#' @param pmid PMID without the `PMID:` prefix.
#' @return Integer count returned by PubMed. Returns 0 on invalid input or
#'   request/parse failure.
#' @noRd
pubmed_esearch_count <- function(pmid) {
  pmid <- normalize_pubmed_ids(pmid)
  if (length(pmid) != 1L || !grepl("^[0-9]+$", pmid)) {
    return(0L)
  }

  tryCatch(
    {
      response <- httr2::request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi") %>%
        httr2::req_url_query(!!!pubmed_eutils_query(list(
          db = "pubmed",
          term = paste0(pmid, "[PMID]"),
          retmode = "xml"
        ))) %>%
        httr2::req_retry(
          max_tries = 3,
          backoff = ~ 2^.x,
          is_transient = ~ httr2::resp_status(.x) %in% c(429, 500, 502, 503, 504)
        ) %>%
        httr2::req_timeout(30) %>%
        httr2::req_perform()

      body <- httr2::resp_body_string(response)
      count <- xml2::read_xml(body) %>%
        xml2::xml_find_first("//Count") %>%
        xml2::xml_text()
      count_int <- suppressWarnings(as.integer(count))
      if (is.na(count_int)) 0L else count_int
    },
    error = function(e) {
      0L
    }
  )
}

#' Fetch PubMed article XML for one chunk of PMIDs via EFetch
#'
#' @param pmids Character vector of PMIDs without `PMID:` prefixes.
#' @return PubMed XML response body as a string.
#' @noRd
pubmed_fetch_xml <- function(pmids) {
  pmids <- unique(normalize_pubmed_ids(pmids))
  pmids <- pmids[grepl("^[0-9]+$", pmids)]
  if (length(pmids) == 0L) {
    return("<PubmedArticleSet/>")
  }

  response <- httr2::request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi") %>%
    httr2::req_url_query(!!!pubmed_eutils_query(list(
      db = "pubmed",
      id = paste(pmids, collapse = ","),
      retmode = "xml",
      rettype = "xml"
    ))) %>%
    httr2::req_retry(
      max_tries = 3,
      backoff = ~ 2^.x,
      is_transient = ~ httr2::resp_status(.x) %in% c(429, 500, 502, 503, 504)
    ) %>%
    httr2::req_timeout(30) %>%
    httr2::req_perform()

  httr2::resp_body_string(response)
}

#' A function that checks whether all PMIDs in a list are valid
#' and can be found in pubmed, returns true if all are and
#' false if one is invalid
#'
#' @param pmid_input A list of PMIDs
#'
#' @return Boolean value representing if all PMIDs were found
#' @export
check_pmid <- function(pmid_input) {
  pmids <- unique(normalize_pubmed_ids(pmid_input))
  if (length(pmids) == 0L) {
    return(TRUE)
  }

  counts <- vapply(pmids, pubmed_esearch_count, integer(1), USE.NAMES = FALSE)
  all(counts > 0L)
}


#' A function that takes a tibble of publication_ids and
#' publication_types and adds them to the database if they are new
#'
#' @param publications_received tibble with publication_id and publication_type
#'
#' @return list with http status message
#' @export
new_publication <- function(publications_received) {
  # check if all received PMIDs are valid
  if (check_pmid(publications_received$publication_id)) {
    # check if publication_ids are already present in the database
    publications_list_collected <- pool %>%
      tbl("publication") %>%
      dplyr::select(publication_id, update_date) %>%
      arrange(publication_id) %>%
      collect() %>%
      right_join(publications_received, by = c("publication_id")) %>%
      filter(is.na(update_date)) %>%
      dplyr::select(-update_date)

    # subset by publication_type
    pub_list_coll_gr <- publications_list_collected %>%
      filter(publication_type == "gene_review")
    pub_list_coll_other <- publications_list_collected %>%
      filter(publication_type != "gene_review")

    # check if subset list is longer then 0 then get info
    if (length(compact(pub_list_coll_gr$publication_id)) > 0) {
      pub_list_coll_gr_info <- pub_list_coll_gr %>%
        rowwise() %>%
        mutate(info = info_from_genereviews_pmid(publication_id)) %>%
        unnest(info)
    }

    # check if subset list is longer then 0 then get info
    if (length(compact(pub_list_coll_other$publication_id)) > 0) {
      pub_list_coll_other_info <- pub_list_coll_other %>%
        rowwise() %>%
        mutate(info = info_from_pmid(publication_id)) %>%
        unnest(info)
    }

    # bind the two tibbles if they exist
    publications_list_collected_info <- bind_rows(
      get0("pub_list_coll_gr_info"),
      get0("pub_list_coll_other_info")
    )

    # add new publications to database table "publication" if present and not NA
    if (nrow(publications_list_collected_info) > 0) {
      cols <- names(publications_list_collected_info)
      placeholders <- paste(rep("?", length(cols)), collapse = ", ")
      sql <- sprintf("INSERT INTO publication (%s) VALUES (%s)",
                     paste(cols, collapse = ", "), placeholders)

      # Atomic batch (#318): a partial publication batch must never half-commit.
      # If any INSERT fails (e.g. an unexpected NULL on a NOT NULL column), the
      # whole batch rolls back and the error propagates as db_transaction_error.
      tryCatch(
        db_with_transaction(function(txn_conn) {
          for (i in seq_len(nrow(publications_list_collected_info))) {
            row <- publications_list_collected_info[i, ]
            db_execute_statement(sql, as.list(row), conn = txn_conn)
          }
          invisible(NULL)
        }),
        db_transaction_error = function(e) {
          rlang::abort(
            message = paste("Publication batch insert failed:", e$message),
            class = c("publication_insert_error", "db_statement_error"),
            original_error = e$message
          )
        }
      )
    }

    # return OK
    return(list(status = 200, message = "OK. Entry created."))
  } else {
    # return Bad Request
    return(list(status = 400, message = "Bad Request. Invalid PMIDs detected."))
  }
}


#' Splits requests for PMID information in chunks for the API
#'
#' @param pmid_value A list of PMIDs
#' @param request_max a number used to partition the requests in chunks
#'
#' @return tibble with article information columns
#' @export
info_from_pmid <- function(pmid_value, request_max = 200) {
  request_max <- as.integer(request_max)
  if (is.na(request_max) || request_max < 1L) {
    rlang::abort("request_max must be a positive integer")
  }

  input_tibble <- tibble::tibble(
    publication_id = normalize_pubmed_ids(pmid_value)
  )

  requested_publication_ids <- unique(
    input_tibble$publication_id[!is.na(input_tibble$publication_id)]
  )

  if (length(requested_publication_ids) == 0L) {
    return(tibble::tibble(
      other_publication_id = character(),
      Title = character(),
      Abstract = character(),
      Publication_date = character(),
      publication_date_source = character(),
      Journal_abbreviation = character(),
      Journal = character(),
      Keywords = character(),
      Lastname = character(),
      Firstname = character()
    ))
  }

  chunks <- split(
    requested_publication_ids,
    ceiling(seq_along(requested_publication_ids) / request_max)
  )

  parsed_articles <- purrr::map_dfr(chunks, function(chunk) {
    pubmed_fetch_xml(chunk) %>%
      parse_pubmed_fetch_xml()
  })

  input_tibble_request <- parsed_articles %>%
    mutate(publication_id = as.character(pmid)) %>%
    mutate(other_publication_id = paste0("DOI:", doi)) %>%
    mutate(publication_date_source = date_source) %>%
    mutate(Publication_date = dplyr::if_else(
      date_source == "unknown",
      NA_character_,
      paste0(year, "-", month, "-", day)
    )) %>%
    dplyr::select(
      publication_id = pmid,
      other_publication_id,
      Title = title,
      Abstract = abstract,
      Publication_date,
      publication_date_source,
      Journal_abbreviation = jabbrv,
      Journal = journal,
      Keywords = keywords,
      Lastname = lastname,
      Firstname = firstname
    )

  # Detect PMIDs PubMed did not return any data for. After fetch+parse,
  # input_tibble_request contains a row per RESOLVED PMID. Any input PMID
  # missing from input_tibble_request was unresolvable. Fail fast (#318):
  # half-committing a stub publication row and a connected entity is worse
  # than a 400 with a clear message.
  resolved_publication_ids <- unique(
    input_tibble_request$publication_id[!is.na(input_tibble_request$publication_id)]
  )
  unresolved <- base::setdiff(requested_publication_ids, resolved_publication_ids)
  if (length(unresolved) > 0) {
    unresolved_display <- paste0("PMID:", unresolved)
    rlang::abort(
      message = paste0(
        "PMIDs not retrievable from PubMed: ",
        paste(unresolved_display, collapse = ", ")
      ),
      class = "publication_fetch_error",
      pmids = unresolved_display
    )
  }

  output_tibble <- input_tibble %>%
    left_join(input_tibble_request, by = "publication_id") %>%
    dplyr::select(-publication_id) %>%
    # Exclude timestamp columns: NA -> NULL via DBI, not "" which MySQL 8.4
    # strict mode rejects (#318). Belt-and-braces — Task 3's fail-fast
    # already aborts on unresolved PMIDs, so this branch is currently
    # unreachable for the documented call path. Kept defensive against
    # future partial-fetch code or refactors.
    mutate(across(-any_of("Publication_date"), ~ replace_na(.x, "")))

  return(output_tibble)
}
