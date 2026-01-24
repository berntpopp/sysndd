# functions/endpoints-functions.R
#### This file holds endpoint functions

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
#'
#' @return A list containing links, meta, and data related to the comparisons
#' list generated.
#'
#' @export
generate_comparisons_list <- function(sort = "symbol",
  filter = "",
  fields = "",
  `page_after` = "0",
  `page_size` = "10",
  fspec = "symbol,SysNDD,radboudumc_ID,gene2phenotype,panelapp,sfari,geisinger_DBD,omim_ndd,orphanet_id") {
  # set start time
  start_time <- Sys.time()

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "symbol")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # get data from database, filter and restructure
  ndd_database_comparison_view <- pool %>%
    tbl("ndd_database_comparison_view")

  sysndd_db_non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, symbol)

  ndd_database_comparison_table_col <- ndd_database_comparison_view %>%
    left_join(sysndd_db_non_alt_loci_set, by = c("hgnc_id")) %>%
    collect()

  # get the category table to compute the max category term
  status_categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    collect() %>%
    select(category_id, max_category = category)

  # normalize categories
  ndd_database_comparison_table_norm <- ndd_database_comparison_table_col %>%
    mutate(category = case_when(
      list == "gene2phenotype" & category == "strong" ~ "Definitive",
      list == "gene2phenotype" & category == "definitive" ~ "Definitive",
      list == "gene2phenotype" & category == "limited" ~ "Limited",
      list == "gene2phenotype" & category == "moderate" ~ "Moderate",
      list == "gene2phenotype" & category == "both RD and IF" ~ "Definitive",
      list == "panelapp" & category == "3" ~ "Definitive",
      list == "panelapp" & category == "2" ~ "Limited",
      list == "panelapp" & category == "1" ~ "Refuted",
      list == "sfari" & category == "1" ~ "Definitive",
      list == "sfari" & category == "2" ~ "Moderate",
      list == "sfari" & category == "3" ~ "Limited",
      list == "sfari" & is.na(category) ~ "Definitive",
      list == "geisinger_DBD" ~ "Definitive",
      TRUE ~ category
    )) %>%
    left_join(status_categories_list, by = c("category" = "max_category")) %>%
    # following section computes the max category for a gene %>%
    group_by(symbol) %>%
    mutate(category_id = min(category_id)) %>%
    ungroup() %>%
    select(-category) %>%
    left_join(status_categories_list, by = c("category_id"))

  ndd_database_comparison_table <- ndd_database_comparison_table_norm %>%
    select(symbol, hgnc_id, list, category = max_category) %>%
    unique() %>%
    pivot_wider(names_from = list,
      values_from = category,
      values_fill = "not listed")

  # use the helper generate_tibble_fspec to
  # generate fields specs from a tibble
  comparison_view_fspec <- generate_tibble_fspec(
    ndd_database_comparison_table,
    fspec)

  # arrange and apply filters according to input
  ndd_database_comparison_table <- ndd_database_comparison_table %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # select fields from table based on input using
  # the helper function "select_tibble_fields"
  ndd_database_comparison_table <- select_tibble_fields(
    ndd_database_comparison_table,
    fields,
    "symbol")

  # use the helper generate_cursor_pag_inf
  # to generate cursor pagination information from a tibble
  ndd_database_comp_table_info <- generate_cursor_pag_inf(
    ndd_database_comparison_table,
    `page_size`,
    `page_after`,
    "symbol")

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2),
  " secs"))

  # add columns to the meta information from generate
  # cursor_pagination_info function return
  meta <- ndd_database_comp_table_info$meta %>%
    add_column(as_tibble(list("sort" = sort,
      "filter" = filter,
      "fields" = fields,
      "fspec" = comparison_view_fspec,
      "executionTime" = execution_time)))

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
        ""),
        ifelse(fields != "", paste0("&fields=", fields), ""),
        link),
      link == "null" ~ "null"
    )) %>%
      pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

  # generate object to return
  return_list <- list(links = links,
    meta = meta,
    data = ndd_database_comp_table_info$data)

  # return the list
  return(return_list)
  }


#' Generate phenotype entities list
#'
#' @description
#' This function generates a phenotype entities list based on the input
#' parameters. It retrieves data from the database, filters and restructures it,
#' computes cursor pagination information, and execution time.
#'
#' @param sort Character string specifying the sorting order.
#' @param filter Character string specifying the filter to apply.
#' @param fields Character string specifying the fields to select.
#' @param page_after Character string indicating the cursor position.
#' @param page_size Character string specifying the number of items per page.
#' @param fspec Character string specifying fields to generate from a tibble.
#'
#' @return A list containing links, meta, and data related to the phenotype
#' entities list generated.
#'
#' @export
generate_phenotype_entities_list <- function(sort = "entity_id",
  filter = "",
  fields = "",
  `page_after` = "0",
  `page_size` = "all",
  fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details") {
  # set start time
  start_time <- Sys.time()

  filter <- URLdecode(filter)

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "entity_id")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # load the phenotype view
  ndd_review_phenotype_connect <- pool %>%
    tbl("ndd_review_phenotype_connect_view") %>%
    collect() %>%
    select(entity_id, modifier_phenotype_id) %>%
    group_by(entity_id) %>%
    arrange(entity_id, modifier_phenotype_id) %>%
    mutate(modifier_phenotype_id = paste0(modifier_phenotype_id,
      collapse = ",")) %>%
    ungroup() %>%
    unique()

  # collect view from database
  entity_phenotype_table <- pool %>%
    tbl("ndd_entity_view") %>%
    collect() %>%
    left_join(ndd_review_phenotype_connect, by = c("entity_id")) %>%
    filter(!is.na(modifier_phenotype_id))

  # apply filters
  sysndd_db_entity_phenotype_table <- entity_phenotype_table %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # use the helper generate_tibble_fspec to
  # generate fields specs from a tibble
  entity_phenotype_table_fspec <- generate_tibble_fspec_mem(
    entity_phenotype_table,
    fspec)
  sysndd_db_entity_phenotype_table_fspec <- generate_tibble_fspec_mem(
    sysndd_db_entity_phenotype_table,
    fspec)
  entity_phenotype_table_fspec$fspec$count_filtered <-
    sysndd_db_entity_phenotype_table_fspec$fspec$count

  # select fields from table based on input
  # using the helper function "select_tibble_fields"
  sysndd_db_entity_phenotype_table <- select_tibble_fields(
    sysndd_db_entity_phenotype_table,
    fields,
    "entity_id")

  # use the helper generate_cursor_pag_inf
  # to generate cursor pagination information from a tibble
  entity_phenotype_table_pag_info <- generate_cursor_pag_inf(
    sysndd_db_entity_phenotype_table,
    `page_size`, `page_after`,
    "entity_id")

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2),
  " secs"))

  # add columns to the meta information from
  # generate_cursor_pag_inf function return
  meta <- entity_phenotype_table_pag_info$meta %>%
    add_column(as_tibble(list("sort" = sort,
      "filter" = filter,
      "fields" = fields,
      "fspec" = entity_phenotype_table_fspec,
      "executionTime" = execution_time)))

  # add host, port and other information to links from the link
  # information from generate_cursor_pag_inf function return
  links <- entity_phenotype_table_pag_info$links %>%
      pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(link = case_when(
      link != "null" ~ paste0(
        dw$api_base_url,
        "/api/phenotype/entities/browse?sort=",
        sort,
        ifelse(filter != "", paste0("&filter=", filter), ""),
        ifelse(fields != "", paste0("&fields=", fields), ""),
        link),
      link == "null" ~ "null"
    )) %>%
      pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

  # generate object to return
  return_list <- list(links = links,
    meta = meta,
    data = entity_phenotype_table_pag_info$data)

  # return the list
  return(return_list)
}


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
generate_panels_list <- function(sort = "symbol",
  filter = "equals(category,'Definitive'),any(inheritance_filter,'Autosomal dominant','Autosomal recessive','X-linked','Other')",
  fields = "category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38",
  `page_after` = 0,
  `page_size` = "all",
  max_category = TRUE) {

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
  filter <- str_replace(filter,
    "category",
    "max_category")
  }

  # replace "All" with respective allowed values
  filter <- str_replace(filter,
    "category,'All'",
    paste0("category,",
      str_c(entity_status_categories_list$category,
        collapse = ","))) %>%
    str_replace("category,All",
    paste0("category,",
      str_c(entity_status_categories_list$category,
        collapse = ","))) %>%
    str_replace("inheritance_filter,'All'",
    paste0("inheritance_filter,",
      str_c(mode_of_inheritance_list$inheritance_filter,
        collapse = ","))) %>%
    str_replace("inheritance_filter,All",
    paste0("inheritance_filter,",
      str_c(mode_of_inheritance_list$inheritance_filter,
        collapse = ",")))

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "symbol")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # Generate field metadata for display
  # TODO(future): Auto-generate field metadata from MySQL schema
  # Current implementation uses manual field specification
  # Enhancement: Query INFORMATION_SCHEMA.COLUMNS for field types,
  # determine sortable/filterable based on MySQL column type
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
      category_id) %>%
    collect() %>%
    # following section computes the max category for a gene
    group_by(symbol) %>%
    mutate(category_id = min(category_id)) %>%
    ungroup() %>%
    left_join(status_categories_list, by = c("category_id")) %>%
    select(-category_id)

  sysndd_db_non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, entrez_id, ensembl_gene_id, ucsc_id, bed_hg19, bed_hg38) %>%
    collect()

  sysndd_db_disease_genes <- sysndd_db_ndd_entity_view %>%
    left_join(sysndd_db_non_alt_loci_set, by = c("hgnc_id"))

  disease_genes_filter <- sysndd_db_disease_genes %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        select(-inheritance_filter) %>%
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
    "symbol")

  # use the helper generate_cursor_pag_inf to
  # generate cursor pagination information from a tibble
  disease_genes_panel_pag_inf <- generate_cursor_pag_inf(
    sysndd_db_disease_genes_panel,
    `page_size`,
    `page_after`,
    "symbol")

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2),
    " secs"))

  # add columns to the meta information from
  # generate_cursor_pag_inf function return
  meta <- disease_genes_panel_pag_inf$meta %>%
    add_column(as_tibble(list("sort" = sort,
      "filter" = filter,
      "fields" = fields,
      "executionTime" = execution_time)))

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
          ""),
        ifelse(fields != "",
          paste0("&fields=", fields),
          ""),
        link),
      link == "null" ~ "null"
    )) %>%
      pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

  # generate object to return
  return_list <- list(links = links,
    meta = meta,
    fields = fields_tibble,
    data = disease_genes_panel_pag_inf$data)

  # return the list
  return(return_list)
}


#' Generate a tibble of statistics for disease types
#'
#' This function takes inputs for sorting and type and
#' generates a tibble of statistics for disease types based
#' on a pool of data. It also has the option to limit the number of
#' categories to only the maximum, if max_category = TRUE.
#'
#' @param sort A character string indicating how to sort the output.
#' The format should be "column_name,direction"
#' (e.g. "category_id,-n" to sort by category_id in ascending
#' order and then by n in descending order).
#' @param type A character string indicating the type of data to include.
#' Can be either "gene" or "entity".
#' @param max_category A logical value indicating whether to limit
#' the number of categories to only the maximum. Default is TRUE.
#' @export
#'
#' @return A list with two components: meta and data. The meta
#' component includes the last_update date from the ndd_entity_view table
#'  in the database, as well as the execution time of the function.
#' The data component includes a tibble of  statistics for disease types,
#' with columns for category, inheritance (if applicable), and count.
#'
#' @examples
#' # Generate a tibble of statistics for genes,
#' sorted by category_id in ascending order
#' generate_stat_tibble(sort = "category_id", type = "gene")
#'
#' # Generate a tibble of statistics for entities,
#' limited to the maximum category
#' generate_stat_tibble(max_category = TRUE, type = "entity")
#'
#' @seealso https://www.tidyverse.org/ for more information on the tidyverse packages used in this function
#' @seealso https://db.rstudio.com/pool/ for more information on the RStudio Pool package
generate_stat_tibble <- function(sort = "category_id,-n",
  type = "gene",
  max_category = TRUE) {
  # set start time
  start_time <- Sys.time()

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "category_id")

  # conditionally select columns to based on input
  sysndd_db_disease_types <- pool %>%
    tbl("ndd_entity_view") %>%
    filter(ndd_phenotype == 1) %>%
    # this is a fix to remove "not applicable" entries
    # this is a fix to remove "refuted" entries
    filter(!(category_id %in% c(4, 5))) %>%
    collect() %>%
    arrange(entity_id) %>%
    {if (type == "gene")
      select(., symbol,
        inheritance = hpo_mode_of_inheritance_term_name,
        category,
        category_id)
     else .
     } %>%
    {if (type == "entity")
      select(., entity_id,
        inheritance = hpo_mode_of_inheritance_term_name,
        category,
        category_id)
     else .
     }

  # if max_category is true replace category in filter
  if (max_category) {
    # get the category table to compute the max category term
    status_categories_list <- pool %>%
      tbl("ndd_entity_status_categories_list") %>%
      collect() %>%
      select(category_id, category)

    # following section computes the max category for a gene
    sysndd_db_disease_types <- sysndd_db_disease_types %>%
        {if (type == "gene")
          group_by(., symbol)
        else .
        } %>%
        {if (type == "entity")
          group_by(., entity_id)
        else .
        } %>%
      mutate(category_id = min(category_id)) %>%
      ungroup() %>%
      select(-category) %>%
      left_join(status_categories_list, by = c("category_id"))
  }

  disease_types_group_cat_inh <- sysndd_db_disease_types %>%
    mutate(inheritance = case_when(
      str_detect(inheritance, "X-linked") ~ "X-linked",
      str_detect(inheritance, "Autosomal dominant inheritance") ~
        "Autosomal dominant",
      str_detect(inheritance, "Autosomal recessive inheritance") ~
        "Autosomal recessive",
      TRUE ~ "Other"
    )) %>%
    unique() %>%
    group_by(category, category_id, inheritance) %>%
    tally() %>%
    ungroup() %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    mutate(category_group = category) %>%
    group_by(category_group) %>%
    nest() %>%
    ungroup() %>%
    select(category = category_group, groups = data)

  disease_types_group_category <- sysndd_db_disease_types %>%
    select(-inheritance) %>%
    unique() %>%
    group_by(category, category_id) %>%
    tally() %>%
    ungroup() %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    group_by(category) %>%
    mutate(inheritance = "All")

  disease_types_statistics <- disease_types_group_category %>%
    left_join(disease_types_group_cat_inh,
     by = c("category")) %>%
    select(-category_id)

  # get data for last entry from database as meta
  disease_entry_date_last <- pool %>%
    tbl("ndd_entity_view") %>%
    select(entry_date) %>%
    arrange(desc(entry_date)) %>%
    head(1) %>%
    collect() %>%
    select(last_update = entry_date)

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2),
  " secs"))

  # add columns to the meta information from generate
  # cursor_pagination_info function return
  meta <- as_tibble(list(
      "last_update" = disease_entry_date_last$last_update,
      "executionTime" = execution_time))

  # generate object to return
  return_list <- list(
    meta = meta,
    data = disease_types_statistics)

  # return the list
  return(return_list)
}


#' Generate Gene News Tibble
#'
#' This function generates a tibble of news for genes associated with
#' neurodevelopmental disorders (NDDs). The data is retrieved from a database
#' and filtered based on certain criteria before being returned as a tibble.
#'
#' @param n Numeric value indicating the number of news items to include in
#' the tibble.
#' @return A tibble containing news for genes associated with NDDs.
#' @export
#' @seealso See 'pool', 'tbl', 'arrange', 'filter', 'collect', 'slice',
#' and 'desc' for more information on the functions used.
#' @examples
#' generate_gene_news_tibble(10)
generate_gene_news_tibble <- function(n) {
  # get data from database and filter
  sysndd_db_disease_genes_news <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    filter(ndd_phenotype == 1 & category == "Definitive") %>%
    collect() %>%
    arrange(desc(entry_date)) %>%
    slice(1:n)

  return(sysndd_db_disease_genes_news)
}


# functions/endpoint-functions.R

#' Generate variant entities list
#'
#' @description
#' This function generates a variant entities list. It retrieves data from the DB,
#' filters it, creates a comma-separated 'modifier_variant_id' (which actually
#' references 'vario_id'), and returns a paginated list.
#'
#' @export
generate_variant_entities_list <- function(sort = "entity_id",
                                           filter = "",
                                           fields = "",
                                           page_after = "0",
                                           page_size = "all",
                                           fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,modifier_variant_id,details") {
  start_time <- Sys.time()
  filter <- URLdecode(filter)

  # 1) Sort and Filter expressions
  sort_exprs <- generate_sort_expressions(sort, unique_id = "entity_id")
  filter_exprs <- generate_filter_expressions(filter)

  # 2) Load your new 'ndd_review_variant_connect_view'
  #    which has 'entity_id' and 'modifier_variant_id'
  ndd_review_variant_connect <- pool %>%
    tbl("ndd_review_variant_connect_view") %>%
    collect() %>%
    select(entity_id, modifier_variant_id) %>%
    group_by(entity_id) %>%
    arrange(entity_id, modifier_variant_id) %>%
    mutate(modifier_variant_id = paste0(modifier_variant_id, collapse = ",")) %>%
    ungroup() %>%
    unique()

  # 3) Join with entity view
  entity_variant_table <- pool %>%
    tbl("ndd_entity_view") %>%
    collect() %>%
    left_join(ndd_review_variant_connect, by = "entity_id") %>%
    # only keep those rows that have a variant
    filter(!is.na(modifier_variant_id))

  # 4) Apply user filter/sort
  sysndd_db_entity_variant_table <- entity_variant_table %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # 5) Generate field specs
  entity_variant_table_fspec <- generate_tibble_fspec_mem(entity_variant_table, fspec)
  sysndd_db_entity_variant_table_fspec <- generate_tibble_fspec_mem(sysndd_db_entity_variant_table, fspec)
  entity_variant_table_fspec$fspec$count_filtered <-
    sysndd_db_entity_variant_table_fspec$fspec$count

  # 6) Select fields
  sysndd_db_entity_variant_table <- select_tibble_fields(
    sysndd_db_entity_variant_table,
    fields,
    "entity_id"
  )

  # 7) Cursor pagination
  entity_variant_table_pag_info <- generate_cursor_pag_inf(
    sysndd_db_entity_variant_table,
    page_size,
    page_after,
    "entity_id"
  )

  # 8) Build meta, links
  end_time <- Sys.time()
  execution_time <- paste0(round(end_time - start_time, 2), " secs")

  meta <- entity_variant_table_pag_info$meta %>%
    add_column(tibble::as_tibble(list(
      "sort" = sort,
      "filter" = filter,
      "fields" = fields,
      "fspec" = entity_variant_table_fspec,
      "executionTime" = execution_time
    )))

  links <- entity_variant_table_pag_info$links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(
      link = case_when(
        link != "null" ~ paste0(
          dw$api_base_url,
          "/api/variant/browse?sort=", sort,
          ifelse(filter != "", paste0("&filter=", filter), ""),
          ifelse(fields != "", paste0("&fields=", fields), ""),
          link
        ),
        TRUE ~ "null"
      )
    ) %>%
    pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

  # 9) Return final
  list(
    links = links,
    meta = meta,
    data = entity_variant_table_pag_info$data
  )
}
