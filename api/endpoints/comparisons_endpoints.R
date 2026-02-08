# api/endpoints/comparisons_endpoints.R
#
# This file contains all Comparisons-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Make sure to source any required helpers or libraries at the top, for example:
# source("functions/database-functions.R", local = TRUE)
# source("functions/pagination_helpers.R", local = TRUE)
# ... etc.

## -------------------------------------------------------------------##
## Comparisons endpoints
## -------------------------------------------------------------------##

#* Get Panel Filtering Options for Comparisons
#*
#* This endpoint provides a list of all filtering options for panels
#* in the comparison view.
#*
#* # `Details`
#* Retrieves a list of all filtering options for panels in the comparison view,
#* such as inheritance, category, or pathogenicity mode.
#*
#* # `Return`
#* Returns a list of filtering options.
#*
#* @tag comparisons
#* @serializer json list(na="string")
#*
#* @get options
function() {
  # Connect to database and fetch data from ndd_database_comparison_view
  ndd_database_comparison_view <- pool %>%
    tbl("ndd_database_comparison_view") %>%
    collect()

  # Identify the "list" column options
  list_df <- ndd_database_comparison_view %>%
    select(list) %>%
    group_by(list) %>%
    mutate(count = n()) %>%
    unique() %>%
    mutate(self = (list == "SysNDD")) %>%
    arrange(desc(self), desc(count)) %>%
    select(list)

  # Identify inheritance options
  inheritance_df <- ndd_database_comparison_view %>%
    select(inheritance) %>%
    unique() %>%
    arrange(inheritance)

  # Identify category options
  category_df <- ndd_database_comparison_view %>%
    select(category) %>%
    unique() %>%
    arrange(category)

  # Identify pathogenicity_mode options
  pathogenicity_mode_df <- ndd_database_comparison_view %>%
    select(pathogenicity_mode) %>%
    unique() %>%
    arrange(pathogenicity_mode)

  # Return the combined data as a list
  list(
    list = list_df,
    inheritance = inheritance_df,
    category = category_df,
    pathogenicity_mode = pathogenicity_mode_df
  )
}


#* Get UpSet Plot Data
#*
#* This endpoint retrieves data for generating an UpSet plot
#* showing the intersection among different databases.
#*
#* # `Details`
#* It collects the comparison data from `ndd_database_comparison_view` and
#* structures it in a way suitable for UpSet plots. Users can optionally
#* specify which databases/fields to include in the intersections.
#* When `definitive_only` is TRUE, each source is filtered to only include
#* entries where the gene has "Definitive" status in that source.
#*
#* # `Return`
#* Returns the data used to generate an UpSet plot (a list of items, each with
#* the sets it belongs to).
#*
#* @tag comparisons
#* @serializer json list(na="string")
#*
#* @param fields Comma-separated list of fields (databases) to include.
#* @param definitive_only If TRUE, filter each source to only show Definitive entries.
#*
#* @get upset
function(res, fields = "", definitive_only = "false") {
  ndd_database_comp_gene_list <- pool %>%
    tbl("ndd_database_comparison_view") %>%
    collect()

  # Split the comma-separated fields (if any)
  if (fields != "") {
    fields <- str_split(str_replace_all(fields, fixed(" "), ""), ",")[[1]]
  } else {
    # If no fields specified, use all unique 'list' values
    fields <- ndd_database_comp_gene_list %>%
      select(list) %>%
      distinct() %>%
      pull(list)
  }

  # Parse definitive_only parameter
  definitive_only <- tolower(definitive_only) %in% c("true", "1", "yes")

  # Filter to selected sources
  filtered_data <- ndd_database_comp_gene_list %>%
    filter(list %in% fields)

  # If definitive_only is TRUE, filter each source to only include Definitive entries
  if (definitive_only) {
    # Normalize categories to identify "Definitive" entries, then filter
    filtered_data <- filtered_data %>%
      normalize_comparison_categories() %>%
      filter(category == "Definitive")
  }

  # Construct the data for UpSet
  comparison_upset_data <- filtered_data %>%
    select(name = hgnc_id, sets = list) %>%
    distinct() %>%
    group_by(name) %>%
    arrange(name) %>%
    mutate(sets = str_c(sets, collapse = ",")) %>%
    distinct() %>%
    ungroup() %>%
    mutate(sets = strsplit(sets, ","))

  # Return the result
  comparison_upset_data
}


#* Get Cosine Similarity Data
#*
#* This endpoint retrieves cosine similarity data among
#* different databases for NDD gene comparisons.
#*
#* # `Details`
#* It transforms the data into a binary matrix (1 if gene is in a database,
#* 0 otherwise) and computes pairwise cosine similarity among the databases.
#*
#* # `Return`
#* Returns the melted similarity matrix with columns x, y, and value.
#*
#* @tag comparisons
#* @serializer json list(na="string")
#*
#* @get similarity
function() {
  # Gather data and transform to wide binary matrix
  ndd_database_comparison_matrix <- pool %>%
    tbl("ndd_database_comparison_view") %>%
    collect() %>%
    distinct(hgnc_id, list) %>%
    mutate(in_list = list) %>%
    pivot_wider(names_from = list, values_from = in_list) %>%
    select(-hgnc_id) %>%
    mutate_all(~ if_else(is.na(.), 0, 1))

  # Compute similarity matrix
  ndd_database_comp_sim <- cosine(ndd_database_comparison_matrix)

  # Melt the similarity matrix
  ndd_database_comp_sim_melted <- melt(ndd_database_comp_sim) %>%
    select(x = Var1, y = Var2, value)

  # Return the result
  ndd_database_comp_sim_melted
}


#* Browse NDD Genes Across Databases
#*
#* This endpoint returns a paginated list of genes showing
#* whether they appear in various external NDD-related databases.
#*
#* # `Details`
#* It uses a helper function `generate_comparisons_list` for
#* filtering, sorting, and pagination. Supports CSV/XLSX export too.
#*
#* # `Return`
#* A data structure that includes `links`, `meta`, and `data`.
#*
#* @tag comparisons
#* @serializer json list(na="string")
#*
#* @param sort Column to sort on. Defaults to "symbol".
#* @param filter Comma-separated list of filters to apply.
#* @param fields Comma-separated list of columns to return.
#* @param page_after Cursor after which entries are shown.
#* @param page_size Page size in cursor pagination.
#* @param fspec Fields for field-spec meta data.
#* @param definitive_only If TRUE, filter each source to only show Definitive entries.
#* @param format Either "json" or "xlsx".
#*
#* @get browse
function(req,
         res,
         sort = "symbol",
         filter = "",
         fields = "",
         `page_after` = "0",
         `page_size` = "10",
         fspec = "symbol,SysNDD,gene2phenotype,panelapp,radboudumc_ID,sfari,geisinger_DBD,orphanet_id,omim_ndd",
         definitive_only = "false",
         format = "json") {
  # Set serializer
  res$serializer <- serializers[[format]]

  # Use helper to retrieve the comparisons list
  comparisons_list <- generate_comparisons_list(
    sort,
    filter,
    fields,
    `page_after`,
    `page_size`,
    fspec,
    definitive_only
  )

  if (format == "xlsx") {
    creation_date <- strftime(
      as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S"
    )
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
      str_replace_all("_api_", "")
    filename <- file.path(paste0(base_filename, "_", creation_date, ".xlsx"))

    bin <- generate_xlsx_bin(comparisons_list, base_filename)
    as_attachment(bin, filename)
  } else {
    comparisons_list
  }
}


#* Get Comparisons Metadata
#*
#* Returns metadata about the last comparisons data refresh.
#* Used by the admin UI to display last-updated date and statistics.
#*
#* # `Details`
#* Fetches the single row from comparisons_metadata table containing
#* last refresh timestamp, status, error message (if any), and statistics.
#*
#* # `Return`
#* Returns a list with metadata fields.
#*
#* @tag comparisons
#* @serializer json list(na="string")
#*
#* @get /metadata
function() {
  # Check if table exists (migration may not have run yet)
  table_exists <- tryCatch({
    pool %>%
      tbl("comparisons_metadata") %>%
      head(1) %>%
      collect()
    TRUE
  }, error = function(e) FALSE)

  if (!table_exists) {
    return(list(
      last_full_refresh = NULL,
      last_refresh_status = "never",
      last_refresh_error = NULL,
      sources_count = 0,
      rows_imported = 0,
      message = "Comparisons metadata table not yet created"
    ))
  }

  metadata <- pool %>%
    tbl("comparisons_metadata") %>%
    collect() %>%
    dplyr::slice(1)

  if (nrow(metadata) == 0) {
    return(list(
      last_full_refresh = NULL,
      last_refresh_status = "never",
      last_refresh_error = NULL,
      sources_count = 0,
      rows_imported = 0
    ))
  }

  list(
    last_full_refresh = metadata$last_full_refresh,
    last_refresh_status = metadata$last_refresh_status,
    last_refresh_error = metadata$last_refresh_error,
    sources_count = metadata$sources_count,
    rows_imported = metadata$rows_imported
  )
}

## Comparisons endpoints
## -------------------------------------------------------------------##
