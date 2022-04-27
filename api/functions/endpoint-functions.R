## endpoint functions


# nest the gene statistics
generate_phenotype_entities_list <- function(sort = "entity_id",
  filter = "",
  fields = "",
  `page[after]` = "0",
  `page[size]` = "all") {
  # set start time
  start_time <- Sys.time()

  filter <- URLdecode(filter) %>%
    str_replace_all("HP:", "HP_")

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "entity_id")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # load the wide phenotype view
  ndd_review_phenotype_connect_wide <- pool %>%
    tbl("ndd_review_phenotype_connect_wide_view")

  #
  sysndd_db_entity_phenotype_table <- pool %>%
    tbl("ndd_entity_view") %>%
    left_join(ndd_review_phenotype_connect_wide, by = c("entity_id")) %>%
    collect() %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    pivot_longer(
      cols = starts_with("HP_"),
      names_to = "phenotype_id",
      values_to = "phenotype_present"
    ) %>%
    filter(phenotype_present == TRUE) %>%
    mutate(phenotype_id = str_replace_all(phenotype_id, "_", ":")) %>%
    group_by(entity_id) %>%
    arrange(entity_id, phenotype_id) %>%
    mutate(phenotype_id = paste0(phenotype_id, collapse = ",")) %>%
    ungroup() %>%
    unique() %>%
    select(-phenotype_present) %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # select fields from table based on input
  # using the helper function "select_tibble_fields"
  sysndd_db_entity_phenotype_table <- select_tibble_fields(
    sysndd_db_entity_phenotype_table,
    fields,
    "entity_id")

  # use the helper generate_cursor_pagination_info
  # to generate cursor pagination information from a tibble
  sysndd_db_entity_phenotype_table_pagination_info <- generate_cursor_pagination_info(
    sysndd_db_entity_phenotype_table,
    `page[size]`, `page[after]`,
    "entity_id")

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2),
  " secs"))

  # add columns to the meta information from
  # generate_cursor_pagination_info function return
  meta <- sysndd_db_entity_phenotype_table_pagination_info$meta %>%
    add_column(as_tibble(list("sort" = sort,
      "filter" = filter,
      "fields" = fields,
      "executionTime" = execution_time)))

  # add host, port and other information to links from the link
  # information from generate_cursor_pagination_info function return
  links <- sysndd_db_entity_phenotype_table_pagination_info$links %>%
      pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(link = case_when(
      link != "null" ~ paste0("http://",
        dw$host, ":",
        dw$port_self,
        "/api/phenotype/entities/browse?sort=",
        sort,
        ifelse(filter != "", paste0("&filter=", filter), ""),
        ifelse(fields != "", paste0("&fields=", fields), ""),
        link),
      link == "null" ~ "null"
    )) %>%
      pivot_wider(everything(), names_from = "type", values_from = "link")

  # generate object to return
  return_list <- list(links = links,
    meta = meta,
    data = sysndd_db_entity_phenotype_table_pagination_info$data)

  # retiurn the list
  return(return_list)
}

# nest the gene statistics
generate_gene_statistics_tibble <- function() {
  sysndd_db_disease_genes <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    filter(ndd_phenotype == 1) %>%
    select(symbol,
      inheritance = hpo_mode_of_inheritance_term_name,
      category) %>%
    collect()

  disease_genes_group_cat_inh <- sysndd_db_disease_genes %>%
    unique() %>%
    mutate(inheritance = case_when(
      str_detect(inheritance, "X-linked") ~ "X-linked",
      str_detect(inheritance, "Autosomal dominant inheritance") ~ "Dominant",
      str_detect(inheritance, "Autosomal recessive inheritance") ~ "Recessive",
      TRUE ~ "Other"
    )) %>%
    group_by(category, inheritance) %>%
    tally() %>%
    ungroup() %>%
    arrange(desc(category), desc(n)) %>%
    mutate(category_group = category) %>%
    group_by(category_group) %>%
    nest() %>%
    ungroup() %>%
    select(category = category_group, groups = data)

  disease_genes_group_category <- sysndd_db_disease_genes %>%
    select(-inheritance) %>%
    unique() %>%
    group_by(category) %>%
    tally() %>%
    ungroup() %>%
    arrange(desc(category), desc(n)) %>%
    group_by(category) %>%
    mutate(inheritance = "All")

  disease_genes_statistics <- disease_genes_group_category %>%
    left_join(disease_genes_group_cat_inh,
     by = c("category")) %>%
    arrange(category)

  return(disease_genes_statistics)
}


# generate the gene news tibble
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
