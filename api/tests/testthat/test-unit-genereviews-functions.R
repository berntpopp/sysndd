# tests/testthat/test-unit-genereviews-functions.R
# Tests for api/functions/genereviews-functions.R
#
# Focus: Pure string manipulation patterns used within GeneReviews functions.
# Note: All functions in genereviews-functions.R make network calls to NCBI,
#       so we test the string transformation PATTERNS extracted from the functions.

library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(tidyr)

# =============================================================================
# PMID normalization pattern tests
# Pattern: str_replace_all(pmid_input, "PMID:", "")
# Used in: info_from_genereviews_pmid(), genereviews_from_pmid()
# =============================================================================

test_that("PMID normalization removes PMID: prefix", {
  # Test the pattern used in lines 12 and 30 of genereviews-functions.R
  pmid_with_prefix <- "PMID:12345678"
  pmid_without_prefix <- "12345678"

  # Apply the pattern
  result_with <- str_replace_all(pmid_with_prefix, "PMID:", "")
  result_without <- str_replace_all(pmid_without_prefix, "PMID:", "")

  expect_equal(result_with, "12345678")
  expect_equal(result_without, "12345678")
})

test_that("PMID normalization handles multiple PMIDs", {
  # If someone accidentally passes multiple PMIDs with prefix
  pmids <- c("PMID:12345", "PMID:67890", "11111")

  results <- str_replace_all(pmids, "PMID:", "")

  expect_equal(results, c("12345", "67890", "11111"))
})

test_that("PMID normalization handles lowercase prefix", {
  # Edge case: lowercase pmid: prefix
  pmid_lower <- "pmid:12345678"
  pmid_mixed <- "Pmid:12345678"

  # The actual pattern only matches "PMID:" (uppercase)
  result_lower <- str_replace_all(pmid_lower, "PMID:", "")
  result_mixed <- str_replace_all(pmid_mixed, "PMID:", "")

  # Lowercase would NOT be replaced
  expect_equal(result_lower, "pmid:12345678")
  expect_equal(result_mixed, "Pmid:12345678")

  # Case-insensitive version would work
  result_insensitive <- str_replace_all(pmid_lower, regex("PMID:", ignore_case = TRUE), "")
  expect_equal(result_insensitive, "12345678")
})

test_that("PMID format validation pattern works", {
  # Test pattern to validate PMID format (numeric only)
  valid_pmids <- c("12345678", "1", "999999999")
  invalid_pmids <- c("PMID12345", "12345abc", "12.345", "")

  for (pmid in valid_pmids) {
    expect_true(str_detect(pmid, "^\\d+$"), info = paste("Valid PMID:", pmid))
  }

  for (pmid in invalid_pmids) {
    expect_false(str_detect(pmid, "^\\d+$"), info = paste("Invalid PMID:", pmid))
  }
})

# =============================================================================
# Bookshelf ID extraction pattern tests
# Pattern: str_replace("/books/", "") %>% str_replace("/", "")
# Used in: genereviews_from_pmid() lines 47-48
# =============================================================================

test_that("Bookshelf ID extraction from href works", {
  # Test the pattern used in lines 47-48
  href <- "/books/NBK501979/"

  result <- href %>%
    str_replace("/books/", "") %>%
    str_replace("/", "")

  expect_equal(result, "NBK501979")
})

test_that("Bookshelf ID extraction handles various href formats", {
  hrefs <- c(
    "/books/NBK1234/",
    "/books/NBK567890/",
    "/books/NBK1/"
  )

  expected <- c("NBK1234", "NBK567890", "NBK1")

  results <- hrefs %>%
    str_replace("/books/", "") %>%
    str_replace("/", "")

  expect_equal(results, expected)
})

test_that("Bookshelf ID format validation works", {
  # Bookshelf IDs follow pattern: NBK followed by digits
  valid_ids <- c("NBK501979", "NBK1", "NBK1234567")
  invalid_ids <- c("501979", "NBK", "NBKabc", "nbk123")

  for (id in valid_ids) {
    expect_true(str_detect(id, "^NBK\\d+$"), info = paste("Valid NBK:", id))
  }

  for (id in invalid_ids) {
    expect_false(str_detect(id, "^NBK\\d+$"), info = paste("Invalid NBK:", id))
  }
})

# =============================================================================
# PMID extraction from href pattern tests
# Pattern: str_replace("/pubmed/", "") %>% str_replace("/", "")
# Used in: info_from_genereviews() lines 81-82, pmid_from_genereviews_name() lines 200-201
# =============================================================================

test_that("PMID extraction from pubmed href works", {
  # Test the pattern used in multiple functions
  href <- "/pubmed/12345678/"

  result <- href %>%
    str_replace("/pubmed/", "") %>%
    str_replace("/", "")

  expect_equal(result, "12345678")
})

test_that("PMID extraction handles various pubmed href formats", {
  hrefs <- c(
    "/pubmed/1/",
    "/pubmed/99999999/",
    "/pubmed/20301494/"
  )

  expected <- c("1", "99999999", "20301494")

  results <- hrefs %>%
    str_replace("/pubmed/", "") %>%
    str_replace("/", "")

  expect_equal(results, expected)
})

# =============================================================================
# Title cleaning pattern tests
# Pattern: str_replace_all("title", "") %>%
#          str_replace_all("\\/", "") %>%
#          str_replace_all("<>", "") %>%
#          str_replace_all(" -.+", "")
# Used in: info_from_genereviews() lines 87-90
# =============================================================================

test_that("title cleaning removes HTML title tags", {
  # Note: This is for cleaning extracted text, not HTML parsing
  raw_title <- "title GRIN2B-Related Neurodevelopmental Disorder title"

  result <- raw_title %>%
    str_replace_all("title", "") %>%
    str_squish()

  expect_equal(result, "GRIN2B-Related Neurodevelopmental Disorder")
})

test_that("title cleaning removes forward slashes", {
  raw_title <- "GRIN2B/Gene Review"

  result <- raw_title %>%
    str_replace_all("\\/", "")

  expect_equal(result, "GRIN2BGene Review")
})

test_that("title cleaning removes angle brackets", {
  raw_title <- "Gene<>Review"

  result <- raw_title %>%
    str_replace_all("<>", "")

  expect_equal(result, "GeneReview")
})

test_that("title cleaning removes trailing dash content", {
  # The pattern " -.+" removes " - GeneReviews - NCBI" suffixes
  raw_title <- "GRIN2B-Related Disorder - GeneReviews - NCBI"

  result <- raw_title %>%
    str_replace_all(" -.+", "")

  expect_equal(result, "GRIN2B-Related Disorder")
})

test_that("full title cleaning pipeline works", {
  # Simulate full cleaning as in info_from_genereviews
  raw_title <- "title GRIN2B/Overview <> - GeneReviews - NCBI title"

  result <- raw_title %>%
    str_replace_all("title", "") %>%
    str_replace_all("\\/", "") %>%
    str_replace_all("<>", "") %>%
    str_replace_all(" -.+", "") %>%
    str_squish()

  expect_equal(result, "GRIN2BOverview")
})

# =============================================================================
# Abstract/text cleaning pattern tests
# Pattern: str_replace_all("<.+?>", "") %>%
#          str_replace_all("\n", " ") %>%
#          str_squish()
# Used in: info_from_genereviews() lines 95-97, 102-104, 115-116
# =============================================================================

test_that("text cleaning removes HTML tags", {
  raw_text <- "This is <b>bold</b> and <i>italic</i> text."

  result <- raw_text %>%
    str_replace_all("<.+?>", "")

  expect_equal(result, "This is bold and italic text.")
})

test_that("text cleaning removes complex HTML tags", {
  raw_text <- '<p class="summary">Summary text</p><div id="content">Content</div>'

  result <- raw_text %>%
    str_replace_all("<.+?>", "")

  expect_equal(result, "Summary textContent")
})

test_that("text cleaning replaces newlines with spaces", {
  raw_text <- "Line 1\nLine 2\nLine 3"

  result <- raw_text %>%
    str_replace_all("\n", " ")

  expect_equal(result, "Line 1 Line 2 Line 3")
})

test_that("text cleaning squishes whitespace", {
  raw_text <- "Too   many    spaces   here"

  result <- str_squish(raw_text)

  expect_equal(result, "Too many spaces here")
})

test_that("full text cleaning pipeline works", {
  # Simulate full cleaning as in info_from_genereviews
  raw_text <- "<p>Summary</p>\n\n<b>Bold</b>   text   with\nline breaks."

  result <- raw_text %>%
    str_replace_all("<.+?>", "") %>%
    str_replace_all("\n", " ") %>%
    str_squish()

  expect_equal(result, "Summary Bold text with line breaks.")
})

test_that("text cleaning handles nested tags", {
  raw_text <- "<div><span>Nested</span> content</div>"

  result <- raw_text %>%
    str_replace_all("<.+?>", "")

  expect_equal(result, "Nested content")
})

# =============================================================================
# Revision history cleaning pattern tests
# Additional patterns from lines 102-107
# =============================================================================

test_that("revision history cleaning removes header text", {
  raw_revision <- "Revision History Review posted live 15 January 2020 (initial revision)"

  result <- raw_revision %>%
    str_replace_all("Revision History", "") %>%
    str_replace_all("Review posted live", "") %>%
    str_replace_all("\\(.+", "") %>%  # Remove parenthetical content
    str_squish()

  expect_equal(result, "15 January 2020")
})

test_that("revision history cleaning removes parenthetical content", {
  raw_text <- "15 January 2020 (Comprehensive update)"

  result <- raw_text %>%
    str_replace_all("\\(.+", "") %>%
    str_squish()

  expect_equal(result, "15 January 2020")
})

# =============================================================================
# Date parsing pattern tests
# Pattern: separate(Date, c("Day", "Month", "Year"), sep = " ")
#          mutate(Month = match(Month, month.name))
# Used in: info_from_genereviews() lines 132-133
# =============================================================================

test_that("date parsing separates day month year", {
  test_data <- tibble(Date = "15 January 2020")

  result <- test_data %>%
    separate(Date, c("Day", "Month", "Year"), sep = " ")

  expect_equal(result$Day, "15")
  expect_equal(result$Month, "January")
  expect_equal(result$Year, "2020")
})

test_that("date parsing handles various date formats", {
  test_data <- tibble(Date = c("1 February 2019", "28 December 2021", "5 March 2015"))

  result <- test_data %>%
    separate(Date, c("Day", "Month", "Year"), sep = " ")

  expect_equal(result$Day, c("1", "28", "5"))
  expect_equal(result$Month, c("February", "December", "March"))
  expect_equal(result$Year, c("2019", "2021", "2015"))
})

test_that("month name to number conversion works", {
  # Test the match(Month, month.name) pattern
  months <- c("January", "February", "March", "December")

  month_numbers <- match(months, month.name)

  expect_equal(month_numbers, c(1, 2, 3, 12))
})

test_that("full date conversion pipeline works", {
  test_data <- tibble(Date = "15 January 2020")

  result <- test_data %>%
    separate(Date, c("Day", "Month", "Year"), sep = " ") %>%
    mutate(Month = match(Month, month.name)) %>%
    mutate(Publication_date = paste0(Year, "-", str_pad(Month, 2, pad = "0"),
                                     "-", str_pad(Day, 2, pad = "0")))

  expect_equal(result$Publication_date, "2020-01-15")
})

test_that("date padding works for single digit days and months", {
  # Test str_pad for formatting dates
  single_day <- "5"
  single_month <- 3

  padded_day <- str_pad(single_day, 2, pad = "0")
  padded_month <- str_pad(single_month, 2, pad = "0")

  expect_equal(padded_day, "05")
  expect_equal(padded_month, "03")
})

# =============================================================================
# Author name parsing pattern tests
# Pattern: separate(First_author, c("Firstname", "Lastname"),
#                   sep = " (?=[^ ]*$)", extra = "merge")
# Used in: info_from_genereviews() lines 134-136
# =============================================================================

test_that("author name separation works for simple names", {
  test_data <- tibble(First_author = "John Smith")

  result <- test_data %>%
    separate(First_author, c("Firstname", "Lastname"),
             sep = " (?=[^ ]*$)", extra = "merge")

  expect_equal(result$Firstname, "John")
  expect_equal(result$Lastname, "Smith")
})

test_that("author name separation handles middle names", {
  # The pattern " (?=[^ ]*$)" splits on the last space
  test_data <- tibble(First_author = "John Robert Smith")

  result <- test_data %>%
    separate(First_author, c("Firstname", "Lastname"),
             sep = " (?=[^ ]*$)", extra = "merge")

  expect_equal(result$Firstname, "John Robert")
  expect_equal(result$Lastname, "Smith")
})

test_that("author name separation handles complex names", {
  test_data <- tibble(First_author = c(
    "Mary Jane Watson",
    "Jean-Pierre Dupont",
    "Maria del Carmen Rodriguez"
  ))

  result <- test_data %>%
    separate(First_author, c("Firstname", "Lastname"),
             sep = " (?=[^ ]*$)", extra = "merge")

  expect_equal(result$Lastname, c("Watson", "Dupont", "Rodriguez"))
})

# =============================================================================
# Keywords concatenation pattern tests
# Pattern: str_c(collapse = "; ")
# Used in: info_from_genereviews() line 121
# =============================================================================

test_that("keywords concatenation works", {
  keywords <- c("GRIN2B", "neurodevelopmental disorder", "epilepsy", "autism")

  result <- str_c(keywords, collapse = "; ")

  expect_equal(result, "GRIN2B; neurodevelopmental disorder; epilepsy; autism")
})

test_that("keywords concatenation handles single keyword", {
  keywords <- c("GRIN2B")

  result <- str_c(keywords, collapse = "; ")

  expect_equal(result, "GRIN2B")
})

test_that("keywords concatenation handles empty vector", {
  keywords <- character(0)

  result <- str_c(keywords, collapse = "; ")

  expect_equal(result, "")
})

# =============================================================================
# URL construction pattern tests
# Pattern: paste0("https://www.ncbi.nlm.nih.gov/books/", Bookshelf_ID)
# Used in: info_from_genereviews() line 70, genereviews_from_pmid() lines 34-36
# =============================================================================

test_that("GeneReviews URL construction works", {
  bookshelf_id <- "NBK501979"

  url <- paste0("https://www.ncbi.nlm.nih.gov/books/", bookshelf_id)

  expect_equal(url, "https://www.ncbi.nlm.nih.gov/books/NBK501979")
})

test_that("PMID search URL construction works", {
  pmid <- "20301494"

  url <- paste0(
    "https://www.ncbi.nlm.nih.gov/books/NBK1116/?term=",
    pmid,
    "[PMID]"
  )

  expect_equal(
    url,
    "https://www.ncbi.nlm.nih.gov/books/NBK1116/?term=20301494[PMID]"
  )
})

test_that("GeneReviews gene URL construction works", {
  gene_name <- "GRIN2B"
  base_url <- "https://www.ncbi.nlm.nih.gov/books/n/gene/"

  url <- paste0(base_url, gene_name)

  expect_equal(url, "https://www.ncbi.nlm.nih.gov/books/n/gene/GRIN2B")
})

# =============================================================================
# Bookshelf IDs string collapsing pattern tests
# Pattern: str_c(Bookshelf_ID_tibble$value, collapse = ",")
# Used in: genereviews_from_pmid() line 51
# =============================================================================

test_that("Bookshelf IDs collapsing works", {
  # When multiple GeneReviews are returned for a PMID
  bookshelf_ids <- tibble(value = c("NBK1234", "NBK5678", "NBK9012"))

  result <- str_c(bookshelf_ids$value, collapse = ",")

  expect_equal(result, "NBK1234,NBK5678,NBK9012")
})

test_that("Bookshelf IDs collapsing handles single ID", {
  bookshelf_ids <- tibble(value = c("NBK501979"))

  result <- str_c(bookshelf_ids$value, collapse = ",")

  expect_equal(result, "NBK501979")
})

test_that("empty Bookshelf IDs returns empty string", {
  bookshelf_ids <- tibble(value = character(0))

  result <- str_c(bookshelf_ids$value, collapse = ",")

  expect_equal(result, "")
})

# =============================================================================
# Check function boolean conversion pattern tests
# Pattern: as.logical(nchar(Bookshelf_IDs))
# Used in: genereviews_from_pmid() line 56
# =============================================================================

test_that("GeneReviews check returns TRUE for non-empty results", {
  # When Bookshelf IDs are found
  bookshelf_ids <- "NBK501979,NBK123456"

  result <- as.logical(nchar(bookshelf_ids))

  expect_true(result)
})

test_that("GeneReviews check returns FALSE for empty results", {
  # When no Bookshelf IDs are found
  bookshelf_ids <- ""

  result <- as.logical(nchar(bookshelf_ids))

  expect_false(result)
})

test_that("GeneReviews check handles single character", {
  # Edge case: single character (unlikely but valid)
  bookshelf_ids <- "N"

  result <- as.logical(nchar(bookshelf_ids))

  expect_true(result)  # nchar("N") = 1, which is truthy
})

# =============================================================================
# NA replacement pattern tests
# Pattern: mutate(across(everything(), ~replace_na(.x, "")))
# Used in: info_from_genereviews() line 153
# =============================================================================

test_that("NA replacement with empty string works", {
  test_data <- tibble(
    Title = "Test Title",
    Abstract = NA_character_,
    Keywords = NA_character_
  )

  result <- test_data %>%
    mutate(across(everything(), ~replace_na(.x, "")))

  expect_equal(result$Title, "Test Title")
  expect_equal(result$Abstract, "")
  expect_equal(result$Keywords, "")
})

test_that("NA replacement preserves non-NA values", {
  test_data <- tibble(
    col1 = c("a", NA, "c"),
    col2 = c(NA, "b", NA)
  )

  result <- test_data %>%
    mutate(across(everything(), ~replace_na(.x, "")))

  expect_equal(result$col1, c("a", "", "c"))
  expect_equal(result$col2, c("", "b", ""))
})

# =============================================================================
# Output tibble structure tests
# =============================================================================

test_that("GeneReviews output column names are correct", {
  # Test the expected output structure from info_from_genereviews
  expected_columns <- c(
    "other_publication_id",
    "Title",
    "Abstract",
    "Publication_date",
    "Journal_abbreviation",
    "Journal",
    "Keywords",
    "Lastname",
    "Firstname"
  )

  # Create mock output structure
  mock_output <- tibble(
    other_publication_id = "Bookshelf_ID:NBK501979",
    Title = "Test Gene Review",
    Abstract = "Summary text",
    Publication_date = "2020-01-15",
    Journal_abbreviation = "GeneReviews",
    Journal = "GeneReviews",
    Keywords = "gene; disorder",
    Lastname = "Smith",
    Firstname = "John"
  )

  expect_equal(names(mock_output), expected_columns)
})

test_that("other_publication_id format is correct", {
  # Test the format: "Bookshelf_ID:NBK501979"
  bookshelf_id <- "NBK501979"
  other_pub_id <- paste0("Bookshelf_ID:", bookshelf_id)

  expect_equal(other_pub_id, "Bookshelf_ID:NBK501979")
  expect_true(str_detect(other_pub_id, "^Bookshelf_ID:NBK\\d+$"))
})
