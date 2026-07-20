# functions/comparisons-list.R
# Cross-database curation comparisons table builder.
#
# Extracted from endpoint-functions.R to keep that module under the 600-line
# ceiling (see AGENTS.md "Code Organization"). Sourced by
# bootstrap/load_modules.R and consumed by comparisons_endpoints.R via
# generate_comparisons_list().

#' Generate comparisons list
#'
#' @description
#' This function generates a comparisons list based on the input parameters. It
#' retrieves data from the database, filters and restructures it, computes the
#' max category term, normalizes categories, arranges and applies filters
#' according to input, and selects fields from the table based on input. It also
#' computes cursor pagination information and execution time.
#'
#' @param sort Character string specifying the sorting order.
#' @param filter Character string specifying the filter to apply.
#' @param fields Character string specifying the fields to select.
#' @param page_after Character string indicating the cursor position.
#' @param page_size Character string specifying the number of items per page.
#' @param fspec Character string specifying fields to generate from a tibble.
#' @param definitive_only Character string ("true"/"false") to filter each source
#'   to only show Definitive entries.
#'
#' @return A list containing links, meta, and data related to the comparisons
#' list generated.
#'
#' @export
generate_comparisons_list <- function(
  sort = "symbol",
  filter = "",
  fields = "",
  `page_after` = "0",
  `page_size` = "10",
  fspec = "symbol,SysNDD,gene2phenotype,panelapp,radboudumc_ID,sfari,ndd_genehub,orphanet_id,omim_ndd",
  definitive_only = "false"
) {
  # set start time
  start_time <- Sys.time()

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "symbol")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # get data from database, filter and restructure
  ndd_database_comparison_view <- pool %>%
    tbl("ndd_database_comparison_view")

  # Get canonical symbols from HGNC table
  sysndd_db_non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, canonical_symbol = symbol)  # Rename to avoid conflict

  ndd_database_comparison_table_col <- ndd_database_comparison_view %>%
    left_join(sysndd_db_non_alt_loci_set, by = c("hgnc_id")) %>%
    collect() %>%
    # Use canonical symbol from HGNC as the display symbol
    dplyr::rename(symbol = canonical_symbol)

  # normalize categories - map source-specific values to standard categories
  # Standard categories: Definitive, Moderate, Limited, Refuted, not applicable
  ndd_database_comparison_table_norm <- ndd_database_comparison_table_col %>%
    normalize_comparison_categories()

  # Parse definitive_only parameter
  definitive_only_bool <- tolower(definitive_only) %in% c("true", "1", "yes")

  # Category priority for per-source deduplication (lower = more significant)
  category_priority <- c(
    "Definitive" = 1L, "Moderate" = 2L, "Limited" = 3L,
    "Refuted" = 4L, "not applicable" = 5L
  )

  # Prepare data for pivoting: keep most significant category per (symbol, list)
  # A gene can have multiple entities in the same source (different diseases),
  # so we pick the best category within each source for pivot_wider uniqueness
  table_data <- ndd_database_comparison_table_norm %>%
    dplyr::select(symbol, hgnc_id, list, category) %>%
    dplyr::mutate(cat_priority = category_priority[category]) %>%
    dplyr::group_by(symbol, hgnc_id, list) %>%
    dplyr::slice_min(cat_priority, n = 1, with_ties = FALSE) %>%
    dplyr::ungroup() %>%
    dplyr::select(-cat_priority)

  # If definitive_only is TRUE, filter to only Definitive entries BEFORE pivoting
  # This means each source column will only show genes that are Definitive in that source
  if (definitive_only_bool) {
    table_data <- table_data %>%
      filter(category == "Definitive")
  }

  ndd_database_comparison_table <- table_data %>%
    pivot_wider(
      names_from = list,
      values_from = category,
      values_fill = "not listed"
    )

  # Global field spec: distinct-value `count` per column on the full table,
  # computed before filters are applied.
  comparison_view_fspec <- generate_tibble_fspec(
    ndd_database_comparison_table,
    fspec
  )

  # arrange and apply filters according to input
  ndd_database_comparison_table <- ndd_database_comparison_table %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # Filtered field spec -> `count_filtered`, so the column-header tooltips
  # report "<filtered>/<total>" consistently with the other table endpoints.
  comparison_view_fspec <- fspec_merge_filtered_counts(
    comparison_view_fspec,
    generate_tibble_fspec(ndd_database_comparison_table, fspec)
  )

  # select fields from table based on input using
  # the helper function "select_tibble_fields"
  ndd_database_comparison_table <- select_tibble_fields(
    ndd_database_comparison_table,
    fields,
    "symbol"
  )

  # use the helper generate_cursor_pag_inf
  # to generate cursor pagination information from a tibble
  ndd_database_comp_table_info <- generate_cursor_pag_inf(
    ndd_database_comparison_table,
    `page_size`,
    `page_after`,
    "symbol"
  )

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(
    round(end_time - start_time, 2),
    " secs"
  ))

  # add columns to the meta information from generate
  # cursor_pagination_info function return
  meta <- ndd_database_comp_table_info$meta %>%
    add_column(as_tibble(list(
      "mapping_version" = COMPARISON_CATEGORY_MAPPING_VERSION,
      "sort" = sort,
      "filter" = filter,
      "fields" = fields,
      "fspec" = comparison_view_fspec,
      "executionTime" = execution_time
    )))

  # add host, port and other information to links from the link
  # information from generate_cursor_pag_inf function return
  links <- ndd_database_comp_table_info$links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(link = case_when(
      link != "null" ~ paste0(
        dw$api_base_url,
        "/api/comparisons/table?sort=",
        sort, ifelse(filter != "",
          paste0("&filter=", filter),
          ""
        ),
        ifelse(fields != "", paste0("&fields=", fields), ""),
        link
      ),
      link == "null" ~ "null"
    )) %>%
    pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

  # generate object to return
  return_list <- list(
    links = links,
    meta = meta,
    data = ndd_database_comp_table_info$data
  )

  # return the list
  return(return_list)
}
