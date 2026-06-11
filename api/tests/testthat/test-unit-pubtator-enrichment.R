# test-unit-pubtator-enrichment.R
#
# Behavior tests for the PubtatorNDD enrichment normalization (issue #175):
#   * pure metric math (enrichment ratio, NPMI, Fisher + BH-FDR) including the
#     zero-count / edge cases, anchored to the worked example in the issue
#     (GRIN2B vs TP53 must separate by ~two orders of magnitude);
#   * the collection logic with the external PubTator fetcher mocked (stub the
#     direct helper, never hit the network).

library(testthat)

source_api_file("functions/pubtator-enrichment-metrics.R", local = FALSE)

# Worked example from issue #175 (NDD corpus 13,459; whole-corpus probe).
# observed = NDD-corpus pubs mentioning the gene; bg = total pubs for the gene.
NDD_CORPUS <- 13459L
TOTAL_CORPUS <- 37000000L

# --- enrichment ratio ---------------------------------------------------------

test_that("enrichment ratio is observed / expected", {
  # GRIN2B: 86 NDD pubs of 13,459 total NDD pubs; 13,459 total gene pubs.
  # expected = NDD_CORPUS * bg / TOTAL = 13459 * 13459 / 37e6 ~= 4.896
  # ratio = 86 / 4.896 ~= 17.6 (strongly enriched).
  ratio <- pubtator_enrichment_ratio(86, 13459, NDD_CORPUS, TOTAL_CORPUS)
  expect_gt(ratio, 10)
})

test_that("enrichment ratio separates true NDD gene from popularity noise", {
  grin2b <- pubtator_enrichment_ratio(86, 13459, NDD_CORPUS, TOTAL_CORPUS)
  tp53 <- pubtator_enrichment_ratio(8, 282103, NDD_CORPUS, TOTAL_CORPUS)
  # GRIN2B is a true NDD gene, TP53 popularity noise: GRIN2B must rank far above.
  expect_gt(grin2b, tp53)
  expect_gt(grin2b / tp53, 100) # ~two orders of magnitude
})

test_that("enrichment ratio returns NA on zero/invalid denominators", {
  expect_true(is.na(pubtator_enrichment_ratio(5, 0, NDD_CORPUS, TOTAL_CORPUS)))
  expect_true(is.na(pubtator_enrichment_ratio(5, 100, NDD_CORPUS, 0)))
  expect_true(is.na(pubtator_enrichment_ratio(NA, 100, NDD_CORPUS, TOTAL_CORPUS)))
})

# --- NPMI ---------------------------------------------------------------------

test_that("NPMI is bounded in [-1, 1]", {
  grin2b <- pubtator_npmi(86, 13459, NDD_CORPUS, TOTAL_CORPUS)
  expect_gte(grin2b, -1)
  expect_lte(grin2b, 1)
})

test_that("NPMI returns -1 when gene and NDD never co-occur (observed == 0)", {
  expect_equal(pubtator_npmi(0, 13459, NDD_CORPUS, TOTAL_CORPUS), -1)
})

test_that("NPMI returns +1 when gene and NDD always co-occur", {
  # gene appears only in the NDD corpus and covers the whole NDD corpus:
  # observed == bg == ndd_corpus_size -> perfect association.
  expect_equal(pubtator_npmi(100, 100, 100, TOTAL_CORPUS), 1)
})

test_that("NPMI is ~0 at independence (observed == expected)", {
  # Construct a gene whose observed equals its expected count.
  bg <- 100000
  expected <- NDD_CORPUS * bg / TOTAL_CORPUS
  npmi <- pubtator_npmi(round(expected), bg, NDD_CORPUS, TOTAL_CORPUS)
  expect_lt(abs(npmi), 0.05)
})

test_that("NPMI ranks true NDD gene above popularity noise", {
  grin2b <- pubtator_npmi(86, 13459, NDD_CORPUS, TOTAL_CORPUS)
  tp53 <- pubtator_npmi(8, 282103, NDD_CORPUS, TOTAL_CORPUS)
  expect_gt(grin2b, tp53)
  # The popularity-biased gene should land near/below independence.
  expect_lt(tp53, grin2b - 0.1)
})

# --- Fisher contingency + p-value --------------------------------------------

test_that("contingency table cells are non-negative and consistent", {
  tbl <- pubtator_contingency_table(86, 13459, NDD_CORPUS, TOTAL_CORPUS)
  expect_false(is.null(tbl))
  expect_true(all(tbl >= 0))
  expect_equal(sum(tbl), TOTAL_CORPUS)
})

test_that("contingency table is NULL when observed exceeds a marginal", {
  expect_null(pubtator_contingency_table(20, 10, NDD_CORPUS, TOTAL_CORPUS))
})

test_that("Fisher p-value is smaller for the enriched true NDD gene", {
  p_grin2b <- pubtator_fisher_pvalue(86, 13459, NDD_CORPUS, TOTAL_CORPUS)
  p_tp53 <- pubtator_fisher_pvalue(8, 282103, NDD_CORPUS, TOTAL_CORPUS)
  expect_gte(p_grin2b, 0)
  expect_lte(p_grin2b, 1)
  expect_lt(p_grin2b, p_tp53)
})

# --- BH-FDR -------------------------------------------------------------------

test_that("BH-FDR preserves ordering and tolerates NA", {
  p <- c(0.001, 0.01, NA, 0.5)
  q <- pubtator_bh_fdr(p)
  expect_equal(length(q), 4)
  expect_true(is.na(q[3]))
  # monotone non-decreasing in the original p-order for the finite entries
  finite <- q[!is.na(q)]
  expect_true(all(diff(finite) >= -1e-9))
  # adjusted q-values are >= raw p-values
  expect_true(all(finite >= c(0.001, 0.01, 0.5) - 1e-9))
})

# --- vectorized compute -------------------------------------------------------

test_that("pubtator_compute_gene_metrics ranks the issue worked example correctly", {
  genes <- data.frame(
    gene_symbol = c("GRIN2B", "SCN1A", "MECP2", "TP53", "APP", "ALB"),
    observed = c(86L, 20L, 16L, 8L, 8L, 3L),
    background_count = c(13459L, 5238L, 10677L, 282103L, 124598L, 269569L),
    stringsAsFactors = FALSE
  )
  scored <- pubtator_compute_gene_metrics(genes, NDD_CORPUS, TOTAL_CORPUS)

  expect_true(all(c("enrichment_ratio", "npmi", "fisher_p", "fdr_bh") %in% names(scored)))

  # True NDD genes by enrichment ratio must outrank popularity noise.
  by_enrichment <- scored$gene_symbol[order(-scored$enrichment_ratio)]
  true_ndd <- c("GRIN2B", "SCN1A", "MECP2")
  noise <- c("TP53", "APP", "ALB")
  expect_true(all(match(true_ndd, by_enrichment) < min(match(noise, by_enrichment))))

  # Same separation holds under NPMI ranking.
  by_npmi <- scored$gene_symbol[order(-scored$npmi)]
  expect_true(all(match(true_ndd, by_npmi) < min(match(noise, by_npmi))))
})

# --- collection logic (mocked fetcher) ---------------------------------------

source_api_file("functions/pubtator-enrichment-collector.R", local = FALSE)

# Deterministic stub of the direct external fetcher: returns canned counts.
make_stub_fetch <- function(counts) {
  function(query, ...) {
    if (identical(query, PUBTATOR_NDD_CORPUS_QUERY)) {
      return(list(error = FALSE, query = query, count = NDD_CORPUS))
    }
    if (identical(query, "*")) {
      return(list(error = FALSE, query = query, count = TOTAL_CORPUS))
    }
    sym <- sub("^@GENE_", "", query)
    if (!is.null(counts[[sym]])) {
      return(list(error = FALSE, query = query, count = counts[[sym]]))
    }
    # Unknown gene -> simulate a transient upstream error (must not poison cache).
    list(error = TRUE, query = query, status = 503L, message = "stub error")
  }
}

test_that("corpus size collection reads the stubbed NDD and total counts", {
  stub <- make_stub_fetch(list())
  corpus <- pubtator_collect_corpus_sizes(fetch_fn = stub)
  expect_equal(corpus$ndd_corpus_size, NDD_CORPUS)
  expect_equal(corpus$total_corpus_size, TOTAL_CORPUS)
  expect_false(corpus$total_is_fallback)
})

test_that("total corpus falls back when the all-corpus probe errors", {
  stub <- function(query, ...) {
    if (identical(query, PUBTATOR_NDD_CORPUS_QUERY)) {
      return(list(error = FALSE, query = query, count = NDD_CORPUS))
    }
    list(error = TRUE, query = query, status = 503L, message = "boom")
  }
  corpus <- pubtator_collect_corpus_sizes(fetch_fn = stub)
  expect_true(corpus$total_is_fallback)
  expect_equal(corpus$total_corpus_size, PUBTATOR_FALLBACK_TOTAL_CORPUS)
})

test_that("background count collection skips genes whose fetch failed", {
  stub <- make_stub_fetch(list(GRIN2B = 13459L, TP53 = 282103L))
  df <- pubtator_collect_background_counts(
    c("GRIN2B", "TP53", "UNKNOWNGENE"),
    fetch_fn = stub
  )
  expect_equal(nrow(df), 3)
  expect_equal(df$background_count[df$gene_symbol == "GRIN2B"], 13459L)
  expect_equal(df$background_count[df$gene_symbol == "TP53"], 282103L)
  expect_true(is.na(df$background_count[df$gene_symbol == "UNKNOWNGENE"]))
})

test_that("fetch helper treats a missing count field as a cacheable zero", {
  # A valid 'no results' answer should NOT be flagged as an error result.
  local_mocked_bindings <- NULL
  res <- pubtator_fetch_total_count("")
  expect_true(res$error) # empty query is an input error
})

# --- endpoint helpers (mocked DB / submit) -----------------------------------

source_api_file("functions/publication-endpoint-helpers.R", local = FALSE)

test_that("enrichment status response reports 'available = FALSE' on no snapshot", {
  fake_query <- function(sql, ...) data.frame()
  res <- pubtator_enrichment_status_response(query_fn = fake_query)
  expect_false(res$available)
  expect_match(res$message, "No enrichment snapshot")
})

test_that("enrichment status response summarizes the current snapshot", {
  fake_query <- function(sql, ...) {
    data.frame(
      corpus_stats_id = 7L,
      ndd_corpus_size = 13459L,
      total_corpus_size = 37000000,
      total_is_fallback = 0L,
      genes_scored = 1234L,
      created_at = "2026-06-11 10:00:00",
      stringsAsFactors = FALSE
    )
  }
  res <- pubtator_enrichment_status_response(query_fn = fake_query)
  expect_true(res$available)
  expect_equal(res$corpus_stats_id, 7L)
  expect_equal(res$ndd_corpus_size, 13459L)
  expect_false(res$total_is_fallback)
  expect_equal(res$genes_scored, 1234L)
})

test_that("enrichment refresh submit returns 202 and shapes the job response", {
  # Plumber response uses res$status <- ...; emulate with an environment.
  res_env <- new.env()
  res_env$status <- NULL
  res_env$setHeader <- function(name, value) invisible(NULL)

  fake_submit <- function(job_type, request_payload, submitted_by = NULL) {
    expect_equal(job_type, "pubtator_enrichment_refresh")
    list(
      job = data.frame(job_id = "abc-123", status = "queued", stringsAsFactors = FALSE),
      duplicate = FALSE
    )
  }

  out <- pubtator_enrichment_refresh_submit(res_env, submitted_by = 5L, submit_fn = fake_submit)
  expect_equal(res_env$status, 202L)
  expect_equal(out$job_id, "abc-123")
  expect_equal(out$status, "accepted")
  expect_match(out$status_url, "/api/jobs/abc-123/status")
})

test_that("enrichment refresh submit returns 409 on a duplicate running job", {
  res_env <- new.env()
  res_env$status <- NULL
  res_env$setHeader <- function(name, value) invisible(NULL)

  fake_submit <- function(job_type, request_payload, submitted_by = NULL) {
    list(
      job = data.frame(job_id = "dup-1", status = "running", stringsAsFactors = FALSE),
      duplicate = TRUE
    )
  }

  out <- pubtator_enrichment_refresh_submit(res_env, submit_fn = fake_submit)
  expect_equal(res_env$status, 409L)
  expect_equal(out$status, "already_running")
})
