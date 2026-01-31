# api/functions/external-proxy-uniprot.R
#### UniProt REST API proxy functions for protein domain data

require(httr2)   # HTTP client
require(jsonlite) # JSON parsing


#' Fetch protein domain features from UniProt
#'
#' @description
#' Queries UniProt REST API for protein domain information by gene symbol.
#' Performs two-step lookup: (1) gene symbol -> UniProt accession, (2) accession -> features.
#' Returns domain coordinates, types, and descriptions for visualization.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1", "TP53")
#'
#' @return List with protein domain data or error information:
#' \describe{
#'   \item{Success}{list(source = "uniprot", gene_symbol, accession, protein_name, protein_length, domains = [...])}
#'   \item{Gene not found}{list(found = FALSE, source = "uniprot")}
#'   \item{Invalid symbol}{list(error = TRUE, source = "uniprot", message = "Invalid gene symbol")}
#'   \item{Error}{list(error = TRUE, source = "uniprot", message = <details>)}
#' }
#'
#' @details
#' Domain feature types included:
#' - DOMAIN: Protein domain (e.g., kinase domain, DNA-binding domain)
#' - REGION: Region of interest
#' - MOTIF: Short sequence motif
#' - REPEAT: Repeated sequence motif
#' - ZN_FING: Zinc finger region
#' - DNA_BIND: DNA-binding region
#' - BINDING: Binding site
#' - ACT_SITE: Active site
#' - METAL: Metal ion-binding site
#' - SITE: Site of interest
#' - DISULFID: Disulfide bond
#' - CROSSLNK: Cross-link
#' - CARBOHYD: Glycosylation site
#' - MOD_RES: Modified residue
#' - LIPID: Lipidation site
#' - SIGNAL: Signal peptide
#' - TRANSIT: Transit peptide
#' - CHAIN: Polypeptide chain
#'
#' Each feature includes: type, description, begin (start position), end (end position).
#'
#' Uses rate limiting (100 req/sec), retry with exponential backoff, and 30s timeout.
#' Cached with 14-day TTL via memoised wrapper (fetch_uniprot_domains_mem).
#'
#' @examples
#' \dontrun{
#'   result <- fetch_uniprot_domains("BRCA1")
#'   if (!result$error && result$found) {
#'     print(paste("Protein length:", result$protein_length, "aa"))
#'     print(paste("Found", length(result$domains), "features"))
#'   }
#' }
#'
#' @export
fetch_uniprot_domains <- function(gene_symbol) {
  # Validate gene symbol format
  if (!validate_gene_symbol(gene_symbol)) {
    return(list(
      error = TRUE,
      source = "uniprot",
      message = "Invalid gene symbol"
    ))
  }

  tryCatch(
    {
      # Step 1: Look up UniProt accession by gene symbol
      # Query: reviewed (Swiss-Prot) human proteins matching exact gene name
      search_url <- paste0(
        "https://rest.uniprot.org/uniprotkb/search",
        "?query=gene_exact:", gene_symbol,
        "+AND+organism_id:9606",
        "+AND+reviewed:true",
        "&fields=accession,protein_name,sequence",
        "&format=json",
        "&size=1"
      )

      search_result <- make_external_request(
        url = search_url,
        api_name = "uniprot",
        throttle_config = EXTERNAL_API_THROTTLE$uniprot
      )

      # Handle errors from make_external_request
      if (!is.null(search_result$error) && search_result$error) {
        return(search_result)
      }

      if (!is.null(search_result$found) && !search_result$found) {
        return(list(found = FALSE, source = "uniprot"))
      }

      # Check if results exist
      if (is.null(search_result$results) || length(search_result$results) == 0) {
        return(list(found = FALSE, source = "uniprot"))
      }

      # Extract first result (most relevant reviewed entry)
      entry <- search_result$results[[1]]
      accession <- entry$primaryAccession
      protein_name <- entry$proteinDescription$recommendedName$fullName$value
      sequence <- entry$sequence$value
      protein_length <- nchar(sequence)

      # Step 2: Fetch protein features/domains using the accession
      features_url <- paste0(
        "https://www.ebi.ac.uk/proteins/api/features/",
        accession
      )

      # Build httr2 request with Accept header for JSON
      features_req <- request(features_url) %>%
        req_headers(Accept = "application/json") %>%
        req_throttle(
          rate = EXTERNAL_API_THROTTLE$uniprot$capacity / EXTERNAL_API_THROTTLE$uniprot$fill_time_s
        ) %>%
        req_retry(
          max_tries = 5,
          max_seconds = 120,
          backoff = ~ 2^.x,
          is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
        ) %>%
        req_timeout(30) %>%
        req_error(is_error = ~FALSE)

      # Perform request
      features_response <- req_perform(features_req)

      # Handle non-200 responses
      if (resp_status(features_response) != 200) {
        return(list(
          error = TRUE,
          status = resp_status(features_response),
          source = "uniprot",
          message = paste("UniProt features API returned HTTP", resp_status(features_response))
        ))
      }

      # Parse features response
      features_data <- resp_body_json(features_response)

      # Filter to domain-relevant feature types
      domain_types <- c(
        "DOMAIN", "REGION", "MOTIF", "REPEAT", "ZN_FING", "DNA_BIND",
        "BINDING", "ACT_SITE", "METAL", "SITE", "DISULFID", "CROSSLNK",
        "CARBOHYD", "MOD_RES", "LIPID", "SIGNAL", "TRANSIT", "CHAIN"
      )

      # Extract features array and filter by type
      all_features <- features_data$features
      filtered_features <- list()

      if (!is.null(all_features) && length(all_features) > 0) {
        for (feature in all_features) {
          if (feature$type %in% domain_types) {
            filtered_features[[length(filtered_features) + 1]] <- list(
              type = feature$type,
              description = if (!is.null(feature$description)) feature$description else "",
              begin = feature$begin,
              end = feature$end
            )
          }
        }
      }

      # Return structured result
      return(list(
        source = "uniprot",
        gene_symbol = gene_symbol,
        accession = accession,
        protein_name = protein_name,
        protein_length = protein_length,
        domains = filtered_features
      ))
    },
    error = function(e) {
      # Catch network errors, timeouts, JSON parsing failures
      return(list(
        error = TRUE,
        source = "uniprot",
        message = conditionMessage(e)
      ))
    }
  )
}


#### Memoised wrapper with stable cache

#' Memoised version of fetch_uniprot_domains with 14-day cache
#'
#' @description
#' Cached version of fetch_uniprot_domains using cache_stable backend.
#' Protein domain annotations are moderately stable, so 14-day TTL balances
#' freshness with performance.
#'
#' @inheritParams fetch_uniprot_domains
#' @return Same as fetch_uniprot_domains
#'
#' @export
fetch_uniprot_domains_mem <- memoise::memoise(
  fetch_uniprot_domains,
  cache = cache_stable
)
