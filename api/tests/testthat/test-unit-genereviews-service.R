# tests/testthat/test-unit-genereviews-service.R
# Tests for api/services/genereviews-service.R
#
# DB-touching helpers (genereviews_entity_gene_set, svc_genereviews_existing_links,
# fetch_genereviews_availability_batch, review_find_by_entity, new_publication,
# put_post_db_pub_con) are stubbed via mockery so these tests run without a live
# database. We validate the coverage merge logic, the needs_attention flag, the
# CSV export shape, and the attach input-validation branches.

library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(readr)

if (!exists("%||%")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# normalize_pubmed_ids is used by the attach validation; provide a stand-in if
# publication-functions.R is not sourced into the test scope.
if (!exists("normalize_pubmed_ids", mode = "function")) {
  normalize_pubmed_ids <- function(pmid_input) {
    if (is.null(pmid_input) || length(pmid_input) == 0) {
      return(character())
    }
    pmids <- as.character(unlist(pmid_input, use.names = FALSE))
    pmids <- trimws(pmids)
    pmids <- sub("^PMID:", "", pmids, ignore.case = TRUE)
    pmids[!is.na(pmids) & nzchar(pmids)]
  }
}

# Stub the lookup batch presence so the service file can source.
if (!exists("fetch_genereviews_availability_batch", mode = "function")) {
  fetch_genereviews_availability_batch <- function(gene_symbols) tibble::tibble()
}

source_api_file("services/genereviews-service.R", local = FALSE)

# ---------------------------------------------------------------------------
# isTRUE_vec helper
# ---------------------------------------------------------------------------

test_that("isTRUE_vec treats NA as FALSE and is vectorised", {
  expect_equal(isTRUE_vec(c(TRUE, FALSE, NA)), c(TRUE, FALSE, FALSE))
})

# ---------------------------------------------------------------------------
# Coverage merge (cheap path, no live lookup)
# ---------------------------------------------------------------------------

test_that("coverage (no live) flags already-linked entities and leaves availability NA", {
  entities <- tibble::tibble(
    entity_id = c(1L, 2L, 3L),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    symbol = c("GRIN2B", "FOO1", "BAR2"),
    disease_ontology_name = c("Disease A", "Disease B", "Disease C")
  )
  links <- tibble::tibble(
    entity_id = c(1L),
    publication_id = c("PMID:20301494"),
    nbk_id = c("NBK1116"),
    title = c("GRIN2B chapter")
  )

  mockery::stub(svc_genereviews_coverage, "genereviews_entity_gene_set", function() entities)
  mockery::stub(svc_genereviews_coverage, "svc_genereviews_existing_links", function() links)

  out <- svc_genereviews_coverage(include_live = FALSE)

  expect_equal(nrow(out), 3L)
  expect_true(out$already_linked[out$entity_id == 1L])
  expect_false(out$already_linked[out$entity_id == 2L])
  expect_equal(out$linked_pmid[out$entity_id == 1L], "PMID:20301494")
  expect_true(all(is.na(out$genereview_available)))
  expect_true(all(is.na(out$needs_attention)))
})

test_that("coverage (live) sets needs_attention when available upstream but not linked", {
  entities <- tibble::tibble(
    entity_id = c(1L, 2L, 3L),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    symbol = c("GRIN2B", "FOO1", "BAR2"),
    disease_ontology_name = c("Disease A", "Disease B", "Disease C")
  )
  # Entity 1 already linked. Entities 2 and 3 not linked.
  links <- tibble::tibble(
    entity_id = c(1L),
    publication_id = c("PMID:20301494"),
    nbk_id = c("NBK1116"),
    title = c("GRIN2B chapter")
  )
  # FOO1 has an upstream chapter (gap -> needs attention); BAR2 has none;
  # GRIN2B has one but is already linked (no attention needed).
  availability <- tibble::tibble(
    gene_symbol = c("GRIN2B", "FOO1", "BAR2"),
    has_genereview = c(TRUE, TRUE, FALSE),
    nbk_id = c("NBK1116", "NBK2222", NA_character_),
    url = c("u1", "u2", NA_character_),
    title = c("t1", "t2", NA_character_),
    chapter_count = c(1L, 1L, 0L),
    lookup_error = c(FALSE, FALSE, FALSE)
  )

  mockery::stub(svc_genereviews_coverage, "genereviews_entity_gene_set", function() entities)
  mockery::stub(svc_genereviews_coverage, "svc_genereviews_existing_links", function() links)
  mockery::stub(
    svc_genereviews_coverage,
    "fetch_genereviews_availability_batch",
    function(symbols) availability
  )

  out <- svc_genereviews_coverage(include_live = TRUE)

  expect_true(out$needs_attention[out$entity_id == 2L]) # FOO1 gap
  expect_false(out$needs_attention[out$entity_id == 1L]) # GRIN2B linked
  expect_false(out$needs_attention[out$entity_id == 3L]) # BAR2 no chapter
  expect_equal(out$available_nbk_id[out$entity_id == 2L], "NBK2222")
})

test_that("coverage returns an empty typed tibble when no entities exist", {
  mockery::stub(
    svc_genereviews_coverage, "genereviews_entity_gene_set",
    function() tibble::tibble(
      entity_id = integer(), hgnc_id = character(),
      symbol = character(), disease_ontology_name = character()
    )
  )
  out <- svc_genereviews_coverage(include_live = FALSE)
  expect_equal(nrow(out), 0L)
  expect_true(all(c("entity_id", "symbol", "already_linked", "needs_attention") %in% names(out)))
})

# ---------------------------------------------------------------------------
# CSV export
# ---------------------------------------------------------------------------

test_that("coverage CSV export produces a header row and data rows", {
  coverage <- tibble::tibble(
    entity_id = 1L,
    hgnc_id = "HGNC:1",
    symbol = "GRIN2B",
    disease_ontology_name = "Disease A",
    already_linked = TRUE,
    linked_pmid = "PMID:20301494",
    linked_nbk_id = "NBK1116",
    genereview_available = NA,
    available_nbk_id = NA_character_,
    available_url = NA_character_,
    available_title = NA_character_,
    lookup_error = FALSE,
    needs_attention = NA
  )

  csv <- svc_genereviews_coverage_csv(coverage)

  expect_true(grepl("symbol", csv))
  expect_true(grepl("GRIN2B", csv))
  expect_true(grepl("already_linked", csv))
  # One header line + one data line + trailing newline.
  expect_equal(length(strsplit(csv, "\n")[[1]]), 2L)
})

# ---------------------------------------------------------------------------
# Attach validation branches
# ---------------------------------------------------------------------------

test_that("attach rejects invalid entity_id", {
  res <- svc_genereviews_attach_to_entity("not-an-int", "20301494")
  expect_equal(res$status, 400)
  expect_match(res$message, "entity_id")
})

test_that("attach rejects invalid PMID", {
  res <- svc_genereviews_attach_to_entity(1L, "not-a-pmid")
  expect_equal(res$status, 400)
  expect_match(res$message, "PMID")
})

test_that("attach rejects a PMID that is not a GeneReviews chapter (before any DB access)", {
  # The GeneReviews-chapter check now runs before the DB lookups, so a non-
  # GeneReviews PMID short-circuits to 400 without needing `pool`.
  mockery::stub(
    svc_genereviews_attach_to_entity, "genereviews_from_pmid",
    function(pmid_input, check = FALSE) FALSE
  )
  res <- svc_genereviews_attach_to_entity(1L, "20301494")
  expect_equal(res$status, 400)
  expect_match(res$message, "GeneReviews chapter")
})

test_that("attach returns 404 when the entity has no review", {
  mockery::stub(
    svc_genereviews_attach_to_entity, "genereviews_from_pmid",
    function(pmid_input, check = FALSE) TRUE
  )
  mockery::stub(
    svc_genereviews_attach_to_entity, "review_find_by_entity",
    function(entity_id) tibble::tibble(review_id = integer(), is_primary = integer())
  )
  res <- svc_genereviews_attach_to_entity(1L, "20301494")
  expect_equal(res$status, 404)
})
