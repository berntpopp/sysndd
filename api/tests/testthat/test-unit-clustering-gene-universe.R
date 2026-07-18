# Unit tests for the category-selected clustering gene-universe resolver (#574 D1).
#
# `clustering_resolve_category_universe()` resolves the gene set a clustering
# job runs on: either the current default (all NDD genes, via
# `generate_ndd_hgnc_ids()`) or a curated-category selection
# (`ndd_entity_view` entity rows filtered by `category %in% selector`, then
# distinct `hgnc_id`). This file is DB-free: the default branch's dependency
# (`generate_ndd_hgnc_ids()`) is overridden in a child environment, and the
# category branch's `conn` is a real in-memory RSQLite connection so the
# dbplyr pipeline (`tbl()` / `filter()` / `select()` / `collect()`) is
# exercised for real rather than mocked.
#
# Trap: do NOT stub `generate_ndd_hgnc_ids` via
# `testthat::local_mocked_bindings(..., .env = globalenv())` -- under
# testthat 3.3.2 that aborts with "No packages loaded with pkgload" because
# globalenv() has no package namespace. A child-env override sidesteps this.

testthat::skip_if_not_installed("RSQLite")

# Source the code under test into a child env so the NULL-branch dependency
# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
# globalenv() or any other test file's bindings.
.gene_universe_env <- function() {
  e <- new.env(parent = globalenv())
  source_api_file("core/errors.R", local = FALSE, envir = e)
  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
  e
}

# In-memory RSQLite fixture standing in for `pool`/a real DB connection.
# `ev` = ndd_entity_view rows, `cats` = ndd_entity_status_categories_list rows.
fake_conn <- function(ev, cats) {
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  DBI::dbWriteTable(con, "ndd_entity_view", as.data.frame(ev))
  DBI::dbWriteTable(con, "ndd_entity_status_categories_list", as.data.frame(cats))
  con
}

# Fixture: entity rows (one row per entity). TWO Definitive NDD genes so the
# ["Definitive"] universe passes the >=2 guard.
ev <- tibble::tribble(
  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
  2L,        "HGNC:1",   1L,             "Limited",
  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
  5L,        "HGNC:4",   1L,             "Moderate",     # gene 4: Moderate NDD (single -> too-small alone)
  6L,        "HGNC:5",   1L,             "Definitive"    # gene 5: second Definitive NDD gene
)
cats <- tibble::tibble(
  category = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
  is_active = 1L
)

test_that("Definitive selects genes with any Definitive NDD entity (multi-entity gene included)", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  r <- e$clustering_resolve_category_universe("Definitive", conn = con)

  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5")) # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
  expect_identical(r$selector, "Definitive")
  expect_identical(r$resolved_gene_count, 2L)
})

test_that("multi-value selector is a union across categories", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)

  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5", "HGNC:4"))
})

test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))
  e$generate_ndd_hgnc_ids <- function() {
    tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5"))
  }

  r <- e$clustering_resolve_category_universe(NULL, conn = con)

  expect_identical(r$hgnc_ids, c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5")) # arrange(entity_id)+distinct, ndd_phenotype==1
  expect_null(r$selector)
})

test_that("unknown token is rejected 400 with the allowed set in the MESSAGE (not detail)", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  err <- tryCatch(
    e$clustering_resolve_category_universe("Definative", conn = con),
    error = function(err) err
  )

  expect_s3_class(err, "error_400")
  expect_match(conditionMessage(err), "Definitive") # allowed set is in the message so it reaches clients
})

test_that("supplied-but-empty selector is 400 (NOT the all-NDD default)", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  expect_error(e$clustering_resolve_category_universe(list(), conn = con), class = "error_400")
  expect_error(e$clustering_resolve_category_universe(list("   "), conn = con), class = "error_400")
})

test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job)", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  expect_error(e$clustering_resolve_category_universe("Refuted", conn = con), class = "error_400") # 0 genes
  expect_error(e$clustering_resolve_category_universe("Moderate", conn = con), class = "error_400") # 1 gene
})

test_that("gene_list_sha256 is sort-order independent", {
  e <- .gene_universe_env()

  expect_identical(
    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
  )
})

test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
  e <- .gene_universe_env()

  expect_null(e$clustering_normalize_category_filter(NULL))
  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
  expect_identical(
    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
    c("Definitive", "Moderate")
  )
})
