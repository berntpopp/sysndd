# functions/phenotype-endpoint-functions.R
#### This file holds phenotype-domain endpoint functions, split out of
#### endpoint-functions.R (#346 Wave 4 Task 6).


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
generate_phenotype_entities_list <- function(
  sort = "entity_id",
  filter = "",
  fields = "",
  `page_after` = "0",
  `page_size` = "all",
  fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details"
) {
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
      collapse = ","
    )) %>%
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
    fspec
  )
  sysndd_db_entity_phenotype_table_fspec <- generate_tibble_fspec_mem(
    sysndd_db_entity_phenotype_table,
    fspec
  )
  entity_phenotype_table_fspec <- fspec_merge_filtered_counts(
    entity_phenotype_table_fspec,
    sysndd_db_entity_phenotype_table_fspec
  )

  # select fields from table based on input
  # using the helper function "select_tibble_fields"
  sysndd_db_entity_phenotype_table <- select_tibble_fields(
    sysndd_db_entity_phenotype_table,
    fields,
    "entity_id"
  )

  # use the helper generate_cursor_pag_inf
  # to generate cursor pagination information from a tibble
  entity_phenotype_table_pag_info <- generate_cursor_pag_inf(
    sysndd_db_entity_phenotype_table,
    `page_size`, `page_after`,
    "entity_id"
  )

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(
    round(end_time - start_time, 2),
    " secs"
  ))

  # add columns to the meta information from
  # generate_cursor_pag_inf function return
  meta <- entity_phenotype_table_pag_info$meta %>%
    add_column(as_tibble(list(
      "sort" = sort,
      "filter" = filter,
      "fields" = fields,
      "fspec" = entity_phenotype_table_fspec,
      "executionTime" = execution_time
    )))

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
        link
      ),
      link == "null" ~ "null"
    )) %>%
    pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

  # generate object to return
  return_list <- list(
    links = links,
    meta = meta,
    data = entity_phenotype_table_pag_info$data
  )

  # return the list
  return(return_list)
}
