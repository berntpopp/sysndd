# tests/testthat/test-unit-omim-ndd-descendants.R
#
# Offline tests for the OMIM-NDD seed/descendant resolution chain (review
# follow-ups to the descendant-expansion fix):
#   omim_ndd_seed_term()            - env-configurable seed
#   omim_ndd_resolve_terms()        - seed + descendants (comparator side)
#   hpo_all_children_from_term_api()- JAX /descendants fetch (httr2)
#
# The live network path is not exercised here; httr2 (and, for the resolver, the
# fetcher) is mocked so we can cover the success, empty/malformed, and failure
# branches — including the observable warning + seed-only degradation that
# guards against silently re-introducing the single-seed under-capture bug.

library(testthat)
library(dplyr)
library(tibble)

# helper-paths.R (auto-loaded by setup.R) provides source_api_file().
source_api_file("functions/hpo-functions.R", local = FALSE)
source_api_file("functions/comparisons-omim.R", local = FALSE)

# ---------------------------------------------------------------------------
# omim_ndd_seed_term()
# ---------------------------------------------------------------------------

test_that("omim_ndd_seed_term reads OMIM_NDD_SEED_TERM with a safe default", {
  withr::local_envvar(OMIM_NDD_SEED_TERM = "HP:0000707")
  expect_equal(omim_ndd_seed_term(), "HP:0000707")

  # Empty/unset falls back to the published default.
  withr::local_envvar(OMIM_NDD_SEED_TERM = "")
  expect_equal(omim_ndd_seed_term(), "HP:0012759")
})

# ---------------------------------------------------------------------------
# omim_ndd_resolve_terms() (fetcher mocked)
# ---------------------------------------------------------------------------

test_that("omim_ndd_resolve_terms returns seed + descendants on success", {
  mockery::stub(
    omim_ndd_resolve_terms, "hpo_all_children_from_term_api",
    function(seed, ...) tibble::tibble(value = c(seed, "HP:0001249", "HP:0010864"))
  )
  expect_setequal(
    omim_ndd_resolve_terms("HP:0012759"),
    c("HP:0012759", "HP:0001249", "HP:0010864")
  )
})

test_that("omim_ndd_resolve_terms degrades to seed-only when the fetch errors", {
  mockery::stub(
    omim_ndd_resolve_terms, "hpo_all_children_from_term_api",
    function(seed, ...) stop("network down")
  )
  # Degradation is intentional (better than aborting OMIM on a transient blip)
  # but must never drop the seed itself.
  expect_equal(omim_ndd_resolve_terms("HP:0012759"), "HP:0012759")
})

test_that("omim_ndd_resolve_terms always includes the seed even if it is missing from the response", {
  mockery::stub(
    omim_ndd_resolve_terms, "hpo_all_children_from_term_api",
    function(seed, ...) tibble::tibble(value = "HP:0001249")
  )
  expect_true("HP:0012759" %in% omim_ndd_resolve_terms("HP:0012759"))
})

# ---------------------------------------------------------------------------
# hpo_all_children_from_term_api() (httr2 mocked)
# ---------------------------------------------------------------------------

test_that("hpo_all_children_from_term_api returns seed + descendants on success", {
  mockery::stub(hpo_all_children_from_term_api, "httr2::req_perform", function(req) "resp")
  mockery::stub(
    hpo_all_children_from_term_api, "httr2::resp_body_json",
    function(resp, ...) data.frame(id = c("HP:0001249", "HP:0010864"), stringsAsFactors = FALSE)
  )
  res <- hpo_all_children_from_term_api("HP:0012759")
  expect_s3_class(res, "tbl_df")
  expect_setequal(res$value, c("HP:0012759", "HP:0001249", "HP:0010864"))
})

test_that("hpo_all_children_from_term_api trims whitespace and drops blank/NA ids", {
  mockery::stub(hpo_all_children_from_term_api, "httr2::req_perform", function(req) "resp")
  mockery::stub(
    hpo_all_children_from_term_api, "httr2::resp_body_json",
    function(resp, ...) data.frame(id = c(" HP:0001249 ", "", NA_character_), stringsAsFactors = FALSE)
  )
  res <- hpo_all_children_from_term_api("HP:0012759")
  expect_setequal(res$value, c("HP:0012759", "HP:0001249"))
})

test_that("hpo_all_children_from_term_api warns + returns seed-only on a malformed response", {
  mockery::stub(hpo_all_children_from_term_api, "httr2::req_perform", function(req) "resp")
  mockery::stub(
    hpo_all_children_from_term_api, "httr2::resp_body_json",
    function(resp, ...) data.frame(name = "no id column here", stringsAsFactors = FALSE)
  )
  expect_warning(
    res <- hpo_all_children_from_term_api("HP:0012759"),
    "no descendants parsed"
  )
  expect_equal(res$value, "HP:0012759")
})

test_that("hpo_all_children_from_term_api warns + returns seed-only when the request fails", {
  mockery::stub(hpo_all_children_from_term_api, "httr2::req_perform", function(req) stop("timeout"))
  expect_warning(
    res <- hpo_all_children_from_term_api("HP:0012759"),
    "fetch failed"
  )
  expect_equal(res$value, "HP:0012759")
})
