# test-unit-publication-functions.R
# Unit tests for api/functions/publication-functions.R
#
# These tests cover table_articles_from_xml() which is a pure XML parsing
# function that extracts article data from PubMed XML format.
#
# Functions tested:
# - table_articles_from_xml(): XML to tibble extraction
#
# NOT tested (requires database or network):
# - check_pmid(): Calls PubMed API
# - new_publication(): Database writes
# - info_from_pmid(): Calls PubMed API

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

# Load required packages
library(dplyr)
library(tibble)
library(stringr)
library(xml2)
library(purrr)
library(rvest)  # Required for genereviews-functions.R

# Source functions being tested
# publication-functions.R sources genereviews-functions.R with relative path,
# so we change to api directory and source from there
# We need to stay in api_dir for the function to work correctly since
# the internal source() call uses relative paths
original_wd <- getwd()
setwd(api_dir)
source("functions/publication-functions.R")

# ============================================================================
# Helper function to create mock PubMed XML
# ============================================================================

create_pubmed_xml <- function(
  pmid = "12345678",
  doi = "10.1234/test.2024",
  title = "Test Article Title",
  abstract = "This is the test abstract.",
  journal = "Test Journal of Science",
  journal_abbrev = "Test J Sci",
  keywords = c("keyword1", "keyword2"),
  mesh_terms = c("MeSH Term 1", "MeSH Term 2"),
  year = "2024",
  month = "6",
  day = "15",
  author_last = "Smith",
  author_first = "John",
  affiliation = "Test University",
  collective_name = NULL,
  include_doi = TRUE,
  doi_location = "elocation"  # elocation, articleid_eid, articleid_id
) {
  # Build DOI section based on location
  doi_section <- ""
  if (include_doi) {
    if (doi_location == "elocation") {
      doi_section <- sprintf('<ELocationID EIdType="doi">%s</ELocationID>', doi)
    }
  }

  # ArticleId DOI (secondary location)
  articleid_doi <- ""
  if (include_doi && doi_location == "articleid_eid") {
    articleid_doi <- sprintf('<ArticleId EIdType="doi">%s</ArticleId>', doi)
  }

  # ArticleId DOI with IdType (tertiary location)
  articleid_doi_idtype <- ""
  if (include_doi && doi_location == "articleid_id") {
    articleid_doi_idtype <- sprintf('<ArticleId IdType="doi">%s</ArticleId>', doi)
  }

  # Build keyword section
  keyword_section <- ""
  if (length(keywords) > 0) {
    keyword_elements <- paste0("<Keyword>", keywords, "</Keyword>", collapse = "\n        ")
    keyword_section <- sprintf("<KeywordList>\n        %s\n      </KeywordList>", keyword_elements)
  }

  # Build MeSH section
  mesh_section <- ""
  if (length(mesh_terms) > 0) {
    mesh_elements <- paste0("<DescriptorName>", mesh_terms, "</DescriptorName>", collapse = "\n        ")
    mesh_section <- sprintf("<MeshHeadingList>\n        %s\n      </MeshHeadingList>", mesh_elements)
  }

  # Build author section
  author_section <- ""
  if (!is.null(author_last) && !is.null(author_first)) {
    author_section <- sprintf(
      '<AuthorList>
        <Author>
          <LastName>%s</LastName>
          <ForeName>%s</ForeName>
          <AffiliationInfo>%s</AffiliationInfo>
        </Author>
      </AuthorList>',
      author_last, author_first, affiliation
    )
  } else if (!is.null(collective_name)) {
    author_section <- sprintf(
      '<AuthorList>
        <Author>
          <CollectiveName>%s</CollectiveName>
        </Author>
      </AuthorList>',
      collective_name
    )
  }

  # Build full XML
  # Note: The function uses "Pubstatus" (lowercase 's') in XPath, so we must match that
  xml <- sprintf('<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>%s</PMID>
      <Article>
        <ArticleTitle>%s</ArticleTitle>
        <Abstract>
          <AbstractText>%s</AbstractText>
        </Abstract>
        %s
        <Journal>
          <Title>%s</Title>
          <ISOAbbreviation>%s</ISOAbbreviation>
        </Journal>
        %s
      </Article>
      %s
      %s
    </MedlineCitation>
    <PubmedData>
      <ArticleIdList>
        <ArticleId IdType="pubmed">%s</ArticleId>
        %s
        %s
      </ArticleIdList>
      <History>
        <PubMedPubDate Pubstatus="pubmed">
          <Year>%s</Year>
          <Month>%s</Month>
          <Day>%s</Day>
        </PubMedPubDate>
      </History>
    </PubmedData>
  </PubmedArticle>
</PubmedArticleSet>',
    pmid, title, abstract, doi_section, journal, journal_abbrev,
    author_section, keyword_section, mesh_section,
    pmid, articleid_doi, articleid_doi_idtype, year, month, day
  )

  return(xml)
}

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

test_that("table_articles_from_xml uses current date when date missing", {
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

  # Should use current date
  current_year <- format(Sys.time(), "%Y")
  expect_equal(result$year[1], current_year)
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

test_that("table_articles_from_xml handles empty keywords and MeSH", {
  xml <- create_pubmed_xml(keywords = c(), mesh_terms = c())
  result <- table_articles_from_xml(xml)

  # keywords should be empty or just whitespace
  expect_true(result$keywords[1] == "" || nchar(trimws(result$keywords[1])) == 0)
})
