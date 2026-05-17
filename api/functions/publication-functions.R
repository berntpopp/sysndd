# functions/publication-functions.R
#### This file holds pubmed functions

# load source files if not already loaded
if (!exists("info_from_genereviews_pmid", mode = "function")) {
  if (file.exists("functions/genereviews-functions.R")) {
    source("functions/genereviews-functions.R", local = TRUE)
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
        httr2::req_url_query(
          db = "pubmed",
          term = paste0(pmid, "[PMID]"),
          retmode = "xml"
        ) %>%
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
    httr2::req_url_query(
      db = "pubmed",
      id = paste(pmids, collapse = ","),
      retmode = "xml",
      rettype = "xml"
    ) %>%
    httr2::req_retry(
      max_tries = 3,
      backoff = ~ 2^.x,
      is_transient = ~ httr2::resp_status(.x) %in% c(429, 500, 502, 503, 504)
    ) %>%
    httr2::req_timeout(30) %>%
    httr2::req_perform()

  httr2::resp_body_string(response)
}

#' Empty parsed PubMed article tibble with the parser's output schema
#' @noRd
empty_pubmed_article_tibble <- function() {
  tibble::tibble(
    pmid = character(),
    doi = character(),
    title = character(),
    abstract = character(),
    jabbrv = character(),
    journal = character(),
    keywords = character(),
    year = character(),
    month = character(),
    day = character(),
    date_source = character(),
    lastname = character(),
    firstname = character(),
    address = character()
  )
}

#' Parse PubMed XML and normalize empty/no-article responses
#' @noRd
parse_pubmed_fetch_xml <- function(pubmed_xml_data) {
  parsed <- tryCatch(
    table_articles_from_xml(pubmed_xml_data),
    error = function(e) empty_pubmed_article_tibble()
  )
  if (nrow(parsed) == 0L || all(is.na(parsed$pmid))) {
    return(empty_pubmed_article_tibble())
  }
  parsed
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


#' Parse PubMed article XML into the publication metadata schema
#'
#' @param pubmed_xml_data A XML string from Pubmed API
#'
#' @return tibble with article information columns
#' @export
resolve_pubmed_date <- function(year, month, day, medline_date = NA_character_) {
  blank <- function(x) {
    is.null(x) || length(x) == 0L || is.na(x) ||
      !nzchar(trimws(as.character(x)[1]))
  }
  month_to_num <- function(m) {
    if (blank(m)) return(NA_character_)
    m <- trimws(as.character(m)[1])
    if (grepl("^[0-9]{1,2}$", m)) {
      return(stringr::str_pad(m, 2, "left", pad = "0"))
    }
    idx <- match(tolower(substr(m, 1, 3)), tolower(month.abb))
    if (is.na(idx)) NA_character_ else sprintf("%02d", idx)
  }

  if (blank(year) && !blank(medline_date)) {
    yr <- regmatches(medline_date, regexpr("[0-9]{4}", medline_date))
    if (length(yr) == 1L) {
      mon_tok <- regmatches(medline_date, regexpr("[A-Za-z]{3,}", medline_date))
      mon <- if (length(mon_tok) == 1L) month_to_num(mon_tok) else NA_character_
      return(list(
        year = yr,
        month = if (is.na(mon)) "01" else mon,
        day = "01",
        date_source = "medline_date"
      ))
    }
  }

  if (blank(year)) {
    return(list(
      year = NA_character_, month = NA_character_,
      day = NA_character_, date_source = "unknown"
    ))
  }

  month_norm <- month_to_num(month)
  day_norm <- if (blank(day) ||
                  !grepl("^[0-9]{1,2}$", trimws(as.character(day)[1]))) {
    NA_character_
  } else {
    stringr::str_pad(trimws(as.character(day)[1]), 2, "left", pad = "0")
  }
  is_partial <- is.na(month_norm) || is.na(day_norm)
  list(
    year = trimws(as.character(year)[1]),
    month = if (is.na(month_norm)) "01" else month_norm,
    day = if (is.na(day_norm)) "01" else day_norm,
    date_source = if (is_partial) "pubmed_partial" else "pubmed"
  )
}

table_articles_from_xml <- function(pubmed_xml_data) {
  pmid_xml <- read_xml(pubmed_xml_data)
  articles <- xml_find_all(pmid_xml, "//PubmedArticle")
  if (length(articles) == 0L) {
    return(empty_pubmed_article_tibble())
  }

  text_first <- function(node, xpath, default = "") {
    value <- xml_text(xml_find_first(node, xpath))
    if (length(value) == 0L || is.na(value)) {
      return(default)
    }
    value
  }

  text_all <- function(node, xpath) {
    values <- xml_text(xml_find_all(node, xpath))
    values[!is.na(values)]
  }

  date_part <- function(article, part) {
    xpath <- paste0(
      ".//PubMedPubDate[@PubStatus = 'pubmed' or @Pubstatus = 'pubmed']/",
      part
    )
    value <- text_first(article, xpath, default = NA_character_)
    if (is.na(value)) {
      value <- text_first(article, paste0(".//Article/Journal/JournalIssue/PubDate/", part),
        default = NA_character_
      )
    }
    value
  }

  purrr::map_dfr(articles, function(article) {
    doi <- text_first(article, ".//Article/ELocationID[@EIdType = 'doi']",
      default = NA_character_
    )
    if (is.na(doi)) {
      doi <- text_first(article, ".//ArticleId[@EIdType = 'doi']",
        default = NA_character_
      )
    }
    if (is.na(doi)) {
      doi <- text_first(article, ".//ArticleId[@IdType = 'doi' and not(ancestor::ReferenceList)]",
        default = ""
      )
    }

    lastname <- text_first(article, ".//AuthorList/Author[1]/LastName")
    firstname <- text_first(article, ".//AuthorList/Author[1]/ForeName")
    collective <- text_first(article, ".//AuthorList/Author[1]/CollectiveName",
      default = NA_character_
    )
    if ((lastname == "" || firstname == "") && !is.na(collective)) {
      lastname <- collective
      firstname <- collective
    }

    medline_date <- text_first(
      article, ".//Article/Journal/JournalIssue/PubDate/MedlineDate",
      default = NA_character_
    )
    pub_date <- resolve_pubmed_date(
      date_part(article, "Year"),
      date_part(article, "Month"),
      date_part(article, "Day"),
      medline_date = medline_date
    )
    year <- pub_date$year
    month <- pub_date$month
    day <- pub_date$day
    date_source <- pub_date$date_source

    mesh <- text_all(article, ".//DescriptorName")
    keyword <- text_all(article, ".//Keyword")

    as_tibble(list(
      pmid = text_first(article, ".//MedlineCitation/PMID"),
      doi = doi,
      title = str_c(text_all(article, ".//Article/ArticleTitle"), collapse = " "),
      abstract = str_c(text_all(article, ".//AbstractText"), collapse = " "),
      jabbrv = text_first(article, ".//Article/Journal/ISOAbbreviation"),
      journal = text_first(article, ".//Article/Journal/Title"),
      keywords = str_c(unique(str_squish(c(mesh, keyword))), collapse = "; "),
      year = year,
      month = month,
      day = day,
      date_source = date_source,
      lastname = lastname,
      firstname = firstname,
      address = str_c(text_all(article, ".//AuthorList/Author[1]/AffiliationInfo"),
        collapse = "; "
      )
    ))
  })
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
