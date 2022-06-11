## endpoint functions


# generate comparisons list
generate_comparisons_list <- function(sort = "symbol",
  filter = "",
  fields = "",
  `page[after]` = "0",
  `page[size]` = "10",
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

  ndd_database_comparison_table  <- ndd_database_comparison_view %>%
    left_join(sysndd_db_non_alt_loci_set, by = c("hgnc_id")) %>%
    collect() %>%
    select(symbol, hgnc_id, list) %>%
    unique() %>%
    mutate(in_list = "yes") %>%
    pivot_wider(names_from = list, values_from = in_list, values_fill = "no")

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
    `page[size]`,
    `page[after]`,
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
      link != "null" ~ paste0("http://",
        dw$host, ":",
        dw$port_self,
        "/api/comparisons/table?sort=",
        sort, ifelse(filter != "",
        paste0("&filter=", filter),
        ""),
        ifelse(fields != "", paste0("&fields=", fields), ""),
        link),
      link == "null" ~ "null"
    )) %>%
      pivot_wider(everything(), names_from = "type", values_from = "link")

  # generate object to return
  return_list <- list(links = links,
    meta = meta,
    data = ndd_database_comp_table_info$data)

  # return the list
  return(return_list)
  }

# generate phenotype entities list
generate_phenotype_entities_list <- function(sort = "entity_id",
  filter = "",
  fields = "",
  `page[after]` = "0",
  `page[size]` = "all",
  fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details") {
  # set start time
  start_time <- Sys.time()

  filter <- URLdecode(filter) %>%
    str_replace_all("HP:", "HP_")

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "entity_id")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # load the wide phenotype view
  ndd_review_phenotype_connect_w <- pool %>%
    tbl("ndd_review_phenotype_connect_wide_view")

  # collect view from database
  entity_phenotype_table <- pool %>%
    tbl("ndd_entity_view") %>%
    left_join(ndd_review_phenotype_connect_w, by = c("entity_id")) %>%
    collect()

  # apply filters
  sysndd_db_entity_phenotype_table <- entity_phenotype_table %>%
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

  # use the helper generate_tibble_fspec to
  # generate fields specs from a tibble
  entity_phenotype_table_fspec <- generate_tibble_fspec_mem(
    entity_phenotype_table,
    fspec)
  sysndd_db_entity_phenotype_table_fspec <- generate_tibble_fspec_mem(sysndd_db_entity_phenotype_table,
    fspec)
  entity_phenotype_table_fspec$fspec$count_filtered <- sysndd_db_entity_phenotype_table_fspec$fspec$count

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
    `page[size]`, `page[after]`,
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
    data = entity_phenotype_table_pag_info$data)

  # return the list
  return(return_list)
}


# generate panels list
generate_panels_list <- function(sort = "symbol",
  filter = "equals(category,'Definitive'),any(inheritance_filter,'Autosomal dominant','Autosomal recessive','X-linked','Other')",
  fields = "category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38",
  `page[after]` = 0,
  `page[size]` = "all") {

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

  # generate table with field information for display
  # TODO: this has to be updated through some logic based
  # on field types in MySQL table in a function
  fields_tibble <- as_tibble(str_split(fields, ",")[[1]]) %>%
    select(key = value) %>%
    mutate(label = str_to_sentence(str_replace_all(key, "_", " "))) %>%
    mutate(sortable = "true") %>%
    mutate(class = "text-left") %>%
    mutate(sortByFormatted = "true") %>%
    mutate(filterByFormatted = "true")

  # join entity_view and non_alt_loci_set tables
  sysndd_db_ndd_entity_view <- pool %>%
    tbl("ndd_entity_view") %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id,
      symbol,
      inheritance = hpo_mode_of_inheritance_term_name,
      inheritance_filter, category)

  sysndd_db_non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, entrez_id, ensembl_gene_id, ucsc_id, bed_hg19, bed_hg38)

  sysndd_db_disease_genes <- sysndd_db_ndd_entity_view %>%
    left_join(sysndd_db_non_alt_loci_set, by = c("hgnc_id")) %>%
    collect() %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        select(-inheritance_filter) %>%
    unique() %>%
        arrange(symbol, inheritance) %>%
        group_by(symbol) %>%
        mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
        ungroup() %>%
        unique() %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # select fields from table based on input using
  # the helper function "select_tibble_fields"
  sysndd_db_disease_genes_panel <- select_tibble_fields(
    sysndd_db_disease_genes,
    fields,
    "symbol")

  # use the helper generate_cursor_pag_inf to
  # generate cursor pagination information from a tibble
  disease_genes_panel_pag_inf <- generate_cursor_pag_inf(
    sysndd_db_disease_genes_panel,
    `page[size]`,
    `page[after]`,
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
      link != "null" ~ paste0("http://",
        dw$host, ":",
        dw$port_self,
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
      pivot_wider(everything(), names_from = "type", values_from = "link")

  # generate object to return
  return_list <- list(links = links,
    meta = meta,
    fields = fields_tibble,
    data = disease_genes_panel_pag_inf$data)

  # return the list
  return(return_list)
}


# nest the gene statistics
generate_gene_stat_tibble <- function(sort = "category_id,-n") {
  # set start time
  start_time <- Sys.time()

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "category_id")

  sysndd_db_disease_genes <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    filter(ndd_phenotype == 1) %>%
    select(symbol,
      inheritance = hpo_mode_of_inheritance_term_name,
      category,
      category_id) %>%
    collect()

  disease_genes_group_cat_inh <- sysndd_db_disease_genes %>%
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

  disease_genes_group_category <- sysndd_db_disease_genes %>%
    select(-inheritance) %>%
    unique() %>%
    group_by(category, category_id) %>%
    tally() %>%
    ungroup() %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    group_by(category) %>%
    mutate(inheritance = "All")

  disease_genes_statistics <- disease_genes_group_category %>%
    left_join(disease_genes_group_cat_inh,
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
    data = disease_genes_statistics)

  # return the list
  return(return_list)
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
