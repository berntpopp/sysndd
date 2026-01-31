# api/functions/external-proxy-gnomad.R
#### gnomAD GraphQL proxy functions for constraint scores and ClinVar variants

require(httr2)   # HTTP client for GraphQL queries
require(jsonlite) # JSON parsing


#' Fetch gnomAD constraint scores for a gene
#'
#' @description
#' Queries gnomAD v4 GraphQL API for gene-level constraint metrics including
#' pLI (probability of loss-of-function intolerance), LOEUF (loss-of-function
#' observed/expected upper bound fraction), and missense/synonymous Z-scores.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1", "TP53")
#'
#' @return List with constraint data or error information:
#' \describe{
#'   \item{Success}{list(source = "gnomad", gene_symbol, gene_id, constraints = list(...))}
#'   \item{Gene not found}{list(found = FALSE, source = "gnomad")}
#'   \item{Invalid symbol}{list(error = TRUE, source = "gnomad", message = "Invalid gene symbol")}
#'   \item{Error}{list(error = TRUE, source = "gnomad", message = <details>)}
#' }
#'
#' @details
#' Constraint fields returned (when available):
#' - pLI: Probability of loss-of-function intolerance (0-1, higher = more constrained)
#' - oe_lof, oe_lof_lower, oe_lof_upper: Observed/expected LoF ratio with confidence interval
#' - oe_mis, oe_mis_lower, oe_mis_upper: Observed/expected missense ratio with CI
#' - oe_syn, oe_syn_lower, oe_syn_upper: Observed/expected synonymous ratio with CI
#' - exp_lof, obs_lof: Expected and observed LoF variant counts
#' - exp_mis, obs_mis: Expected and observed missense variant counts
#' - exp_syn, obs_syn: Expected and observed synonymous variant counts
#' - lof_z, mis_z, syn_z: Z-scores for LoF, missense, and synonymous variants
#'
#' Uses rate limiting (10 req/min), retry with exponential backoff, and 30s timeout.
#' Cached with 30-day TTL via memoised wrapper (fetch_gnomad_constraints_mem).
#'
#' @examples
#' \dontrun{
#'   result <- fetch_gnomad_constraints("BRCA1")
#'   if (!result$error && result$found) {
#'     print(result$constraints$pLI)
#'   }
#' }
#'
#' @export
fetch_gnomad_constraints <- function(gene_symbol) {
  # Validate gene symbol format (prevents GraphQL injection)
  if (!validate_gene_symbol(gene_symbol)) {
    return(list(
      error = TRUE,
      source = "gnomad",
      message = "Invalid gene symbol"
    ))
  }

  tryCatch(
    {
      # GraphQL query for gene-level constraint metrics
      query_string <- "
        query GeneConstraint($symbol: String!) {
          gene(gene_symbol: $symbol, reference_genome: GRCh38) {
            gene_id
            symbol
            gnomad_constraint {
              pLI
              oe_lof
              oe_lof_lower
              oe_lof_upper
              oe_mis
              oe_mis_lower
              oe_mis_upper
              oe_syn
              oe_syn_lower
              oe_syn_upper
              exp_lof
              obs_lof
              exp_mis
              obs_mis
              exp_syn
              obs_syn
              lof_z
              mis_z
              syn_z
            }
          }
        }
      "

      # Build GraphQL POST request with httr2
      req <- request("https://gnomad.broadinstitute.org/api") %>%
        req_method("POST") %>%
        req_body_json(list(
          query = query_string,
          variables = list(symbol = gene_symbol)
        )) %>%
        req_throttle(
          rate = EXTERNAL_API_THROTTLE$gnomad$capacity / EXTERNAL_API_THROTTLE$gnomad$fill_time_s
        ) %>%
        req_retry(
          max_tries = 3,
          max_seconds = 120,
          backoff = ~ 2^.x,
          is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
        ) %>%
        req_timeout(30) %>%
        req_error(is_error = ~FALSE)  # Handle errors manually

      # Perform request
      response <- req_perform(req)

      # Handle non-200 responses
      if (resp_status(response) != 200) {
        return(list(
          error = TRUE,
          status = resp_status(response),
          source = "gnomad",
          message = paste("gnomAD API returned HTTP", resp_status(response))
        ))
      }

      # Parse JSON response
      response_data <- resp_body_json(response)

      # Check if gene was found (data$gene is NULL if not found)
      if (is.null(response_data$data$gene)) {
        return(list(found = FALSE, source = "gnomad"))
      }

      # Extract constraint data
      gene_data <- response_data$data$gene
      constraints <- gene_data$gnomad_constraint

      # Return structured result
      return(list(
        source = "gnomad",
        gene_symbol = gene_data$symbol,
        gene_id = gene_data$gene_id,
        constraints = constraints
      ))
    },
    error = function(e) {
      # Catch network errors, timeouts, JSON parsing failures
      return(list(
        error = TRUE,
        source = "gnomad",
        message = conditionMessage(e)
      ))
    }
  )
}


#' Fetch ClinVar variants for a gene from gnomAD
#'
#' @description
#' Queries gnomAD v4 GraphQL API for ClinVar variants associated with a gene.
#' Returns clinical significance, HGVS notation, review status, and whether
#' the variant is present in gnomAD population data.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1", "TP53")
#'
#' @return List with ClinVar variant data or error information:
#' \describe{
#'   \item{Success}{list(source = "gnomad_clinvar", gene_symbol, gene_id, variants = [...], variant_count)}
#'   \item{Gene not found}{list(found = FALSE, source = "gnomad")}
#'   \item{Invalid symbol}{list(error = TRUE, source = "gnomad", message = "Invalid gene symbol")}
#'   \item{Error}{list(error = TRUE, source = "gnomad", message = <details>)}
#' }
#'
#' @details
#' Each variant includes:
#' - clinical_significance: ClinVar classification (Pathogenic, Benign, VUS, etc.)
#' - clinvar_variation_id: ClinVar variant ID
#' - gold_stars: Review status confidence (0-4 stars)
#' - hgvsc: HGVS coding sequence notation (c. notation)
#' - hgvsp: HGVS protein sequence notation (p. notation)
#' - in_gnomad: Boolean, whether variant is observed in gnomAD population data
#' - major_consequence: Most severe consequence (missense, frameshift, etc.)
#' - pos: Genomic position (GRCh38)
#' - review_status: ClinVar review status text
#' - variant_id: gnomAD variant identifier (chrom-pos-ref-alt)
#'
#' Uses rate limiting (10 req/min), retry with exponential backoff, and 30s timeout.
#' Cached with 7-day TTL via memoised wrapper (fetch_gnomad_clinvar_variants_mem).
#'
#' @examples
#' \dontrun{
#'   result <- fetch_gnomad_clinvar_variants("BRCA1")
#'   if (!result$error && result$found) {
#'     print(paste("Found", result$variant_count, "ClinVar variants"))
#'   }
#' }
#'
#' @export
fetch_gnomad_clinvar_variants <- function(gene_symbol) {
  # Validate gene symbol format
  if (!validate_gene_symbol(gene_symbol)) {
    return(list(
      error = TRUE,
      source = "gnomad",
      message = "Invalid gene symbol"
    ))
  }

  tryCatch(
    {
      # GraphQL query for ClinVar variants associated with gene
      query_string <- "
        query GeneClinvar($symbol: String!) {
          gene(gene_symbol: $symbol, reference_genome: GRCh38) {
            gene_id
            symbol
            clinvar_variants {
              clinical_significance
              clinvar_variation_id
              gold_stars
              hgvsc
              hgvsp
              in_gnomad
              major_consequence
              pos
              review_status
              variant_id
            }
          }
        }
      "

      # Build GraphQL POST request with httr2
      req <- request("https://gnomad.broadinstitute.org/api") %>%
        req_method("POST") %>%
        req_body_json(list(
          query = query_string,
          variables = list(symbol = gene_symbol)
        )) %>%
        req_throttle(
          rate = EXTERNAL_API_THROTTLE$gnomad$capacity / EXTERNAL_API_THROTTLE$gnomad$fill_time_s
        ) %>%
        req_retry(
          max_tries = 3,
          max_seconds = 120,
          backoff = ~ 2^.x,
          is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
        ) %>%
        req_timeout(30) %>%
        req_error(is_error = ~FALSE)  # Handle errors manually

      # Perform request
      response <- req_perform(req)

      # Handle non-200 responses
      if (resp_status(response) != 200) {
        return(list(
          error = TRUE,
          status = resp_status(response),
          source = "gnomad",
          message = paste("gnomAD API returned HTTP", resp_status(response))
        ))
      }

      # Parse JSON response
      response_data <- resp_body_json(response)

      # Check if gene was found
      if (is.null(response_data$data$gene)) {
        return(list(found = FALSE, source = "gnomad"))
      }

      # Extract ClinVar variant data
      gene_data <- response_data$data$gene
      variants <- gene_data$clinvar_variants

      # Return structured result
      return(list(
        source = "gnomad_clinvar",
        gene_symbol = gene_data$symbol,
        gene_id = gene_data$gene_id,
        variants = variants,
        variant_count = length(variants)
      ))
    },
    error = function(e) {
      # Catch network errors, timeouts, JSON parsing failures
      return(list(
        error = TRUE,
        source = "gnomad",
        message = conditionMessage(e)
      ))
    }
  )
}


#### Memoised wrappers with per-source caching

#' Memoised version of fetch_gnomad_constraints with 30-day cache
#'
#' @description
#' Cached version of fetch_gnomad_constraints using cache_static backend.
#' Constraint scores are static data that rarely changes, so 30-day TTL is appropriate.
#'
#' @inheritParams fetch_gnomad_constraints
#' @return Same as fetch_gnomad_constraints
#'
#' @export
fetch_gnomad_constraints_mem <- memoise::memoise(
  fetch_gnomad_constraints,
  cache = cache_static
)


#' Memoised version of fetch_gnomad_clinvar_variants with 7-day cache
#'
#' @description
#' Cached version of fetch_gnomad_clinvar_variants using cache_dynamic backend.
#' ClinVar data is updated regularly, so 7-day TTL balances freshness with performance.
#'
#' @inheritParams fetch_gnomad_clinvar_variants
#' @return Same as fetch_gnomad_clinvar_variants
#'
#' @export
fetch_gnomad_clinvar_variants_mem <- memoise::memoise(
  fetch_gnomad_clinvar_variants,
  cache = cache_dynamic
)
