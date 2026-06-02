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
#* @param compact:bool When true, push the filter to SQL where possible and
#*   skip the global-fspec computation (only the filtered-set fspec is
#*   computed). Use for lookup-style queries (symbol-by-symbol resolution,
#*   `/Genes/<symbol>` page loads). Leave false for the main /Genes table
#*   page where the global fspec drives the filter-dropdown facet counts.
#*   Default false.
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
         format = "json",
         compact = "false") {
  # Set serializers
  res$serializer <- serializers[[format]]

  # Start time calculation
  start_time <- Sys.time()

  # Derive allowlist from ndd_entity_view; returns NULL on transient DB error
  # (legacy behavior: allowlist disabled, bare-identifier check still applies).
  gene_allowed_cols <- allowed_columns_for_view("ndd_entity_view")

  # Generate sort expression
  sort_exprs <- generate_sort_expressions(sort, unique_id = "symbol",
    allowed_columns = gene_allowed_cols)

  # Generate filter expression
  filter_exprs <- generate_filter_expressions(filter,
    allowed_columns = gene_allowed_cols)

  is_compact <- isTRUE(tolower(as.character(compact[[1]])) %in% c("true", "1", "yes"))

  # The SQL pushdown is only safe for filters made entirely of expressions
  # that dbplyr can translate. We try-catch the fast path and fall back to
  # the in-R loop on any translation error.
  has_text_filter <- length(filter_exprs) > 0L && nzchar(trimws(filter))

  ndd_entity_view_lazy <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id)

  # Fast path: compact + a text filter present → push the filter to SQL,
  # then compute entities_count on the (small) filtered set in R. This avoids
  # the global view collect (~4 200 rows) for lookup-style queries.
  fast_path_filtered <- NULL
  if (is_compact && has_text_filter) {
    fast_path_filtered <- tryCatch(
      ndd_entity_view_lazy %>%
        filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        collect() %>%
        group_by(symbol) %>%
        mutate(entities_count = n()) %>%
        ungroup(),
      error = function(e) {
        message(sprintf(
          "[gene-list] SQL filter pushdown failed (%s); falling back to in-R filter",
          conditionMessage(e)
        ))
        NULL
      }
    )
  }

  if (!is.null(fast_path_filtered)) {
    sysndd_db_genes_table <- fast_path_filtered
    sysndd_db_genes_table_filtered <- fast_path_filtered %>%
      arrange(!!!rlang::parse_exprs(sort_exprs))
  } else {
    # Default path: collect global view, then group/filter in R. Required for
    # the main /Genes table page where the global fspec drives the
    # filter-dropdown facet counts ("X of Y").
    sysndd_db_genes_table <- ndd_entity_view_lazy %>%
      collect() %>%
      group_by(symbol) %>%
      mutate(entities_count = n()) %>%
      ungroup()
    sysndd_db_genes_table_filtered <- sysndd_db_genes_table %>%
      filter(!!!rlang::parse_exprs(filter_exprs)) %>%
      arrange(!!!rlang::parse_exprs(sort_exprs))
  }

  # In compact mode the response represents the filtered set, so the fspec
  # must be derived from the filtered tibble — both for the fast-path
  # (where filtered IS the working set) AND for the in-R fallback path
  # (where `sysndd_db_genes_table` is the full collected view but the
  # response data is `sysndd_db_genes_table_filtered`). Otherwise the
  # fallback path returns count_filtered = count(global), which is wrong.
  if (is_compact) {
    sysndd_db_genes_table_fspec <- generate_tibble_fspec_mem(
      sysndd_db_genes_table_filtered,
      fspec
    )
    sysndd_db_genes_table_fspec$fspec$count_filtered <-
      sysndd_db_genes_table_fspec$fspec$count
  } else {
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
  }

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
      STRING_id,
      bed_hg38,
      any_of(c("gnomad_constraints", "alphafold_id"))
    ) %>%
    arrange(hgnc_id) %>%
    collect() %>%
    mutate(
      # Exclude gnomad_constraints from pipe-splitting: it stores a JSON
      # object as a single TEXT blob. Running str_split("|") over it would
      # silently mangle any future JSON field that contains a "|" character
      # and — more immediately — wraps the scalar JSON string in a list,
      # forcing the frontend to dereference `[0]`. See
      # .planning/_archive/legacy-plans/v11.0/phase-a.md §3 A2.
      across(-any_of("gnomad_constraints"), ~ str_split(., pattern = "\\|"))
    )
}


## Gene endpoints
## -------------------------------------------------------------------##
