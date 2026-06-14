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

#' Compute the flat per-gene base tibble for the gene listing
#'
#' Collects `pubtator_human_gene_entity_view`, nests it per gene, and derives the
#' flat prioritization fields (publication_count, entities_count, is_novel,
#' oldest_pub_date, pmids). Extracted from the `/pubtator/genes` endpoint to keep
#' that file within the code-quality size baseline; enrichment metrics are joined
#' separately by the caller via [pubtator_join_enrichment_metrics()].
#'
#' @param pool_obj A dbplyr-capable pool/connection.
#' @return A per-gene tibble with the flat prioritization fields.
#' @export
pubtator_genes_nest_base <- function(pool_obj) {
  df_raw <- pool_obj %>%
    dplyr::tbl("pubtator_human_gene_entity_view") %>%
    dplyr::collect()
  df_nested <- nest_pubtator_gene_tibble_mem(df_raw)
  df_nested %>%
    dplyr::mutate(
      publication_count = purrr::map_int(publications, ~
        dplyr::filter(.x, !is.na(pmid)) %>% nrow()),
      entities_count = purrr::map_int(entities, ~
        dplyr::filter(.x, !is.na(entity_id)) %>% nrow()),
      is_novel = as.integer(entities_count == 0),
      oldest_pub_date = purrr::map_chr(publications, ~ {
        valid_pubs <- dplyr::filter(.x, !is.na(pmid) & !is.na(date))
        if (nrow(valid_pubs) == 0) {
          return(NA_character_)
        }
        as.character(min(valid_pubs$date, na.rm = TRUE))
      }),
      pmids = purrr::map_chr(publications, ~ {
        valid_pubs <- dplyr::filter(.x, !is.na(pmid)) %>%
          dplyr::arrange(date) %>%
          dplyr::distinct(pmid)
        paste(valid_pubs$pmid, collapse = ",")
      })
    )
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

#' Read the current PubtatorNDD enrichment snapshot status (lightweight)
#'
#' Cheap companion to [pubtator_enrichment_status_response()] used by the gene
#' listing to decide whether the enrichment-based ranking is meaningful. Returns
#' `status = "current"` when a `pubtator_corpus_stats` row with `is_current = 1`
#' exists, otherwise `status = "missing"` (e.g. before the first refresh). A
#' future "stale" state (snapshot present but older than the source data) can be
#' added here once the nightly job records a data version.
#'
#' @param query_fn Query function (injectable for tests). Default
#'   `db_execute_query`.
#' @return List with `status` (`"current"`/`"missing"`), `refreshed_at`
#'   (character or NA), and `genes_scored` (integer or NA).
#' @export
pubtator_genes_enrichment_meta <- function(query_fn = db_execute_query) {
  rows <- tryCatch(
    query_fn(
      "SELECT created_at, genes_scored
       FROM pubtator_corpus_stats
       WHERE is_current = 1
       LIMIT 1"
    ),
    error = function(e) NULL
  )

  if (is.null(rows) || nrow(rows) == 0) {
    return(list(
      status = "missing",
      refreshed_at = NA_character_,
      genes_scored = NA_integer_
    ))
  }

  list(
    status = "current",
    refreshed_at = as.character(rows$created_at[[1]]),
    genes_scored = rows$genes_scored[[1]]
  )
}

#' Resolve the effective gene-listing sort given enrichment availability
#'
#' The default gene sort leads with enrichment metrics
#' (`-enrichment_ratio,-npmi,publication_count`). Before the first enrichment
#' refresh those columns are all-NA, so `arrange()` silently degrades to ordering
#' by the first non-NA key (publication_count ASC) — i.e. the *least*-studied
#' genes first, which is a misleading default.
#'
#' When enrichment is unavailable AND the requested sort actually depends on an
#' enrichment metric, this helper drops the enrichment keys (and any
#' publication_count token) and forces a deterministic, sensible
#' `-publication_count` (most-studied first) lead, preserving any remaining
#' non-enrichment tiebreak keys. A sort that does not reference enrichment is an
#' explicit user choice and is returned unchanged. When enrichment is available
#' the requested sort is always returned unchanged.
#'
#' Pure function (no DB/IO) so it is unit-testable in isolation.
#'
#' @param sort Raw sort string (comma-separated, `-` prefix = descending).
#' @param enrichment_available Logical; TRUE when a current enrichment snapshot
#'   exists.
#' @return The sort string to actually apply.
#' @export
pubtator_resolve_genes_sort <- function(sort, enrichment_available) {
  if (isTRUE(enrichment_available)) {
    return(sort)
  }

  enrichment_keys <- c(
    "enrichment_ratio", "npmi", "fisher_p", "fdr_bh",
    "observed", "background_count"
  )

  tokens <- trimws(strsplit(sort %||% "", ",", fixed = TRUE)[[1]])
  tokens <- tokens[nzchar(tokens)]
  bare <- sub("^-", "", tokens)

  # A sort that never relied on enrichment is an explicit choice: respect it.
  if (!any(bare %in% enrichment_keys)) {
    return(sort)
  }

  # Drop enrichment keys and any publication_count token, then force a
  # descending publication_count lead so the fallback ranking is sensible.
  kept <- tokens[!bare %in% c(enrichment_keys, "publication_count")]
  paste(c("-publication_count", kept), collapse = ",")
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

#' Collect a lazy table, pushing a user filter down to SQL when possible
#'
#' Shared list-endpoint pattern: when a non-empty filter expression is present,
#' push it to SQL and collect; on a dbplyr translation error fall back to
#' collect-then-filter in R (emitting one diagnostic). Sorting is intentionally
#' left to the caller so endpoints can apply custom (e.g. numeric) ordering
#' after collection.
#'
#' @param lazy_tbl A dbplyr lazy table (e.g. `pool %>% dplyr::tbl("publication")`).
#' @param filter_exprs Character vector from `generate_filter_expressions()`.
#' @param source_label Short label used in the fallback diagnostic message.
#' @return A collected tibble (unsorted).
#' @export
collect_with_filter_pushdown <- function(lazy_tbl, filter_exprs, source_label) {
  has_filter <- length(filter_exprs) > 0 && nzchar(filter_exprs[[1]])
  if (!has_filter) {
    return(dplyr::collect(lazy_tbl))
  }
  tryCatch(
    lazy_tbl %>%
      dplyr::filter(!!!rlang::parse_exprs(filter_exprs)) %>%
      dplyr::collect(),
    error = function(e) {
      message(sprintf(
        "[%s] SQL filter pushdown failed (%s); falling back",
        source_label, conditionMessage(e)
      ))
      dplyr::collect(lazy_tbl) %>%
        dplyr::filter(!!!rlang::parse_exprs(filter_exprs))
    }
  )
}

#' Build the standard cursor-pagination meta tibble for list endpoints
#'
#' @param pag_meta The `meta` tibble from `generate_cursor_pag_inf()`.
#' @param sort,filter,fields Raw query parameters echoed back to the client.
#' @param fspec_obj Field-spec object from `generate_tibble_fspec_mem()`.
#' @param execution_time Human-readable execution-time string.
#' @return `pag_meta` with the standard echo columns appended.
#' @export
build_cursor_meta <- function(pag_meta, sort, filter, fields, fspec_obj,
                              execution_time) {
  pag_meta %>%
    tibble::add_column(
      tibble::as_tibble(list(
        sort = sort,
        filter = filter,
        fields = fields,
        fspec = fspec_obj,
        executionTime = execution_time
      ))
    )
}

#' Build cursor-pagination next/prev links for a list endpoint
#'
#' @param pag_links The `links` tibble from `generate_cursor_pag_inf()`.
#' @param resource_path API resource path without query string
#'   (e.g. "/publication", "/pubtator/genes").
#' @param sort,filter,fields Raw query parameters carried into the links.
#' @param api_base_url Base URL prefix; defaults to the global `dw$api_base_url`.
#' @return A one-row tibble of named links.
#' @export
build_cursor_links <- function(pag_links, resource_path, sort, filter, fields,
                               api_base_url = dw$api_base_url) {
  pag_links %>%
    tidyr::pivot_longer(
      dplyr::everything(),
      names_to = "type", values_to = "link"
    ) %>%
    dplyr::mutate(
      link = dplyr::case_when(
        link != "null" ~ paste0(
          api_base_url,
          resource_path, "?",
          "sort=", sort,
          ifelse(filter != "", paste0("&filter=", filter), ""),
          ifelse(fields != "", paste0("&fields=", fields), ""),
          link
        ),
        TRUE ~ "null"
      )
    ) %>%
    tidyr::pivot_wider(
      id_cols = dplyr::everything(),
      names_from = "type", values_from = "link"
    )
}
