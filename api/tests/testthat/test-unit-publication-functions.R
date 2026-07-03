# Unit tests for api/functions/publication-functions.R
# check_pmid() and info_from_pmid() (PubMed EFetch fetch/resolve/error paths).
# The pure PubMed-XML parser (table_articles_from_xml / table_book_articles_from_xml
# / resolve_pubmed_date / parse_pubmed_fetch_xml) now lives in pubmed-xml-parser.R
# and is covered by test-unit-pubmed-xml-parser*.R. Shared XML builders live in
# pubmed-xml-fixtures.R.

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

# Stay in api_dir so publication-functions.R's relative source() calls resolve.
original_wd <- getwd()
setwd(api_dir)
source("functions/publication-functions.R")

# =============================================================================
# PubMed E-utilities Helper Tests (Refs #324)
# =============================================================================

test_that("check_pmid normalizes PMID prefixes before direct PubMed count lookup", {
  calls <- character()
  mockery::stub(check_pmid, "pubmed_esearch_count", function(pmid) {
    calls <<- c(calls, pmid)
    1L
  })

  expect_true(check_pmid(c("PMID:41564340", "33054928")))
  expect_equal(calls, c("41564340", "33054928"))
})

test_that("check_pmid returns FALSE when direct PubMed count lookup finds no record", {
  mockery::stub(check_pmid, "pubmed_esearch_count", function(pmid) {
    if (identical(pmid, "22222222")) 0L else 1L
  })

  expect_false(check_pmid(c("PMID:11111111", "PMID:22222222")))
})

test_that("info_from_pmid fetches PubMed XML via direct EFetch helper", {
  calls <- list()
  one_pmid_xml <- '<?xml version="1.0"?><PubmedArticleSet><PubmedArticle>
   <MedlineCitation><PMID>11111111</PMID>
   <Article><Journal><Title>J Test</Title><ISOAbbreviation>JT</ISOAbbreviation></Journal>
   <ArticleTitle>Resolvable</ArticleTitle><Abstract><AbstractText>x</AbstractText></Abstract>
   <AuthorList><Author><LastName>A</LastName><ForeName>B</ForeName></Author></AuthorList>
   </Article></MedlineCitation>
   <PubmedData><History>
    <PubMedPubDate PubStatus="pubmed"><Year>2024</Year><Month>1</Month><Day>1</Day></PubMedPubDate>
   </History><ArticleIdList><ArticleId IdType="doi">10.1/x</ArticleId></ArticleIdList></PubmedData>
   </PubmedArticle></PubmedArticleSet>'

  mockery::stub(info_from_pmid, "pubmed_fetch_xml", function(pmids) {
    calls[[length(calls) + 1L]] <<- pmids
    one_pmid_xml
  })

  result <- info_from_pmid("PMID:11111111")

  expect_equal(calls, list("11111111"))
  expect_equal(result$Title, "Resolvable")
})

test_that("info_from_pmid resolves multiple valid PMIDs from one EFetch response", {
  multi_pmid_xml <- '<?xml version="1.0"?><PubmedArticleSet>
   <PubmedArticle><MedlineCitation><PMID>11111111</PMID>
   <Article><Journal><Title>J Test</Title><ISOAbbreviation>JT</ISOAbbreviation></Journal>
   <ArticleTitle>First</ArticleTitle><Abstract><AbstractText>x</AbstractText></Abstract>
   <AuthorList><Author><LastName>A</LastName><ForeName>B</ForeName></Author></AuthorList>
   </Article></MedlineCitation>
   <PubmedData><History>
    <PubMedPubDate PubStatus="pubmed"><Year>2024</Year><Month>1</Month><Day>1</Day></PubMedPubDate>
   </History><ArticleIdList><ArticleId IdType="doi">10.1/x</ArticleId></ArticleIdList></PubmedData>
   </PubmedArticle>
   <PubmedArticle><MedlineCitation><PMID>22222222</PMID>
   <Article><Journal><Title>J Test</Title><ISOAbbreviation>JT</ISOAbbreviation></Journal>
   <ArticleTitle>Second</ArticleTitle><Abstract><AbstractText>y</AbstractText></Abstract>
   <AuthorList><Author><LastName>C</LastName><ForeName>D</ForeName></Author></AuthorList>
   </Article></MedlineCitation>
   <PubmedData><History>
    <PubMedPubDate PubStatus="pubmed"><Year>2024</Year><Month>2</Month><Day>2</Day></PubMedPubDate>
   </History><ArticleIdList><ArticleId IdType="doi">10.2/y</ArticleId></ArticleIdList></PubmedData>
   </PubmedArticle></PubmedArticleSet>'

  mockery::stub(info_from_pmid, "pubmed_fetch_xml", function(...) multi_pmid_xml)

  result <- info_from_pmid(c("PMID:11111111", "PMID:22222222"))

  expect_equal(result$Title, c("First", "Second"))
  expect_equal(result$Publication_date, c("2024-01-01", "2024-02-02"))
})

# =============================================================================
# info_from_pmid Fail-Fast Tests (Refs #318)
# =============================================================================

test_that("info_from_pmid raises publication_fetch_error when PubMed returns nothing for a PMID", {
  # We request two PMIDs but the stubbed direct EFetch helper returns XML for
  # only one of them. info_from_pmid must abort with publication_fetch_error
  # listing the unresolved PMID. Both PubMed entrypoints are stubbed so this
  # unit test cannot perform network I/O before the fetch stub is reached.

  one_pmid_xml <- '<?xml version="1.0"?><PubmedArticleSet><PubmedArticle>
   <MedlineCitation><PMID>11111111</PMID>
   <Article><Journal><Title>J Test</Title><ISOAbbreviation>JT</ISOAbbreviation></Journal>
   <ArticleTitle>Resolvable</ArticleTitle><Abstract><AbstractText>x</AbstractText></Abstract>
   <AuthorList><Author><LastName>A</LastName><ForeName>B</ForeName></Author></AuthorList>
   </Article></MedlineCitation>
   <PubmedData><History>
    <PubMedPubDate PubStatus="pubmed"><Year>2024</Year><Month>1</Month><Day>1</Day></PubMedPubDate>
   </History><ArticleIdList><ArticleId IdType="doi">10.1/x</ArticleId></ArticleIdList></PubmedData>
   </PubmedArticle></PubmedArticleSet>'

  mockery::stub(info_from_pmid, "pubmed_fetch_xml", function(...) one_pmid_xml)

  error <- tryCatch(
    info_from_pmid(c("11111111", "22222222")),
    publication_fetch_error = function(e) e
  )

  expect_s3_class(error, "publication_fetch_error")
  expect_match(error$message, "PMID:22222222", fixed = TRUE)
  expect_equal(error$pmids, "PMID:22222222")
})

test_that("info_from_pmid de-duplicates unresolved PMID values in publication_fetch_error", {
  unrelated_pmid_xml <- create_pubmed_xml(pmid = "11111111")

  mockery::stub(info_from_pmid, "pubmed_fetch_xml", function(...) unrelated_pmid_xml)

  error <- tryCatch(
    info_from_pmid(c("PMID:22222222", "PMID:22222222")),
    publication_fetch_error = function(e) e
  )

  expect_s3_class(error, "publication_fetch_error")
  expect_equal(error$pmids, "PMID:22222222")
  expect_equal(stringr::str_count(error$message, "PMID:22222222"), 1)
})

test_that("info_from_pmid reports explicit input PMID when parsed response has NA PMID", {
  parsed_with_na_pmid <- tibble::tibble(
    pmid = NA_character_,
    doi = "10.1/na",
    title = "Missing PubMed identifier",
    abstract = "x",
    jabbrv = "JT",
    journal = "J Test",
    keywords = "",
    year = "2024",
    month = "01",
    day = "01",
    date_source = "pubmed",
    lastname = "A",
    firstname = "B",
    address = ""
  )

  mockery::stub(info_from_pmid, "pubmed_fetch_xml", function(...) "<xml />")
  mockery::stub(info_from_pmid, "table_articles_from_xml", function(...) parsed_with_na_pmid)

  error <- tryCatch(
    info_from_pmid("PMID:22222222"),
    publication_fetch_error = function(e) e
  )

  expect_s3_class(error, "publication_fetch_error")
  expect_match(error$message, "PMID:22222222", fixed = TRUE)
  expect_false(grepl("PMID:NA", error$message, fixed = TRUE))
  expect_equal(error$pmids, "PMID:22222222")
})

# =============================================================================
# Publication_date NA preservation Tests (Refs #318)
# =============================================================================

test_that("info_from_pmid leaves Publication_date as NA when value is NA in the joined tibble", {
  # Pin the helper-expression we use in info_from_pmid: NA Publication_date
  # must survive the replace_na step so DBI can pass NULL to MySQL.
  # The full info_from_pmid path is exercised by integration tests (Task 11).
  fake <- tibble::tibble(
    Title = NA_character_,
    Publication_date = NA_character_,
    Journal = NA_character_
  )
  result <- fake %>%
    dplyr::mutate(dplyr::across(-dplyr::any_of("Publication_date"),
                                ~ tidyr::replace_na(.x, "")))
  expect_true(is.na(result$Publication_date))
  expect_equal(result$Title, "")
  expect_equal(result$Journal, "")
})
