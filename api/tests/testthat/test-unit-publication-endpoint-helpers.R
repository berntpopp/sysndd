source_api_file("functions/publication-endpoint-helpers.R", local = FALSE)

test_that("publication_stats_response returns core publication counters", {
  queries <- list()
  query_fn <- function(sql, params = list()) {
    queries[[length(queries) + 1L]] <<- list(sql = sql, params = params)
    if (grepl("COUNT\\(\\*\\) as total", sql)) {
      return(data.frame(total = 12L))
    }
    if (grepl("MIN\\(update_date\\)", sql)) {
      return(data.frame(oldest_update = as.Date("2023-01-02")))
    }
    if (grepl("outdated_count", sql)) {
      return(data.frame(outdated_count = 3L))
    }
    stop("unexpected query")
  }

  result <- publication_stats_response(query_fn = query_fn)

  expect_equal(result$total, 12L)
  expect_equal(result$oldest_update, "2023-01-02")
  expect_equal(result$outdated_count, 3L)
  expect_null(result$filtered_count)
  expect_length(queries, 3L)
})

test_that("publication_stats_response includes valid optional date filter", {
  query_fn <- function(sql, params = list()) {
    if (grepl("filtered_count", sql)) {
      expect_equal(params, list("2024-05-19"))
      return(data.frame(filtered_count = 7L))
    }
    if (grepl("COUNT\\(\\*\\) as total", sql)) {
      return(data.frame(total = 12L))
    }
    if (grepl("MIN\\(update_date\\)", sql)) {
      return(data.frame(oldest_update = as.Date("2023-01-02")))
    }
    if (grepl("outdated_count", sql)) {
      return(data.frame(outdated_count = 3L))
    }
    stop("unexpected query")
  }

  result <- publication_stats_response(
    not_updated_since = "2024-05-19",
    query_fn = query_fn
  )

  expect_equal(result$filtered_count, 7L)
  expect_equal(result$filter_date, "2024-05-19")
})

test_that("publication_stats_response ignores invalid optional date filter", {
  result <- publication_stats_response(
    not_updated_since = "not-a-date",
    query_fn = function(sql, params = list()) {
      if (grepl("filtered_count", sql)) {
        stop("filtered query should not run")
      }
      if (grepl("COUNT\\(\\*\\) as total", sql)) {
        return(data.frame(total = 12L))
      }
      if (grepl("MIN\\(update_date\\)", sql)) {
        return(data.frame(oldest_update = as.Date("2023-01-02")))
      }
      if (grepl("outdated_count", sql)) {
        return(data.frame(outdated_count = 3L))
      }
      stop("unexpected query")
    }
  )

  expect_null(result$filtered_count)
  expect_null(result$filter_date)
})

test_that("collect_with_filter_pushdown returns all rows when no filter", {
  df <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))

  expect_equal(nrow(collect_with_filter_pushdown(df, character(0), "t")), 3L)
  expect_equal(nrow(collect_with_filter_pushdown(df, "", "t")), 3L)
})

test_that("collect_with_filter_pushdown applies a valid filter", {
  df <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))

  out <- collect_with_filter_pushdown(df, "id == 2", "t")

  expect_equal(out$val, "b")
})

test_that("build_cursor_meta appends the standard echo columns", {
  meta <- tibble::tibble(perpage = 10L, currentItemCount = 3L)

  out <- build_cursor_meta(
    meta, "publication_id", "Title=='x'", "a,b", "FSPEC", "0.12 secs"
  )

  expect_equal(out$sort, "publication_id")
  expect_equal(out$filter, "Title=='x'")
  expect_equal(out$fields, "a,b")
  expect_equal(out$fspec, "FSPEC")
  expect_equal(out$executionTime, "0.12 secs")
  expect_equal(out$perpage, 10L)
})

test_that("build_cursor_links builds absolute URLs and preserves null", {
  links <- tibble::tibble(
    prev = "null",
    `next` = "&page_after=20&page_size=10",
    self = "&page_after=0&page_size=10"
  )

  out <- build_cursor_links(
    links, "/publication", "publication_id", "", "",
    api_base_url = "https://api.test"
  )

  expect_equal(out$prev, "null")
  expect_equal(
    out$`next`,
    "https://api.test/publication?sort=publication_id&page_after=20&page_size=10"
  )
  expect_equal(
    out$self,
    "https://api.test/publication?sort=publication_id&page_after=0&page_size=10"
  )
})

test_that("build_cursor_links carries filter and fields when present", {
  links <- tibble::tibble(
    prev = "null",
    `next` = "&page_after=0"
  )

  out <- build_cursor_links(
    links, "/pubtator/genes", "-is_novel",
    "gene_symbol=='BRCA1'", "gene_symbol,pmids",
    api_base_url = "https://api.test"
  )

  expect_match(out$`next`, "&filter=gene_symbol=='BRCA1'", fixed = TRUE)
  expect_match(out$`next`, "&fields=gene_symbol,pmids", fixed = TRUE)
  expect_equal(out$prev, "null")
})

test_that("pubtator_genes_enrichment_meta reports current snapshot", {
  query_fn <- function(sql, params = list()) {
    expect_match(sql, "pubtator_corpus_stats", fixed = TRUE)
    expect_match(sql, "is_current = 1", fixed = TRUE)
    data.frame(
      created_at = "2026-06-14 09:00:00",
      genes_scored = 352L,
      stringsAsFactors = FALSE
    )
  }

  res <- pubtator_genes_enrichment_meta(query_fn = query_fn)

  expect_equal(res$status, "current")
  expect_equal(res$refreshed_at, "2026-06-14 09:00:00")
  expect_equal(res$genes_scored, 352L)
})

test_that("pubtator_genes_enrichment_meta reports missing snapshot when empty", {
  query_fn <- function(sql, params = list()) data.frame()

  res <- pubtator_genes_enrichment_meta(query_fn = query_fn)

  expect_equal(res$status, "missing")
  expect_true(is.na(res$refreshed_at))
  expect_true(is.na(res$genes_scored))
})

test_that("pubtator_genes_enrichment_meta degrades to missing on query error", {
  query_fn <- function(sql, params = list()) stop("db down")

  res <- pubtator_genes_enrichment_meta(query_fn = query_fn)

  expect_equal(res$status, "missing")
  expect_true(is.na(res$refreshed_at))
})

test_that("pubtator_resolve_genes_sort keeps requested sort when enrichment available", {
  sort <- "-enrichment_ratio,-npmi,publication_count"
  expect_equal(
    pubtator_resolve_genes_sort(sort, enrichment_available = TRUE),
    sort
  )
})

test_that("pubtator_resolve_genes_sort forces -publication_count lead when enrichment missing", {
  # Default sort depends on enrichment: enrichment keys + the ascending
  # publication_count token are dropped, replaced by a descending lead.
  expect_equal(
    pubtator_resolve_genes_sort(
      "-enrichment_ratio,-npmi,publication_count",
      enrichment_available = FALSE
    ),
    "-publication_count"
  )

  # Sort referencing ONLY enrichment keys collapses to the deterministic fallback.
  expect_equal(
    pubtator_resolve_genes_sort("-enrichment_ratio,-fdr_bh", enrichment_available = FALSE),
    "-publication_count"
  )

  # Enrichment lead with a non-enrichment, non-publication_count tiebreak: the
  # tiebreak is preserved after the forced descending lead.
  expect_equal(
    pubtator_resolve_genes_sort("-npmi,gene_symbol", enrichment_available = FALSE),
    "-publication_count,gene_symbol"
  )
})

test_that("pubtator_resolve_genes_sort respects explicit non-enrichment sorts when missing", {
  # No enrichment key referenced => explicit user choice, returned unchanged
  # (including an explicit ascending publication_count).
  expect_equal(
    pubtator_resolve_genes_sort("-publication_count,gene_symbol", enrichment_available = FALSE),
    "-publication_count,gene_symbol"
  )
  expect_equal(
    pubtator_resolve_genes_sort("gene_symbol", enrichment_available = FALSE),
    "gene_symbol"
  )
  expect_equal(
    pubtator_resolve_genes_sort("publication_count", enrichment_available = FALSE),
    "publication_count"
  )
})
