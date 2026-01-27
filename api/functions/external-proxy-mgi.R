# functions/external-proxy-mgi.R
#### MGI (Mouse Genome Informatics) phenotype proxy functions

#' Fetch MGI mouse phenotype data for a gene symbol
#'
#' @description
#' Retrieves mouse phenotype data from Mouse Genome Informatics (MGI) for a
#' given gene symbol. Implements defensive error handling for undocumented
#' MGI API endpoints.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1")
#'
#' @return List containing:
#' \describe{
#'   \item{Success}{source, gene_symbol, mgi_id, mouse_symbol, phenotype_count,
#'                  phenotypes, mgi_url}
#'   \item{Not found}{found = FALSE, source = "mgi"}
#'   \item{API format error}{found = FALSE, source = "mgi", message = <details>}
#'   \item{Error}{error = TRUE, source = "mgi", message = <details>}
#' }
#'
#' @details
#' Queries MGI search API to find mouse gene ortholog by human gene symbol.
#' MGI API endpoints are not well documented, so implementation is defensive:
#' returns `found = FALSE` rather than crashing on unexpected formats.
#'
#' Uses memoised caching with 14-day TTL (cache_stable) since phenotype
#' annotations change moderately.
#'
#' @examples
#' \dontrun{
#'   result <- fetch_mgi_phenotypes("BRCA1")
#'   if (!isTRUE(result$found == FALSE) && !isTRUE(result$error)) {
#'     print(result$mgi_url)
#'   }
#' }
#'
#' @export
fetch_mgi_phenotypes <- function(gene_symbol) {
  tryCatch(
    {
      # Validate gene symbol format
      if (!validate_gene_symbol(gene_symbol)) {
        return(list(
          error = TRUE,
          source = "mgi",
          message = paste("Invalid gene symbol format:", gene_symbol)
        ))
      }

      # Query MGI marker search API
      # Note: MGI endpoints are undocumented; this is a best-effort implementation
      mgi_search_url <- paste0(
        "http://www.informatics.jax.org/api/marker/search",
        "?nomen=", gene_symbol,
        "&organism=mouse"
      )

      mgi_response <- make_external_request(
        url = mgi_search_url,
        api_name = "mgi",
        throttle_config = EXTERNAL_API_THROTTLE$mgi
      )

      # Handle errors from MGI query
      if (isTRUE(mgi_response$error)) {
        return(list(
          error = TRUE,
          source = "mgi",
          message = paste("MGI query failed:", mgi_response$message)
        ))
      }

      # Handle not found
      if (isTRUE(mgi_response$found == FALSE)) {
        return(list(found = FALSE, source = "mgi"))
      }

      # Defensive parsing: check if response has expected structure
      # MGI API may return various formats; handle gracefully
      if (is.null(mgi_response) || length(mgi_response) == 0) {
        return(list(
          found = FALSE,
          source = "mgi",
          message = "MGI API returned empty response"
        ))
      }

      # Try to extract marker information
      # Different MGI endpoints have different structures
      marker_id <- NULL
      mouse_symbol <- NULL
      marker_name <- NULL

      # Case 1: Response is a list of markers
      if (is.list(mgi_response) && length(mgi_response) > 0) {
        marker <- mgi_response[[1]]
        marker_id <- marker$mgiId %||% marker$accessionId %||% marker$primaryId
        mouse_symbol <- marker$symbol %||% marker$markerSymbol
        marker_name <- marker$name %||% marker$markerName
      }

      # If we couldn't extract marker ID, try fallback approach
      if (is.null(marker_id)) {
        # Fallback: Try the disease portal phenotype API
        fallback_url <- paste0(
          "http://www.informatics.jax.org/diseasePortal/phenoByGene/",
          gene_symbol
        )

        fallback_response <- make_external_request(
          url = fallback_url,
          api_name = "mgi",
          throttle_config = EXTERNAL_API_THROTTLE$mgi
        )

        # If fallback also fails, return not found
        if (isTRUE(fallback_response$error) ||
            isTRUE(fallback_response$found == FALSE) ||
            is.null(fallback_response)) {
          return(list(
            found = FALSE,
            source = "mgi",
            message = "MGI API returned unexpected format"
          ))
        }

        # Try to extract from fallback response
        marker_id <- fallback_response$mgiId %||%
                     fallback_response$geneId %||%
                     fallback_response$markerId
        mouse_symbol <- fallback_response$symbol %||%
                        fallback_response$geneSymbol
        marker_name <- fallback_response$name %||%
                       fallback_response$geneName
      }

      # If still no marker ID, return not found
      if (is.null(marker_id)) {
        return(list(
          found = FALSE,
          source = "mgi",
          message = "Could not extract MGI marker ID from API response"
        ))
      }

      # Extract phenotype data if available
      phenotype_count <- 0
      phenotypes <- list()

      # Try to extract phenotype annotations (structure varies by endpoint)
      if (!is.null(mgi_response$phenotypes)) {
        phenotypes <- mgi_response$phenotypes
        phenotype_count <- length(phenotypes)
      } else if (!is.null(mgi_response$annotations)) {
        phenotypes <- mgi_response$annotations
        phenotype_count <- length(phenotypes)
      } else if (!is.null(mgi_response$phenotype_annotations)) {
        phenotypes <- mgi_response$phenotype_annotations
        phenotype_count <- length(phenotypes)
      }

      # Return structured response
      return(list(
        source = "mgi",
        gene_symbol = gene_symbol,
        mgi_id = marker_id,
        mouse_symbol = mouse_symbol %||% gene_symbol,
        marker_name = marker_name,
        phenotype_count = phenotype_count,
        phenotypes = phenotypes,
        mgi_url = paste0("https://www.informatics.jax.org/marker/", marker_id)
      ))
    },
    error = function(e) {
      return(list(
        error = TRUE,
        source = "mgi",
        message = conditionMessage(e)
      ))
    }
  )
}


#' Memoised version of fetch_mgi_phenotypes with 14-day cache
#'
#' @description
#' Cached wrapper around fetch_mgi_phenotypes using cache_stable
#' (14-day TTL). MGI phenotype data changes moderately as new annotations
#' are added.
#'
#' @param gene_symbol Character string, HGNC gene symbol
#'
#' @return Same as fetch_mgi_phenotypes
#'
#' @seealso fetch_mgi_phenotypes
#'
#' @export
fetch_mgi_phenotypes_mem <- memoise::memoise(
  fetch_mgi_phenotypes,
  cache = cache_stable
)
