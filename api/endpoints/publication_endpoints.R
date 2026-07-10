# api/endpoints/publication_endpoints.R
#
# Publication-related endpoints. This file is a thin routing/authorization
# shell (Wave 3 / Task 2, #346): every decorator, handler formal/default, and
# `require_role()` gate stays here, but the request-processing bodies live in
# `svc_`-prefixed functions in api/services/publication-query-endpoint-service.R
# (public reads) and api/services/publication-admin-endpoint-service.R
# (Administrator/Curator mutations + status). See those files for behavior
# details. The `query == ""` 400 guard and the `/pubtator/update/submit`
# duplicate-job 409 short-circuit stay here on purpose (routing-layer
# auditability; see the admin service file header).

## -------------------------------------------------------------------##
## Publication endpoints
## -------------------------------------------------------------------##

#* Get Publication Statistics
#*
#* Returns total/oldest_update/outdated_count, and filtered_count when
#* `not_updated_since` is supplied.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param not_updated_since Optional ISO date (YYYY-MM-DD) filter.
#*
#* @response 200 OK. Returns publication statistics.
#*
#* @get /stats
function(req, res, not_updated_since = NULL) {
  publication_stats_response(not_updated_since)
}


#* Fetch Publication by PMID
#*
#* Looks up publication metadata (title, abstract, authors, etc.) by PMID.
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
  svc_publication_get_by_pmid(pmid)
}


#* Validate PMID Existence in PubMed
#*
#* Checks whether a given PMID exists in PubMed.
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
  svc_publication_validate_pmid(pmid)
}


#* Search Publications on PubTator
#*
#* Queries the PubTator API for NDD-literature-discovery matches. Allows
#* pagination.
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
  # SECURITY (#6): bound the live PubTator call by the per-request external-
  # time ceiling + base download timeout so a slow upstream cannot occupy a
  # worker. Kept as an explicit dependency here (not just the service default)
  # so the budget-bounded fetcher stays auditable at the routing layer.
  svc_publication_pubtator_search(req, res, current_page, search_fn = pubtator_public_search)
}


#* Get a Cursor Pagination Object of All Publications
#*
#* Supports sort/filter/fields/cursor pagination and json/xlsx output. See
#* services/publication-query-endpoint-service.R::svc_publication_list() for
#* the full behavior.
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
  svc_publication_list(req, res, sort, filter, fields, page_after, page_size, fspec, format)
}


#* Get a Cursor-Pagination Object of All Rows from pubtator_search_cache
#*
#* Supports sort/filter/fields/cursor pagination and json/xlsx output. See
#* services/publication-query-endpoint-service.R::svc_publication_pubtator_table()
#* for the full behavior.
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
  res$serializer <- serializers[[format]]
  final_list <- svc_publication_pubtator_table(
    req, res,
    sort = sort, filter = filter, fields = fields,
    page_after = page_after, page_size = page_size, fspec = fspec
  )

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
#* One row per gene of flat prioritization fields (publication_count,
#* entities_count, is_novel, oldest_pub_date, pmids, enrichment metrics).
#* Default sort prioritizes enrichment, falling back to `-publication_count`
#* when no enrichment snapshot exists (see `enrichmentStatus` in meta). See
#* services/publication-query-endpoint-service.R::svc_publication_pubtator_genes()
#* for the full behavior.
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
#* @response 200 OK - a cursor-paginated list of flat per-gene rows
#*
#* @get /pubtator/genes
function(req,
         res,
         sort = "-enrichment_ratio,-npmi,publication_count",
         filter = "",
         fields = "",
         page_after = "0",
         page_size = "10",
         fspec = "gene_name,gene_symbol,gene_normalized_id,hgnc_id,publication_count,entities_count,is_novel,oldest_pub_date,observed,background_count,enrichment_ratio,npmi,fisher_p,fdr_bh,pmids", # nolint: line_length_linter
         format = "json") {
  res$serializer <- serializers[[format]]
  final_list <- svc_publication_pubtator_genes(
    req, res,
    sort = sort, filter = filter, fields = fields,
    page_after = page_after, page_size = page_size, fspec = fspec
  )

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
#* Populates gene_symbols in pubtator_search_cache for rows where it is
#* currently NULL, joining non_alt_loci_set (HGNC) to filter for human genes.
#*
#* @tag publication
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @response 200 OK - returns count of updated rows
#* @post /pubtator/backfill-genes
function(req, res) {
  require_role(req, res, "Administrator")
  svc_publication_backfill_genes()
}


#* Get PubTator cache status for a query
#*
#* Returns cache information for a query: pages cached, total available, and
#* whether an update would fetch new data or hit cache.
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
  # SECURITY (#6): operational cache probe on a user-supplied, cache-defeating
  # query. Gate to Curator+ and budget-wrap the probe.
  require_role(req, res, "Curator")

  if (query == "") {
    res$status <- 400
    return(list(error = "Query parameter is required"))
  }

  svc_publication_pubtator_cache_status(res, query, total_pages_fn = pubtator_public_total_pages)
}


#* Trigger PubTator search and store results
#*
#* Initiates a new PubTator search for the given query, fetches results with
#* annotations, and stores them. Soft update (default) fetches only pages not
#* already cached; `clear_old=true` clears cached data first. Use
#* `/pubtator/cache-status` first to check what's cached.
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
#* @post /pubtator/update
function(req, res, query = "", max_pages = 10, clear_old = FALSE) {
  require_role(req, res, "Administrator")

  if (query == "") {
    res$status <- 400
    return(list(error = "Query parameter is required"))
  }

  svc_publication_pubtator_update(req, res, query, max_pages, clear_old)
}


#* Submit Async PubTator Update Job
#*
#* Non-blocking version of `/pubtator/update`: submits an async job and
#* returns immediately with a job_id for status polling via
#* `/api/jobs/<job_id>/status`. Use for large page counts to avoid request
#* timeouts.
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
#* @post /pubtator/update/submit
function(req, res, query = "", max_pages = 10, clear_old = FALSE) {
  require_role(req, res, "Administrator")

  if (query == "") {
    res$status <- 400
    return(list(error = "Query parameter is required"))
  }

  max_pages <- as.integer(max_pages)
  clear_old <- as.logical(clear_old)

  # Duplicate-job short-circuit stays in the shell (auditable at the routing
  # layer); job creation/response-shaping is delegated below.
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

  svc_publication_pubtator_update_submit(req, res, query, max_pages, clear_old, q_hash)
}


#* Clear all PubTator cache data
#*
#* Clears all data from PubTator cache tables. Use with caution.
#*
#* @tag publication
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @response 200 OK - returns count of deleted rows
#* @post /pubtator/clear-cache
function(req, res) {
  require_role(req, res, "Administrator")
  svc_publication_pubtator_clear_cache(res)
}


#* Submit a PubtatorNDD gene-enrichment refresh job
#*
#* Normalizes raw NDD co-occurrence counts for research-popularity bias
#* (#175); runs in the durable async worker (network egress). Cadence: monthly.
#*
#* @tag publication
#* @serializer json list(na="null")
#*
#* @response 202 Accepted. Returns job_id; poll the status_url.
#* @response 409 A refresh is already running.
#* @post /pubtator/enrichment/refresh
function(req, res) {
  require_role(req, res, "Administrator")
  pubtator_enrichment_refresh_submit(res, submitted_by = req$user_id %||% NULL)
}


#* PubtatorNDD enrichment snapshot status
#*
#* Reports the current enrichment snapshot: when computed, corpus sizes used,
#* and how many genes were scored. Public read.
#*
#* @tag publication
#* @serializer json list(na="null", auto_unbox=TRUE)
#*
#* @response 200 OK. Returns the current snapshot summary (or available=false).
#* @get /pubtator/enrichment/status
function(req, res) {
  pubtator_enrichment_status_response()
}
