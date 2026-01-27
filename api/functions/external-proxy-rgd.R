# functions/external-proxy-rgd.R
#### RGD (Rat Genome Database) phenotype proxy functions

#' Fetch RGD rat phenotype data for a gene symbol
#'
#' @description
#' Retrieves rat phenotype data from Rat Genome Database (RGD) for a given
#' gene symbol. Performs human-to-rat ortholog lookup and fetches phenotype
#' annotations. Implements defensive error handling for undocumented API
#' endpoints.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1")
#'
#' @return List containing:
#' \describe{
#'   \item{Success}{source, gene_symbol, rgd_id, rat_symbol, rat_name,
#'                  phenotype_count, phenotypes, rgd_url}
#'   \item{Not found}{found = FALSE, source = "rgd"}
#'   \item{API format error}{found = FALSE, source = "rgd", message = <details>}
#'   \item{Error}{error = TRUE, source = "rgd", message = <details>}
#' }
#'
#' @details
#' Step 1: Queries RGD REST API to find human gene by symbol, then finds rat
#' ortholog. If direct human lookup fails, tries direct rat gene search.
#'
#' Step 2: Fetches phenotype annotations for the rat gene RGD ID.
#'
#' RGD API endpoints are not well documented, so implementation is defensive:
#' returns `found = FALSE` rather than crashing on unexpected formats.
#'
#' Uses memoised caching with 14-day TTL (cache_stable) since phenotype
#' annotations change moderately.
#'
#' @examples
#' \dontrun{
#'   result <- fetch_rgd_phenotypes("BRCA1")
#'   if (!isTRUE(result$found == FALSE) && !isTRUE(result$error)) {
#'     print(result$rgd_url)
#'   }
#' }
#'
#' @export
fetch_rgd_phenotypes <- function(gene_symbol) {
  tryCatch(
    {
      # Validate gene symbol format
      if (!validate_gene_symbol(gene_symbol)) {
        return(list(
          error = TRUE,
          source = "rgd",
          message = paste("Invalid gene symbol format:", gene_symbol)
        ))
      }

      # Step 1: Try to find rat gene by direct search first (faster)
      rat_search_url <- paste0(
        "https://rest.rgd.mcw.edu/rgdws/genes/species/Rat/",
        gene_symbol
      )

      rat_response <- make_external_request(
        url = rat_search_url,
        api_name = "rgd",
        throttle_config = EXTERNAL_API_THROTTLE$rgd
      )

      rat_rgd_id <- NULL
      rat_symbol <- NULL
      rat_name <- NULL

      # Check if direct rat search succeeded
      if (!isTRUE(rat_response$error) &&
          !isTRUE(rat_response$found == FALSE) &&
          !is.null(rat_response)) {

        # Extract rat gene info
        # RGD API may return single object or array
        gene_data <- if (is.list(rat_response) && length(rat_response) > 0) {
          # If it's a list, take first element
          rat_response[[1]]
        } else {
          rat_response
        }

        rat_rgd_id <- gene_data$rgdId %||%
                      gene_data$RGD_ID %||%
                      gene_data$id
        rat_symbol <- gene_data$symbol %||%
                      gene_data$geneSymbol
        rat_name <- gene_data$name %||%
                    gene_data$geneName
      }

      # If direct rat search failed, try human ortholog lookup
      if (is.null(rat_rgd_id)) {
        # Query human gene first
        human_search_url <- paste0(
          "https://rest.rgd.mcw.edu/rgdws/genes/species/Human/",
          gene_symbol
        )

        human_response <- make_external_request(
          url = human_search_url,
          api_name = "rgd",
          throttle_config = EXTERNAL_API_THROTTLE$rgd
        )

        # Handle errors from human query
        if (isTRUE(human_response$error)) {
          return(list(
            error = TRUE,
            source = "rgd",
            message = paste("RGD human query failed:", human_response$message)
          ))
        }

        # Handle not found
        if (isTRUE(human_response$found == FALSE)) {
          return(list(found = FALSE, source = "rgd"))
        }

        # Extract human RGD ID
        human_gene <- if (is.list(human_response) && length(human_response) > 0) {
          human_response[[1]]
        } else {
          human_response
        }

        human_rgd_id <- human_gene$rgdId %||%
                        human_gene$RGD_ID %||%
                        human_gene$id

        if (is.null(human_rgd_id)) {
          return(list(
            found = FALSE,
            source = "rgd",
            message = "Could not extract human RGD ID from API response"
          ))
        }

        # Query rat ortholog for the human gene
        ortholog_url <- paste0(
          "https://rest.rgd.mcw.edu/rgdws/orthologs/gene/",
          human_rgd_id,
          "/Rat"
        )

        ortholog_response <- make_external_request(
          url = ortholog_url,
          api_name = "rgd",
          throttle_config = EXTERNAL_API_THROTTLE$rgd
        )

        # Handle errors from ortholog query
        if (isTRUE(ortholog_response$error)) {
          return(list(
            error = TRUE,
            source = "rgd",
            message = paste("RGD ortholog query failed:", ortholog_response$message)
          ))
        }

        # Handle not found (no rat ortholog)
        if (isTRUE(ortholog_response$found == FALSE) ||
            is.null(ortholog_response) ||
            length(ortholog_response) == 0) {
          return(list(found = FALSE, source = "rgd"))
        }

        # Extract rat ortholog info
        rat_ortholog <- if (is.list(ortholog_response) && length(ortholog_response) > 0) {
          ortholog_response[[1]]
        } else {
          ortholog_response
        }

        rat_rgd_id <- rat_ortholog$rgdId %||%
                      rat_ortholog$RGD_ID %||%
                      rat_ortholog$id
        rat_symbol <- rat_ortholog$symbol %||%
                      rat_ortholog$geneSymbol
        rat_name <- rat_ortholog$name %||%
                    rat_ortholog$geneName
      }

      # If still no rat RGD ID, return not found
      if (is.null(rat_rgd_id)) {
        return(list(
          found = FALSE,
          source = "rgd",
          message = "Could not extract rat RGD ID from API response"
        ))
      }

      # Step 2: Fetch phenotype annotations for the rat gene
      phenotype_url <- paste0(
        "https://rest.rgd.mcw.edu/rgdws/annotations/rgdId/",
        rat_rgd_id,
        "/phenotype"
      )

      phenotype_response <- make_external_request(
        url = phenotype_url,
        api_name = "rgd",
        throttle_config = EXTERNAL_API_THROTTLE$rgd
      )

      # Extract phenotype data (optional - may not exist for all genes)
      phenotype_count <- 0
      phenotypes <- list()

      if (!isTRUE(phenotype_response$error) &&
          !isTRUE(phenotype_response$found == FALSE) &&
          !is.null(phenotype_response)) {
        phenotypes <- phenotype_response
        phenotype_count <- length(phenotypes)
      }

      # Return structured response
      return(list(
        source = "rgd",
        gene_symbol = gene_symbol,
        rgd_id = rat_rgd_id,
        rat_symbol = rat_symbol %||% gene_symbol,
        rat_name = rat_name,
        phenotype_count = phenotype_count,
        phenotypes = phenotypes,
        rgd_url = paste0("https://rgd.mcw.edu/rgdweb/report/gene/main.html?id=", rat_rgd_id)
      ))
    },
    error = function(e) {
      return(list(
        error = TRUE,
        source = "rgd",
        message = conditionMessage(e)
      ))
    }
  )
}


#' Memoised version of fetch_rgd_phenotypes with 14-day cache
#'
#' @description
#' Cached wrapper around fetch_rgd_phenotypes using cache_stable
#' (14-day TTL). RGD phenotype data changes moderately as new annotations
#' are added.
#'
#' @param gene_symbol Character string, HGNC gene symbol
#'
#' @return Same as fetch_rgd_phenotypes
#'
#' @seealso fetch_rgd_phenotypes
#'
#' @export
fetch_rgd_phenotypes_mem <- memoise::memoise(
  fetch_rgd_phenotypes,
  cache = cache_stable
)
