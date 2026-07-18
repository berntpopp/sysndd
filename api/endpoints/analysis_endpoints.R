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

analysis_snapshot_endpoint_response <- function(snapshot_result, res) {
  if (!is.null(snapshot_result$status) && snapshot_result$status >= 400L) {
    res$status <- snapshot_result$status
    if (!is.null(snapshot_result$retry_after)) {
      res$setHeader("Retry-After", as.character(snapshot_result$retry_after))
    }
    return(snapshot_result$body)
  }

  snapshot_result$body
}

analysis_endpoint_scalar <- function(value, default = NULL) {
  if (is.null(value) || length(value) == 0L) {
    return(default)
  }
  value[[1]]
}

analysis_paginate_snapshot_clusters <- function(body, page_after_clean, page_size_int, res = NULL) {
  clusters <- tibble::as_tibble(body$clusters %||% tibble::tibble())
  if (nrow(clusters) == 0L) {
    body$clusters <- clusters
    body$pagination <- list(
      page_size = page_size_int,
      page_after = page_after_clean,
      next_cursor = NULL,
      total_count = 0L,
      has_more = FALSE
    )
    return(body)
  }

  required_columns <- c("cluster", "hash_filter")
  missing_columns <- setdiff(required_columns, names(clusters))
  if (length(missing_columns) > 0L) {
    if (!is.null(res)) {
      res$status <- 500L
    }
    return(list(
      code = "snapshot_payload_invalid",
      message = "Functional cluster snapshot payload is missing required pagination fields.",
      details = list(missing_columns = missing_columns)
    ))
  }

  clusters_sorted <- clusters %>%
    dplyr::arrange(cluster) %>%
    dplyr::mutate(row_num = dplyr::row_number())

  if (page_after_clean == "") {
    start_idx <- 1L
  } else {
    cursor_pos <- which(clusters_sorted$hash_filter == page_after_clean)
    start_idx <- if (length(cursor_pos) > 0L) cursor_pos[[1]] + 1L else 1L
  }

  if (start_idx > nrow(clusters_sorted)) {
    body$clusters <- clusters_sorted[0L, setdiff(names(clusters_sorted), "row_num"), drop = FALSE]
    body$pagination <- list(
      page_size = page_size_int,
      page_after = page_after_clean,
      next_cursor = NULL,
      total_count = nrow(clusters_sorted),
      has_more = FALSE
    )
    return(body)
  }

  end_idx <- min(start_idx + page_size_int - 1L, nrow(clusters_sorted))
  clusters_page <- clusters_sorted %>%
    dplyr::slice(start_idx:end_idx) %>%
    dplyr::select(-row_num)

  next_cursor <- if (end_idx < nrow(clusters_sorted)) {
    clusters_page %>%
      dplyr::slice(dplyr::n()) %>%
      dplyr::pull(hash_filter)
  } else {
    NULL
  }

  body$clusters <- clusters_page
  body$pagination <- list(
    page_size = page_size_int,
    page_after = page_after_clean,
    next_cursor = next_cursor,
    total_count = nrow(clusters_sorted),
    has_more = !is.null(next_cursor)
  )
  body
}

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
#* @param algorithm:str Supported public preset algorithm: "leiden" (default)
#*
#* @response 200 OK. Returns object with:
#*   - categories: Full list of enrichment categories with links
#*   - clusters: Array of cluster objects (paginated)
#*   - pagination: {page_size, page_after, next_cursor, total_count, has_more}
#*   - meta: {algorithm, cache_hit}
#*
#* @get functional_clustering
function(page_after = "", page_size = "10", algorithm = "leiden", res) {
  # NOTE: Backward compatibility
  # - Clients not using pagination get first 10 clusters (was all clusters)
  # - To get all clusters, iterate using next_cursor until has_more=false
  # - Categories still returned in full (not paginated)

  # Validate and parse pagination parameters
  n <- suppressWarnings(as.integer(page_size))
  if (is.na(n)) n <- 10L
  page_size_int <- min(max(n, 1L), 50L)
  page_after_clean <- if (is.null(page_after) || page_after == "") "" else page_after

  algorithm_clean <- tolower(as.character(analysis_endpoint_scalar(algorithm, "leiden")))

  snapshot_result <- service_analysis_snapshot_read(
    "functional_clusters",
    list(algorithm = algorithm_clean)
  )
  body <- analysis_snapshot_endpoint_response(snapshot_result, res)
  if (!is.null(snapshot_result$status) && snapshot_result$status >= 400L) {
    return(body)
  }

  analysis_paginate_snapshot_clusters(body, page_after_clean, page_size_int, res = res)
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
function(res) {
  snapshot_result <- service_analysis_snapshot_read("phenotype_clusters", list())
  analysis_snapshot_endpoint_response(snapshot_result, res)
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
function(res) {
  snapshot_result <- service_analysis_snapshot_read("phenotype_functional_correlations", list())
  analysis_snapshot_endpoint_response(snapshot_result, res)
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
#* - Results are read from the fixed public snapshot preset
#*
#* # `Parameters`
#* - cluster_type: "clusters" fixed public preset
#* - min_confidence: "400" fixed public preset
#* - max_edges: "10000" fixed public preset
#*
#* @tag analysis
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @param cluster_type:str Fixed public preset cluster type: "clusters"
#* @param min_confidence:str Fixed public preset STRING confidence: "400"
#* @param max_edges:str Fixed public preset maximum edges: "10000"
#*
#* @response 200 OK. Returns nodes, edges, and metadata
#*
#* @get network_edges
function(cluster_type = "clusters", min_confidence = "400", max_edges = "10000", res) {
  cluster_type_clean <- tolower(as.character(analysis_endpoint_scalar(cluster_type, "clusters")))
  min_confidence_value <- as.character(analysis_endpoint_scalar(min_confidence, "400"))
  max_edges_value <- as.character(analysis_endpoint_scalar(max_edges, "10000"))

  snapshot_result <- service_analysis_snapshot_read(
    "gene_network_edges",
    list(
      cluster_type = cluster_type_clean,
      min_confidence = min_confidence_value,
      max_edges = max_edges_value
    )
  )
  analysis_snapshot_endpoint_response(snapshot_result, res)
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
#* @response 404 Not Found. Cluster not found, summary rejected, or not cached (generation needs Curator+)
#* @response 500 Internal Server Error. Generation failed
#* @response 503 Service Unavailable. LLM not configured
#*
#* @get functional_cluster_summary
function(cluster_hash = NULL, cluster_number = NULL, req, res) {
  source("functions/llm-endpoint-helpers.R", local = TRUE)
  allow_gen <- !is.null(req$user_role) && req$user_role %in% c("Curator", "Administrator")
  get_cluster_summary(cluster_hash, cluster_number, "functional", res, allow_generation = allow_gen)
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
#* @response 404 Not Found. Cluster not found, summary rejected, or not cached (generation needs Curator+)
#* @response 500 Internal Server Error. Generation failed
#* @response 503 Service Unavailable. LLM not configured
#*
#* @get phenotype_cluster_summary
function(cluster_hash = NULL, cluster_number = NULL, req, res) {
  source("functions/llm-endpoint-helpers.R", local = TRUE)
  allow_gen <- !is.null(req$user_role) && req$user_role %in% c("Curator", "Administrator")
  get_cluster_summary(cluster_hash, cluster_number, "phenotype", res, allow_generation = allow_gen)
}


#* Functional Clustering Reproducibility Bundle
#*
#* Read-only sibling of `/functional_clustering` (#512). Returns the inputs
#* needed to INDEPENDENTLY recompute the served functional modularity: the
#* largest-connected-component STRING edge list, the complete Leiden membership,
#* the served modularity, params, and a SHA-256 reproducibility hash.
#*
#* # `Details`
#* - DB-only read from the current public snapshot's reproducibility row.
#* - Approved-public data only (the snapshot is built from approved public data).
#* - The `bundle` is the decompressed, parsed JSON of the stored gzip blob.
#*
#* NOTE: These reproducibility routes live in this file (not a separate mounted
#* sub-router) on purpose. Plumber cannot mount a second router at `/api/analysis`
#* (a duplicate mount replaces the first) and a sub-router 404 does not fall
#* through to other mounts, so the only way to serve the documented sibling path
#* `/api/analysis/functional_clustering/reproducibility` is as a route inside the
#* same analysis sub-router. The endpoint logic is kept thin (delegated to
#* `analysis_reproducibility_endpoint()` in functions/analysis-reproducibility.R).
#*
#* @tag analysis
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @response 200 OK. Returns { reproducibility_hash, kind, byte_size, snapshot_id, bundle }.
#* @response 404 Not Found. No public snapshot or no reproducibility bundle yet.
#*
#* @get functional_clustering/reproducibility
function(res) {
  analysis_reproducibility_endpoint("functional_clusters", res)
}


#* Phenotype Clustering Reproducibility Bundle
#*
#* Read-only sibling of `/phenotype_clustering` (#512). Returns the inputs needed
#* to INDEPENDENTLY recompute the served phenotype silhouette: the MCA coordinate
#* matrix, the cluster membership, the served silhouette, params, and a SHA-256
#* reproducibility hash.
#*
#* # `Details`
#* - DB-only read from the current public snapshot's reproducibility row.
#* - Approved-public data only.
#* - See the functional sibling above for why these routes live in this file.
#*
#* @tag analysis
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @response 200 OK. Returns { reproducibility_hash, kind, byte_size, snapshot_id, bundle }.
#* @response 404 Not Found. No public snapshot or no reproducibility bundle yet.
#*
#* @get phenotype_clustering/reproducibility
function(res) {
  analysis_reproducibility_endpoint("phenotype_clusters", res)
}


## -------------------------------------------------------------------##
## Analysis-snapshot RELEASES: public read routes (#573 Slice A / Task A6)
## -------------------------------------------------------------------##
#
# Immutable, content-addressed public releases of the analysis snapshots
# above (see services/analysis-snapshot-release-service.R for the full
# contract). DB-only, published-only: every svc_release_* read is pinned to
# status = "published", so an unknown release id and a draft release id are
# indistinguishable to the caller -- both resolve to a plain 404. `conn =
# pool` mirrors the established global-pool endpoint pattern (see
# endpoints/seo_endpoints.R) -- the A3 release repository requires an
# explicit connection on every call (no NULL/global-pool fallback), unlike
# the sibling analysis-snapshot-repository.R.
#
# DECLARATION ORDER IS LOAD-BEARING: `releases/latest` MUST stay declared
# before `releases/<release_id>` below -- Plumber matches routes in
# declaration order, so the dynamic `<release_id>` segment would otherwise
# shadow the literal "latest" segment (the same class of bug documented in
# AGENTS.md's `/status/_list` vs `/status/<status_id_requested>` lesson). A
# static test (test-integration-analysis-release-endpoints.R) guards this
# ordering directly against this source file.

analysis_release_query_int <- function(value, default) {
  parsed <- suppressWarnings(as.integer(analysis_endpoint_scalar(value, default)))
  if (is.na(parsed)) default else parsed
}

#* List published analysis-snapshot releases
#*
#* Immutable, content-addressed public releases (newest first). Draft
#* releases are never returned.
#*
#* @tag analysis
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @param limit:str Max releases to return (default "50")
#* @param offset:str Offset into the published list (default "0")
#*
#* @response 200 OK. Returns { releases, pagination }.
#*
#* @get releases
function(limit = "50", offset = "0", res) {
  limit_int <- analysis_release_query_int(limit, 50L)
  offset_int <- analysis_release_query_int(offset, 0L)
  releases <- svc_release_list(limit = limit_int, offset = offset_int, conn = pool)
  list(
    releases = releases,
    pagination = list(
      limit = limit_int,
      offset = offset_int,
      count = length(releases)
    )
  )
}


#* Get the newest published analysis-snapshot release
#*
#* MUST stay declared before `releases/<release_id>` (see the ordering note
#* above this section).
#*
#* @tag analysis
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @response 200 OK. Returns the release head + `manifest` (same shape as the detail route).
#* @response 404 Not Found. No published release exists yet.
#*
#* @get releases/latest
function(res) {
  newest <- svc_release_list(limit = 1, offset = 0, conn = pool)
  if (length(newest) == 0L) {
    stop_for_not_found("No published analysis-snapshot release exists yet")
  }
  svc_release_get(as.character(newest[[1]]$release_id), conn = pool)
}


#* Get one published analysis-snapshot release
#*
#* @tag analysis
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @param release_id Release id (`asr_<16 hex>`).
#*
#* @response 200 OK. Returns the release head + `manifest`.
#* @response 404 Not Found. Unknown release id, or the release is still a draft.
#*
#* @get releases/<release_id>
function(release_id, res) {
  svc_release_get(release_id, conn = pool)
}


#* Get a published release's stored `manifest.json` bytes verbatim
#*
#* Serves the EXACT stored bytes (never re-serialized), so
#* `sha256(bytes) == manifest_sha256` on the release head.
#*
#* @tag analysis
#* @serializer octet list(type = "application/json")
#* @param release_id Release id.
#*
#* @response 200 OK. Raw manifest.json bytes, Content-Type application/json.
#* @response 404 Not Found. Unknown release id, or the release is still a draft.
#*
#* @get releases/<release_id>/manifest.json
function(release_id, res) {
  content <- svc_release_manifest(release_id, conn = pool)
  # Content-Type is set by the octet serializer (application/json) -- do NOT also
  # res$setHeader() it, which would emit a duplicate Content-Type header.
  content$bytes
}


#* Get one content file from a published release by its exact archive path
#*
#* `path` is a QUERY parameter, not a path segment -- Plumber 1.3.2 has no
#* `<path:.*>` multi-segment param type, so a nested path segment would 404.
#* Resolved by an exact `(release_id, file_path)` primary-key lookup, so
#* there is no path-traversal surface.
#*
#* @tag analysis
#* @serializer octet
#* @param release_id Release id.
#* @param path:str Exact archive-relative file path, e.g. "functional_clusters/payload.json".
#*
#* @response 200 OK. Raw file bytes, Content-Type from the stored file's media type.
#* @response 404 Not Found. Unknown release id, draft release, or unknown file path.
#*
#* @get releases/<release_id>/file
function(release_id, path = "", res) {
  file_path <- analysis_endpoint_scalar(path, "")
  content <- svc_release_file(release_id, file_path, conn = pool)
  # The stored media type is per-file (usually application/json), so set the
  # serializer's type dynamically rather than res$setHeader()-ing a second
  # Content-Type alongside the octet serializer's default.
  res$serializer <- plumber::serializer_octet(type = content$media_type)
  content$bytes
}


#* Download a published release's whole archive (`bundle.tar.gz`) verbatim
#*
#* @tag analysis
#* @serializer octet list(type = "application/gzip")
#* @param release_id Release id.
#*
#* @response 200 OK. Raw gzip tar bytes, served as an attachment download.
#* @response 404 Not Found. Unknown release id, or the release is still a draft.
#*
#* @get releases/<release_id>/bundle
function(release_id, res) {
  bundle <- svc_release_bundle(release_id, conn = pool)
  # Content-Type (application/gzip) is set by the octet serializer -- do NOT also
  # res$setHeader() it (duplicate header). Content-Disposition/Length are distinct.
  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', bundle$filename))
  res$setHeader("Content-Length", as.character(length(bundle$bytes)))
  bundle$bytes
}

## Analyses endpoints
## -------------------------------------------------------------------##
