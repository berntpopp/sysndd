# api/endpoints/publication_endpoints.R
#
# This file contains all Publication-related endpoints extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible.

##-------------------------------------------------------------------##
## Publication endpoints
##-------------------------------------------------------------------##

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
