# Unit tests for api/functions/pubmed-xml-parser.R
# resolve_pubmed_date() date normalization + table_book_articles_from_xml()
# (GeneReviews <PubmedBookArticle>) + parse_pubmed_fetch_xml() union of article
# and book records. table_articles_from_xml() is covered in
# test-unit-pubmed-xml-parser.R. Shared XML builders live in pubmed-xml-fixtures.R.

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/publication-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

library(dplyr)
library(tibble)
library(stringr)
library(xml2)
library(purrr)
library(rvest)
library(tidyr)

# publication-functions.R conditionally sources db-helpers.R (RMariaDB) only when
# db_execute_query is undefined; stub it so the file loads without RMariaDB.
if (!exists("db_execute_query", mode = "function", envir = globalenv())) {
  assign("db_execute_query",
    function(...) stop("db_execute_query stub: mock in each test"),
    envir = globalenv()
  )
}

# Shared PubMed XML builders (create_pubmed_xml / create_pubmed_book_xml).
source(file.path(api_dir, "tests", "testthat", "pubmed-xml-fixtures.R"))

# Stay in api_dir so publication-functions.R's relative source() calls resolve;
# it guard-sources pubmed-xml-parser.R (the parser functions under test).
original_wd <- getwd()
setwd(api_dir)
source("functions/publication-functions.R")

test_that("resolve_pubmed_date defaults missing day and month, not the year", {
  full <- resolve_pubmed_date("2013", "06", "08")
  expect_equal(full$year, "2013")
  expect_equal(full$month, "06")
  expect_equal(full$day, "08")
  expect_equal(full$date_source, "pubmed")

  no_day <- resolve_pubmed_date("2013", "Jun", NA_character_)
  expect_equal(no_day$year, "2013")
  expect_equal(no_day$month, "06")
  expect_equal(no_day$day, "01")
  expect_equal(no_day$date_source, "pubmed_partial")

  no_month <- resolve_pubmed_date("2017", NA_character_, NA_character_)
  expect_equal(no_month$year, "2017")
  expect_equal(no_month$month, "01")
  expect_equal(no_month$day, "01")
  expect_equal(no_month$date_source, "pubmed_partial")
})

test_that("resolve_pubmed_date parses MedlineDate and reports unknown", {
  medline <- resolve_pubmed_date(NA_character_, NA_character_, NA_character_,
                                 medline_date = "2013 Jun-Jul")
  expect_equal(medline$year, "2013")
  expect_equal(medline$month, "06")
  expect_equal(medline$day, "01")
  expect_equal(medline$date_source, "medline_date")

  unknown <- resolve_pubmed_date(NA_character_, NA_character_, NA_character_)
  expect_true(is.na(unknown$year))
  expect_equal(unknown$date_source, "unknown")
})

# ============================================================================
# table_book_articles_from_xml() Tests - GeneReviews <PubmedBookArticle> (#500)
# ============================================================================

test_that("book parser extracts pmid, title, journal, author", {
  result <- table_book_articles_from_xml(create_pubmed_book_xml())
  expect_equal(nrow(result), 1L)
  expect_equal(result$pmid[1], "20301425")
  expect_equal(result$title[1],
    "BRCA1- and BRCA2-Associated Hereditary Breast and Ovarian Cancer")
  expect_equal(result$journal[1], "GeneReviews")
  expect_equal(result$lastname[1], "Petrucelli")
  expect_equal(result$firstname[1], "Nadine")
})

test_that("book parser uses ContributionDate as a verified pubmed date", {
  result <- table_book_articles_from_xml(create_pubmed_book_xml())
  expect_equal(result$date_source[1], "pubmed")
  expect_equal(paste(result$year[1], result$month[1], result$day[1], sep = "-"),
    "1998-09-04")
})

test_that("book parser falls back to PubMedPubDate when no ContributionDate", {
  xml <- create_pubmed_book_xml(include_contribution_date = FALSE,
                                include_pubmed_history = TRUE)
  result <- table_book_articles_from_xml(xml)
  expect_equal(result$date_source[1], "pubmed")
  expect_equal(paste(result$year[1], result$month[1], result$day[1], sep = "-"),
    "2024-12-12")
})

test_that("book parser falls back to Book/PubDate year (partial) when no other date", {
  xml <- create_pubmed_book_xml(include_contribution_date = FALSE,
                                include_pubmed_history = FALSE)
  result <- table_book_articles_from_xml(xml)
  expect_equal(result$date_source[1], "pubmed_partial")
  expect_equal(result$year[1], "1993")
})

test_that("parse_pubmed_fetch_xml returns BOTH article and book rows from a mixed set", {
  mixed <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>\n<PubmedArticleSet>\n',
    '<PubmedArticle><MedlineCitation><PMID>11112222</PMID><Article>',
    '<ArticleTitle>Regular Article</ArticleTitle>',
    '<Journal><Title>J Test</Title></Journal></Article></MedlineCitation>',
    '<PubmedData><History><PubMedPubDate Pubstatus="pubmed">',
    '<Year>2020</Year><Month>01</Month><Day>15</Day></PubMedPubDate>',
    '</History></PubmedData></PubmedArticle>\n',
    '<PubmedBookArticle><BookDocument><PMID>20301425</PMID>',
    '<Book><BookTitle>GeneReviews</BookTitle><PubDate><Year>1993</Year></PubDate></Book>',
    '<ArticleTitle>A GeneReview</ArticleTitle>',
    '<ContributionDate><Year>1998</Year><Month>09</Month><Day>04</Day></ContributionDate>',
    '</BookDocument></PubmedBookArticle>\n',
    '</PubmedArticleSet>')
  result <- parse_pubmed_fetch_xml(mixed)
  expect_setequal(result$pmid, c("11112222", "20301425"))
})
