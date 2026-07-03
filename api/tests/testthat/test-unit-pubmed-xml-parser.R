# Unit tests for api/functions/pubmed-xml-parser.R
# table_articles_from_xml(): <PubmedArticle> XML -> publication-metadata tibble.
# resolve_pubmed_date() and the GeneReviews <PubmedBookArticle> parser are covered
# in test-unit-pubmed-xml-parser-books.R. Shared XML builders live in
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

# Stay in api_dir so publication-functions.R's relative source() calls resolve;
# it guard-sources pubmed-xml-parser.R (the parser functions under test).
original_wd <- getwd()
setwd(api_dir)
source("functions/publication-functions.R")

# ============================================================================
# table_articles_from_xml() Tests - Basic Parsing
# ============================================================================

test_that("table_articles_from_xml extracts PMID correctly", {
  xml <- create_pubmed_xml(pmid = "99887766")
  result <- table_articles_from_xml(xml)

  expect_s3_class(result, "tbl_df")
  expect_equal(result$pmid[1], "99887766")
})

test_that("table_articles_from_xml extracts title correctly", {
  xml <- create_pubmed_xml(title = "Novel Findings in Genetics")
  result <- table_articles_from_xml(xml)

  expect_equal(result$title[1], "Novel Findings in Genetics")
})

test_that("table_articles_from_xml extracts abstract correctly", {
  xml <- create_pubmed_xml(abstract = "This study examines important findings.")
  result <- table_articles_from_xml(xml)

  expect_equal(result$abstract[1], "This study examines important findings.")
})

test_that("table_articles_from_xml extracts journal info correctly", {
  xml <- create_pubmed_xml(
    journal = "American Journal of Human Genetics",
    journal_abbrev = "Am J Hum Genet"
  )
  result <- table_articles_from_xml(xml)

  expect_equal(result$journal[1], "American Journal of Human Genetics")
  expect_equal(result$jabbrv[1], "Am J Hum Genet")
})

test_that("table_articles_from_xml extracts author info correctly", {
  xml <- create_pubmed_xml(author_last = "Johnson", author_first = "Sarah")
  result <- table_articles_from_xml(xml)

  expect_equal(result$lastname[1], "Johnson")
  expect_equal(result$firstname[1], "Sarah")
})

test_that("table_articles_from_xml extracts affiliation correctly", {
  xml <- create_pubmed_xml(affiliation = "Harvard Medical School, Boston, MA")
  result <- table_articles_from_xml(xml)

  expect_true(grepl("Harvard Medical School", result$address[1]))
})

# ============================================================================
# table_articles_from_xml() Tests - DOI Handling
# ============================================================================

test_that("table_articles_from_xml extracts DOI from ELocationID", {
  xml <- create_pubmed_xml(doi = "10.1016/j.gene.2024.01.001", doi_location = "elocation")
  result <- table_articles_from_xml(xml)

  expect_equal(result$doi[1], "10.1016/j.gene.2024.01.001")
})

test_that("table_articles_from_xml extracts DOI from ArticleId EIdType", {
  xml <- create_pubmed_xml(doi = "10.1002/humu.24001", doi_location = "articleid_eid")
  result <- table_articles_from_xml(xml)

  expect_equal(result$doi[1], "10.1002/humu.24001")
})

test_that("table_articles_from_xml extracts DOI from ArticleId IdType", {
  xml <- create_pubmed_xml(doi = "10.1038/ng.2024", doi_location = "articleid_id")
  result <- table_articles_from_xml(xml)

  expect_equal(result$doi[1], "10.1038/ng.2024")
})

test_that("table_articles_from_xml handles missing DOI", {
  xml <- create_pubmed_xml(include_doi = FALSE)
  result <- table_articles_from_xml(xml)

  # Should be empty string when no DOI found
  expect_equal(result$doi[1], "")
})

# ============================================================================
# table_articles_from_xml() Tests - Date Handling
# ============================================================================

test_that("table_articles_from_xml extracts and formats date correctly", {
  xml <- create_pubmed_xml(year = "2023", month = "12", day = "25")
  result <- table_articles_from_xml(xml)

  expect_equal(result$year[1], "2023")
  expect_equal(result$month[1], "12")  # Already 2 digits
  expect_equal(result$day[1], "25")    # Already 2 digits
})

test_that("table_articles_from_xml pads single-digit month/day", {
  xml <- create_pubmed_xml(year = "2024", month = "3", day = "5")
  result <- table_articles_from_xml(xml)

  expect_equal(result$month[1], "03")  # Padded to 2 digits
  expect_equal(result$day[1], "05")    # Padded to 2 digits
})

test_that("table_articles_from_xml reports unknown when date missing", {
  # Create XML without date info but with required author
  xml <- '<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>12345678</PMID>
      <Article>
        <ArticleTitle>Test</ArticleTitle>
        <Abstract><AbstractText>Test abstract</AbstractText></Abstract>
        <Journal>
          <Title>Test Journal</Title>
          <ISOAbbreviation>Test J</ISOAbbreviation>
        </Journal>
        <AuthorList>
          <Author>
            <LastName>Smith</LastName>
            <ForeName>John</ForeName>
          </Author>
        </AuthorList>
      </Article>
    </MedlineCitation>
    <PubmedData>
      <ArticleIdList>
        <ArticleId IdType="pubmed">12345678</ArticleId>
      </ArticleIdList>
      <History>
      </History>
    </PubmedData>
  </PubmedArticle>
</PubmedArticleSet>'

  result <- table_articles_from_xml(xml)

  expect_true(is.na(result$year[1]))
  expect_true(is.na(result$month[1]))
  expect_true(is.na(result$day[1]))
  expect_equal(result$date_source[1], "unknown")
})

# ============================================================================
# table_articles_from_xml() Tests - Author Handling
# ============================================================================

test_that("table_articles_from_xml handles collective author name", {
  xml <- create_pubmed_xml(
    author_last = NULL,
    author_first = NULL,
    collective_name = "ENCODE Project Consortium"
  )
  result <- table_articles_from_xml(xml)

  # Both lastname and firstname should be the collective name
  expect_equal(result$lastname[1], "ENCODE Project Consortium")
  expect_equal(result$firstname[1], "ENCODE Project Consortium")
})

test_that("table_articles_from_xml extracts first author only", {
  # XML with multiple authors (manual construction)
  xml <- '<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>12345678</PMID>
      <Article>
        <ArticleTitle>Multi-author Paper</ArticleTitle>
        <Abstract><AbstractText>Test abstract</AbstractText></Abstract>
        <Journal>
          <Title>Test Journal</Title>
          <ISOAbbreviation>Test J</ISOAbbreviation>
        </Journal>
        <AuthorList>
          <Author>
            <LastName>FirstAuthor</LastName>
            <ForeName>First</ForeName>
            <AffiliationInfo>University A</AffiliationInfo>
          </Author>
          <Author>
            <LastName>SecondAuthor</LastName>
            <ForeName>Second</ForeName>
            <AffiliationInfo>University B</AffiliationInfo>
          </Author>
        </AuthorList>
      </Article>
    </MedlineCitation>
    <PubmedData>
      <ArticleIdList>
        <ArticleId IdType="pubmed">12345678</ArticleId>
      </ArticleIdList>
      <History>
        <PubMedPubDate Pubstatus="pubmed">
          <Year>2024</Year><Month>1</Month><Day>1</Day>
        </PubMedPubDate>
      </History>
    </PubmedData>
  </PubmedArticle>
</PubmedArticleSet>'

  result <- table_articles_from_xml(xml)

  # Should extract first author only
  expect_equal(result$lastname[1], "FirstAuthor")
  expect_equal(result$firstname[1], "First")
})

test_that("table_articles_from_xml handles first author without ForeName", {
  xml <- '<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>41564340</PMID>
      <Article>
        <ArticleTitle>Structural Destabilization of FRMD3</ArticleTitle>
        <Abstract><AbstractText>Test abstract</AbstractText></Abstract>
        <Journal>
          <Title>ACS chemical neuroscience</Title>
          <ISOAbbreviation>ACS Chem Neurosci</ISOAbbreviation>
        </Journal>
        <AuthorList>
          <Author>
            <LastName>Diksha</LastName>
            <AffiliationInfo>All India Institute of Medical Sciences</AffiliationInfo>
          </Author>
        </AuthorList>
      </Article>
    </MedlineCitation>
    <PubmedData>
      <ArticleIdList>
        <ArticleId IdType="pubmed">41564340</ArticleId>
      </ArticleIdList>
      <History>
        <PubMedPubDate Pubstatus="pubmed">
          <Year>2026</Year><Month>2</Month><Day>4</Day>
        </PubMedPubDate>
      </History>
    </PubmedData>
  </PubmedArticle>
</PubmedArticleSet>'

  result <- table_articles_from_xml(xml)

  expect_equal(nrow(result), 1)
  expect_equal(result$pmid[1], "41564340")
  expect_equal(result$lastname[1], "Diksha")
  expect_equal(result$firstname[1], "")
})

# ============================================================================
# table_articles_from_xml() Tests - Keywords and MeSH Terms
# ============================================================================

test_that("table_articles_from_xml concatenates keywords", {
  xml <- create_pubmed_xml(
    keywords = c("genetic variant", "rare disease", "exome sequencing"),
    mesh_terms = c()
  )
  result <- table_articles_from_xml(xml)

  expect_true(grepl("genetic variant", result$keywords[1]))
  expect_true(grepl("rare disease", result$keywords[1]))
  expect_true(grepl("exome sequencing", result$keywords[1]))
  expect_true(grepl("; ", result$keywords[1]))  # Semicolon separator
})

test_that("table_articles_from_xml concatenates MeSH terms", {
  xml <- create_pubmed_xml(
    keywords = c(),
    mesh_terms = c("Humans", "Mutation", "Phenotype")
  )
  result <- table_articles_from_xml(xml)

  expect_true(grepl("Humans", result$keywords[1]))
  expect_true(grepl("Mutation", result$keywords[1]))
  expect_true(grepl("Phenotype", result$keywords[1]))
})

test_that("table_articles_from_xml combines keywords and MeSH terms", {
  xml <- create_pubmed_xml(
    keywords = c("OMIM"),
    mesh_terms = c("Genetics")
  )
  result <- table_articles_from_xml(xml)

  expect_true(grepl("OMIM", result$keywords[1]))
  expect_true(grepl("Genetics", result$keywords[1]))
})

test_that("table_articles_from_xml removes duplicate keywords/MeSH", {
  xml <- create_pubmed_xml(
    keywords = c("Genetics", "Rare disease"),
    mesh_terms = c("Genetics")  # Duplicate with keywords
  )
  result <- table_articles_from_xml(xml)

  # Should appear only once due to unique()
  expect_equal(
    length(gregexpr("Genetics", result$keywords[1])[[1]]),
    1
  )
})

# ============================================================================
# table_articles_from_xml() Tests - Edge Cases
# ============================================================================

test_that("table_articles_from_xml handles multiple abstract sections", {
  xml <- '<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>12345678</PMID>
      <Article>
        <ArticleTitle>Structured Abstract Paper</ArticleTitle>
        <Abstract>
          <AbstractText Label="BACKGROUND">Background text here.</AbstractText>
          <AbstractText Label="METHODS">Methods text here.</AbstractText>
          <AbstractText Label="RESULTS">Results text here.</AbstractText>
          <AbstractText Label="CONCLUSIONS">Conclusions text here.</AbstractText>
        </Abstract>
        <Journal>
          <Title>Test Journal</Title>
          <ISOAbbreviation>Test J</ISOAbbreviation>
        </Journal>
        <AuthorList>
          <Author>
            <LastName>Smith</LastName>
            <ForeName>John</ForeName>
          </Author>
        </AuthorList>
      </Article>
    </MedlineCitation>
    <PubmedData>
      <ArticleIdList>
        <ArticleId IdType="pubmed">12345678</ArticleId>
      </ArticleIdList>
      <History>
        <PubMedPubDate Pubstatus="pubmed">
          <Year>2024</Year><Month>1</Month><Day>1</Day>
        </PubMedPubDate>
      </History>
    </PubmedData>
  </PubmedArticle>
</PubmedArticleSet>'

  result <- table_articles_from_xml(xml)

  # All abstract sections should be concatenated
  expect_true(grepl("Background text", result$abstract[1]))
  expect_true(grepl("Methods text", result$abstract[1]))
  expect_true(grepl("Results text", result$abstract[1]))
  expect_true(grepl("Conclusions text", result$abstract[1]))
})

test_that("table_articles_from_xml handles articles with multiple titles", {
  # Some articles have vernacular titles in addition to English titles
  xml <- '<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>12345678</PMID>
      <Article>
        <ArticleTitle>English Title First</ArticleTitle>
        <VernacularTitle>Titre Francais</VernacularTitle>
        <Abstract><AbstractText>Abstract</AbstractText></Abstract>
        <Journal>
          <Title>Test Journal</Title>
          <ISOAbbreviation>Test J</ISOAbbreviation>
        </Journal>
        <AuthorList>
          <Author>
            <LastName>Smith</LastName>
            <ForeName>John</ForeName>
          </Author>
        </AuthorList>
      </Article>
    </MedlineCitation>
    <PubmedData>
      <ArticleIdList>
        <ArticleId IdType="pubmed">12345678</ArticleId>
      </ArticleIdList>
      <History>
        <PubMedPubDate Pubstatus="pubmed">
          <Year>2024</Year><Month>1</Month><Day>1</Day>
        </PubMedPubDate>
      </History>
    </PubmedData>
  </PubmedArticle>
</PubmedArticleSet>'

  result <- table_articles_from_xml(xml)

  # Should concatenate titles with space
  expect_true(grepl("English Title First", result$title[1]))
})

test_that("table_articles_from_xml returns tibble with expected columns", {
  xml <- create_pubmed_xml()
  result <- table_articles_from_xml(xml)

  expected_columns <- c(
    "pmid", "doi", "title", "abstract", "jabbrv", "journal",
    "keywords", "year", "month", "day", "lastname", "firstname", "address"
  )

  expect_true(all(expected_columns %in% names(result)))
  expect_equal(nrow(result), 1)
})

test_that("table_articles_from_xml returns one row per PubMed article", {
  xml <- '<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>11111111</PMID>
      <Article>
        <ArticleTitle>First article</ArticleTitle>
        <Abstract><AbstractText>First abstract</AbstractText></Abstract>
        <Journal><Title>J One</Title><ISOAbbreviation>J1</ISOAbbreviation></Journal>
        <AuthorList><Author><LastName>A</LastName><ForeName>B</ForeName></Author></AuthorList>
      </Article>
    </MedlineCitation>
    <PubmedData><History>
      <PubMedPubDate PubStatus="pubmed"><Year>2024</Year><Month>1</Month><Day>1</Day></PubMedPubDate>
    </History></PubmedData>
  </PubmedArticle>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>22222222</PMID>
      <Article>
        <ArticleTitle>Second article</ArticleTitle>
        <Abstract><AbstractText>Second abstract</AbstractText></Abstract>
        <Journal><Title>J Two</Title><ISOAbbreviation>J2</ISOAbbreviation></Journal>
        <AuthorList><Author><LastName>C</LastName><ForeName>D</ForeName></Author></AuthorList>
      </Article>
    </MedlineCitation>
    <PubmedData><History>
      <PubMedPubDate PubStatus="pubmed"><Year>2024</Year><Month>2</Month><Day>2</Day></PubMedPubDate>
    </History></PubmedData>
  </PubmedArticle>
</PubmedArticleSet>'

  result <- table_articles_from_xml(xml)

  expect_equal(result$pmid, c("11111111", "22222222"))
  expect_equal(result$title, c("First article", "Second article"))
})

test_that("table_articles_from_xml handles empty keywords and MeSH", {
  xml <- create_pubmed_xml(keywords = c(), mesh_terms = c())
  result <- table_articles_from_xml(xml)

  # keywords should be empty or just whitespace
  expect_true(result$keywords[1] == "" || nchar(trimws(result$keywords[1])) == 0)
})
