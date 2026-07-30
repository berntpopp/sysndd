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

# Width of publication.Lastname / publication.Firstname after migration 048
# widened both from VARCHAR(50) to VARCHAR(255) (#614). Keep the two in step: this
# constant is the ONLY place the parser encodes the column bound.
PUBLICATION_AUTHOR_NAME_MAX_CHARS <- 255L

#' Clamp a parsed author name to the publication table's column width
#'
#' A backstop, not the fix. Migration 048 widened Lastname/Firstname to
#' VARCHAR(255) precisely so a real consortium byline is stored whole -- but
#' PubMed's <CollectiveName> is unbounded free text, and an overflow here does not
#' fail in isolation: publication ingestion runs inside the review-save
#' transaction, so one over-long byline rolls back the curator's ENTIRE save with
#' an opaque 500 (#614). Losing the tail of a byline is strictly better than
#' losing the save, so an over-long name is clamped rather than allowed to reach
#' the INSERT.
#'
#' It is deliberately NOT silent: clamping emits a warning naming the field and
#' the observed length, so a systematically over-long upstream shows up in the
#' logs instead of quietly corrupting citation metadata.
#'
#' `nchar()` counts CHARACTERS by default, which is what MySQL's VARCHAR(255)
#' bounds -- not bytes -- so the two measures agree for any BMP string. (A
#' non-BMP character is a separate failure the column's charset governs, not a
#' length problem, and this clamp does not claim to address it.)
#'
#' @param name Character scalar (NA/NULL pass through untouched).
#' @param field Column name used in the warning, e.g. "Lastname".
#' @param max_chars Column width to clamp to.
#' @return `name`, clamped to `max_chars` characters.
#' @noRd
pubmed_clamp_author_name <- function(name, field = "author name",
                                     max_chars = PUBLICATION_AUTHOR_NAME_MAX_CHARS) {
  if (is.null(name) || length(name) != 1L || is.na(name)) {
    return(name)
  }
  value <- as.character(name)
  observed <- nchar(value)
  if (observed <= max_chars) {
    return(value)
  }
  warning(sprintf(
    paste0(
      "PubMed %s is %d characters, longer than the publication.%s column (%d); ",
      "clamping so the enclosing review save is not rolled back (#614)."
    ),
    field, observed, field, max_chars
  ))
  substr(value, 1L, max_chars)
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
      # Clamped at the parser's exit, so both write paths that consume this
      # tibble -- info_from_pmid() on the review-save path and the
      # publication_refresh job -- are covered by one bound (#614).
      lastname = pubmed_clamp_author_name(lastname, "Lastname"),
      firstname = pubmed_clamp_author_name(firstname, "Firstname"),
      address = str_c(text_all(article, ".//AuthorList/Author[1]/AffiliationInfo"),
        collapse = "; "
      )
    ))
  })
}

#' Parse <PubmedBookArticle>/<BookDocument> nodes (GeneReviews / NCBI Bookshelf)
#'
#' EFetch on db=pubmed returns GeneReviews chapters as <PubmedBookArticle>, which
#' table_articles_from_xml (//PubmedArticle only) ignores (#500). Date ladder,
#' first present wins, then resolve_pubmed_date(): (1) BookDocument/ContributionDate
#' (the chapter's authored/revision date -> a verified full date), (2)
#' PubmedBookData/History/PubMedPubDate[@PubStatus='pubmed'], (3) Book/PubDate
#' (often year-only -> pubmed_partial). Reuses the pubmed/pubmed_partial source
#' vocabulary. Modeled on the proven ../genereviews-link _parse_book_article.
#' @noRd
table_book_articles_from_xml <- function(pubmed_xml_data) {
  book_xml <- read_xml(pubmed_xml_data)
  books <- xml_find_all(book_xml, "//PubmedBookArticle")
  if (length(books) == 0L) {
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

  book_date_parts <- function(book) {
    bases <- c(
      ".//BookDocument/ContributionDate",
      ".//PubmedBookData/History/PubMedPubDate[@PubStatus = 'pubmed' or @Pubstatus = 'pubmed']",
      ".//BookDocument/Book/PubDate"
    )
    for (base in bases) {
      yr <- text_first(book, paste0(base, "/Year"), default = NA_character_)
      if (!is.na(yr) && nzchar(yr)) {
        return(list(
          year = yr,
          month = text_first(book, paste0(base, "/Month"), default = NA_character_),
          day = text_first(book, paste0(base, "/Day"), default = NA_character_)
        ))
      }
    }
    list(year = NA_character_, month = NA_character_, day = NA_character_)
  }

  purrr::map_dfr(books, function(book) {
    parts <- book_date_parts(book)
    pub_date <- resolve_pubmed_date(parts$year, parts$month, parts$day)

    title <- text_first(book, ".//BookDocument/ArticleTitle")
    if (!nzchar(title)) title <- text_first(book, ".//BookDocument/BookTitle")
    if (!nzchar(title)) title <- text_first(book, ".//BookDocument/Book/BookTitle")

    book_title <- text_first(book, ".//BookDocument/Book/BookTitle")
    journal <- if (nzchar(book_title)) book_title else "GeneReviews"

    lastname <- text_first(book, ".//AuthorList[@Type = 'authors']/Author[1]/LastName")
    firstname <- text_first(book, ".//AuthorList[@Type = 'authors']/Author[1]/ForeName")
    if (lastname == "" && firstname == "") {
      lastname <- text_first(book, ".//AuthorList/Author[1]/LastName")
      firstname <- text_first(book, ".//AuthorList/Author[1]/ForeName")
    }
    collective <- text_first(book, ".//AuthorList/Author[1]/CollectiveName",
      default = NA_character_
    )
    if ((lastname == "" || firstname == "") && !is.na(collective)) {
      lastname <- collective
      firstname <- collective
    }

    as_tibble(list(
      pmid = text_first(book, ".//BookDocument/PMID"),
      doi = "",
      title = title,
      abstract = str_c(text_all(book, ".//Abstract/AbstractText"), collapse = " "),
      jabbrv = "",
      journal = journal,
      keywords = "",
      year = pub_date$year,
      month = pub_date$month,
      day = pub_date$day,
      date_source = pub_date$date_source,
      lastname = pubmed_clamp_author_name(lastname, "Lastname"),
      firstname = pubmed_clamp_author_name(firstname, "Firstname"),
      address = ""
    ))
  })
}

#' Parse PubMed EFetch XML (both <PubmedArticle> and <PubmedBookArticle>) and
#' normalize empty responses. A mixed EFetch batch contains both node types as
#' siblings under <PubmedArticleSet>; //PubmedArticle and //PubmedBookArticle are
#' disjoint, so no record is double-counted.
#' @noRd
parse_pubmed_fetch_xml <- function(pubmed_xml_data) {
  articles <- tryCatch(
    table_articles_from_xml(pubmed_xml_data),
    error = function(e) empty_pubmed_article_tibble()
  )
  books <- tryCatch(
    table_book_articles_from_xml(pubmed_xml_data),
    error = function(e) empty_pubmed_article_tibble()
  )
  parsed <- dplyr::bind_rows(articles, books)
  if (nrow(parsed) == 0L || all(is.na(parsed$pmid))) {
    return(empty_pubmed_article_tibble())
  }
  parsed
}
