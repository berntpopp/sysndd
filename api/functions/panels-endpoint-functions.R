# functions/panels-endpoint-functions.R
#### This file holds panels-domain endpoint functions, split out of
#### endpoint-functions.R (#346 Wave 4 Task 6).


#' Generate panels list
#'
#' @description
#' This function generates a panels list based on the input parameters. It
#' retrieves data from the database, filters and restructures it, computes
#' cursor pagination information, and execution time.
#'
#' @param sort Character string specifying the sorting order.
#' @param filter Character string specifying the filter to apply.
#' @param fields Character string specifying the fields to select.
#' @param page_after Numeric value indicating the cursor position.
#' @param page_size Character string specifying the number of items per page.
#' @param max_category Logical value indicating whether to use the max category.
#'
#' @return A list containing links, meta, fields, and data related to the panels
#' list generated.
#'
#' @export
generate_panels_list <- function(
  sort = "symbol",
  filter = "equals(category,'Definitive'),any(inheritance_filter,'Autosomal dominant','Autosomal recessive','X-linked','Other')", # nolint: line_length_linter
  fields = "category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38", # nolint: line_length_linter
  `page_after` = 0,
  `page_size` = "all",
  max_category = TRUE
) {
  # set start time
  start_time <- Sys.time()

  # get allowed values for category
  entity_status_categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    select(category) %>%
    collect()

  # get allowed values for inheritance
  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    filter(is_active) %>%
    select(inheritance_filter) %>%
    collect() %>%
    unique()

  # if max_category is true replace category in filter
  if (max_category) {
    filter <- str_replace(
      filter,
      "category",
      "max_category"
    )
  }

  # replace "All" with respective allowed values
  filter <- str_replace(
    filter,
    "category,'All'",
    paste0(
      "category,",
      str_c(entity_status_categories_list$category,
        collapse = ","
      )
    )
  ) %>%
    str_replace(
      "category,All",
      paste0(
        "category,",
        str_c(entity_status_categories_list$category,
          collapse = ","
        )
      )
    ) %>%
    str_replace(
      "inheritance_filter,'All'",
      paste0(
        "inheritance_filter,",
        str_c(mode_of_inheritance_list$inheritance_filter,
          collapse = ","
        )
      )
    ) %>%
    str_replace(
      "inheritance_filter,All",
      paste0(
        "inheritance_filter,",
        str_c(mode_of_inheritance_list$inheritance_filter,
          collapse = ","
        )
      )
    )

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "symbol")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # Generate field metadata for display
  # Manual specification used for panels endpoint to ensure consistent UI behavior
  # All fields treated as sortable text for simplicity
  fields_tibble <- as_tibble(str_split(fields, ",")[[1]]) %>%
    select(key = value) %>%
    mutate(label = str_to_sentence(str_replace_all(key, "_", " "))) %>%
    mutate(sortable = "true") %>%
    mutate(class = "text-left") %>%
    mutate(sortByFormatted = "true") %>%
    mutate(filterByFormatted = "true")

  # get the category table to compute the max category term
  status_categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    collect() %>%
    select(category_id, max_category = category)

  # join entity_view and non_alt_loci_set tables
  sysndd_db_ndd_entity_view <- pool %>%
    tbl("ndd_entity_view") %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id,
      symbol,
      inheritance = hpo_mode_of_inheritance_term_name,
      inheritance_filter,
      category,
      category_id
    ) %>%
    collect() %>%
    # following section computes the max category for a gene
    group_by(symbol) %>%
    mutate(category_id = min(category_id)) %>%
    ungroup() %>%
    left_join(status_categories_list, by = c("category_id")) %>%
    select(-category_id) %>%
    # When max_category=FALSE, remove the max_category column (not needed)
    {
      if (!max_category) select(., -max_category) else .
    }

  sysndd_db_non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, entrez_id, ensembl_gene_id, ucsc_id, bed_hg19, bed_hg38) %>%
    collect()

  sysndd_db_disease_genes <- sysndd_db_ndd_entity_view %>%
    left_join(sysndd_db_non_alt_loci_set, by = c("hgnc_id"))

  disease_genes_filter <- sysndd_db_disease_genes %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    select(-inheritance_filter) %>%
    # When max_category=TRUE, replace category column with max_category
    # This ensures arrange, mutate, and output use the max category per gene
    {
      if (max_category) {
        select(., -category) %>%
          rename(category = max_category)
      } else {
        .
      }
    } %>%
    unique() %>%
    arrange(symbol, category, inheritance) %>%
    group_by(symbol) %>%
    mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
    mutate(category = str_c(unique(category), collapse = "; ")) %>%
    ungroup() %>%
    unique() %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # select fields from table based on input using
  # the helper function "select_tibble_fields"
  sysndd_db_disease_genes_panel <- select_tibble_fields(
    disease_genes_filter,
    fields,
    "symbol"
  )

  # use the helper generate_cursor_pag_inf to
  # generate cursor pagination information from a tibble
  disease_genes_panel_pag_inf <- generate_cursor_pag_inf(
    sysndd_db_disease_genes_panel,
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

  # add columns to the meta information from
  # generate_cursor_pag_inf function return
  meta <- disease_genes_panel_pag_inf$meta %>%
    add_column(as_tibble(list(
      "sort" = sort,
      "filter" = filter,
      "fields" = fields,
      "executionTime" = execution_time
    )))

  # add host, port and other information to links from the
  # link information from generate_cursor_pag_inf function return
  links <- disease_genes_panel_pag_inf$links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(link = case_when(
      link != "null" ~ paste0(
        dw$api_base_url,
        "/api/panels/browse?sort=",
        sort,
        ifelse(filter != "",
          paste0("&filter=", filter),
          ""
        ),
        ifelse(fields != "",
          paste0("&fields=", fields),
          ""
        ),
        link
      ),
      link == "null" ~ "null"
    )) %>%
    pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

  # generate object to return
  return_list <- list(
    links = links,
    meta = meta,
    fields = fields_tibble,
    data = disease_genes_panel_pag_inf$data
  )

  # return the list
  return(return_list)
}
