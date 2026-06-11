# api/functions/publication-endpoint-helpers.R

publication_stats_response <- function(not_updated_since = NULL,
                                       query_fn = db_execute_query) {
  total_result <- query_fn(
    "SELECT COUNT(*) as total FROM publication"
  )
  oldest_result <- query_fn(
    "SELECT MIN(update_date) as oldest_update FROM publication"
  )
  outdated_result <- query_fn(
    "SELECT COUNT(*) as outdated_count FROM publication WHERE update_date < DATE_SUB(NOW(), INTERVAL 1 YEAR)"
  )

  result <- list(
    total = as.integer(total_result$total[1]),
    oldest_update = as.character(oldest_result$oldest_update[1]),
    outdated_count = as.integer(outdated_result$outdated_count[1])
  )

  if (!is.null(not_updated_since) && nzchar(not_updated_since)) {
    filter_date <- tryCatch(
      as.Date(not_updated_since),
      error = function(e) NULL
    )

    if (!is.null(filter_date) && !is.na(filter_date)) {
      filtered_result <- query_fn(
        "SELECT COUNT(*) as filtered_count FROM publication WHERE update_date < ?",
        list(as.character(filter_date))
      )
      result$filtered_count <- as.integer(filtered_result$filtered_count[1])
      result$filter_date <- as.character(filter_date)
    }
  }

  result
}

#' Left-join normalized PubtatorNDD enrichment metrics onto the gene listing
#'
#' Issue #175: raw NDD co-occurrence count conflates true NDD relevance with
#' research popularity. The worker-precomputed enrichment metrics
#' (`pubtator_gene_enrichment_view`) are LEFT-joined so genes without a metric
#' yet still appear with NA metric columns.
#'
#' @param df_counts Nested gene tibble with computed prioritization fields.
#' @param pool_obj A dbplyr-capable pool/connection.
#' @return `df_counts` with observed/background_count/enrichment_ratio/npmi/
#'   fisher_p/fdr_bh columns guaranteed present.
#' @export
pubtator_join_enrichment_metrics <- function(df_counts, pool_obj) {
  enrichment_cols <- c(
    "gene_symbol", "observed", "background_count",
    "enrichment_ratio", "npmi", "fisher_p", "fdr_bh"
  )
  df_enrichment <- tryCatch(
    pool_obj %>%
      dplyr::tbl("pubtator_gene_enrichment_view") %>%
      dplyr::select(dplyr::any_of(enrichment_cols)) %>%
      dplyr::collect(),
    error = function(e) NULL
  )

  if (is.null(df_enrichment) || nrow(df_enrichment) == 0) {
    return(dplyr::mutate(
      df_counts,
      observed = NA_integer_,
      background_count = NA_integer_,
      enrichment_ratio = NA_real_,
      npmi = NA_real_,
      fisher_p = NA_real_,
      fdr_bh = NA_real_
    ))
  }

  dplyr::left_join(df_counts, df_enrichment, by = "gene_symbol")
}

#' Submit the durable PubtatorNDD enrichment refresh job and shape the response
#'
#' @param res Plumber response (status/headers are set here).
#' @param submitted_by Optional user id.
#' @param submit_fn Submit function (injectable for tests).
#' @return Submission summary list.
#' @export
pubtator_enrichment_refresh_submit <- function(res,
                                               submitted_by = NULL,
                                               submit_fn = async_job_service_submit) {
  submitted <- submit_fn(
    job_type = "pubtator_enrichment_refresh",
    request_payload = list(refresh = "all"),
    submitted_by = submitted_by
  )

  job <- submitted$job
  job_id <- job$job_id[[1]]
  status_url <- paste0("/api/jobs/", job_id, "/status")

  res$status <- if (isTRUE(submitted$duplicate)) 409L else 202L
  res$setHeader("Location", status_url)
  res$setHeader("Retry-After", "5")

  list(
    job_id = job_id,
    status = if (isTRUE(submitted$duplicate)) "already_running" else "accepted",
    job_status = job$status[[1]],
    status_url = status_url
  )
}

#' Build the current PubtatorNDD enrichment snapshot status payload
#'
#' @param query_fn Query function (injectable for tests).
#' @return List describing the current snapshot, or `available = FALSE`.
#' @export
pubtator_enrichment_status_response <- function(query_fn = db_execute_query) {
  rows <- tryCatch(
    query_fn(
      "SELECT corpus_stats_id, ndd_corpus_size, total_corpus_size,
              total_is_fallback, genes_scored, created_at
       FROM pubtator_corpus_stats
       WHERE is_current = 1
       LIMIT 1"
    ),
    error = function(e) NULL
  )

  if (is.null(rows) || nrow(rows) == 0) {
    return(list(
      available = FALSE,
      message = "No enrichment snapshot yet; run POST /pubtator/enrichment/refresh"
    ))
  }

  list(
    available = TRUE,
    corpus_stats_id = rows$corpus_stats_id[[1]],
    ndd_corpus_size = rows$ndd_corpus_size[[1]],
    total_corpus_size = rows$total_corpus_size[[1]],
    total_is_fallback = as.logical(rows$total_is_fallback[[1]]),
    genes_scored = rows$genes_scored[[1]],
    refreshed_at = as.character(rows$created_at[[1]])
  )
}
