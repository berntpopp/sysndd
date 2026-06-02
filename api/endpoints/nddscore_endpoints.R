# api/endpoints/nddscore_endpoints.R
#
# Public NDDScore endpoints. NDDScore is model-derived/read-only; curated
# SysNDD evidence is never reclassified.

if (!exists("nddscore_repo_current_release", mode = "function")) {
  source("functions/nddscore-repository.R", local = FALSE)
}

## -------------------------------------------------------------------##
## NDDScore endpoints
## -------------------------------------------------------------------##

.nddscore_endpoint_notice <- paste(
  "NDDScore is model-derived/read-only;",
  "curated SysNDD evidence is never reclassified."
)

.nddscore_endpoint_scalar <- function(value, default = NULL) {
  if (is.null(value) || length(value) == 0L) {
    return(default)
  }
  value <- value[[1]]
  if (is.null(value) || is.na(value) || !nzchar(as.character(value))) {
    return(default)
  }
  as.character(value)
}

.nddscore_endpoint_int <- function(value, default) {
  value <- suppressWarnings(as.integer(.nddscore_endpoint_scalar(value, default)))
  if (is.na(value)) {
    return(default)
  }
  value
}

.nddscore_endpoint_filter <- function(...) {
  params <- list(...)
  filters <- list()
  for (name in names(params)) {
    value <- .nddscore_endpoint_scalar(params[[name]], NULL)
    if (!is.null(value)) {
      filters[[name]] <- value
    }
  }
  filters
}

.nddscore_endpoint_has_rows <- function(value) {
  !is.null(value) && is.data.frame(value) && nrow(value) > 0L
}

nddscore_endpoint_not_found <- function(
    res,
    message = "No active NDDScore release is available.") {
  res$status <- 404L
  if (is.function(res$setHeader)) {
    res$serializer <- plumber::serializer_unboxed_json(type = "application/problem+json")
  }
  list(
    error = "not_found",
    message = message
  )
}

.nddscore_endpoint_active_release <- function(res) {
  release <- nddscore_repo_current_release()
  if (!.nddscore_endpoint_has_rows(release)) {
    return(nddscore_endpoint_not_found(res))
  }
  release
}

.nddscore_endpoint_response <- function(data, meta = list()) {
  list(
    meta = c(
      list(notice = .nddscore_endpoint_notice),
      meta
    ),
    data = data
  )
}

#* Fetch Current NDDScore Release
#*
#* NDDScore is model-derived/read-only; curated SysNDD evidence is never
#* reclassified.
#*
#* @tag nddscore
#* @serializer json list(na="null")
#* @response 200 OK. Returns active NDDScore release metadata.
#* @response 404 Not Found. No active NDDScore release is available.
#* @get /release/current
function(res) {
  release <- .nddscore_endpoint_active_release(res)
  if (is.list(release) && identical(release$error, "not_found")) {
    return(release)
  }

  .nddscore_endpoint_response(release)
}

#* Fetch NDDScore Gene Predictions
#*
#* NDDScore is model-derived/read-only; curated SysNDD evidence is never
#* reclassified.
#*
#* @tag nddscore
#* @serializer json list(na="null")
#* @param hgnc_id Optional HGNC ID filter.
#* @param gene_symbol Optional gene symbol filter.
#* @param risk_tier Optional risk tier filter.
#* @param confidence_tier Optional confidence tier filter.
#* @param known_sysndd_gene Optional known SysNDD gene filter.
#* @param model_split Optional model split filter.
#* @param search Optional HGNC ID or symbol search.
#* @param sort Sort column, prefix with '-' for descending.
#* @param page Page number, starting at 1.
#* @param page_size Page size, capped by the repository.
#* @response 200 OK. Returns paginated gene predictions.
#* @response 404 Not Found. No active NDDScore release is available.
#* @get /genes
function(res,
         hgnc_id = NULL,
         gene_symbol = NULL,
         ndd_score_min = NULL,
         ndd_score_max = NULL,
         rank_min = NULL,
         rank_max = NULL,
         percentile_min = NULL,
         percentile_max = NULL,
         risk_tier = NULL,
         confidence_tier = NULL,
         known_sysndd_gene = NULL,
         model_split = NULL,
         top_inheritance_mode = NULL,
         hpo_terms = NULL,
         search = NULL,
         sort = "rank",
         page = 1L,
         page_size = 25L) {
  release <- .nddscore_endpoint_active_release(res)
  if (is.list(release) && identical(release$error, "not_found")) {
    return(release)
  }

  result <- nddscore_repo_genes(
    filters = .nddscore_endpoint_filter(
      hgnc_id = hgnc_id,
      gene_symbol = gene_symbol,
      ndd_score_min = ndd_score_min,
      ndd_score_max = ndd_score_max,
      rank_min = rank_min,
      rank_max = rank_max,
      percentile_min = percentile_min,
      percentile_max = percentile_max,
      risk_tier = risk_tier,
      confidence_tier = confidence_tier,
      known_sysndd_gene = known_sysndd_gene,
      model_split = model_split,
      top_inheritance_mode = top_inheritance_mode,
      hpo_terms = hpo_terms,
      search = search
    ),
    sort = .nddscore_endpoint_scalar(sort, "rank"),
    page = .nddscore_endpoint_int(page, 1L),
    page_size = .nddscore_endpoint_int(page_size, 25L)
  )

  .nddscore_endpoint_response(
    result$data,
    list(
      total = result$total,
      page = result$page,
      page_size = result$page_size
    )
  )
}

#* Fetch Single NDDScore Gene Prediction
#*
#* NDDScore is model-derived/read-only; curated SysNDD evidence is never
#* reclassified.
#*
#* @tag nddscore
#* @serializer json list(na="null")
#* @param hgnc_id_or_symbol HGNC ID or gene symbol.
#* @response 200 OK. Returns gene prediction and HPO predictions.
#* @response 404 Not Found. No active release or gene record is available.
#* @get /genes/<hgnc_id_or_symbol>
function(res, hgnc_id_or_symbol) {
  release <- .nddscore_endpoint_active_release(res)
  if (is.list(release) && identical(release$error, "not_found")) {
    return(release)
  }

  result <- nddscore_repo_gene_detail(
    .nddscore_endpoint_scalar(URLdecode(hgnc_id_or_symbol), "")
  )
  if (is.null(result$gene)) {
    return(nddscore_endpoint_not_found(
      res,
      sprintf("NDDScore gene '%s' was not found.", hgnc_id_or_symbol)
    ))
  }

  .nddscore_endpoint_response(result)
}

#* Fetch NDDScore HPO Predictions
#*
#* NDDScore is model-derived/read-only; curated SysNDD evidence is never
#* reclassified.
#*
#* @tag nddscore
#* @serializer json list(na="null")
#* @param hgnc_id Optional HGNC ID filter.
#* @param gene_symbol Optional gene symbol filter.
#* @param phenotype_id Optional HPO term ID filter.
#* @param phenotype_name Optional HPO term name filter.
#* @param passes_default_threshold Optional default-threshold filter.
#* @param search Optional gene or HPO search.
#* @param sort Sort column, prefix with '-' for descending.
#* @param page Page number, starting at 1.
#* @param page_size Page size, capped by the repository.
#* @response 200 OK. Returns paginated HPO predictions.
#* @response 404 Not Found. No active NDDScore release is available.
#* @get /hpo
function(res,
         hgnc_id = NULL,
         gene_symbol = NULL,
         phenotype_id = NULL,
         phenotype_name = NULL,
         passes_default_threshold = NULL,
         search = NULL,
         sort = "-probability",
         page = 1L,
         page_size = 25L) {
  release <- .nddscore_endpoint_active_release(res)
  if (is.list(release) && identical(release$error, "not_found")) {
    return(release)
  }

  result <- nddscore_repo_hpo(
    filters = .nddscore_endpoint_filter(
      hgnc_id = hgnc_id,
      gene_symbol = gene_symbol,
      phenotype_id = phenotype_id,
      phenotype_name = phenotype_name,
      passes_default_threshold = passes_default_threshold,
      search = search
    ),
    sort = .nddscore_endpoint_scalar(sort, "-probability"),
    page = .nddscore_endpoint_int(page, 1L),
    page_size = .nddscore_endpoint_int(page_size, 25L)
  )

  .nddscore_endpoint_response(
    result$data,
    list(
      total = result$total,
      page = result$page,
      page_size = result$page_size
    )
  )
}

#* Fetch NDDScore HPO Terms
#*
#* NDDScore is model-derived/read-only; curated SysNDD evidence is never
#* reclassified.
#*
#* @tag nddscore
#* @serializer json list(na="null")
#* @response 200 OK. Returns active-release HPO term metrics.
#* @response 404 Not Found. No active NDDScore release is available.
#* @get /terms
function(res) {
  release <- .nddscore_endpoint_active_release(res)
  if (is.list(release) && identical(release$error, "not_found")) {
    return(release)
  }

  .nddscore_endpoint_response(nddscore_repo_terms())
}

#* Fetch NDDScore Download Information
#*
#* NDDScore is model-derived/read-only; curated SysNDD evidence is never
#* reclassified.
#*
#* @tag nddscore
#* @serializer json list(na="null")
#* @response 200 OK. Returns source archive and citation information.
#* @response 404 Not Found. No active NDDScore release is available.
#* @get /download/info
function(res) {
  info <- nddscore_repo_download_info()
  if (is.null(info)) {
    return(nddscore_endpoint_not_found(res))
  }

  .nddscore_endpoint_response(info)
}
