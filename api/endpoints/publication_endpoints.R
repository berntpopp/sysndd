# api/endpoints/publication_endpoints.R
#
# This file contains all Publication-related endpoints extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible.

## -------------------------------------------------------------------##
## Publication endpoints
## -------------------------------------------------------------------##

#* Get Publication Statistics
#*
#* Returns summary statistics about publications in the database:
#* - total: count of all publications
#* - oldest_update: the oldest update_date value (most stale publication)
#* - outdated_count: count where update_date is older than 1 year
#* - filtered_count: (optional) count of publications not updated since the specified date
#*
#* # `Return`
#* JSON object with total, oldest_update, outdated_count, and optionally filtered_count fields.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param not_updated_since Optional ISO date string (YYYY-MM-DD) to filter publications
#*   not updated since this date. When provided, returns filtered_count.
#*
#* @response 200 OK. Returns publication statistics.
#*
#* @get /stats
function(req, res, not_updated_since = NULL) {
  # Get total count
  total_result <- db_execute_query(
    "SELECT COUNT(*) as total FROM publication"
  )
  total <- as.integer(total_result$total[1])

  # Get oldest update_date
  oldest_result <- db_execute_query(
    "SELECT MIN(update_date) as oldest_update FROM publication"
  )
  oldest_update <- as.character(oldest_result$oldest_update[1])

  # Get count of publications not updated in over 1 year
  outdated_result <- db_execute_query(
    "SELECT COUNT(*) as outdated_count FROM publication WHERE update_date < DATE_SUB(NOW(), INTERVAL 1 YEAR)"
  )
  outdated_count <- as.integer(outdated_result$outdated_count[1])

  # Build response
  result <- list(
    total = total,
    oldest_update = oldest_update,
    outdated_count = outdated_count
  )

  # If date filter provided, calculate filtered count
  if (!is.null(not_updated_since) && nzchar(not_updated_since)) {
    # Validate date format
    filter_date <- tryCatch(
      as.Date(not_updated_since),
      error = function(e) NULL
    )

    if (!is.null(filter_date) && !is.na(filter_date)) {
      filtered_result <- db_execute_query(
        "SELECT COUNT(*) as filtered_count FROM publication WHERE update_date < ?",
        list(as.character(filter_date))
      )
      result$filtered_count <- as.integer(filtered_result$filtered_count[1])
      result$filter_date <- as.character(filter_date)
    }
  }

  result
}


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
  # nolint start: line_length_linter
  query <- '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disorder" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)'
  # nolint end

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
    filter(!!!rlang::parse_exprs(filter_exprs))

  # Handle numeric sorting for publication_id (PMID:12345 format)
  # Extract the sort column and direction
  sort_col <- str_replace_all(sort, "^[+-]", "")
  sort_desc <- str_sub(sort, 1, 1) == "-"

  if (sort_col == "publication_id") {
    # Extract numeric part and sort numerically
    publication_tbl <- publication_tbl %>%
      mutate(.pmid_numeric = as.numeric(str_replace(publication_id, "^PMID:", "")))

    if (sort_desc) {
      publication_tbl <- publication_tbl %>% arrange(desc(.pmid_numeric))
    } else {
      publication_tbl <- publication_tbl %>% arrange(.pmid_numeric)
    }

    publication_tbl <- publication_tbl %>% dplyr::select(-.pmid_numeric)
  } else {
    # Standard sorting for other columns
    publication_tbl <- publication_tbl %>%
      arrange(!!!rlang::parse_exprs(sort_exprs))
  }

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
         fspec = "search_id,query_id,id,pmid,doi,title,journal,date,score,gene_symbols,text_hl",
         format = "json") {
  # Set the serializer
  res$serializer <- serializers[[format]]

  start_time <- Sys.time()

  # Generate sort & filter expressions
  sort_exprs <- generate_sort_expressions(sort, unique_id = "search_id")
  filter_exprs <- generate_filter_expressions(filter)

  # Collect from DB - gene_symbols is now pre-computed during pubtator_db_update
  # The gene_symbols column contains comma-separated human gene symbols from HGNC
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
#* from `pubtator_human_gene_entity_view`. It provides prioritization fields:
#* - `publication_count`: how many valid publication rows
#* - `entities_count`: how many valid entity rows (SysNDD entities)
#* - `is_novel`: 1 if gene has no SysNDD entity (coverage gap), 0 otherwise
#* - `oldest_pub_date`: earliest publication date for this gene
#* - `pmids`: comma-separated list of PMIDs for this gene
#*
#* Default sort prioritizes novel genes (not in SysNDD) then by oldest_pub_date
#* to surface long-overlooked genes for curator review.
#*
#* If the nested list-column has rows that are all NA in the key column
#* (e.g. `entity_id` == NA), those get filtered out => count becomes 0.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param sort:str    Which columns to sort on. Default "-is_novel,oldest_pub_date"
#*                    (novel genes first, then by oldest publication date).
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
         sort = "-is_novel,oldest_pub_date",
         filter = "",
         fields = "",
         page_after = "0",
         page_size = "10",
         fspec = "gene_name,gene_symbol,gene_normalized_id,hgnc_id,publication_count,entities_count,is_novel,oldest_pub_date,pmids,publications,entities", # nolint: line_length_linter
         format = "json") {
  # 1) Set serializer
  res$serializer <- serializers[[format]]

  # 2) Start time
  start_time <- Sys.time()

  # 3) Generate sort/filter expressions
  sort_exprs <- generate_sort_expressions(sort, unique_id = "gene_symbol")
  filter_exprs <- generate_filter_expressions(filter)

  # 4) Fetch from DB (no filter yet - computed fields don't exist)
  df_raw <- pool %>%
    tbl("pubtator_human_gene_entity_view") %>%
    collect()

  # 5) Nest the data => one row per gene
  df_nested <- nest_pubtator_gene_tibble_mem(df_raw)

  # 6) Add computed fields for prioritization
  #    - publication_count: number of valid publications
  #    - entities_count: number of SysNDD entities (0 = novel/coverage gap)
  #    - is_novel: 1 if gene has no SysNDD entity, 0 otherwise
  #    - oldest_pub_date: earliest publication date
  #    - pmids: comma-separated list of PMIDs (string, not array)
  df_counts <- df_nested %>%
    dplyr::mutate(
      publication_count = purrr::map_int(publications, ~
        dplyr::filter(.x, !is.na(pmid)) %>% nrow()),
      entities_count = purrr::map_int(entities, ~
        dplyr::filter(.x, !is.na(entity_id)) %>% nrow()),
      is_novel = as.integer(entities_count == 0),
      oldest_pub_date = purrr::map_chr(publications, ~ {
        valid_pubs <- dplyr::filter(.x, !is.na(pmid) & !is.na(date))
        if (nrow(valid_pubs) == 0) {
          return(NA_character_)
        }
        min_date <- min(valid_pubs$date, na.rm = TRUE)
        as.character(min_date)
      }),
      pmids = purrr::map_chr(publications, ~ {
        valid_pubs <- dplyr::filter(.x, !is.na(pmid)) %>%
          dplyr::arrange(date) %>%
          dplyr::distinct(pmid)
        paste(valid_pubs$pmid, collapse = ",")
      })
    )

  # 7) Apply filter AFTER computed fields exist
  df_filtered <- df_counts %>%
    dplyr::filter(!!!rlang::parse_exprs(filter_exprs))

  # 8) Apply sorting after filtering
  df_sorted <- df_filtered %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # 9) Field selection
  df_selected <- select_tibble_fields(
    df_sorted,
    fields,
    unique_id = "gene_symbol"
  )

  # 10) Cursor pagination on 'gene_symbol'
  pag_info <- generate_cursor_pag_inf(
    df_selected,
    page_size,
    page_after,
    "gene_symbol"
  )

  # 11) Field specs
  tbl_fspec <- generate_tibble_fspec_mem(pag_info$data, fspec)
  tbl_fspec$fspec$count_filtered <- tbl_fspec$fspec$count

  # 12) Execution time
  end_time <- Sys.time()
  execution_time <- paste0(round(end_time - start_time, 2), " secs")

  # 13) Build meta
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

  # 13) Build links for next/prev
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

  # 14) XLSX or JSON
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


#* Backfill gene_symbols for existing PubTator data
#*
#* This admin endpoint populates the gene_symbols column in pubtator_search_cache
#* for rows where it is currently NULL. It joins with non_alt_loci_set (HGNC)
#* to filter for human genes only.
#*
#* # `Details`
#* After running migration 005_add_pubtator_gene_symbols.sql, existing data
#* will have NULL gene_symbols. This endpoint computes and stores them.
#*
#* # `Return`
#* JSON object with count of rows updated.
#*
#* @tag publication
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @response 200 OK - returns count of updated rows
#*
#* @post /pubtator/backfill-genes
function(req, res) {
  start_time <- Sys.time()

  # Find search_ids with NULL gene_symbols
  null_ids <- pool %>%
    tbl("pubtator_search_cache") %>%
    dplyr::filter(is.na(gene_symbols)) %>%
    dplyr::select(search_id) %>%
    collect()

  if (nrow(null_ids) == 0) {
    return(list(
      updated = 0,
      message = "No rows need backfilling - all gene_symbols already populated"
    ))
  }

  # Compute human gene symbols by joining with HGNC
  gene_symbols_df <- pool %>%
    tbl("pubtator_annotation_cache") %>%
    dplyr::filter(type == "Gene") %>%
    dplyr::inner_join(
      pool %>% tbl("non_alt_loci_set") %>% dplyr::select(entrez_id, symbol),
      by = c("normalized_id" = "entrez_id")
    ) %>%
    dplyr::filter(search_id %in% !!null_ids$search_id) %>%
    dplyr::select(search_id, symbol) %>%
    collect() %>%
    dplyr::group_by(search_id) %>%
    dplyr::summarise(
      gene_symbols = paste(sort(unique(na.omit(symbol))), collapse = ","),
      .groups = "drop"
    ) %>%
    dplyr::filter(gene_symbols != "")

  # Update in database
  updated_count <- 0
  if (nrow(gene_symbols_df) > 0) {
    for (r in seq_len(nrow(gene_symbols_df))) {
      db_execute_statement(
        "UPDATE pubtator_search_cache
         SET gene_symbols = ?
         WHERE search_id = ?",
        list(gene_symbols_df$gene_symbols[r], gene_symbols_df$search_id[r])
      )
      updated_count <- updated_count + 1
    }
  }

  end_time <- Sys.time()
  execution_time <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)

  list(
    updated = updated_count,
    total_null = nrow(null_ids),
    execution_time = paste0(execution_time, " secs"),
    message = paste0(
      "Updated ", updated_count, " rows with gene symbols. ",
      nrow(null_ids) - updated_count, " rows had no human genes."
    )
  )
}


#* Get PubTator cache status for a query
#*
#* Returns cache information for a query including pages cached, total available,
#* and whether an update would fetch new data or hit cache.
#*
#* @tag publication
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @param query:str The search query for PubTator
#*
#* @response 200 OK - returns cache status
#*
#* @get /pubtator/cache-status
function(req, res, query = "") {
  if (query == "") {
    res$status <- 400
    return(list(error = "Query parameter is required"))
  }

  # Get total pages from PubTator API
  total_pages <- pubtator_v3_total_pages_from_query(query)

  # Check cache
  q_hash <- generate_query_hash(query)
  cached <- db_execute_query(

    "SELECT query_id, queried_page_number, total_page_number, query_date
     FROM pubtator_query_cache WHERE query_hash = ?",
    list(q_hash)
  )

  if (nrow(cached) == 0) {
    return(list(
      query = query,
      cached = FALSE,
      pages_cached = 0,
      total_pages_available = total_pages,
      total_results_available = total_pages * 10,
      cache_date = NULL,
      estimated_fetch_time_minutes = round(total_pages * 2.5 / 60, 1),
      message = "No cache exists. Full fetch required."
    ))
  }

  pages_cached <- cached$queried_page_number[1]
  pages_remaining <- max(0, total_pages - pages_cached)

  # Get publication count from cache
  pub_count <- db_execute_query(
    "SELECT COUNT(*) as cnt FROM pubtator_search_cache WHERE query_id = ?",
    list(cached$query_id[1])
  )$cnt[1]

  list(
    query = query,
    cached = TRUE,
    query_id = cached$query_id[1],
    pages_cached = pages_cached,
    publications_cached = pub_count,
    total_pages_available = total_pages,
    total_results_available = total_pages * 10,
    pages_remaining = pages_remaining,
    cache_date = as.character(cached$query_date[1]),
    estimated_fetch_time_minutes = round(pages_remaining * 2.5 / 60, 1),
    message = if (pages_remaining == 0) {
      "Cache is complete. Use clear_old=true to refresh."
    } else {
      paste0("Soft update will fetch ", pages_remaining, " new pages.")
    }
  )
}


#* Trigger PubTator search and store results
#*
#* This admin endpoint initiates a new PubTator search for the given query,
#* fetches results with annotations, and stores them in the database.
#* Uses optimized rate limiting (~24 requests/min) to respect API limits.
#*
#* # `Details`
#* **Soft Update (default)**: Only fetches pages not already cached.
#* If you request max_pages=100 and 50 are cached, only 50 new pages are fetched.
#*
#* **Hard Update (clear_old=true)**: Clears all cached data for this query
#* and fetches fresh from page 1.
#*
#* Use `/pubtator/cache-status` first to check what's cached.
#*
#* # `Return`
#* JSON object with query_id, cache info, and statistics.
#*
#* @tag publication
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @param query:str The search query for PubTator (e.g., "epilepsy gene variant")
#* @param max_pages:int Maximum pages to fetch (default 10, each page has 10 results)
#* @param clear_old:bool Hard update - clear existing cache first (default false)
#*
#* @response 200 OK - returns query_id and statistics
#* @response 400 Bad request - missing query parameter
#*
#* @post /pubtator/update
function(req, res, query = "", max_pages = 10, clear_old = FALSE) {
  start_time <- Sys.time()

  if (query == "") {
    res$status <- 400
    return(list(error = "Query parameter is required"))
  }

  max_pages <- as.integer(max_pages)
  clear_old <- as.logical(clear_old)

  log_info("PubTator update requested: query='{query}', max_pages={max_pages}, clear_old={clear_old}")

  # Check cache state BEFORE update
  q_hash <- generate_query_hash(query)
  cached_before <- db_execute_query(
    "SELECT query_id, queried_page_number FROM pubtator_query_cache WHERE query_hash = ?",
    list(q_hash)
  )
  pages_before <- if (nrow(cached_before) > 0) cached_before$queried_page_number[1] else 0

  # Call pubtator_db_update function
  tryCatch(
    {
      query_id <- pubtator_db_update(
        db_host = dw$db_host,
        db_port = dw$db_port,
        db_name = dw$db_name,
        db_user = dw$db_user,
        db_password = dw$db_password,
        query = query,
        max_pages = max_pages,
        do_full_update = clear_old
      )

      end_time <- Sys.time()
      execution_time <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)

      if (is.null(query_id)) {
        return(list(
          success = FALSE,
          message = "No results found or error occurred",
          execution_time = paste0(execution_time, " secs")
        ))
      }

      # Get cache state AFTER update
      cached_after <- db_execute_query(
        "SELECT queried_page_number, total_page_number FROM pubtator_query_cache WHERE query_id = ?",
        list(query_id)
      )
      pages_after <- cached_after$queried_page_number[1]
      total_pages <- cached_after$total_page_number[1]

      # Calculate what was actually fetched
      pages_fetched <- if (clear_old) pages_after else max(0, pages_after - pages_before)
      cache_hit <- pages_fetched == 0

      # Get counts
      search_count <- pool %>%
        tbl("pubtator_search_cache") %>%
        dplyr::filter(query_id == !!query_id) %>%
        dplyr::count() %>%
        collect() %>%
        pull(n)

      search_ids_tbl <- pool %>%
        tbl("pubtator_search_cache") %>%
        dplyr::filter(query_id == !!query_id) %>%
        dplyr::select(search_id)

      annotation_count <- pool %>%
        tbl("pubtator_annotation_cache") %>%
        dplyr::inner_join(search_ids_tbl, by = "search_id") %>%
        dplyr::count() %>%
        collect() %>%
        pull(n)

      list(
        success = TRUE,
        query_id = query_id,
        query = query,
        update_type = if (clear_old) "hard" else "soft",
        cache_hit = cache_hit,
        pages_fetched = pages_fetched,
        pages_cached_total = pages_after,
        pages_available = total_pages,
        publications_count = search_count,
        annotations_count = annotation_count,
        execution_time = paste0(execution_time, " secs"),
        message = if (cache_hit) {
          paste0("Cache hit - already have ", pages_after, " pages. Use clear_old=true for hard refresh.")
        } else {
          paste0("Fetched ", pages_fetched, " new pages (", pages_fetched * 10, " publications). ",
                 "Total cached: ", pages_after, "/", total_pages, " pages.")
        }
      )
    },
    error = function(e) {
      log_error("PubTator update failed: {e$message}")
      res$status <- 500
      list(
        success = FALSE,
        error = e$message
      )
    }
  )
}


#* Submit Async PubTator Update Job
#*
#* Submits an async job to fetch PubTator data. Returns immediately with a job ID
#* for status polling via `/api/jobs/<job_id>/status`.
#*
#* This is the **non-blocking** version of `/pubtator/update`. Use this for
#* fetching large numbers of pages to avoid request timeouts.
#*
#* **Soft Update (default)**: Only fetches pages not already cached.
#* **Hard Update (clear_old=true)**: Clears existing cache and fetches fresh.
#*
#* Use `/pubtator/cache-status` to check what's cached before submitting.
#*
#* @tag publication
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @param query:str The search query for PubTator (e.g., "epilepsy gene variant")
#* @param max_pages:int Maximum pages to fetch (default 10, each page has 10 results)
#* @param clear_old:bool Hard update - clear existing cache first (default false)
#*
#* @response 202 Accepted - job submitted, returns job_id
#* @response 400 Bad request - missing query parameter
#* @response 409 Conflict - duplicate job already running
#* @response 503 Service unavailable - job queue full
#*
#* @post /pubtator/update/submit
function(req, res, query = "", max_pages = 10, clear_old = FALSE) {
  if (query == "") {
    res$status <- 400
    return(list(error = "Query parameter is required"))
  }

  max_pages <- as.integer(max_pages)
  clear_old <- as.logical(clear_old)

  log_info("PubTator async update submitted: query='{query}', max_pages={max_pages}, clear_old={clear_old}")

  # Check for duplicate running job
  q_hash <- generate_query_hash(query)
  dup_check <- check_duplicate_job("pubtator_update", list(query_hash = q_hash, clear_old = clear_old))
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "PubTator update for this query already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # CRITICAL: Extract database config BEFORE mirai call
  # Database connections cannot cross process boundaries
  db_config <- list(
    db_host = dw$host,
    db_port = dw$port,
    db_name = dw$dbname,
    db_user = dw$user,
    db_password = dw$password
  )


  # Estimate timeout based on pages
  # Each page takes ~6s (350ms rate limit + 2s fetch + 3s DB operations)
  # Plus 2 minute buffer for gene symbol computation at end
  timeout_ms <- max(120000, (max_pages * 6000) + 120000)

  # Create async job
  result <- create_job(
    operation = "pubtator_update",
    params = list(
      query = query,
      max_pages = max_pages,
      clear_old = clear_old,
      query_hash = q_hash,
      db_config = db_config
    ),
    timeout_ms = timeout_ms,
    executor_fn = function(params) {
      # This runs in mirai daemon
      # Create progress reporter for status polling
      progress <- create_progress_reporter(params$.__job_id__)
      job_id <- params$.__job_id__

      message(sprintf(
        "[%s] [job:%s] PubTator update starting: query='%s', max_pages=%d, clear_old=%s",
        Sys.time(), job_id, params$query, params$max_pages, params$clear_old
      ))

      progress("init", "Initializing PubTator fetch...", current = 0, total = params$max_pages)

      # Use the async-friendly version that creates its own DB connection
      # Handles: rate limiting, pagination, database storage, gene symbols
      result <- pubtator_db_update_async(
        db_config = params$db_config,
        query = params$query,
        max_pages = params$max_pages,
        do_full_update = params$clear_old,
        progress_fn = progress
      )

      progress("complete", "PubTator fetch complete", current = params$max_pages, total = params$max_pages)

      list(
        status = "completed",
        success = result$success,
        query_id = result$query_id,
        query = params$query,
        pages_cached = result$pages_cached,
        pages_total = result$pages_total,
        publications_count = result$publications_count,
        message = result$message
      )
    }
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "5")

  # Estimated time: ~2.5s per page
  estimated_seconds <- round(max_pages * 2.5)

  list(
    job_id = result$job_id,
    status = result$status,
    query = query,
    max_pages = max_pages,
    estimated_seconds = estimated_seconds,
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}


#* Clear all PubTator cache data
#*
#* This admin endpoint clears all data from PubTator cache tables.
#* Use with caution - this will remove all cached search results and annotations.
#*
#* @tag publication
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @response 200 OK - returns count of deleted rows
#*
#* @post /pubtator/clear-cache
function(req, res) {
  start_time <- Sys.time()

  tryCatch(
    {
      log_info("Starting pubtator cache clear...")

      # Get counts before deletion using raw SQL for reliability
      conn <- pool::poolCheckout(pool)
      on.exit(pool::poolReturn(conn), add = TRUE)

      search_count <- DBI::dbGetQuery(
        conn,
        "SELECT COUNT(*) as cnt FROM pubtator_search_cache"
      )$cnt[1]

      annotation_count <- DBI::dbGetQuery(
        conn,
        "SELECT COUNT(*) as cnt FROM pubtator_annotation_cache"
      )$cnt[1]

      query_count <- DBI::dbGetQuery(
        conn,
        "SELECT COUNT(*) as cnt FROM pubtator_query_cache"
      )$cnt[1]

      log_info("Counts: queries={query_count}, publications={search_count}, annotations={annotation_count}")

      # Delete in order (annotations first due to foreign key-like relationships)
      DBI::dbExecute(conn, "DELETE FROM pubtator_annotation_cache")
      DBI::dbExecute(conn, "DELETE FROM pubtator_search_cache")
      DBI::dbExecute(conn, "DELETE FROM pubtator_query_cache")

      end_time <- Sys.time()
      execution_time <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)

      list(
        success = TRUE,
        deleted = list(
          queries = query_count,
          publications = search_count,
          annotations = annotation_count
        ),
        execution_time = paste0(execution_time, " secs"),
        message = paste0(
          "Cleared ", query_count, " queries, ",
          search_count, " publications, ",
          annotation_count, " annotations"
        )
      )
    },
    error = function(e) {
      log_error("PubTator cache clear failed: {conditionMessage(e)}")
      res$status <- 500
      list(
        success = FALSE,
        error = conditionMessage(e)
      )
    }
  )
}
