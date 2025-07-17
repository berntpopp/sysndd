# api/endpoints/gene_endpoints.R
#
# This file contains all gene-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible (e.g., two-space indentation,
# meaningful function names, etc.).
#
# Be sure to source any required helpers if needed, for example:
# source("functions/database-functions.R", local = TRUE)

## -------------------------------------------------------------------##
## Gene endpoints
## -------------------------------------------------------------------##

#* Fetch Gene Data with Filters and Field Selection
#*
#* This endpoint fetches gene data from the database, allowing for filtering,
#* field selection, and pagination.
#*
#* # `Details`
#* Retrieves gene data with optional filters, sorting, and pagination. Users
#* can also specify the fields they want returned.
#*
#* # `Return`
#* Returns a paginated list of genes based on the provided filters.
#*
#* @tag gene
#* @serializer json list(na="string")
#*
#* @param sort The column to sort the output by.
#* @param filter Filters to apply.
#* @param fields Fields to be returned in the output.
#* @param page_after Cursor for pagination.
#* @param page_size Size of the page for pagination.
#* @param fspec Field specifications for meta data response.
#* @param format The output format (e.g., "json" or "xlsx").
#*
#* @response 200 OK. Returns the filtered and paginated list of genes.
#*
#* @get /
function(req,
         res,
         sort = "symbol",
         filter = "",
         fields = "",
         `page_after` = "0",
         `page_size` = "10",
         fspec = "symbol,category,hpo_mode_of_inheritance_term_name,ndd_phenotype_word,entities_count,details",
         format = "json") {
  # Set serializers
  res$serializer <- serializers[[format]]

  # Start time calculation
  start_time <- Sys.time()

  # Generate sort expression
  sort_exprs <- generate_sort_expressions(sort, unique_id = "symbol")

  # Generate filter expression
  filter_exprs <- generate_filter_expressions(filter)

  # Get data from database and filter
  sysndd_db_genes_table <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    collect() %>%
    group_by(symbol) %>%
    mutate(entities_count = n()) %>%
    ungroup()

  # Apply filters and sorting
  sysndd_db_genes_table_filtered <- sysndd_db_genes_table %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # Field specs
  sysndd_db_genes_table_fspec <- generate_tibble_fspec_mem(
    sysndd_db_genes_table,
    fspec
  )
  sysndd_db_genes_table_filtered_fspec <- generate_tibble_fspec_mem(
    sysndd_db_genes_table_filtered,
    fspec
  )
  sysndd_db_genes_table_fspec$fspec$count_filtered <-
    sysndd_db_genes_table_filtered_fspec$fspec$count

  # Nest data
  sysndd_db_genes_nested <- nest_gene_tibble_mem(sysndd_db_genes_table_filtered)

  # Select fields
  sysndd_db_genes_nested <- select_tibble_fields(
    sysndd_db_genes_nested,
    fields,
    "symbol"
  )

  # Generate pagination
  genes_nested_pag_info <- generate_cursor_pag_inf(
    sysndd_db_genes_nested,
    page_size,
    page_after,
    "symbol"
  )

  # Compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(
    paste0(round(end_time - start_time, 2), " secs")
  )

  # Add meta info
  meta <- genes_nested_pag_info$meta %>%
    add_column(
      tibble::as_tibble(list(
        "sort" = sort,
        "filter" = filter,
        "fields" = fields,
        "fspec" = sysndd_db_genes_table_fspec,
        "executionTime" = execution_time
      ))
    )

  # Update links
  links <- genes_nested_pag_info$links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(
      link = case_when(
        link != "null" ~ paste0(
          dw$api_base_url,
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

  # Construct response
  gene_list <- list(
    links = links,
    meta = meta,
    data = genes_nested_pag_info$data
  )

  if (format == "xlsx") {
    creation_date <- strftime(
      as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S"
    )
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
      str_replace_all("_api_", "")
    filename <- file.path(
      paste0(base_filename, "_", creation_date, ".xlsx")
    )

    bin <- generate_xlsx_bin(gene_list, base_filename)
    as_attachment(bin, filename)
  } else {
    gene_list
  }
}


#* Fetch Single Gene Information
#*
#* This endpoint fetches detailed information for a single gene based on either
#* its HGNC ID or symbol.
#*
#* # `Details`
#* Retrieves detailed gene information including associated IDs and names.
#*
#* # `Return`
#* Returns detailed information about the specified gene.
#*
#* @tag gene
#* @serializer json list(na="null")
#*
#* @param gene_input The HGNC ID or symbol of the gene.
#* @param input_type The type of input ('hgnc' or 'symbol').
#*
#* @response 200 OK. Returns detailed information of the gene.
#*
#* @get /<gene_input>
function(gene_input, input_type = "hgnc") {
  if (input_type == "hgnc") {
    gene_input <- URLdecode(gene_input) %>%
      str_replace_all("HGNC:", "")
    gene_input <- paste0("HGNC:", gene_input)
  } else if (input_type == "symbol") {
    gene_input <- URLdecode(gene_input) %>%
      str_to_lower()
  }

  non_alt_loci_set_collected <- pool %>%
    tbl("non_alt_loci_set") %>%
    {
      if (input_type == "hgnc") {
        filter(., hgnc_id == gene_input)
      } else {
        .
      }
    } %>%
    {
      if (input_type == "symbol") {
        filter(., str_to_lower(symbol) == gene_input)
      } else {
        .
      }
    } %>%
    select(
      hgnc_id,
      symbol,
      name,
      entrez_id,
      ensembl_gene_id,
      ucsc_id,
      ccds_id,
      uniprot_ids,
      omim_id,
      mane_select,
      mgd_id,
      rgd_id,
      STRING_id
    ) %>%
    arrange(hgnc_id) %>%
    collect() %>%
    mutate(
      across(everything(), ~ str_split(., pattern = "\\|"))
    )
}


## Gene endpoints
## -------------------------------------------------------------------##
