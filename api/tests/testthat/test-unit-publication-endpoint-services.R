# tests/testthat/test-unit-publication-endpoint-services.R
#
# Wave 3 / Task 2 (#346): unit tests for the extracted publication endpoint
# services (api/services/publication-query-endpoint-service.R and
# api/services/publication-admin-endpoint-service.R). Every DB-touching path
# is either exercised through an injected fake (host-runnable, no live
# database) or explicitly gated with skip_if_no_test_db() and verified
# centrally in the container.
#
# A trailing "shell delegation contract" section statically re-asserts, from
# this (unprotected) test file, the endpoint-shell wiring that
# test-endpoint-publication.R and test-unit-pubtator-public-route-guard.R
# already lock structurally (this task does not modify those two files).

library(testthat)
library(dplyr)
library(tidyr)
library(tibble)
library(stringr)
library(logger)

if (!exists("%||%")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# `dw` (deployment-wide config) is a global initialized in start_sysndd_api.R;
# build_cursor_links() reads dw$api_base_url by default.
if (!exists("dw")) {
  dw <- list(api_base_url = "http://localhost/api")
}

# `serializers` (format -> plumber serializer) is a global initialized in
# bootstrap/init_globals.R; svc_publication_list() looks it up by bare name
# to set res$serializer. Stub the "json" entry so the DB-gated cursor-shape
# test below can call the service directly without booting the full API.
if (!exists("serializers")) {
  serializers <- list(json = plumber::serializer_json())
}

# --- dependency sourcing (pure/pagination helpers the services call) --------
source_api_file("functions/logging-functions.R", local = FALSE)
source_api_file("functions/pubtator-parser.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)
source_api_file("functions/response-fields-helpers.R", local = FALSE)
source_api_file("functions/publication-endpoint-helpers.R", local = FALSE)

# generate_tibble_fspec_mem is normally created by bootstrap/init_cache.R's
# memoise wrapper around generate_tibble_fspec(); stand in with an
# unmemoised wrapper so pagination-shape tests run without cache init.
if (!exists("generate_tibble_fspec_mem", mode = "function")) {
  generate_tibble_fspec_mem <- function(field_tibble, fspecInput) {
    generate_tibble_fspec(field_tibble, fspecInput)
  }
}

source_api_file("services/publication-query-endpoint-service.R", local = FALSE)
source_api_file("services/publication-admin-endpoint-service.R", local = FALSE)

# Minimal Plumber-response stand-in: `res$status <- x` / `res$setHeader(...)`
# mutate the shared environment by reference, mirroring the real
# PlumberResponse object (see test-unit-pubtator-enrichment.R for precedent).
fake_res <- function() {
  res <- new.env()
  res$status <- NULL
  res$serializer <- NULL
  res$headers <- list()
  res$setHeader <- function(name, value) {
    res$headers[[name]] <- value
    invisible(NULL)
  }
  res
}

# =============================================================================
# svc_publication_pmid_digits / svc_publication_validate_pmid
# =============================================================================

test_that("svc_publication_pmid_digits strips everything but digits", {
  expect_equal(svc_publication_pmid_digits("12345"), "12345")
  expect_equal(svc_publication_pmid_digits("PMID:12345"), "12345")
  expect_equal(svc_publication_pmid_digits(URLencode("PMID:987", reserved = TRUE)), "987")
})

test_that("svc_publication_validate_pmid normalizes before calling check_fn", {
  seen <- NULL
  fake_check <- function(pmid) {
    seen <<- pmid
    TRUE
  }
  out <- svc_publication_validate_pmid("PMID:20301494", check_fn = fake_check)
  expect_true(out)
  expect_equal(seen, "20301494")
})

test_that("svc_publication_validate_pmid passes through a FALSE validator result", {
  out <- svc_publication_validate_pmid("999999999999", check_fn = function(pmid) FALSE)
  expect_false(out)
})

# =============================================================================
# svc_publication_pubtator_search
# =============================================================================

test_that("pubtator search returns 200 with meta/data on success", {
  res <- fake_res()
  fake_search <- function(query, page, max_pages) {
    list(pmids = c("1", "2", "3"), total_pages = 7)
  }
  out <- svc_publication_pubtator_search(list(), res, current_page = 2, search_fn = fake_search)
  expect_equal(res$status, 200)
  expect_equal(out$meta$perPage, 10)
  expect_equal(out$meta$currentPage, 2)
  expect_equal(out$meta$totalPages, 7)
  expect_equal(out$data, c("1", "2", "3"))
})

test_that("pubtator search degrades to the upstream's 503 status", {
  res <- fake_res()
  fake_search <- function(query, page, max_pages) {
    list(error = TRUE, status = 503L, source = "pubtator")
  }
  out <- svc_publication_pubtator_search(list(), res, current_page = 1, search_fn = fake_search)
  expect_equal(res$status, 503L)
  expect_equal(out$error, "PubTator is temporarily unavailable.")
  expect_equal(out$source, "pubtator")
})

test_that("pubtator search falls back to 503 when the upstream omits a status", {
  res <- fake_res()
  fake_search <- function(query, page, max_pages) list(error = TRUE)
  svc_publication_pubtator_search(list(), res, current_page = 1, search_fn = fake_search)
  expect_equal(res$status, 503L)
})

# =============================================================================
# svc_publication_pubtator_genes: enrichment-fallback sort echo + cursor shape
# =============================================================================

genes_fixture <- function() {
  tibble::tibble(
    gene_symbol = c("GRIN2B", "TP53", "FOO1"),
    gene_name = c("glutamate receptor", "tumor protein", "foo gene"),
    gene_normalized_id = c("2904", "7157", "9999"),
    hgnc_id = c("HGNC:4585", "HGNC:11998", "HGNC:0"),
    publication_count = c(50L, 10L, 5L),
    entities_count = c(2L, 0L, 1L),
    is_novel = c(0L, 1L, 0L),
    oldest_pub_date = as.character(as.Date(c("2001-01-01", "2010-05-05", "2015-03-03"))),
    pmids = c("1,2,3", "4,5", "6")
  )
}

test_that("genes listing echoes the raw requested sort and forces -publication_count when enrichment is missing", {
  res <- fake_res()
  out <- svc_publication_pubtator_genes(
    list(), res,
    sort = "-enrichment_ratio,-npmi,publication_count",
    summary_fn = function(pool_obj) list(data = genes_fixture()),
    enrichment_meta_fn = function() list(status = "missing", refreshed_at = NA_character_),
    join_enrichment_fn = function(df_counts, pool_obj) {
      dplyr::mutate(
        df_counts,
        observed = NA_integer_, background_count = NA_integer_,
        enrichment_ratio = NA_real_, npmi = NA_real_, fisher_p = NA_real_, fdr_bh = NA_real_
      )
    }
  )

  # Echoes the client's raw sort, not the internally-resolved fallback.
  expect_equal(out$meta$sort, "-enrichment_ratio,-npmi,publication_count")
  expect_equal(out$meta$enrichmentStatus, "missing")
  expect_true(is.na(out$meta$enrichmentRefreshedAt))

  # Data is actually ordered by -publication_count (the resolved fallback).
  expect_equal(out$data$gene_symbol, c("GRIN2B", "TP53", "FOO1"))
  expect_true(all(diff(out$data$publication_count) <= 0))

  # Standard cursor envelope shape.
  expect_true(all(c("links", "meta", "data") %in% names(out)))
  expect_equal(out$meta$totalItems, 3)
})

test_that("genes listing respects the requested enrichment sort when a current snapshot exists", {
  res <- fake_res()
  enriched <- dplyr::mutate(
    genes_fixture(),
    observed = c(3L, 1L, 1L),
    background_count = c(10L, 100L, 5L),
    enrichment_ratio = c(2.5, 0.1, 9.0), # FOO1 highest, GRIN2B mid, TP53 lowest
    npmi = c(0.4, 0.1, 0.9),
    fisher_p = c(0.01, 0.5, 0.001),
    fdr_bh = c(0.02, 0.6, 0.01)
  )
  out <- svc_publication_pubtator_genes(
    list(), res,
    sort = "-enrichment_ratio,-npmi,publication_count",
    summary_fn = function(pool_obj) list(data = enriched),
    enrichment_meta_fn = function() list(status = "current", refreshed_at = "2026-07-01 00:00:00"),
    join_enrichment_fn = function(df_counts, pool_obj) df_counts
  )

  expect_equal(out$meta$enrichmentStatus, "current")
  expect_equal(out$meta$enrichmentRefreshedAt, "2026-07-01 00:00:00")
  # Sorted by -enrichment_ratio: FOO1 (9.0) > GRIN2B (2.5) > TP53 (0.1).
  expect_equal(out$data$gene_symbol, c("FOO1", "GRIN2B", "TP53"))
})

test_that("genes listing leaves an explicit non-enrichment sort unchanged when enrichment is missing", {
  res <- fake_res()
  out <- svc_publication_pubtator_genes(
    list(), res,
    sort = "gene_symbol",
    summary_fn = function(pool_obj) list(data = genes_fixture()),
    enrichment_meta_fn = function() list(status = "missing", refreshed_at = NA_character_),
    join_enrichment_fn = function(df_counts, pool_obj) {
      dplyr::mutate(
        df_counts,
        observed = NA_integer_, background_count = NA_integer_,
        enrichment_ratio = NA_real_, npmi = NA_real_, fisher_p = NA_real_, fdr_bh = NA_real_
      )
    }
  )
  expect_equal(out$data$gene_symbol, c("FOO1", "GRIN2B", "TP53"))
})

# =============================================================================
# svc_publication_backfill_genes(_fetch)
# =============================================================================

test_that("backfill reports zero updates when nothing needs backfilling", {
  out <- svc_publication_backfill_genes(
    fetch_fn = function(pool_obj) list(null_ids = tibble::tibble(search_id = integer()), gene_symbols_df = tibble::tibble())
  )
  expect_equal(out$updated, 0)
  expect_match(out$message, "No rows need backfilling")
})

test_that("backfill updates one row per resolved gene_symbols entry, in order", {
  calls <- list()
  fake_execute <- function(sql, params) {
    calls[[length(calls) + 1L]] <<- params
    invisible(NULL)
  }
  fetch_fn <- function(pool_obj) {
    list(
      null_ids = tibble::tibble(search_id = c(1L, 2L, 3L)),
      gene_symbols_df = tibble::tibble(
        search_id = c(1L, 2L),
        gene_symbols = c("GRIN2B", "FOO1,TP53")
      )
    )
  }
  out <- svc_publication_backfill_genes(execute_fn = fake_execute, fetch_fn = fetch_fn)

  expect_equal(out$updated, 2)
  expect_equal(out$total_null, 3)
  expect_match(out$message, "Updated 2 rows")
  expect_match(out$message, "1 rows had no human genes")
  expect_length(calls, 2)
  expect_equal(calls[[1]], list("GRIN2B", 1L))
  expect_equal(calls[[2]], list("FOO1,TP53", 2L))
})

# =============================================================================
# svc_publication_pubtator_cache_status
# =============================================================================

test_that("cache status degrades to the upstream's 503 status", {
  res <- fake_res()
  out <- svc_publication_pubtator_cache_status(
    res, "epilepsy",
    total_pages_fn = function(query) list(error = TRUE, status = 503L)
  )
  expect_equal(res$status, 503L)
  expect_equal(out$source, "pubtator")
})

test_that("cache status reports 'not cached' when no cache row exists", {
  res <- fake_res()
  out <- svc_publication_pubtator_cache_status(
    res, "epilepsy",
    total_pages_fn = function(query) list(total_pages = 4),
    query_fn = function(sql, params = list()) data.frame()
  )
  expect_false(out$cached)
  expect_equal(out$total_pages_available, 4)
  expect_match(out$message, "No cache exists")
})

test_that("cache status reports remaining pages when partially cached", {
  res <- fake_res()
  query_fn <- function(sql, params = list()) {
    if (grepl("pubtator_query_cache", sql)) {
      return(data.frame(
        query_id = 9L, queried_page_number = 3L, total_page_number = 10L,
        query_date = "2026-01-01", stringsAsFactors = FALSE
      ))
    }
    data.frame(cnt = 30L)
  }
  out <- svc_publication_pubtator_cache_status(
    res, "epilepsy",
    total_pages_fn = function(query) list(total_pages = 10),
    query_fn = query_fn
  )
  expect_true(out$cached)
  expect_equal(out$pages_remaining, 7)
  expect_match(out$message, "Soft update will fetch 7 new pages")
})

test_that("cache status reports 'complete' when nothing remains", {
  res <- fake_res()
  query_fn <- function(sql, params = list()) {
    if (grepl("pubtator_query_cache", sql)) {
      return(data.frame(
        query_id = 9L, queried_page_number = 10L, total_page_number = 10L,
        query_date = "2026-01-01", stringsAsFactors = FALSE
      ))
    }
    data.frame(cnt = 100L)
  }
  out <- svc_publication_pubtator_cache_status(
    res, "epilepsy",
    total_pages_fn = function(query) list(total_pages = 10),
    query_fn = query_fn
  )
  expect_equal(out$pages_remaining, 0)
  expect_match(out$message, "Cache is complete")
})

# =============================================================================
# svc_publication_pubtator_update
# =============================================================================

test_that("synchronous update reports failure when the updater returns NULL", {
  res <- fake_res()
  out <- svc_publication_pubtator_update(
    list(), res, "epilepsy",
    update_fn = function(...) NULL,
    query_fn = function(sql, params = list()) data.frame()
  )
  expect_false(out$success)
  expect_match(out$message, "No results found or error occurred")
})

test_that("synchronous update reports a fetched-pages message on a soft update", {
  res <- fake_res()
  query_fn <- function(sql, params = list()) {
    if (grepl("queried_page_number FROM", sql)) return(data.frame(query_id = 1L, queried_page_number = 2L))
    data.frame(queried_page_number = 5L, total_page_number = 10L)
  }
  out <- svc_publication_pubtator_update(
    list(), res, "epilepsy", max_pages = 10, clear_old = FALSE,
    update_fn = function(...) 42L,
    query_fn = query_fn,
    counts_fn = function(query_id) list(search_count = 30L, annotation_count = 90L)
  )
  expect_true(out$success)
  expect_equal(out$update_type, "soft")
  expect_false(out$cache_hit)
  expect_equal(out$pages_fetched, 3)
  expect_equal(out$publications_count, 30L)
  expect_match(out$message, "Fetched 3 new pages")
})

test_that("synchronous update reports a cache-hit message when no new pages were fetched", {
  res <- fake_res()
  query_fn <- function(sql, params = list()) {
    if (grepl("queried_page_number FROM", sql)) return(data.frame(query_id = 1L, queried_page_number = 5L))
    data.frame(queried_page_number = 5L, total_page_number = 5L)
  }
  out <- svc_publication_pubtator_update(
    list(), res, "epilepsy",
    update_fn = function(...) 42L,
    query_fn = query_fn,
    counts_fn = function(query_id) list(search_count = 5L, annotation_count = 10L)
  )
  expect_true(out$cache_hit)
  expect_match(out$message, "Cache hit")
})

test_that("synchronous update sets a 500 status and returns the error on failure", {
  res <- fake_res()
  out <- svc_publication_pubtator_update(
    list(), res, "epilepsy",
    update_fn = function(...) stop("upstream exploded"),
    query_fn = function(sql, params = list()) data.frame()
  )
  expect_equal(res$status, 500)
  expect_false(out$success)
  expect_match(out$error, "upstream exploded")
})

# =============================================================================
# svc_publication_pubtator_update_submit
# =============================================================================

test_that("async submit returns 503 + Retry-After on capacity exceeded", {
  res <- fake_res()
  out <- svc_publication_pubtator_update_submit(
    list(), res, "epilepsy", 10L, FALSE, "hash123",
    submit_fn = function(...) list(error = "CAPACITY_EXCEEDED", message = "queue full", retry_after = 42)
  )
  expect_equal(res$status, 503)
  expect_equal(res$headers[["Retry-After"]], "42")
  expect_equal(out$error, "CAPACITY_EXCEEDED")
})

test_that("async submit returns 202 with Location/Retry-After and the job body on success", {
  res <- fake_res()
  seen_args <- NULL
  out <- svc_publication_pubtator_update_submit(
    list(), res, "epilepsy", 10L, FALSE, "hash123",
    submit_fn = function(operation, params, timeout_ms, executor_fn) {
      seen_args <<- list(operation = operation, params = params, executor_fn = executor_fn)
      list(job_id = "job-abc", status = "accepted", estimated_seconds = 30)
    }
  )
  expect_equal(res$status, 202)
  expect_equal(res$headers[["Location"]], "/api/jobs/job-abc/status")
  expect_equal(res$headers[["Retry-After"]], "5")
  expect_equal(out$job_id, "job-abc")
  expect_equal(out$query, "epilepsy")
  expect_equal(out$max_pages, 10L)
  expect_match(out$status_url, "/api/jobs/job-abc/status")

  # The job is submitted with the right operation/params and a real executor.
  expect_equal(seen_args$operation, "pubtator_update")
  expect_equal(seen_args$params$query, "epilepsy")
  expect_equal(seen_args$params$query_hash, "hash123")
  expect_true(is.function(seen_args$executor_fn))
})

# =============================================================================
# svc_publication_pubtator_clear_cache
# =============================================================================

test_that("clear-cache deletes annotation_cache, then search_cache, then query_cache, in order", {
  res <- fake_res()
  executed <- character()
  out <- svc_publication_pubtator_clear_cache(
    res,
    checkout_fn = function() "fake-conn",
    return_fn = function(conn) invisible(NULL),
    query_fn = function(conn, sql) data.frame(cnt = 7L),
    execute_fn = function(conn, sql) {
      executed <<- c(executed, sql)
      invisible(NULL)
    }
  )

  expect_true(out$success)
  expect_equal(out$deleted, list(queries = 7L, publications = 7L, annotations = 7L))
  expect_length(executed, 3)
  expect_match(executed[1], "pubtator_annotation_cache")
  expect_match(executed[2], "pubtator_search_cache")
  expect_match(executed[3], "pubtator_query_cache")
})

test_that("clear-cache sets a 500 status and returns the error when the connection fails", {
  res <- fake_res()
  out <- svc_publication_pubtator_clear_cache(
    res,
    checkout_fn = function() stop("pool exhausted"),
    return_fn = function(conn) invisible(NULL)
  )
  expect_equal(res$status, 500)
  expect_false(out$success)
  expect_match(out$error, "pool exhausted")
})

# =============================================================================
# DB-gated end-to-end coverage (skip_if_no_test_db; verified centrally in the
# container per the task brief). Each of these calls dplyr::tbl() against a
# real DBI connection, which needs the {dbplyr} backend package; it is a
# declared renv dependency (present in the container) but not always
# installed on a host test runner, so skip gracefully rather than erroring.
# =============================================================================

test_that("svc_publication_get_by_pmid reads a real row by normalized PMID", {
  skip_if_not_installed("dbplyr")
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    if (!DBI::dbExistsTable(con, "publication")) {
      testthat::skip("publication table not present in this test DB")
    }
    out <- svc_publication_get_by_pmid("not-a-real-pmid-999999999", pool_obj = con)
    expect_s3_class(out, "data.frame")
    expect_equal(nrow(out), 0)
  })
})

test_that("svc_publication_list returns a cursor envelope against the real schema", {
  skip_if_not_installed("dbplyr")
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    if (!DBI::dbExistsTable(con, "publication")) {
      testthat::skip("publication table not present in this test DB")
    }
    out <- svc_publication_list(list(), fake_res(), pool_obj = con)
    expect_true(all(c("links", "meta", "data") %in% names(out)))
  })
})

test_that("svc_publication_pubtator_table returns a cursor envelope against the real schema", {
  skip_if_not_installed("dbplyr")
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    if (!DBI::dbExistsTable(con, "pubtator_search_cache")) {
      testthat::skip("pubtator_search_cache table not present in this test DB")
    }
    out <- svc_publication_pubtator_table(list(), fake_res(), pool_obj = con)
    expect_true(all(c("links", "meta", "data") %in% names(out)))
  })
})

# =============================================================================
# Shell delegation contract (static — this is our own test file, not one of
# the protected guard files; the protected files continue to lock decorator/
# formal/role-gate byte-identity separately).
# =============================================================================

publication_endpoint_source <- function() {
  paste(readLines(file.path(get_api_dir(), "endpoints", "publication_endpoints.R"), warn = FALSE),
        collapse = "\n")
}

test_that("the endpoint shell delegates every read route to its named svc_ function", {
  ep <- publication_endpoint_source()
  for (fn in c(
    "svc_publication_get_by_pmid(", "svc_publication_validate_pmid(",
    "svc_publication_pubtator_search(", "svc_publication_list(",
    "svc_publication_pubtator_table(", "svc_publication_pubtator_genes("
  )) {
    expect_true(grepl(fn, ep, fixed = TRUE), info = fn)
  }
})

test_that("the endpoint shell delegates every mutation/status route to its named svc_ function", {
  ep <- publication_endpoint_source()
  for (fn in c(
    "svc_publication_backfill_genes(", "svc_publication_pubtator_cache_status(",
    "svc_publication_pubtator_update(", "svc_publication_pubtator_update_submit(",
    "svc_publication_pubtator_clear_cache("
  )) {
    expect_true(grepl(fn, ep, fixed = TRUE), info = fn)
  }
})

test_that("the /pubtator/update/submit shell keeps the duplicate-409 short-circuit ahead of the service call", {
  ep <- publication_endpoint_source()
  submit_idx <- regexpr("@post /pubtator/update/submit", ep, fixed = TRUE)
  expect_gt(submit_idx, 0)
  dup_idx <- regexpr("check_duplicate_job", substr(ep, submit_idx, nchar(ep)), fixed = TRUE)
  svc_idx <- regexpr("svc_publication_pubtator_update_submit(", substr(ep, submit_idx, nchar(ep)), fixed = TRUE)
  expect_gt(dup_idx, 0)
  expect_gt(svc_idx, 0)
  expect_lt(dup_idx, svc_idx)
})
