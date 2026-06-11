# api/endpoints/genereviews_endpoints.R
#
# Curator-facing GeneReviews integration endpoints (issues #14, #46).
#
# Mounted at /api/genereviews via mount_endpoint() (RFC 9457 error handler +
# 404 handler attached). All routes are Curator+ gated. Live NCBI availability
# lookups are cached (memoise_external_success_only) and opt-in via the
# `include_live` flag so the cheap, already-linked-only coverage view never
# triggers external calls.

## -------------------------------------------------------------------##
## GeneReviews coverage endpoints
## -------------------------------------------------------------------##

#* Single-gene GeneReviews availability lookup
#*
#* Returns whether a GeneReviews chapter exists for a gene symbol, plus the
#* NBK accession and Bookshelf URL when available. Result is cached.
#*
#* @tag genereviews
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @param symbol:str HGNC gene symbol (e.g. "GRIN2B").
#*
#* @response 200 OK. Availability payload.
#* @response 400 Bad request. Missing/invalid symbol.
#* @response 403 Forbidden. Requires Curator role.
#*
#* @get /availability/<symbol>
function(req, res, symbol = "") {
  require_role(req, res, "Curator")

  symbol <- toupper(trimws(URLdecode(symbol)))
  if (!nzchar(symbol)) {
    stop_for_bad_request("Gene symbol is required.")
  }

  result <- fetch_genereviews_availability_mem(symbol)

  if (is.list(result) && isTRUE(result$error)) {
    res$status <- 503
    return(list(
      error = TRUE,
      source = "genereviews",
      message = result$message %||% "GeneReviews lookup temporarily unavailable."
    ))
  }

  result
}


#* GeneReviews coverage table across SysNDD entities
#*
#* Returns one row per active entity with its gene symbol and whether a
#* GeneReviews reference is already linked. When `include_live=true`, also
#* performs the (cached) NCBI availability lookup per gene and flags entities
#* whose gene has a GeneReviews chapter upstream that is not yet linked
#* (`needs_attention = true`, the #46 gap signal).
#*
#* @tag genereviews
#* @serializer json list(na="string")
#*
#* @param include_live:bool When true, include live (cached) NCBI availability
#*   and the needs_attention flag. Defaults to false (cheap, no external calls).
#*
#* @response 200 OK. Coverage rows.
#* @response 403 Forbidden. Requires Curator role.
#*
#* @get /coverage
function(req, res, include_live = FALSE) {
  require_role(req, res, "Curator")

  include_live <- as.logical(include_live)
  if (is.na(include_live)) {
    include_live <- FALSE
  }

  coverage <- svc_genereviews_coverage(include_live = include_live)

  list(
    meta = list(
      include_live = include_live,
      total = nrow(coverage),
      already_linked = sum(coverage$already_linked, na.rm = TRUE),
      needs_attention = if (include_live) {
        sum(coverage$needs_attention, na.rm = TRUE)
      } else {
        NA
      }
    ),
    data = coverage
  )
}


#* Export GeneReviews coverage as CSV (the #46 "Excel table")
#*
#* Returns the gene -> GeneReviews coverage table as a CSV download. When
#* `include_live=true` the CSV includes upstream availability and the
#* needs_attention flag for genes lacking a linked GeneReviews entry.
#*
#* @tag genereviews
#*
#* @param include_live:bool When true, include live (cached) NCBI availability.
#*   Defaults to false.
#*
#* @response 200 OK. text/csv attachment.
#* @response 403 Forbidden. Requires Curator role.
#*
#* @get /coverage/export
function(req, res, include_live = FALSE) {
  require_role(req, res, "Curator")

  include_live <- as.logical(include_live)
  if (is.na(include_live)) {
    include_live <- FALSE
  }

  res$serializer <- serializers[["csv"]]

  coverage <- svc_genereviews_coverage(include_live = include_live)

  creation_date <- format(Sys.time(), "%Y-%m-%d_T%H-%M-%S")
  filename <- paste0("sysndd_genereviews_coverage_", creation_date, ".csv")
  res$setHeader(
    "Content-Disposition",
    paste0("attachment; filename=", filename)
  )

  svc_genereviews_coverage_csv(coverage)
}


#* Attach a GeneReviews reference to an entity
#*
#* Curator action (issue #14): links a GeneReviews chapter (by its PMID) to an
#* entity's primary review using the existing publication model
#* (publication_type = "gene_review"). Idempotent: re-attaching an already
#* linked PMID is a success no-op.
#*
#* Auth-sensitive inputs are body-only. Request JSON body:
#*   { "entity_id": <int>, "pmid": "<PMID|number>" }
#*
#* @tag genereviews
#* @serializer json list(na="string", auto_unbox=TRUE)
#*
#* @response 200 OK. Reference attached (or already present).
#* @response 400 Bad request. Invalid entity_id/PMID, or PMID is not a
#*   GeneReviews chapter.
#* @response 403 Forbidden. Requires Curator role.
#* @response 404 Not found. Entity has no review to attach to.
#*
#* @post /attach
function(req, res) {
  require_role(req, res, "Curator")

  body <- req$argsBody
  entity_id <- body$entity_id
  pmid <- body$pmid

  if (is.null(entity_id) || is.null(pmid)) {
    stop_for_bad_request("Both entity_id and pmid are required in the request body.")
  }

  # Plumber may deliver scalars as length-1 lists/vectors; take the first.
  entity_id <- entity_id[[1]]
  pmid <- pmid[[1]]

  result <- svc_genereviews_attach_to_entity(entity_id, pmid)

  if (result$status == 400) {
    stop_for_bad_request(result$message)
  }
  if (result$status == 404) {
    stop_for_not_found(result$message)
  }
  if (result$status != 200) {
    res$status <- result$status
    return(list(error = TRUE, message = result$message))
  }

  res$status <- 200
  list(
    status = 200,
    message = result$message,
    entity_id = as.integer(entity_id),
    review_id = result$review_id,
    publication_id = result$publication_id
  )
}
