# api/functions/external-proxy-ensembl.R
#### Ensembl REST API proxy functions for gene structure data

require(httr2)   # HTTP client
require(jsonlite) # JSON parsing


#' Fetch gene structure from Ensembl
#'
#' @description
#' Queries Ensembl REST API for gene structure data including chromosomal location,
#' strand, biotype, and canonical transcript with exon coordinates. Performs two-step
#' lookup: (1) gene symbol -> Ensembl gene ID, (2) gene ID -> full gene structure.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1", "TP53")
#'
#' @return List with gene structure data or error information:
#' \describe{
#'   \item{Success}{list(source = "ensembl", gene_symbol, gene_id, chromosome,
#'     start, end, strand, canonical_transcript = list(...))}
#'   \item{Gene not found}{list(found = FALSE, source = "ensembl")}
#'   \item{Invalid symbol}{list(error = TRUE, source = "ensembl", message = "Invalid gene symbol")}
#'   \item{Error}{list(error = TRUE, source = "ensembl", message = <details>)}
#' }
#'
#' @details
#' Gene-level fields returned:
#' - gene_id: Ensembl gene ID (ENSG...)
#' - chromosome: Chromosome name (seq_region_name)
#' - start, end: Genomic coordinates (GRCh38)
#' - strand: 1 (forward) or -1 (reverse)
#'
#' Canonical transcript fields:
#' - transcript_id: Ensembl transcript ID (ENST...)
#' - start, end: Transcript coordinates
#' - biotype: Transcript biotype (protein_coding, etc.)
#' - exons: Array of exon objects, each with:
#'   - id: Exon ID (ENSE...)
#'   - start, end: Exon coordinates
#'
#' Uses rate limiting (15 req/sec documented), retry with exponential backoff, and 30s timeout.
#' Cached with 14-day TTL via memoised wrapper (fetch_ensembl_gene_structure_mem).
#'
#' @examples
#' \dontrun{
#'   result <- fetch_ensembl_gene_structure("BRCA1")
#'   if (!result$error && result$found) {
#'     print(paste("Gene:", result$gene_id, "on", result$chromosome))
#'     print(paste("Exons:", length(result$canonical_transcript$exons)))
#'   }
#' }
#'
#' @export
fetch_ensembl_gene_structure <- function(gene_symbol) {
  # Validate gene symbol format
  if (!validate_gene_symbol(gene_symbol)) {
    return(list(
      error = TRUE,
      source = "ensembl",
      message = "Invalid gene symbol"
    ))
  }

  tryCatch(
    {
      # Step 1: Look up Ensembl gene ID by symbol
      xrefs_url <- paste0(
        "https://rest.ensembl.org/xrefs/symbol/homo_sapiens/",
        gene_symbol,
        "?content-type=application/json"
      )

      xrefs_result <- make_external_request(
        url = xrefs_url,
        api_name = "ensembl",
        throttle_config = EXTERNAL_API_THROTTLE$ensembl
      )

      # Handle errors from make_external_request
      if (!is.null(xrefs_result$error) && xrefs_result$error) {
        return(xrefs_result)
      }

      if (!is.null(xrefs_result$found) && !xrefs_result$found) {
        return(list(found = FALSE, source = "ensembl"))
      }

      # Check if results exist (xrefs_result is an array)
      if (is.null(xrefs_result) || length(xrefs_result) == 0) {
        return(list(found = FALSE, source = "ensembl"))
      }

      # Find the gene entry (type == "gene")
      gene_id <- NULL
      for (xref in xrefs_result) {
        if (!is.null(xref$type) && xref$type == "gene") {
          gene_id <- xref$id
          break
        }
      }

      if (is.null(gene_id)) {
        return(list(found = FALSE, source = "ensembl"))
      }

      # Step 2: Fetch gene structure with lookup endpoint (expand=1 to get transcripts)
      lookup_url <- paste0(
        "https://rest.ensembl.org/lookup/id/",
        gene_id,
        "?content-type=application/json;expand=1"
      )

      lookup_result <- make_external_request(
        url = lookup_url,
        api_name = "ensembl",
        throttle_config = EXTERNAL_API_THROTTLE$ensembl
      )

      # Handle errors
      if (!is.null(lookup_result$error) && lookup_result$error) {
        return(lookup_result)
      }

      if (!is.null(lookup_result$found) && !lookup_result$found) {
        return(list(found = FALSE, source = "ensembl"))
      }

      # Extract gene-level data
      gene_data <- lookup_result
      chromosome <- gene_data$seq_region_name
      gene_start <- gene_data$start
      gene_end <- gene_data$end
      strand <- gene_data$strand
      biotype <- gene_data$biotype

      # Find canonical transcript (is_canonical = 1)
      canonical_transcript <- NULL
      if (!is.null(gene_data$Transcript) && length(gene_data$Transcript) > 0) {
        for (transcript in gene_data$Transcript) {
          if (!is.null(transcript$is_canonical) && transcript$is_canonical == 1) {
            # Extract exons from canonical transcript
            exons_list <- list()
            if (!is.null(transcript$Exon) && length(transcript$Exon) > 0) {
              for (exon in transcript$Exon) {
                exons_list[[length(exons_list) + 1]] <- list(
                  id = exon$id,
                  start = exon$start,
                  end = exon$end
                )
              }
            }

            canonical_transcript <- list(
              transcript_id = transcript$id,
              start = transcript$start,
              end = transcript$end,
              biotype = transcript$biotype,
              exons = exons_list
            )
            break
          }
        }
      }

      # If no canonical transcript found, return error
      if (is.null(canonical_transcript)) {
        return(list(
          error = TRUE,
          source = "ensembl",
          message = "No canonical transcript found for gene"
        ))
      }

      # Return structured result
      return(list(
        source = "ensembl",
        gene_symbol = gene_symbol,
        gene_id = gene_id,
        chromosome = chromosome,
        start = gene_start,
        end = gene_end,
        strand = strand,
        canonical_transcript = canonical_transcript
      ))
    },
    error = function(e) {
      # Catch network errors, timeouts, JSON parsing failures
      return(list(
        error = TRUE,
        source = "ensembl",
        message = conditionMessage(e)
      ))
    }
  )
}


#### Memoised wrapper with stable cache

#' Memoised version of fetch_ensembl_gene_structure with 14-day cache
#'
#' @description
#' Cached version of fetch_ensembl_gene_structure using cache_stable backend.
#' Gene structure annotations are moderately stable, so 14-day TTL balances
#' freshness with performance.
#'
#' @inheritParams fetch_ensembl_gene_structure
#' @return Same as fetch_ensembl_gene_structure
#'
#' @export
fetch_ensembl_gene_structure_mem <- memoise::memoise(
  fetch_ensembl_gene_structure,
  cache = cache_stable
)
