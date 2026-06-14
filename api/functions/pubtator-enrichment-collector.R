# functions/pubtator-enrichment-collector.R
#
# Background-count collection + DB persistence for the PubtatorNDD enrichment
# normalization (GitHub issue #175). The web API must never run this on a
# public request: it makes one external PubTator call per gene plus two
# corpus-size calls, so it runs inside the durable async worker
# (`pubtator_enrichment_refresh` job; see functions/async-job-handlers.R).
#
# Split of concerns:
#   * pubtator-enrichment-metrics.R  -- pure math (no I/O), unit-tested.
#   * this file                      -- external fetch + corpus sizes + the
#                                        refresh orchestrator that writes
#                                        pubtator_corpus_stats /
#                                        pubtator_gene_enrichment (migration 027).
#
# External calls go through memoise_external_success_only() so a transient
# upstream failure (returned as list(error = TRUE, ...)) is NOT cached and the
# 7-day cache only retains real counts.

require(jsonlite)
require(logger)

# Default total-corpus size used as a fallback only if the corpus-size probe
# fails. PubTator3 indexes ~the whole of PubMed (~37M citations as of 2024);
# this is intentionally conservative and is overwritten whenever the live
# probe succeeds. Never silently trust it for ranking without a successful
# corpus probe -- the refresh records which value was actually used.
PUBTATOR_FALLBACK_TOTAL_CORPUS <- 37000000L

# The disease-side query that defines the "NDD corpus" size probe. This MUST be
# a PubTator3 entity query that the search endpoint actually resolves to a
# non-zero count. The previous value "@DISEASE_neurodevelopmental" silently
# returned count=0 (no such normalized entity), which made every enrichment
# refresh fail at the corpus-size step with "Failed to fetch NDD corpus size".
# "@DISEASE_Neurodevelopmental_Disorders" is the resolvable concept form
# (search count ~6.5k as of 2026-06). Keep this as a single constant so the
# NDD-corpus size and the per-gene observed counts stay aligned, and verify any
# replacement returns a non-zero count before changing it.
PUBTATOR_NDD_CORPUS_QUERY <- "@DISEASE_Neurodevelopmental_Disorders"

#' Reset the per-request external-time accumulator if the helper is present
#'
#' The enrichment collector is a durable batch job that makes many independent
#' external PubTator calls (one corpus probe + one per gene). The per-request
#' external-time ceiling (`EXTERNAL_PROXY_REQUEST_MAX_SECONDS`, #344) is designed
#' for public request paths; left unchecked it short-circuits the back half of a
#' batch to a degraded 503. Calling this before each external call gives each
#' call its own fresh budget while keeping each call's own per-call
#' timeout/retry (via `external_proxy_budget()`). Guarded so the collector can be
#' sourced in library-light test contexts where the accumulator is absent.
#' @keywords internal
.pubtatornidd_reset_external_budget <- function() {
  if (exists("external_proxy_request_reset", mode = "function")) {
    external_proxy_request_reset()
  }
  invisible(NULL)
}

#' Fetch the total PubTator publication count for a single search query
#'
#' Hits the PubTator3 search endpoint and reads `response.count`. This is the
#' raw fetcher; wrap with `memoise_external_success_only()` for caching (see
#' `pubtator_total_count_mem` below).
#'
#' @param query Character search string already in PubTator syntax, e.g.
#'   "@GENE_GRIN2B" or "@DISEASE_neurodevelopmental".
#' @param api_base_url PubTator3 API base URL.
#' @param endpoint_search Search endpoint path.
#'
#' @return On success, `list(error = FALSE, query = query, count = <integer>)`.
#'   On a transient/upstream failure, `list(error = TRUE, query = query,
#'   status = <int>, message = <chr>)` -- this shape is detected by
#'   `external_proxy_is_error()` and must not be cached.
#' @export
pubtator_fetch_total_count <- function(query,
                                       api_base_url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
                                       endpoint_search = "search/") {
  if (is.null(query) || !nzchar(query)) {
    return(list(error = TRUE, query = query, status = 400L,
                message = "empty query"))
  }

  url_search <- paste0(api_base_url, endpoint_search, "?text=", query, "&page=1")

  tryCatch(
    {
      response <- jsonlite::fromJSON(URLencode(url_search), flatten = TRUE)
      raw_count <- response$count
      if (is.null(raw_count) || length(raw_count) == 0 || is.na(raw_count[[1]])) {
        # A valid "no results" answer is still a successful, cacheable response.
        return(list(error = FALSE, query = query, count = 0L))
      }
      list(error = FALSE, query = query, count = as.integer(raw_count[[1]]))
    },
    error = function(e) {
      log_warn(skip_formatter(paste(
        "PubTator total-count fetch failed for query", query, ":", e$message
      )))
      list(error = TRUE, query = query, status = 503L, message = e$message)
    }
  )
}

#' Memoised total-count fetcher (7-day cache, errors not cached)
#'
#' Bound lazily so the file can be sourced in library-light test contexts that
#' do not define the external-proxy cache backends.
#' @export
pubtator_total_count_mem <- if (exists("cache_dynamic") &&
                                exists("memoise_external_success_only")) {
  memoise_external_success_only(pubtator_fetch_total_count, cache = cache_dynamic)
} else {
  pubtator_fetch_total_count
}

#' Collect the corpus-level sizes needed to normalize gene counts
#'
#' @param fetch_fn Total-count fetcher (injectable for tests). Defaults to the
#'   memoised production fetcher.
#'
#' @return `list(ndd_corpus_size = <int|NA>, total_corpus_size = <int>,
#'   total_is_fallback = <lgl>)`. `total_corpus_size` falls back to
#'   `PUBTATOR_FALLBACK_TOTAL_CORPUS` if the all-corpus probe fails.
#' @export
pubtator_collect_corpus_sizes <- function(fetch_fn = pubtator_total_count_mem) {
  # This is a durable batch job, not a public request: the per-request external
  # time ceiling (EXTERNAL_PROXY_REQUEST_MAX_SECONDS, #344) would otherwise
  # short-circuit our many independent calls to a degraded 503. Reset the
  # accumulator before each call so each gets its own fresh per-call budget
  # (per-call timeout/retry still applies via external_proxy_budget). See
  # .pubtatornidd_reset_external_budget().
  .pubtatornidd_reset_external_budget()
  ndd_res <- fetch_fn(PUBTATOR_NDD_CORPUS_QUERY)
  ndd_size <- if (isTRUE(ndd_res$error)) NA_integer_ else as.integer(ndd_res$count)

  # Total corpus size: an unfiltered search returns the index size. A bare "*"
  # query is the conventional "everything" probe; guard with the fallback.
  .pubtatornidd_reset_external_budget()
  total_res <- fetch_fn("*")
  total_is_fallback <- isTRUE(total_res$error) ||
    is.null(total_res$count) || is.na(total_res$count) ||
    as.integer(total_res$count) <= 0L

  total_size <- if (total_is_fallback) {
    PUBTATOR_FALLBACK_TOTAL_CORPUS
  } else {
    as.integer(total_res$count)
  }

  list(
    ndd_corpus_size = ndd_size,
    total_corpus_size = total_size,
    total_is_fallback = total_is_fallback
  )
}

#' Collect background (total) publication counts for a set of genes
#'
#' @param gene_symbols Character vector of HGNC gene symbols.
#' @param fetch_fn Total-count fetcher (injectable for tests).
#' @param progress_fn Optional progress reporter `function(step, message,
#'   current, total)`.
#'
#' @return Data frame `gene_symbol`, `background_count` (NA when the per-gene
#'   fetch failed so the gene can be skipped rather than mis-ranked).
#' @export
pubtator_collect_background_counts <- function(gene_symbols,
                                               fetch_fn = pubtator_total_count_mem,
                                               progress_fn = NULL) {
  gene_symbols <- unique(gene_symbols[!is.na(gene_symbols) & nzchar(gene_symbols)])
  total <- length(gene_symbols)
  background <- rep(NA_integer_, total)

  report <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress_fn) && is.function(progress_fn)) {
      tryCatch(progress_fn(step, message, current = current, total = total),
               error = function(e) NULL)
    }
  }

  for (i in seq_len(total)) {
    sym <- gene_symbols[[i]]
    # Per-call reset: each gene's background fetch gets its own fresh external
    # budget so this legitimate multi-minute batch is not capped by the
    # per-request external-time ceiling (#344). See corpus-sizes note above.
    .pubtatornidd_reset_external_budget()
    res <- fetch_fn(paste0("@GENE_", sym))
    if (!isTRUE(res$error) && !is.null(res$count) && !is.na(res$count)) {
      background[[i]] <- as.integer(res$count)
    }
    if (i %% 25 == 0 || i == total) {
      report("collect", sprintf("Fetched background counts %d/%d", i, total),
             current = i, total = total)
    }
  }

  data.frame(
    gene_symbol = gene_symbols,
    background_count = background,
    stringsAsFactors = FALSE
  )
}

#' Read the curated PubtatorNDD per-gene observed (NDD co-occurrence) counts
#'
#' Reads the same approved view the gene-prioritization endpoint serves, so
#' `observed` matches what users rank on. One row per gene.
#'
#' @param conn A live DBI connection.
#'
#' @return Data frame `hgnc_id`, `gene_symbol`, `observed`.
#' @export
pubtator_read_observed_counts <- function(conn) {
  rows <- db_execute_query(
    "SELECT nal.hgnc_id AS hgnc_id,
            nal.symbol  AS gene_symbol,
            COUNT(DISTINCT s.pmid) AS observed
     FROM pubtator_search_cache s
     JOIN pubtator_annotation_cache a ON s.search_id = a.search_id
     JOIN non_alt_loci_set nal ON nal.entrez_id = a.normalized_id
     WHERE a.type = 'Gene'
       AND EXISTS (
         SELECT 1 FROM pubtator_annotation_cache x
         WHERE x.search_id = s.search_id
           AND x.type = 'Species'
           AND x.normalized_id = '9606'
       )
     GROUP BY nal.hgnc_id, nal.symbol",
    list(),
    conn = conn
  )
  rows$observed <- as.integer(rows$observed)
  rows
}

#' Run a full enrichment refresh: collect counts, compute metrics, persist
#'
#' Orchestrator executed by the durable `pubtator_enrichment_refresh` worker
#' job. Wraps the writes in a transaction so the new snapshot activates
#' atomically (exactly one current `pubtator_corpus_stats` row).
#'
#' @param conn A live DBI connection (the worker checks one out of the pool).
#' @param fetch_fn Total-count fetcher (injectable for tests).
#' @param progress_fn Optional progress reporter.
#' @param refreshed_by Optional user id recorded on the snapshot.
#'
#' @return List with `success`, `genes_scored`, `ndd_corpus_size`,
#'   `total_corpus_size`, `total_is_fallback`, `corpus_stats_id`.
#' @export
pubtator_enrichment_refresh_run <- function(conn,
                                            fetch_fn = pubtator_total_count_mem,
                                            progress_fn = NULL,
                                            refreshed_by = NULL) {
  report <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress_fn) && is.function(progress_fn)) {
      tryCatch(progress_fn(step, message, current = current, total = total),
               error = function(e) NULL)
    }
  }

  report("observed", "Reading curated PubtatorNDD gene counts...", current = 0, total = 1)
  observed_df <- pubtator_read_observed_counts(conn)
  if (nrow(observed_df) == 0) {
    return(list(success = FALSE, genes_scored = 0L,
                message = "No PubtatorNDD gene counts found; run a PubTator update first"))
  }

  report("corpus", "Fetching corpus sizes...", current = 0, total = 1)
  corpus <- pubtator_collect_corpus_sizes(fetch_fn = fetch_fn)
  if (is.na(corpus$ndd_corpus_size) || corpus$ndd_corpus_size <= 0) {
    return(list(success = FALSE, genes_scored = 0L,
                message = "Failed to fetch NDD corpus size from PubTator"))
  }

  report("background",
         sprintf("Fetching background counts for %d genes...", nrow(observed_df)),
         current = 0, total = nrow(observed_df))
  background_df <- pubtator_collect_background_counts(
    observed_df$gene_symbol, fetch_fn = fetch_fn, progress_fn = progress_fn
  )

  merged <- dplyr::inner_join(observed_df, background_df, by = "gene_symbol")

  report("compute", "Computing enrichment, NPMI, Fisher + BH-FDR...",
         current = nrow(merged), total = nrow(merged))
  scored <- pubtator_compute_gene_metrics(
    merged,
    ndd_corpus_size = corpus$ndd_corpus_size,
    total_corpus_size = corpus$total_corpus_size
  )

  report("persist", "Writing enrichment snapshot...", current = 0, total = 1)
  corpus_stats_id <- pubtator_enrichment_persist(
    conn = conn,
    scored = scored,
    corpus = corpus,
    refreshed_by = refreshed_by
  )

  list(
    success = TRUE,
    genes_scored = nrow(scored),
    ndd_corpus_size = corpus$ndd_corpus_size,
    total_corpus_size = corpus$total_corpus_size,
    total_is_fallback = corpus$total_is_fallback,
    corpus_stats_id = corpus_stats_id,
    message = sprintf("Scored %d genes against NDD corpus of %d publications",
                      nrow(scored), corpus$ndd_corpus_size)
  )
}

#' Persist a scored snapshot atomically (one current corpus-stats row)
#'
#' @param conn A live DBI connection.
#' @param scored Data frame from `pubtator_compute_gene_metrics()`.
#' @param corpus Corpus-size list from `pubtator_collect_corpus_sizes()`.
#' @param refreshed_by Optional user id.
#'
#' @return The new `corpus_stats_id`.
#' @export
pubtator_enrichment_persist <- function(conn, scored, corpus, refreshed_by = NULL) {
  DBI::dbBegin(conn)
  result <- tryCatch(
    {
      # Demote any previously-current snapshot, then insert the new current one.
      db_execute_statement(
        "UPDATE pubtator_corpus_stats SET is_current = 0 WHERE is_current = 1",
        list(), conn = conn
      )
      db_execute_statement(
        "INSERT INTO pubtator_corpus_stats
           (ndd_corpus_size, total_corpus_size, total_is_fallback,
            genes_scored, refreshed_by, is_current)
         VALUES (?, ?, ?, ?, ?, 1)",
        unname(list(
          as.integer(corpus$ndd_corpus_size),
          as.integer(corpus$total_corpus_size),
          as.integer(isTRUE(corpus$total_is_fallback)),
          as.integer(nrow(scored)),
          if (is.null(refreshed_by)) NA_integer_ else as.integer(refreshed_by)
        )),
        conn = conn
      )
      corpus_stats_id <- db_execute_query(
        "SELECT LAST_INSERT_ID() AS id", list(), conn = conn
      )$id[[1]]

      # Replace per-gene rows for this fresh snapshot.
      db_execute_statement(
        "DELETE FROM pubtator_gene_enrichment", list(), conn = conn
      )
      for (i in seq_len(nrow(scored))) {
        db_execute_statement(
          "INSERT INTO pubtator_gene_enrichment
             (corpus_stats_id, hgnc_id, gene_symbol, observed, background_count,
              enrichment_ratio, npmi, fisher_p, fdr_bh)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
          unname(list(
            as.integer(corpus_stats_id),
            scored$hgnc_id[[i]],
            scored$gene_symbol[[i]],
            as.integer(scored$observed[[i]]),
            .pubtator_na_int(scored$background_count[[i]]),
            .pubtator_na_num(scored$enrichment_ratio[[i]]),
            .pubtator_na_num(scored$npmi[[i]]),
            .pubtator_na_num(scored$fisher_p[[i]]),
            .pubtator_na_num(scored$fdr_bh[[i]])
          )),
          conn = conn
        )
      }
      DBI::dbCommit(conn)
      corpus_stats_id
    },
    error = function(e) {
      tryCatch(DBI::dbRollback(conn), error = function(e2) NULL)
      stop(e)
    }
  )
  result
}

#' Durable worker entrypoint for the `pubtator_enrichment_refresh` job
#'
#' Checks out a connection from the global pool, runs the refresh, and shapes the
#' job result. Kept here (not in async-job-handlers.R) so the oversized handler
#' registry file does not grow.
#'
#' @param job The durable job row (provides `job_id`, `submitted_by`).
#' @param progress_reporter_fn Factory `function(job_id) -> progress_fn`.
#' @return Completed job result list.
#' @export
pubtator_enrichment_job_run <- function(job, progress_reporter_fn) {
  progress <- progress_reporter_fn(job$job_id[[1]])
  progress("init", "Starting PubtatorNDD enrichment refresh...", current = 0, total = 1)

  if (!base::exists("pool", envir = .GlobalEnv, inherits = FALSE)) {
    stop("PubtatorNDD enrichment refresh requires the global database pool", call. = FALSE)
  }

  db_pool <- base::get("pool", envir = .GlobalEnv, inherits = FALSE)
  conn <- pool::poolCheckout(db_pool)
  on.exit(pool::poolReturn(conn), add = TRUE)

  refreshed_by <- NULL
  if (!is.null(job$submitted_by) && !is.na(job$submitted_by[[1]])) {
    refreshed_by <- job$submitted_by[[1]]
  }

  result <- pubtator_enrichment_refresh_run(
    conn = conn,
    progress_fn = progress,
    refreshed_by = refreshed_by
  )

  if (!isTRUE(result$success)) {
    stop(result$message %||% "PubtatorNDD enrichment refresh failed", call. = FALSE)
  }

  progress("complete", result$message, current = 1, total = 1)

  list(
    status = "completed",
    success = TRUE,
    genes_scored = result$genes_scored,
    ndd_corpus_size = result$ndd_corpus_size,
    total_corpus_size = result$total_corpus_size,
    total_is_fallback = result$total_is_fallback,
    corpus_stats_id = result$corpus_stats_id,
    message = result$message
  )
}

#' @noRd
.pubtator_na_int <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x)) NA_integer_ else as.integer(x)
}

#' @noRd
.pubtator_na_num <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x) || !is.finite(x)) {
    NA_real_
  } else {
    as.numeric(x)
  }
}
