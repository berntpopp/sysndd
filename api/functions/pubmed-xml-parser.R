# functions/pubmed-xml-parser.R
#
# PubMed EFetch XML -> publication-metadata tibble. Extracted from
# publication-functions.R (#500) so the parsing concern is a focused, testable
# unit and so <PubmedBookArticle> (GeneReviews) support can be added without
# pushing publication-functions.R past the 600-line ceiling.
#
# Output schema (one row per resolved record) is defined by
# empty_pubmed_article_tibble(). Consumed by info_from_pmid() and the
# publication_date_backfill job.

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

#' Normalize a PubMed Year/Month/Day (+ MedlineDate) into ymd + a source flag
#' @noRd
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

#' Parse <PubmedArticle> nodes into the publication metadata schema
#' @noRd
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
      year = pub_date$year,
      month = pub_date$month,
      day = pub_date$day,
      date_source = pub_date$date_source,
      lastname = lastname,
      firstname = firstname,
      address = str_c(text_all(article, ".//AuthorList/Author[1]/AffiliationInfo"),
        collapse = "; "
      )
    ))
  })
}

#' Parse PubMed EFetch XML and normalize empty/no-article responses
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
