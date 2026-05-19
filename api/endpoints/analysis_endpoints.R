# api/endpoints/analysis_endpoints.R
#
# This file contains all Analysis-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Be sure to source any required helper files at the top (e.g.,
# source("functions/database-functions.R", local = TRUE)) if needed.
#
# Note: For long-running operations, consider using async endpoints:
#   POST /api/jobs/clustering/submit - Async functional clustering
#   POST /api/jobs/phenotype_clustering/submit - Async phenotype clustering
#   GET /api/jobs/<job_id>/status - Poll job status

## -------------------------------------------------------------------##
## Analyses endpoints
## -------------------------------------------------------------------##

#* Retrieve Functional Clustering Data with Pagination
#*
#* This endpoint fetches functional clustering data for genes with NDD phenotype.
#* Results are paginated to reduce response size and improve performance.
#*
#* # `Details`
#* - Returns clusters sorted by cluster number for stable pagination
#* - Use `page_after` cursor to fetch subsequent pages
#* - Default page size is 10 clusters, maximum is 50
#* - Categories are returned in full (small dataset, not paginated)
#*
#* # `Pagination`
#* - First page: omit `page_after` or pass empty string
#* - Next page: use `next_cursor` from previous response as `page_after`
#* - Last page: `has_more` will be `false` and `next_cursor` will be `null`
#*
#* # `Return`
#* Returns categories, paginated clusters, and pagination metadata.
#*
#* @tag analysis
#* @serializer json list(na="string")
#* @param page_after:str Cursor for pagination (hash_filter of last item, empty for first page)
#* @param page_size:str Number of clusters per page (default "10", max "50")
#* @param algorithm:str Clustering algorithm: "leiden" (default, fast) or "walktrap" (slower, legacy)
#*
#* @response 200 OK. Returns object with:
#*   - categories: Full list of enrichment categories with links
#*   - clusters: Array of cluster objects (paginated)
#*   - pagination: {page_size, page_after, next_cursor, total_count, has_more}
#*   - meta: {algorithm, cache_hit}
#*
#* @get functional_clustering
function(page_after = "", page_size = "10", algorithm = "leiden") {
  # Define link sources
  value <- c(
    "COMPARTMENTS",
    "Component",
    "DISEASES",
    "Function",
    "HPO",
    "InterPro",
    "KEGG",
    "Keyword",
    "NetworkNeighborAL",
    "Pfam",
    "PMID",
    "Process",
    "RCTM",
    "SMART",
    "TISSUES",
    "WikiPathways"
  )

  link <- c(
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://disease-ontology.org/term/",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://hpo.jax.org/app/browse/term/",
    "http://www.ebi.ac.uk/interpro/entry/InterPro/",
    "https://www.genome.jp/dbget-bin/www_bget?",
    "https://www.uniprot.org/keywords/",
    "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
    "https://www.ebi.ac.uk/interpro/entry/pfam/",
    "https://www.ncbi.nlm.nih.gov/search/all/?term=",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://reactome.org/content/detail/R-",
    "http://www.ebi.ac.uk/interpro/entry/smart/",
    "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
    "https://www.wikipathways.org/index.php/Pathway:"
  )

  links <- tibble(value, link)

  # NOTE: Backward compatibility
  # - Clients not using pagination get first 10 clusters (was all clusters)
  # - To get all clusters, iterate using next_cursor until has_more=false
  # - Categories still returned in full (not paginated)

  # Validate and parse pagination parameters
  page_size_int <- min(max(as.integer(page_size), 1), 50)
  page_after_clean <- if (is.null(page_after) || page_after == "") "" else page_after

  # Validate algorithm parameter
  algorithm_clean <- tolower(algorithm)
  if (!algorithm_clean %in% c("leiden", "walktrap")) {
    algorithm_clean <- "leiden" # Default to faster algorithm
  }

  # Track timing for performance monitoring
  start_time <- Sys.time()

  # Get data from database
  genes_from_entity_table <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id) %>%
    collect() %>%
    unique()

  # Generate clusters for the retrieved HGNC IDs with selected algorithm
  functional_clusters <- gen_string_clust_obj_mem(
    genes_from_entity_table$hgnc_id,
    algorithm = algorithm_clean
  )

  # Handle empty clustering results (no STRING interactions for input genes)
  if (nrow(functional_clusters) == 0) {
    # Calculate elapsed time
    elapsed_seconds <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

    return(list(
      categories = tibble(value = character(), text = character(), link = character()),
      clusters = functional_clusters,
      pagination = list(
        page_size = page_size_int,
        page_after = page_after_clean,
        next_cursor = NULL,
        total_count = 0L,
        has_more = FALSE
      ),
      meta = list(
        algorithm = algorithm_clean,
        elapsed_seconds = round(elapsed_seconds, 2),
        gene_count = nrow(genes_from_entity_table),
        cluster_count = 0L
      )
    ))
  }

  # Calculate elapsed time
  elapsed_seconds <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Generate categories
  categories <- functional_clusters %>%
    select(term_enrichment) %>%
    unnest(cols = c(term_enrichment)) %>%
    select(category) %>%
    unique() %>%
    arrange(category) %>%
    mutate(
      text = case_when(
        nchar(category) <= 5 ~ category,
        nchar(category) > 5 ~ str_to_sentence(category)
      )
    ) %>%
    select(value = category, text) %>%
    left_join(links, by = c("value"))

  # Sort clusters deterministically for stable pagination
  # (prevents duplicates/gaps across pages)
  clusters_sorted <- functional_clusters %>%
    arrange(cluster) %>%
    mutate(row_num = row_number())

  # Find cursor position
  if (page_after_clean == "") {
    start_idx <- 1
  } else {
    cursor_pos <- which(clusters_sorted$hash_filter == page_after_clean)
    start_idx <- if (length(cursor_pos) > 0) cursor_pos[1] + 1 else 1
  }

  # Extract page slice
  end_idx <- min(start_idx + page_size_int - 1, nrow(clusters_sorted))
  clusters_page <- clusters_sorted %>%
    slice(start_idx:end_idx) %>%
    select(-row_num) # Remove internal field

  # Generate next cursor (hash_filter of last item in page)
  next_cursor <- if (end_idx < nrow(clusters_sorted)) {
    clusters_page %>%
      slice(n()) %>%
      pull(hash_filter)
  } else {
    NULL
  }

  # Generate the object to return with pagination metadata
  list(
    categories = categories,
    clusters = clusters_page, # Paginated clusters (was functional_clusters)
    pagination = list(
      page_size = page_size_int,
      page_after = page_after_clean,
      next_cursor = next_cursor,
      total_count = nrow(clusters_sorted),
      has_more = !is.null(next_cursor)
    ),
    meta = list(
      algorithm = algorithm_clean,
      elapsed_seconds = round(elapsed_seconds, 2),
      gene_count = nrow(genes_from_entity_table),
      cluster_count = nrow(clusters_sorted)
    )
  )
}


#* Retrieve Phenotype Clustering Data
#*
#* This endpoint fetches data clusters of entities based on phenotypes
#* using Multiple Correspondence Analysis (MCA) and Hierarchical Clustering.
#*
#* # `Details`
#* Retrieves phenotype-based clusters of entities.
#*
#* # `Return`
#* Returns a list of entities grouped by phenotype clusters.
#*
#* @tag analysis
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns phenotype clustering data.
#*
#* @get phenotype_clustering
function() {
  generate_phenotype_clusters()
}


#* Correlation of Phenotype & Functional Clusters
#*
#* This endpoint calculates the correlation between:
#*   - Phenotype-based clusters (MCA)
#*   - Functional clusters (STRING-db based)
#*   - Optionally, SFARI genes
#*
#* It returns a JSON object containing:
#*   - "correlation_matrix": a matrix of Pearson correlation coefficients
#*   - "correlation_melted": the melted version (x, y, value)
#*
#* @tag analysis
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns correlation data among clusters.
#*
#* @get phenotype_functional_cluster_correlation
function() {
  generate_phenotype_functional_cluster_correlation()
}


#* Retrieve Network Edges for Cytoscape.js Visualization
#*
#* Returns protein-protein interaction edges from STRINGdb in Cytoscape.js format.
#* Nodes include gene identifiers and cluster membership.
#* Edges include STRING confidence scores.
#*
#* # `Details`
#* - Nodes contain hgnc_id, symbol, cluster assignment, and degree (connection count)
#* - Edges contain source, target (HGNC IDs), and confidence (0-1 normalized)
#* - Metadata includes node_count, edge_count, cluster_count, string_version
#* - Results are cached via memoise for performance
#*
#* # `Parameters`
#* - cluster_type: Use "clusters" for main clusters or "subclusters" for nested
#* - min_confidence: STRING confidence threshold (0-1000, higher = more stringent)
#*
#* @tag analysis
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @param cluster_type:str Type of clusters: "clusters" (default) or "subclusters"
#* @param min_confidence:str Minimum STRING confidence (0-1000, default "400")
#* @param max_edges:str Maximum edges to return (default "10000", 0 for all). Higher confidence edges are prioritized.
#*
#* @response 200 OK. Returns nodes, edges, and metadata
#*
#* @get network_edges
function(cluster_type = "clusters", min_confidence = "400", max_edges = "10000") {
  # Validate cluster_type parameter
  cluster_type_clean <- tolower(cluster_type)
  if (!cluster_type_clean %in% c("clusters", "subclusters")) {
    cluster_type_clean <- "clusters" # Default to main clusters
  }

  # Parse and validate min_confidence parameter
  min_confidence_int <- as.integer(min_confidence)
  if (is.na(min_confidence_int)) {
    min_confidence_int <- 400 # Default if parsing fails
  }
  # Clamp to valid STRING confidence range (0-1000)
  min_confidence_int <- min(max(min_confidence_int, 0), 1000)

  # Parse max_edges parameter (0 = unlimited)
  max_edges_int <- as.integer(max_edges)
  if (is.na(max_edges_int) || max_edges_int < 0) {
    max_edges_int <- 10000 # Default to 10000 for browser performance
  }

  generate_network_edges_response(
    cluster_type = cluster_type_clean,
    min_confidence = min_confidence_int,
    max_edges = max_edges_int
  )
}


#* Get LLM Summary for Functional Cluster
#*
#* Retrieves or generates an LLM summary for a functional gene cluster.
#* First checks cache, then generates on-demand if not found.
#*
#* # `Details`
#* - Looks up cached summary by cluster_hash (SHA256 hash of cluster composition)
#* - If not cached, generates new summary via Gemini API
#* - Excludes rejected summaries (validation_status = 'rejected')
#* - Returns summary_json with structured content (summary, key_themes, pathways, etc.)
#*
#* @tag analysis
#* @serializer json list(na="string")
#* @param cluster_hash:str SHA256 hash of cluster composition (or equals(hash,...) format)
#* @param cluster_number:str Cluster number (integer as string)
#*
#* @response 200 OK. Returns summary with metadata
#* @response 400 Bad Request. Missing required parameters
#* @response 404 Not Found. Cluster not found or summary rejected
#* @response 500 Internal Server Error. Generation failed
#* @response 503 Service Unavailable. LLM not configured
#*
#* @get functional_cluster_summary
function(cluster_hash = NULL, cluster_number = NULL, res) {
  source("functions/llm-cache-repository.R", local = TRUE)
  source("functions/llm-service.R", local = TRUE)
  source("functions/llm-endpoint-helpers.R", local = TRUE)
  get_cluster_summary(cluster_hash, cluster_number, "functional", res)
}


#* Get LLM Summary for Phenotype Cluster
#*
#* Retrieves or generates an LLM summary for a phenotype cluster.
#* First checks cache, then generates on-demand if not found.
#*
#* # `Details`
#* - Looks up cached summary by cluster_hash (SHA256 hash of cluster composition)
#* - If not cached, generates new summary via Gemini API
#* - Excludes rejected summaries (validation_status = 'rejected')
#* - Returns summary_json with structured content (summary, key_themes, pathways, etc.)
#*
#* @tag analysis
#* @serializer json list(na="string")
#* @param cluster_hash:str SHA256 hash of cluster composition (or equals(hash,...) format)
#* @param cluster_number:str Cluster number (integer as string)
#*
#* @response 200 OK. Returns summary with metadata
#* @response 400 Bad Request. Missing required parameters
#* @response 404 Not Found. Cluster not found or summary rejected
#* @response 500 Internal Server Error. Generation failed
#* @response 503 Service Unavailable. LLM not configured
#*
#* @get phenotype_cluster_summary
function(cluster_hash = NULL, cluster_number = NULL, res) {
  source("functions/llm-cache-repository.R", local = TRUE)
  source("functions/llm-service.R", local = TRUE)
  source("functions/llm-endpoint-helpers.R", local = TRUE)
  get_cluster_summary(cluster_hash, cluster_number, "phenotype", res)
}

## Analyses endpoints
## -------------------------------------------------------------------##
