# api/services/publication-query-endpoint-service.R
#
# Wave 3 / Task 2 (#346): extracted read-path bodies for
# api/endpoints/publication_endpoints.R. Endpoint shells keep every decorator,
# handler formal, and public-read authorization posture (no require_role());
# this file owns the cohesive request-processing logic so the endpoint file
# stays a thin routing/delegation layer.
#
# All public bindings here are svc_-prefixed so a dropped prefix cannot
# silently shadow a repository function loaded earlier in
# bootstrap/load_modules.R (functions/* is sourced before services/*).
#
# Dependencies (all already loaded earlier by bootstrap_load_modules()):
#   dplyr, stringr, rlang
#   functions/publication-endpoint-helpers.R (collect_with_filter_pushdown,
#     build_cursor_meta, build_cursor_links, pubtator_genes_enrichment_meta,
#     pubtator_resolve_genes_sort, pubtator_join_enrichment_metrics,
#     pubtator_public_search)
#   functions/response-helpers.R (allowed_columns_for_view,
#     generate_sort_expressions, generate_filter_expressions)
#   functions/response-fields-helpers.R (select_tibble_fields,
#     generate_cursor_pag_inf, generate_tibble_fspec_mem)
#   functions/pubtator-gene-summary.R (pubtator_genes_summary_base)
#   functions/publication-functions.R (check_pmid)
#   pool, serializers globals (initialized in start_sysndd_api.R)


#' Extract the numeric digits from a raw `<pmid>` path parameter.
#'
#' Shared normalization for both `GET <pmid>` routes: URL-decodes the segment
#' and strips everything except digits, e.g. `"PMID%3A123"` -> `"123"`.
#'
#' @param pmid_raw Raw path parameter as received by Plumber.
#' @return Character string of digits only (possibly `""`).
#' @export
svc_publication_pmid_digits <- function(pmid_raw) {
  str_replace_all(URLdecode(pmid_raw), "[^0-9]+", "")
}


#' Fetch a single publication's metadata by PMID.
#'
#' Body of the first `GET <pmid>` route (metadata lookup).
#'
#' @param pmid Raw path parameter.
#' @param pool_obj A dbplyr-capable pool/connection (default global `pool`).
#' @return A tibble with the matching publication row(s).
#' @export
svc_publication_get_by_pmid <- function(pmid, pool_obj = pool) {
  pmid_id <- paste0("PMID:", svc_publication_pmid_digits(pmid))

  pool_obj %>%
    dplyr::tbl("publication") %>%
    dplyr::filter(publication_id == pmid_id) %>%
    dplyr::select(
      publication_id,
      other_publication_id,
      Title,
      Abstract,
      Lastname,
      Firstname,
      Publication_date,
      Journal,
      Keywords
    ) %>%
    dplyr::arrange(publication_id) %>%
    dplyr::collect()
}


#' Validate that a PMID exists in PubMed.
#'
#' Body of the second `GET <pmid>` route. Note this route intentionally
#' checks the bare numeric PMID (no `"PMID:"` prefix), unlike
#' [svc_publication_get_by_pmid()].
#'
#' @param pmid Raw path parameter.
#' @param check_fn Injectable validator (default [check_pmid()]).
#' @return The validator's result (a logical).
#' @export
svc_publication_validate_pmid <- function(pmid, check_fn = check_pmid) {
  check_fn(svc_publication_pmid_digits(pmid))
}


#' Public, budget-bounded PubTator literature search (`GET pubtator/search`).
#'
#' Runs the fixed NDD literature-discovery query through the budget-bounded
#' `search_fn` and shapes the paged meta/data envelope. A degraded upstream
#' (`error = TRUE`) is surfaced as a 503, never a 200 with empty data.
#'
#' @param req,res Plumber request/response (`res$status` is set here).
#' @param current_page Requested page number (1-based).
#' @param search_fn Injectable search function (default
#'   [pubtator_public_search()]).
#' @return List body for the response (meta + data), or the 503 error body.
#' @export
svc_publication_pubtator_search <- function(req, res, current_page = 1,
                                             search_fn = pubtator_public_search) {
  # nolint start: line_length_linter
  query <- '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disorder" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)'
  # nolint end
  max_pages <- 1
  current_page <- as.numeric(current_page)

  res_pt <- search_fn(query, current_page, max_pages)
  if (isTRUE(res_pt$error)) {
    res$status <- res_pt$status %||% 503L
    return(list(error = "PubTator is temporarily unavailable.", source = "pubtator"))
  }

  res$status <- 200
  list(
    meta = list(
      "perPage" = 10,
      "currentPage" = current_page,
      "totalPages" = res_pt$total_pages
    ),
    data = res_pt$pmids
  )
}


#' Cursor-paginated listing of all publications (`GET /`).
#'
#' Full body of the publication list endpoint: allowlisted sort/filter,
#' SQL-pushdown collection, numeric PMID sort handling, field selection,
#' cursor pagination, field-spec generation, and the JSON/XLSX response
#' branch.
#'
#' @param req,res Plumber request/response.
#' @param sort,filter,fields,page_after,page_size,fspec,format Query params
#'   (see the route's `@param` docs in `endpoints/publication_endpoints.R`).
#' @param pool_obj A dbplyr-capable pool/connection (default global `pool`).
#' @return The cursor-pagination list body, or an XLSX attachment.
#' @export
svc_publication_list <- function(req, res,
                                  sort = "publication_id",
                                  filter = "",
                                  fields = "",
                                  page_after = 0,
                                  page_size = "10",
                                  fspec = "publication_id,Title,Abstract,Lastname,Firstname,Publication_date,Journal,Keywords", # nolint: line_length_linter
                                  format = "json",
                                  pool_obj = pool) {
  res$serializer <- serializers[[format]]
  start_time <- Sys.time()

  pub_allowed_cols <- allowed_columns_for_view("publication")
  sort_exprs <- generate_sort_expressions(sort, unique_id = "publication_id",
    allowed_columns = pub_allowed_cols)
  filter_exprs <- generate_filter_expressions(filter,
    allowed_columns = pub_allowed_cols)

  publication_tbl <- collect_with_filter_pushdown(
    pool_obj %>% dplyr::tbl("publication"),
    filter_exprs,
    "publication-list"
  )

  sort_col <- str_replace_all(sort, "^[+-]", "")
  sort_desc <- str_sub(sort, 1, 1) == "-"

  if (sort_col == "publication_id") {
    publication_tbl <- publication_tbl %>%
      dplyr::mutate(.pmid_numeric = as.numeric(str_replace(publication_id, "^PMID:", "")))
    publication_tbl <- if (sort_desc) {
      publication_tbl %>% dplyr::arrange(dplyr::desc(.pmid_numeric))
    } else {
      publication_tbl %>% dplyr::arrange(.pmid_numeric)
    }
    publication_tbl <- publication_tbl %>% dplyr::select(-.pmid_numeric)
  } else {
    publication_tbl <- publication_tbl %>%
      dplyr::arrange(!!!rlang::parse_exprs(sort_exprs))
  }

  publication_tbl <- select_tibble_fields(publication_tbl, fields, "publication_id")

  publication_pag_info <- generate_cursor_pag_inf(
    publication_tbl, page_size, page_after, "publication_id"
  )

  publication_tbl_fspec <- generate_tibble_fspec_mem(publication_tbl, fspec)
  publication_fspec <- publication_tbl_fspec
  publication_fspec$fspec$count_filtered <- publication_tbl_fspec$fspec$count

  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2), " secs"))

  meta <- build_cursor_meta(
    publication_pag_info$meta, sort, filter, fields, publication_fspec, execution_time
  )
  links <- build_cursor_links(publication_pag_info$links, "/publication", sort, filter, fields)

  publications_list <- list(links = links, meta = meta, data = publication_pag_info$data)

  if (format == "xlsx") {
    creation_date <- strftime(
      as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S"
    )
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
      str_replace_all("_api_", "")
    filename <- file.path(paste0(base_filename, "_", creation_date, ".xlsx"))
    bin <- generate_xlsx_bin(publications_list, base_filename)
    as_attachment(bin, filename)
  } else {
    publications_list
  }
}


#' Cursor-paginated listing of `pubtator_search_cache` rows (data only).
#'
#' Body of `GET /pubtator/table` minus the JSON/XLSX response branch, which
#' stays in the endpoint shell so the literal `"xlsx"` dispatch remains
#' auditable at the routing layer.
#'
#' @inheritParams svc_publication_list
#' @return The cursor-pagination list body (links/meta/data).
#' @export
svc_publication_pubtator_table <- function(req, res,
                                            sort = "search_id",
                                            filter = "",
                                            fields = "",
                                            page_after = 0,
                                            page_size = "10",
                                            fspec = "search_id,query_id,id,pmid,doi,title,journal,date,score,gene_symbols,text_hl", # nolint: line_length_linter
                                            pool_obj = pool) {
  start_time <- Sys.time()

  pubtator_cache_allowed_cols <- allowed_columns_for_view("pubtator_search_cache")
  sort_exprs <- generate_sort_expressions(sort, unique_id = "search_id",
    allowed_columns = pubtator_cache_allowed_cols)
  filter_exprs <- generate_filter_expressions(filter,
    allowed_columns = pubtator_cache_allowed_cols)

  table_data <- collect_with_filter_pushdown(
    pool_obj %>% dplyr::tbl("pubtator_search_cache"),
    filter_exprs,
    "pubtator-table"
  ) %>%
    dplyr::arrange(!!!rlang::parse_exprs(sort_exprs))

  table_data <- select_tibble_fields(table_data, fields, unique_id = "search_id")

  pag_info <- generate_cursor_pag_inf(table_data, page_size, page_after, "search_id")

  tbl_fspec <- generate_tibble_fspec_mem(pag_info$data, fspec)
  fspec_obj <- tbl_fspec
  fspec_obj$fspec$count_filtered <- tbl_fspec$fspec$count

  end_time <- Sys.time()
  execution_time <- paste0(round(end_time - start_time, 2), " secs")

  meta <- build_cursor_meta(pag_info$meta, sort, filter, fields, fspec_obj, execution_time)
  links <- build_cursor_links(pag_info$links, "/pubtator/table", sort, filter, fields)

  list(links = links, meta = meta, data = pag_info$data)
}


#' Cursor-paginated, flat per-gene PubTator listing (data only).
#'
#' Body of `GET /pubtator/genes` minus the JSON/XLSX response branch (kept in
#' the endpoint shell, same rationale as [svc_publication_pubtator_table()]).
#' The data-fetch steps are injectable so the enrichment-fallback sort-echo
#' behavior is host-testable without a live database.
#'
#' @param req,res Plumber request/response.
#' @param sort,filter,fields,page_after,page_size,fspec Query params.
#' @param summary_fn Injectable base-row fetcher (default
#'   [pubtator_genes_summary_base()]), called as `summary_fn(pool_obj)$data`.
#' @param enrichment_meta_fn Injectable snapshot-status fetcher (default
#'   [pubtator_genes_enrichment_meta()]).
#' @param join_enrichment_fn Injectable metric join (default
#'   [pubtator_join_enrichment_metrics()]).
#' @param pool_obj A dbplyr-capable pool/connection (default global `pool`).
#' @return The cursor-pagination list body (links/meta/data), `meta` extended
#'   with `enrichmentStatus`/`enrichmentRefreshedAt`.
#' @export
svc_publication_pubtator_genes <- function(req, res,
                                            sort = "-enrichment_ratio,-npmi,publication_count",
                                            filter = "",
                                            fields = "",
                                            page_after = "0",
                                            page_size = "10",
                                            fspec = "gene_name,gene_symbol,gene_normalized_id,hgnc_id,publication_count,entities_count,is_novel,oldest_pub_date,observed,background_count,enrichment_ratio,npmi,fisher_p,fdr_bh,pmids", # nolint: line_length_linter
                                            summary_fn = pubtator_genes_summary_base,
                                            enrichment_meta_fn = pubtator_genes_enrichment_meta,
                                            join_enrichment_fn = pubtator_join_enrichment_metrics,
                                            pool_obj = pool) {
  start_time <- Sys.time()

  # Before the first enrichment refresh the metric columns are all-NA and the
  # default `-enrichment_ratio` sort silently degrades to publication_count
  # ASC. When no current snapshot exists, resolve to a deterministic
  # `-publication_count` order but keep echoing the client's raw `sort`.
  enrichment_meta <- enrichment_meta_fn()
  enrichment_available <- identical(enrichment_meta$status, "current")
  effective_sort <- pubtator_resolve_genes_sort(sort, enrichment_available)

  # TODO allowlist: filtering/sorting operate on computed post-collect fields
  # that do not exist in the underlying view; pass NULL to preserve legacy
  # behavior (bare-identifier check still applies).
  sort_exprs <- generate_sort_expressions(effective_sort, unique_id = "gene_symbol",
    allowed_columns = NULL)
  filter_exprs <- generate_filter_expressions(filter, allowed_columns = NULL)

  df_counts <- summary_fn(pool_obj)$data
  df_counts <- join_enrichment_fn(df_counts, pool_obj)

  df_filtered <- df_counts %>%
    dplyr::filter(!!!rlang::parse_exprs(filter_exprs))
  df_sorted <- df_filtered %>%
    dplyr::arrange(!!!rlang::parse_exprs(sort_exprs))

  df_selected <- select_tibble_fields(df_sorted, fields, unique_id = "gene_symbol")

  pag_info <- generate_cursor_pag_inf(df_selected, page_size, page_after, "gene_symbol")

  tbl_fspec <- generate_tibble_fspec_mem(pag_info$data, fspec)
  tbl_fspec$fspec$count_filtered <- tbl_fspec$fspec$count

  end_time <- Sys.time()
  execution_time <- paste0(round(end_time - start_time, 2), " secs")

  # Echo the requested `sort` (not the internally-resolved one) and append the
  # enrichment snapshot status so the client can show whether ranking is current.
  meta <- build_cursor_meta(pag_info$meta, sort, filter, fields, tbl_fspec, execution_time)
  meta$enrichmentStatus <- enrichment_meta$status
  meta$enrichmentRefreshedAt <- enrichment_meta$refreshed_at %||% NA_character_

  links <- build_cursor_links(pag_info$links, "/pubtator/genes", sort, filter, fields)

  list(links = links, meta = meta, data = pag_info$data)
}
