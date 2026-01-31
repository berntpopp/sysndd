# functions/external-proxy-alphafold.R
#### AlphaFold structure prediction proxy functions

#' Fetch AlphaFold 3D structure metadata for a gene symbol
#'
#' @description
#' Retrieves AlphaFold 3D structure prediction metadata and file URLs for a
#' given gene symbol. Performs two-step lookup: (1) UniProt accession from
#' gene symbol, (2) AlphaFold prediction from UniProt accession.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1")
#'
#' @return List containing:
#' \describe{
#'   \item{Success}{source, gene_symbol, uniprot_accession, entry_id, pdb_url,
#'                  cif_url, bcif_url, pae_image_url, model_url,
#'                  model_created_date, latest_version}
#'   \item{Not found}{found = FALSE, source = "alphafold"}
#'   \item{Error}{error = TRUE, source = "alphafold", message = <details>}
#' }
#'
#' @details
#' Step 1: Queries UniProt REST API to find canonical accession for gene symbol
#' in human (organism_id:9606, reviewed:true).
#'
#' Step 2: Queries AlphaFold EBI API for structure prediction metadata using
#' the UniProt accession. Returns PDB/CIF/BCIF URLs for structure files plus
#' PAE (Predicted Aligned Error) image URL.
#'
#' Uses memoised caching with 30-day TTL (cache_static) since structure
#' predictions rarely change.
#'
#' @examples
#' \dontrun{
#'   result <- fetch_alphafold_structure("BRCA1")
#'   if (!isTRUE(result$found == FALSE) && !isTRUE(result$error)) {
#'     print(result$pdb_url)
#'   }
#' }
#'
#' @export
fetch_alphafold_structure <- function(gene_symbol) {
  tryCatch(
    {
      # Validate gene symbol format
      if (!validate_gene_symbol(gene_symbol)) {
        return(list(
          error = TRUE,
          source = "alphafold",
          message = paste("Invalid gene symbol format:", gene_symbol)
        ))
      }

      # Step 1: Look up UniProt accession for the gene symbol
      uniprot_url <- paste0(
        "https://rest.uniprot.org/uniprotkb/search",
        "?query=gene_exact:", gene_symbol,
        "+AND+organism_id:9606",
        "+AND+reviewed:true",
        "&fields=accession",
        "&format=json",
        "&size=1"
      )

      uniprot_response <- make_external_request(
        url = uniprot_url,
        api_name = "alphafold",  # For error reporting
        throttle_config = EXTERNAL_API_THROTTLE$uniprot  # Query UniProt API
      )

      # Handle errors from UniProt query
      if (isTRUE(uniprot_response$error)) {
        return(list(
          error = TRUE,
          source = "alphafold",
          message = paste("UniProt query failed:", uniprot_response$message)
        ))
      }

      # Handle not found (no UniProt accession for gene)
      if (isTRUE(uniprot_response$found == FALSE)) {
        return(list(found = FALSE, source = "alphafold"))
      }

      # Extract UniProt accession
      if (is.null(uniprot_response$results) ||
          length(uniprot_response$results) == 0 ||
          is.null(uniprot_response$results[[1]]$primaryAccession)) {
        return(list(found = FALSE, source = "alphafold"))
      }

      accession <- uniprot_response$results[[1]]$primaryAccession

      # Step 2: Fetch AlphaFold prediction metadata
      alphafold_url <- paste0(
        "https://alphafold.ebi.ac.uk/api/prediction/",
        accession
      )

      alphafold_response <- make_external_request(
        url = alphafold_url,
        api_name = "alphafold",
        throttle_config = EXTERNAL_API_THROTTLE$alphafold
      )

      # Handle errors from AlphaFold query
      if (isTRUE(alphafold_response$error)) {
        return(list(
          error = TRUE,
          source = "alphafold",
          message = paste("AlphaFold query failed:", alphafold_response$message)
        ))
      }

      # Handle not found (no AlphaFold structure for accession)
      if (isTRUE(alphafold_response$found == FALSE)) {
        return(list(found = FALSE, source = "alphafold"))
      }

      # AlphaFold API returns an array; take first element
      structure_data <- if (is.list(alphafold_response) && length(alphafold_response) > 0) {
        alphafold_response[[1]]
      } else {
        alphafold_response
      }

      # Extract structure metadata
      return(list(
        source = "alphafold",
        gene_symbol = gene_symbol,
        uniprot_accession = accession,
        entry_id = structure_data$entryId,
        pdb_url = structure_data$pdbUrl,
        cif_url = structure_data$cifUrl,
        bcif_url = structure_data$bcifUrl,
        pae_image_url = structure_data$paeImageUrl,
        model_url = structure_data$cifUrl,  # Use CIF URL for Mol* viewer
        model_created_date = structure_data$modelCreatedDate,
        latest_version = structure_data$latestVersion
      ))
    },
    error = function(e) {
      return(list(
        error = TRUE,
        source = "alphafold",
        message = conditionMessage(e)
      ))
    }
  )
}


#' Memoised version of fetch_alphafold_structure with 30-day cache
#'
#' @description
#' Cached wrapper around fetch_alphafold_structure using cache_static
#' (30-day TTL). AlphaFold structure predictions are static data that
#' rarely changes.
#'
#' @param gene_symbol Character string, HGNC gene symbol
#'
#' @return Same as fetch_alphafold_structure
#'
#' @seealso fetch_alphafold_structure
#'
#' @export
fetch_alphafold_structure_mem <- memoise::memoise(
  fetch_alphafold_structure,
  cache = cache_static
)
