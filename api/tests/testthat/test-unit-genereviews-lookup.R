# tests/testthat/test-unit-genereviews-lookup.R
# Tests for api/functions/genereviews-lookup.R
#
# These tests mock the internal E-utilities transport (genereviews_eutils_xml)
# so no network is touched. Per AGENTS.md, tests that mock NCBI stub the direct
# helper rather than the network. We validate parsing, the has/missing branches,
# input validation, the batch shaping, and the error contract that keeps the
# success-only cache from being poisoned.

library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(xml2)

# Provide the infix default operator used by the lookup module if not present.
if (!exists("%||%")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Minimal validate_gene_symbol stand-in (the real one lives in
# external-proxy-functions.R; provide it if not already sourced).
if (!exists("validate_gene_symbol", mode = "function")) {
  validate_gene_symbol <- function(symbol) {
    if (is.null(symbol) || length(symbol) == 0 || is.na(symbol) || nchar(symbol) == 0) {
      return(FALSE)
    }
    grepl("^[A-Z][A-Za-z0-9-]+$", symbol)
  }
}

# Provide the success-only memoise wrapper as a passthrough if not sourced, so
# fetch_genereviews_availability_mem can be created when the module loads.
if (!exists("memoise_external_success_only", mode = "function")) {
  memoise_external_success_only <- function(f, cache) f
}
if (!exists("cache_static")) {
  cache_static <- NULL
}

source_api_file("functions/genereviews-lookup.R", local = FALSE)

# ---------------------------------------------------------------------------
# Helpers to build fake E-utilities XML documents
# ---------------------------------------------------------------------------

fake_esearch_xml <- function(ids = c("12345")) {
  id_nodes <- paste0("<Id>", ids, "</Id>", collapse = "")
  xml2::read_xml(paste0(
    "<eSearchResult><Count>", length(ids), "</Count>",
    "<IdList>", id_nodes, "</IdList></eSearchResult>"
  ))
}

fake_esearch_empty <- function() {
  xml2::read_xml("<eSearchResult><Count>0</Count><IdList/></eSearchResult>")
}

fake_esummary_xml <- function(nbk = "NBK1116", title = "GRIN2B-Related Neurodevelopmental Disorder") {
  xml2::read_xml(paste0(
    "<eSummaryResult><DocSum>",
    "<Id>12345</Id>",
    "<Item Name='AccessionID' Type='String'>", nbk, "</Item>",
    "<Item Name='Title' Type='String'>", title, "</Item>",
    "</DocSum></eSummaryResult>"
  ))
}

# ---------------------------------------------------------------------------
# Bookshelf URL helper
# ---------------------------------------------------------------------------

test_that("genereviews_bookshelf_url builds the public URL", {
  expect_equal(
    genereviews_bookshelf_url("NBK1116"),
    "https://www.ncbi.nlm.nih.gov/books/NBK1116/"
  )
})

test_that("genereviews_bookshelf_url returns NA for missing id", {
  expect_true(is.na(genereviews_bookshelf_url(NA_character_)))
  expect_true(is.na(genereviews_bookshelf_url("")))
  expect_true(is.na(genereviews_bookshelf_url(NULL)))
})

# ---------------------------------------------------------------------------
# Single-gene availability lookup
# ---------------------------------------------------------------------------

test_that("availability returns has_genereview = TRUE with NBK id when a chapter exists", {
  fake_xml <- function(endpoint, query) {
    if (endpoint == "esearch.fcgi") fake_esearch_xml("12345") else fake_esummary_xml()
  }
  mockery::stub(fetch_genereviews_availability, "genereviews_eutils_xml", fake_xml)

  result <- fetch_genereviews_availability("GRIN2B")

  expect_true(result$has_genereview)
  expect_equal(result$nbk_id, "NBK1116")
  expect_equal(result$url, "https://www.ncbi.nlm.nih.gov/books/NBK1116/")
  expect_equal(result$title, "GRIN2B-Related Neurodevelopmental Disorder")
  expect_equal(result$chapter_count, 1L)
  expect_null(result$error)
})

test_that("availability returns has_genereview = FALSE when no chapter exists", {
  fake_xml <- function(endpoint, query) fake_esearch_empty()
  mockery::stub(fetch_genereviews_availability, "genereviews_eutils_xml", fake_xml)

  result <- fetch_genereviews_availability("SOMEGENE1")

  expect_false(result$has_genereview)
  expect_true(is.na(result$nbk_id))
  expect_true(is.na(result$url))
  expect_equal(result$chapter_count, 0L)
  expect_null(result$error)
})

test_that("availability rejects invalid gene symbols without calling NCBI", {
  # No stub installed: if it tried to call out, the test would error.
  result <- fetch_genereviews_availability("not a gene")
  expect_false(result$has_genereview)
  expect_true(isTRUE(result$not_found))
})

test_that("availability returns the error contract on upstream failure (no cache poison)", {
  failing <- function(endpoint, query) stop("NCBI timeout")
  mockery::stub(fetch_genereviews_availability, "genereviews_eutils_xml", failing)

  result <- fetch_genereviews_availability("GRIN2B")

  expect_true(isTRUE(result$error))
  expect_equal(result$source, "genereviews")
  expect_equal(result$status, 503L)
  expect_match(result$message, "NCBI timeout")
  # The error result must NOT carry a has_genereview success field.
  expect_null(result$has_genereview)
})

# ---------------------------------------------------------------------------
# Batch lookup shaping
# ---------------------------------------------------------------------------

test_that("batch lookup returns one row per unique symbol with correct columns", {
  fake_mem <- function(symbol) {
    if (symbol == "GRIN2B") {
      list(
        source = "genereviews", gene_symbol = symbol, has_genereview = TRUE,
        nbk_id = "NBK1116", url = "https://www.ncbi.nlm.nih.gov/books/NBK1116/",
        title = "GRIN2B chapter", chapter_count = 1L
      )
    } else {
      list(
        source = "genereviews", gene_symbol = symbol, has_genereview = FALSE,
        nbk_id = NA_character_, url = NA_character_, title = NA_character_,
        chapter_count = 0L
      )
    }
  }
  mockery::stub(
    fetch_genereviews_availability_batch,
    "fetch_genereviews_availability_mem",
    fake_mem
  )

  out <- fetch_genereviews_availability_batch(c("GRIN2B", "FOO1", "GRIN2B"))

  expect_equal(nrow(out), 2L) # de-duplicated
  expect_setequal(out$gene_symbol, c("GRIN2B", "FOO1"))
  expect_true(out$has_genereview[out$gene_symbol == "GRIN2B"])
  expect_false(out$has_genereview[out$gene_symbol == "FOO1"])
  expect_false(any(out$lookup_error))
  expect_setequal(
    names(out),
    c("gene_symbol", "has_genereview", "nbk_id", "url", "title",
      "chapter_count", "lookup_error")
  )
})

test_that("batch lookup marks lookup_error rows for upstream failures", {
  fake_mem <- function(symbol) {
    list(error = TRUE, source = "genereviews", gene_symbol = symbol, message = "boom")
  }
  mockery::stub(
    fetch_genereviews_availability_batch,
    "fetch_genereviews_availability_mem",
    fake_mem
  )

  out <- fetch_genereviews_availability_batch(c("GRIN2B"))

  expect_equal(nrow(out), 1L)
  expect_true(out$lookup_error[1])
  expect_true(is.na(out$has_genereview[1]))
})

test_that("batch lookup returns an empty typed tibble for empty input", {
  out <- fetch_genereviews_availability_batch(character(0))
  expect_equal(nrow(out), 0L)
  expect_true(all(c("gene_symbol", "has_genereview", "lookup_error") %in% names(out)))
})
