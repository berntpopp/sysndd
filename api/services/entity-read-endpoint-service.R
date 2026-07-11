# Entity Read Endpoint Service for SysNDD API
#
# Public read logic extracted from endpoints/entity_endpoints.R (#346, Wave 3).
# Two layers, split for testability:
#   - "shape" functions are PURE: given already-collected/filtered tibbles they
#     do field selection, cursor pagination, and fspec/meta/link assembly, with
#     no pool/DB access, so they run as ordinary host unit tests.
#   - "query"/detail functions are the DB-touching orchestrators that mirror the
#     original endpoint bodies line-for-line (same query order, same
#     current_review branches) and delegate the pure part to the shape helpers.
#
# Public-read approved-review gate (#3): every read below that is
# current_review-branch-aware sources rows through primary_approved_reviews()
# (is_primary = 1 AND review_approved = 1) for the "current" branch, and takes
# a caller-supplied `approved_review_ids` (also sourced from
# primary_approved_reviews()) for the legacy current_review = FALSE branch.
# The entity_endpoints.R shells keep computing that approved_review_ids gate
# inline (see AGENTS.md / test-unit-public-approved-review-guard.R) so the
# gate stays visible at the endpoint layer; never accept an unfiltered
# review_id set here as a substitute.

#' Coerce the `compact` query param to a real boolean
#'
#' Plumber returns scalars as length-1 character vectors (or a bare logical
#' when called in-process), so this normalizes any of those shapes the same
#' way the original inline `entity_endpoints.R` list handler did.
#'
#' @param compact Raw `compact` query param value.
#' @return Logical.
#' @export
svc_entity_compact_flag <- function(compact) {
  isTRUE(tolower(as.character(compact[[1]])) %in% c("true", "1", "yes"))
}


#' Shape a collected entity page into the `GET /entity` response body
#'
#' Pure post-processing: field selection, cursor pagination, and fspec/meta/
#' link assembly. Takes tibbles that have already been fetched (and, for the
#' default path, sorted + filtered) so it is unit-testable without a pool.
#' `meta$executionTime` is left as `NA_character_`; the DB-touching caller
#' (`svc_entity_list_query`) overwrites it with the end-to-end elapsed time so
#' the reported duration still covers the DB fetch, matching prior behavior.
#'
#' @param sysndd_db_disease_table Already sorted + filtered entity tibble
#'   (the working/paged set).
#' @param ndd_entity_view Already-collected, unfiltered entity view tibble
#'   (used for the global fspec in default mode; ignored in compact mode).
#' @param sort,filter,fields,page_after,page_size,fspec Same-named query
#'   params as the `GET /` endpoint.
#' @param is_compact Logical, pre-coerced compact flag
#'   (see `svc_entity_compact_flag()`).
#' @param api_base_url Base URL used to build pagination links.
#' @return `list(links, meta, data)`.
#' @export
svc_entity_shape_entity_page <- function(sysndd_db_disease_table, ndd_entity_view,
                                          sort, filter, fields, page_after, page_size,
                                          fspec, is_compact, api_base_url) {
  sysndd_db_disease_table <- select_tibble_fields(
    sysndd_db_disease_table,
    fields,
    "entity_id"
  )

  disease_table_pagination_info <- generate_cursor_pag_inf(
    sysndd_db_disease_table,
    page_size,
    page_after,
    "entity_id"
  )

  # In compact mode the filtered set IS the working set, so global counts and
  # filtered counts coincide. In default mode keep the global+filtered split
  # so the dropdowns can show "X of Y" totals when the user is filtering.
  sysndd_db_disease_table_fspec <- generate_tibble_fspec_mem(
    sysndd_db_disease_table,
    fspec
  )
  if (is_compact) {
    disease_table_fspec <- sysndd_db_disease_table_fspec
    disease_table_fspec$fspec <- disease_table_fspec$fspec %>%
      dplyr::mutate(count_filtered = count)
  } else {
    disease_table_fspec <- generate_tibble_fspec_mem(
      ndd_entity_view,
      fspec
    )
    disease_table_fspec <- fspec_merge_filtered_counts(
      disease_table_fspec,
      sysndd_db_disease_table_fspec
    )
  }

  meta <- disease_table_pagination_info$meta %>%
    add_column(
      tibble::as_tibble(list(
        "sort" = sort,
        "filter" = filter,
        "fields" = fields,
        "fspec" = disease_table_fspec,
        "executionTime" = NA_character_
      ))
    )

  links <- disease_table_pagination_info$links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(
      link = case_when(
        link != "null" ~ paste0(
          api_base_url,
          "?sort=",
          sort,
          ifelse(filter != "", paste0("&filter=", filter), ""),
          ifelse(fields != "", paste0("&fields=", fields), ""),
          link
        ),
        link == "null" ~ "null"
      )
    ) %>%
    pivot_wider(
      id_cols = everything(),
      names_from = "type",
      values_from = "link"
    )

  list(
    links = links,
    meta = meta,
    data = disease_table_pagination_info$data
  )
}


#' `GET /entity` cursor-paginated entity list — DB-touching orchestrator
#'
#' Mirrors the original inline handler: derives the sort/filter allowlist,
#' pushes a compact-mode text filter to SQL when safe (fast path), otherwise
#' collects the full view and filters/sorts in R, resolves an optional
#' vario_id join filter, then delegates shaping to
#' `svc_entity_shape_entity_page()`.
#'
#' @param sort,filter,fields,page_after,page_size,fspec,compact Same-named
#'   query params as the `GET /` endpoint.
#' @param pool Database connection pool.
#' @param api_base_url Base URL used to build pagination links; defaults to
#'   the running API's `dw$api_base_url` when available (call-time default,
#'   mirrors the `.cache_fingerprint` pattern) so callers don't need to pass
#'   it explicitly.
#' @return `list(links, meta, data)`.
#' @export
svc_entity_list_query <- function(sort = "entity_id", filter = "", fields = "",
                                   page_after = 0, page_size = "10",
                                   fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details", # nolint: line_length_linter
                                   compact = "false", pool,
                                   api_base_url = if (exists("dw")) dw$api_base_url else NULL) {
  start_time <- Sys.time()

  is_compact <- svc_entity_compact_flag(compact)

  # Derive allowlist from ndd_entity_view; returns NULL on transient DB error
  # (legacy behavior: allowlist disabled, bare-identifier check still applies).
  entity_allowed_cols <- allowed_columns_for_view("ndd_entity_view")

  sort_exprs <- generate_sort_expressions(sort, unique_id = "entity_id",
    allowed_columns = entity_allowed_cols)

  # Extract vario_id filter (handled separately due to join table)
  vario_filter_result <- extract_vario_filter(filter)

  filter_exprs <- generate_filter_expressions(vario_filter_result$filter_without_vario,
    allowed_columns = entity_allowed_cols)

  has_text_filter <- length(filter_exprs) > 0 && nzchar(filter_exprs[[1]])
  has_vario_filter <- isTRUE(vario_filter_result$has_vario_filter)

  ndd_entity_review <- primary_approved_reviews(pool, cols = c("entity_id", "synopsis"))

  ndd_entity_view_lazy <- pool %>%
    tbl("ndd_entity_view") %>%
    left_join(ndd_entity_review, by = c("entity_id"))

  # Fast path: compact mode + text filter + no vario join -> push the filter
  # to SQL via dbplyr. Falls back to the in-R filter loop if dbplyr can't
  # translate the expression.
  fast_path_filtered <- NULL
  if (is_compact && has_text_filter && !has_vario_filter) {
    fast_path_filtered <- tryCatch(
      ndd_entity_view_lazy %>%
        filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        collect(),
      error = function(e) {
        message(sprintf(
          "[entity-list] SQL filter pushdown failed (%s); falling back to in-R filter",
          conditionMessage(e)
        ))
        NULL
      }
    )
  }

  if (!is.null(fast_path_filtered)) {
    ndd_entity_view <- fast_path_filtered
    sysndd_db_disease_table <- fast_path_filtered %>%
      arrange(!!!rlang::parse_exprs(sort_exprs))
  } else {
    ndd_entity_view <- ndd_entity_view_lazy %>% collect()

    if (has_vario_filter) {
      matching_entity_ids <- get_entity_ids_by_vario(vario_filter_result$vario_ids, pool)
      ndd_entity_view <- ndd_entity_view %>%
        filter(entity_id %in% matching_entity_ids)
    }

    sysndd_db_disease_table <- ndd_entity_view %>%
      arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
      filter(!!!rlang::parse_exprs(filter_exprs))
  }

  result <- svc_entity_shape_entity_page(
    sysndd_db_disease_table = sysndd_db_disease_table,
    ndd_entity_view = ndd_entity_view,
    sort = sort, filter = filter, fields = fields,
    page_after = page_after, page_size = page_size,
    fspec = fspec, is_compact = is_compact,
    api_base_url = api_base_url
  )

  end_time <- Sys.time()
  result$meta$executionTime <- as.character(
    paste0(round(end_time - start_time, 2), " secs")
  )

  result
}


#' `GET /entity/<id>/phenotypes` — DB-touching orchestrator
#'
#' @param sysndd_id Entity id.
#' @param current_review Logical (or plumber-coerced equivalent); TRUE reads
#'   the currently active review only, FALSE reads all approved-primary
#'   reviews (legacy "all reviews" mode).
#' @param approved_review_ids Pre-fetched approved-primary review ids for the
#'   `current_review = FALSE` branch (ignored when `current_review` is TRUE);
#'   the caller computes this via `primary_approved_reviews()` so the
#'   approved-review gate stays visible at the endpoint layer.
#' @param pool Database connection pool.
#' @return Tibble of entity_id, phenotype_id, HPO_term, modifier_id.
#' @export
svc_entity_phenotypes <- function(sysndd_id, current_review, approved_review_ids, pool) {
  if (current_review) {
    ndd_entity_review_list <- primary_approved_reviews(pool) %>%
      dplyr::filter(entity_id == sysndd_id) %>%
      dplyr::select(entity_id, review_id, synopsis, review_date, comment) %>%
      dplyr::arrange(review_date) %>%
      dplyr::collect()

    ndd_review_phenotype_conn_coll <- pool %>%
      tbl("ndd_review_phenotype_connect") %>%
      filter(review_id %in% ndd_entity_review_list$review_id & is_active == 1) %>%
      collect()
  } else {
    ndd_review_phenotype_conn_coll <- pool %>%
      tbl("ndd_review_phenotype_connect") %>%
      filter(is_active == 1 & review_id %in% approved_review_ids) %>%
      collect()
  }

  phenotype_list_collected <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  ndd_entity_active <- pool %>%
    tbl("ndd_entity_view") %>%
    dplyr::select(entity_id) %>%
    collect()

  ndd_entity_active %>%
    left_join(ndd_review_phenotype_conn_coll, by = c("entity_id")) %>%
    filter(entity_id == sysndd_id) %>%
    inner_join(phenotype_list_collected, by = c("phenotype_id")) %>%
    dplyr::select(entity_id, phenotype_id, HPO_term, modifier_id) %>%
    arrange(phenotype_id) %>%
    unique()
}


#' `GET /entity/<id>/variation` — DB-touching orchestrator
#'
#' @inheritParams svc_entity_phenotypes
#' @return Tibble of entity_id, vario_id, vario_name, modifier_id.
#' @export
svc_entity_variation <- function(sysndd_id, current_review, approved_review_ids, pool) {
  if (current_review) {
    ndd_entity_review_list <- primary_approved_reviews(pool) %>%
      dplyr::filter(entity_id == sysndd_id) %>%
      dplyr::select(entity_id, review_id, synopsis, review_date, comment) %>%
      dplyr::arrange(review_date) %>%
      dplyr::collect()

    ndd_review_variation_conn_coll <- pool %>%
      tbl("ndd_review_variation_ontology_connect") %>%
      filter(review_id %in% ndd_entity_review_list$review_id
        & entity_id == sysndd_id & is_active == 1) %>%
      collect()
  } else {
    ndd_review_variation_conn_coll <- pool %>%
      tbl("ndd_review_variation_ontology_connect") %>%
      filter(is_active == 1 & entity_id == sysndd_id & review_id %in% approved_review_ids) %>%
      collect()
  }

  variation_list_collected <- pool %>%
    tbl("variation_ontology_list") %>%
    collect()

  ndd_review_variation_conn_coll %>%
    inner_join(variation_list_collected, by = c("vario_id")) %>%
    dplyr::select(entity_id, vario_id, vario_name, modifier_id) %>%
    arrange(vario_id) %>%
    unique()
}


#' `GET /entity/<id>/review` — DB-touching orchestrator
#'
#' @param sysndd_id Entity id.
#' @param pool Database connection pool.
#' @return Single-row-per-entity tibble of entity_id, review_id, synopsis,
#'   review_date, comment (NA columns when there is no approved-primary
#'   review).
#' @export
svc_entity_review <- function(sysndd_id, pool) {
  ndd_entity_review_list <- primary_approved_reviews(pool) %>%
    dplyr::filter(entity_id == sysndd_id) %>%
    dplyr::select(entity_id, review_id, synopsis, review_date, comment) %>%
    dplyr::arrange(review_date) %>%
    dplyr::collect()

  tibble::as_tibble(sysndd_id) %>%
    dplyr::select(entity_id = value) %>%
    mutate(entity_id = as.integer(entity_id)) %>%
    left_join(ndd_entity_review_list, by = c("entity_id"))
}


#' `GET /entity/<id>/status` — DB-touching orchestrator
#'
#' @param sysndd_id Entity id.
#' @param pool Database connection pool.
#' @return Tibble of status_id, entity_id, category, category_id, status_date,
#'   comment, problematic for the entity's active + approved status rows.
#' @export
svc_entity_status <- function(sysndd_id, pool) {
  ndd_entity_status_collected <- pool %>%
    tbl("ndd_entity_status") %>%
    collect()

  entity_status_categories_coll <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    collect()

  ndd_entity_status_collected %>%
    filter(entity_id == sysndd_id & is_active & status_approved == 1) %>%
    inner_join(entity_status_categories_coll, by = c("category_id")) %>%
    dplyr::select(
      status_id,
      entity_id,
      category,
      category_id,
      status_date,
      comment,
      problematic
    ) %>%
    arrange(status_date)
}


#' `GET /entity/<id>/publications` — DB-touching orchestrator
#'
#' @inheritParams svc_entity_phenotypes
#' @return Tibble of entity_id, publication_id, publication_type, is_reviewed.
#' @export
svc_entity_publications <- function(sysndd_id, current_review, approved_review_ids, pool) {
  if (current_review) {
    ndd_entity_review_list <- primary_approved_reviews(pool) %>%
      dplyr::filter(entity_id == sysndd_id) %>%
      dplyr::select(entity_id, review_id, synopsis, review_date, comment) %>%
      dplyr::arrange(review_date) %>%
      dplyr::collect()

    review_publication_join_coll <- pool %>%
      tbl("ndd_review_publication_join") %>%
      filter(review_id %in% ndd_entity_review_list$review_id) %>%
      collect()
  } else {
    review_publication_join_coll <- pool %>%
      tbl("ndd_review_publication_join") %>%
      filter(is_reviewed == 1 & review_id %in% approved_review_ids) %>%
      collect()
  }

  ndd_entity_active <- pool %>%
    tbl("ndd_entity_view") %>%
    dplyr::select(entity_id) %>%
    collect()

  ndd_entity_active %>%
    left_join(review_publication_join_coll, by = c("entity_id")) %>%
    filter(entity_id == sysndd_id) %>%
    dplyr::select(entity_id, publication_id, publication_type, is_reviewed) %>%
    arrange(publication_id) %>%
    unique()
}
