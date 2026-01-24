# api/endpoints/publication_endpoints.R
#
# This file contains all Publication-related endpoints extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible.

## -------------------------------------------------------------------##
## Publication endpoints
## -------------------------------------------------------------------##

#* Fetch Publication by PMID
#*
#* Fetches a publication from the DB by PMID.
#* Returns metadata: title, abstract, authors, etc.
#*
#* # `Details`
#* Looks up the publication table for the matching PMID.
#* Returns metadata: title, abstract, authors, etc.
#*
#* # `Return`
#* JSON object with the publication metadata.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param pmid The PubMed ID of the publication.
#*
#* @response 200 OK. Returns publication metadata.
#*
#* @get <pmid>
function(pmid) {
  pmid <- URLdecode(pmid) %>%
    str_replace_all("[^0-9]+", "")
  pmid <- paste0("PMID:", pmid)

  publication_collected <- pool %>%
    tbl("publication") %>%
    filter(publication_id == pmid) %>%
    select(
      publication_id,
      other_publication_id,
      Title,
      Abstract,
      Lastname,
      Firstname,
      Publication_date,
      Journal,
      Keywords
    ) %>%
    arrange(publication_id) %>%
    collect()

  publication_collected
}


#* Validate PMID Existence in PubMed
#*
#* Checks if a given PMID exists in PubMed.
#*
#* # `Details`
#* Uses the helper function check_pmid(pmid).
#*
#* # `Return`
#* JSON object indicating if PMID is valid or not.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param pmid The PMID to validate.
#*
#* @response 200 OK. Returns validation result.
#*
#* @get <pmid>
function(req, res, pmid) {
  pmid <- URLdecode(pmid) %>%
    str_replace_all("[^0-9]+", "")
  check_pmid(pmid)
}


#* Search Publications on PubTator
#*
#* Queries the PubTator API for publications matching a set query. Allows pagination.
#*
#* # `Details`
#* Returns a list of publication metadata (PMIDs, titles, etc.).
#* Also returns meta (e.g., total pages).
#*
#* # `Return`
#* JSON containing 'meta' and 'data'.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param current_page Numeric: The starting page number for the API response.
#*
#* @response 200 OK. Returns the list of publications' metadata.
#*
#* @get pubtator/search
function(req, res, current_page = 1) {
  query <- '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disorder" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)'

  max_pages <- 1
  current_page <- as.numeric(current_page)

  pmids_data <- pubtator_v3_pmids_from_request(query, current_page, max_pages)
  per_page <- 10
  total_pages <- pubtator_v3_total_pages_from_query(query)

  response_data <- list(
    meta = list(
      "perPage" = per_page,
      "currentPage" = current_page,
      "totalPages" = total_pages
    ),
    data = pmids_data
  )

  res$status <- 200
  response_data
}


#* Get a Cursor Pagination Object of All Publications
#*
#* This endpoint returns a cursor pagination object of all publications based on
#* the data in the database. It supports query parameters for sorting, filtering, and
#* selecting fields, as well as cursor-based pagination (page_after, page_size).
#*
#* # `Details`
#* - Allows the user to sort on columns, specify filters, and pick which columns
#*   should be returned (fields).
#* - Uses the standard cursor pagination helpers: generate_sort_expressions,
#*   generate_filter_expressions, and generate_cursor_pag_inf.
#* - The meta section in the response contains pagination info, the sort and filter
#*   used, the execution time, and a field specification object.
#*
#* # `Return`
#* A cursor pagination object containing links, meta, and data (publication objects).
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param sort:str Output column to arrange output on. Defaults to 'publication_id'.
#* @param filter:str Comma-separated list of filters to apply (e.g. "Lastname=='Smith',Journal=='Nature'").
#* @param fields:str Comma-separated list of output columns (e.g. "publication_id,Title").
#* @param page_after:str Cursor after which entries are shown. Defaults to 0.
#* @param page_size:str Page size in cursor pagination. Defaults to "10".
#* @param fspec:str Fields to generate field specification for. Defaults to
#*   "publication_id,Title,Abstract,Lastname,Firstname,Publication_date,Journal,Keywords".
#* @param format:str Format of output. Defaults to "json". Another example is "xlsx".
#*
#* @response 200 OK. A cursor pagination object with links, meta and data (publication objects).
#* @response 500 Internal server error.
#*
#* @get /
function(req,
         res,
         sort = "publication_id",
         filter = "",
         fields = "",
         page_after = 0,
         page_size = "10",
         fspec = "publication_id,Title,Abstract,Lastname,Firstname,Publication_date,Journal,Keywords",
         format = "json") {
  # Set serializers
  res$serializer <- serializers[[format]]

  # Start time calculation
  start_time <- Sys.time()

  # Generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "publication_id")

  # Generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # Get publication data from database
  publication_tbl <- pool %>%
    tbl("publication") %>%
    collect() %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # Select fields from table based on input
  publication_tbl <- select_tibble_fields(
    publication_tbl,
    fields,
    "publication_id"
  )

  # Use the helper to generate cursor pagination information
  publication_pag_info <- generate_cursor_pag_inf(
    publication_tbl,
    page_size,
    page_after,
    "publication_id"
  )

  # Generate field specs
  publication_tbl_fspec <- generate_tibble_fspec_mem(
    publication_tbl,
    fspec
  )
  publication_fspec <- publication_tbl_fspec

  # The filtered count is the same as the final table's count
  publication_fspec$fspec$count_filtered <- publication_tbl_fspec$fspec$count

  # Compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(
    paste0(round(end_time - start_time, 2), " secs")
  )

  # Build the meta object
  meta <- publication_pag_info$meta %>%
    add_column(
      tibble::as_tibble(list(
        "sort" = sort,
        "filter" = filter,
        "fields" = fields,
        "fspec" = publication_fspec,
        "executionTime" = execution_time
      ))
    )

  # Add host, port, etc. to the links (if needed). Adjust to your environment:
  links <- publication_pag_info$links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(
      link = case_when(
        link != "null" ~ paste0(
          dw$api_base_url,
          "/publication?",
          "sort=", sort,
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

  # Return final list
  publications_list <- list(
    links = links,
    meta = meta,
    data = publication_pag_info$data
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

    bin <- generate_xlsx_bin(publications_list, base_filename)
    as_attachment(bin, filename)
  } else {
    publications_list
  }
}


#* Get a Cursor-Pagination Object of All Rows from pubtator_search_cache
#*
#* This endpoint returns a cursor pagination object of all rows in the
#* `pubtator_search_cache` table, supporting the usual query parameters:
#* - sort
#* - filter
#* - fields
#* - page_after
#* - page_size
#* - fspec
#* - format
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param sort:str  Which columns to sort on, e.g. "search_id" or "pmid". Default "search_id".
#* @param filter:str Comma-separated filters, e.g. "pmid=='123456'".
#* @param fields:str Comma-separated columns, e.g. "search_id,pmid,date".
#* @param page_after:str The cursor to start results after. Default "0".
#* @param page_size:str How many rows per page. Default "10".
#* @param fspec:str Comma-separated columns for field spec generation.
#*        Example: "search_id,pmid,date,score".
#* @param format:str Output format, "json" or "xlsx". Default "json".
#*
#* @response 200 OK - a cursor-paginated list of pubtator_search_cache rows.
#*
#* @get /pubtator/table
function(req,
         res,
         sort = "search_id",
         filter = "",
         fields = "",
         page_after = 0,
         page_size = "10",
         fspec = "search_id,query_id,id,pmid,doi,title,journal,date,score,text_hl",
         format = "json") {
  # Set the serializer
  res$serializer <- serializers[[format]]

  start_time <- Sys.time()

  # Generate sort & filter expressions
  sort_exprs <- generate_sort_expressions(sort, unique_id = "search_id")
  filter_exprs <- generate_filter_expressions(filter)

  # Collect from DB
  table_data <- pool %>%
    tbl("pubtator_search_cache") %>%
    collect() %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # Select columns
  table_data <- select_tibble_fields(
    table_data,
    fields,
    unique_id = "search_id" # always include
  )

  # Cursor pagination
  pag_info <- generate_cursor_pag_inf(table_data, page_size, page_after, "search_id")

  # Field specs
  tbl_fspec <- generate_tibble_fspec_mem(pag_info$data, fspec)
  fspec_obj <- tbl_fspec
  fspec_obj$fspec$count_filtered <- tbl_fspec$fspec$count

  end_time <- Sys.time()
  execution_time <- paste0(round(end_time - start_time, 2), " secs")

  # Build meta
  meta <- pag_info$meta %>%
    add_column(
      tibble::as_tibble(list(
        sort = sort,
        filter = filter,
        fields = fields,
        fspec = fspec_obj,
        executionTime = execution_time
      ))
    )

  # Build links (here we assume something like dw$api_base_url plus path)
  links <- pag_info$links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(
      link = case_when(
        link != "null" ~ paste0(
          dw$api_base_url,
          "/pubtator/table?",
          "sort=", sort,
          ifelse(filter != "", paste0("&filter=", filter), ""),
          ifelse(fields != "", paste0("&fields=", fields), ""),
          link
        ),
        TRUE ~ "null"
      )
    ) %>%
    pivot_wider(
      id_cols = everything(),
      names_from = "type",
      values_from = "link"
    )

  final_list <- list(
    links = links,
    meta = meta,
    data = pag_info$data
  )

  # If xlsx, return as file
  if (format == "xlsx") {
    creation_date <- format(Sys.time(), "%Y-%m-%d_T%H-%M-%S")
    base_filename <- gsub("/", "_", req$PATH_INFO)
    filename <- paste0(base_filename, "_", creation_date, ".xlsx")

    bin <- generate_xlsx_bin(final_list, base_filename)
    as_attachment(bin, filename)
  } else {
    final_list
  }
}


#* Get a Cursor-Pagination Object of Genes from pubtator_human_gene_entity_view
#*
#* This endpoint returns a cursor pagination object with one row per gene,
#* listing nested `publications` and `entities` for each gene. The data is
#* from `pubtator_human_gene_entity_view`. It also provides two count columns:
#* - `publication_count`: how many valid publication rows
#* - `entities_count`: how many valid entity rows
#*
#* If the nested list-column has rows that are all NA in the key column
#* (e.g. `entity_id` == NA), those get filtered out => count becomes 0.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param sort:str    Which columns to sort on, e.g. "gene_symbol".
#* @param filter:str  Comma-separated filters, e.g. "gene_symbol=='BRCA1'".
#* @param fields:str  Comma-separated columns to return
#* @param page_after:str The cursor to start results after. Default "0".
#* @param page_size:str  Page size. Default "10".
#* @param fspec:str   Field spec for meta info.
#* @param format:str  "json" or "xlsx". Default "json".
#*
#* @response 200 OK - a cursor-paginated list of nested gene rows
#*
#* @get /pubtator/genes
function(req,
         res,
         sort = "gene_symbol",
         filter = "",
         fields = "",
         page_after = "0",
         page_size = "10",
         fspec = "gene_name,gene_symbol,gene_normalized_id,hgnc_id,publication_count,entities_count,publications,entities",
         format = "json") {
  # 1) Set serializer
  res$serializer <- serializers[[format]]

  # 2) Start time
  start_time <- Sys.time()

  # 3) Generate sort/filter expressions
  sort_exprs <- generate_sort_expressions(sort, unique_id = "gene_symbol")
  filter_exprs <- generate_filter_expressions(filter)

  # 4) Fetch from DB => apply filter & sorting
  df_raw <- pool %>%
    tbl("pubtator_human_gene_entity_view") %>%
    collect()

  df_filtered <- df_raw %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # 5) Nest the data => one row per gene
  df_nested <- nest_pubtator_gene_tibble_mem(df_filtered)

  # 6) Add publication_count & entities_count
  #    For publications, we check `pmid` is non-NA.
  #    For entities, we check `entity_id` is non-NA.
  df_counts <- df_nested %>%
    mutate(
      publication_count = purrr::map_int(publications, ~
        dplyr::filter(.x, !is.na(pmid)) %>% nrow()),
      entities_count = purrr::map_int(entities, ~
        dplyr::filter(.x, !is.na(entity_id)) %>% nrow())
    )

  # 7) Field selection
  df_selected <- select_tibble_fields(
    df_counts,
    fields,
    unique_id = "gene_symbol"
  )

  # 8) Cursor pagination on 'gene_symbol'
  pag_info <- generate_cursor_pag_inf(
    df_selected,
    page_size,
    page_after,
    "gene_symbol"
  )

  # 9) Field specs
  tbl_fspec <- generate_tibble_fspec_mem(pag_info$data, fspec)
  tbl_fspec$fspec$count_filtered <- tbl_fspec$fspec$count

  # 10) Execution time
  end_time <- Sys.time()
  execution_time <- paste0(round(end_time - start_time, 2), " secs")

  # 11) Build meta
  meta <- pag_info$meta %>%
    add_column(
      tibble::as_tibble(list(
        sort = sort,
        filter = filter,
        fields = fields,
        fspec = tbl_fspec,
        executionTime = execution_time
      ))
    )

  # 12) Build links for next/prev
  links <- pag_info$links %>%
    tidyr::pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    dplyr::mutate(
      link = dplyr::case_when(
        link != "null" ~ paste0(
          dw$api_base_url,
          "/pubtator/genes?",
          "sort=", sort,
          ifelse(filter != "", paste0("&filter=", filter), ""),
          ifelse(fields != "", paste0("&fields=", fields), ""),
          link
        ),
        TRUE ~ "null"
      )
    ) %>%
    tidyr::pivot_wider(
      id_cols = dplyr::everything(),
      names_from = "type",
      values_from = "link"
    )

  final_list <- list(
    links = links,
    meta  = meta,
    data  = pag_info$data
  )

  # 13) XLSX or JSON
  if (format == "xlsx") {
    creation_date <- format(Sys.time(), "%Y-%m-%d_T%H-%M-%S")
    base_filename <- gsub("/", "_", req$PATH_INFO)
    filename <- paste0(base_filename, "_", creation_date, ".xlsx")

    bin <- generate_xlsx_bin(final_list, base_filename)
    as_attachment(bin, filename)
  } else {
    final_list
  }
}
