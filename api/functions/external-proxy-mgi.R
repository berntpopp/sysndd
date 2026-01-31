# functions/external-proxy-mgi.R
#### MGI (Mouse Genome Informatics) phenotype proxy functions via MouseMine API

# MouseMine API base URL (InterMine implementation for MGI data)
MOUSEMINE_BASE_URL <- "https://www.mousemine.org/mousemine/service"

#' Fetch MGI mouse phenotype data for a gene symbol via MouseMine API
#'
#' @description
#' Retrieves mouse phenotype data from Mouse Genome Informatics (MGI) via the
#' MouseMine InterMine API. Uses HGene_MPhenotype template to find mouse
#' phenotypes for a human gene symbol, then _Genotype_Phenotype template
#' to get zygosity breakdown.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1")
#'
#' @return List containing:
#' \describe{
#'   \item{Success}{source, gene_symbol, mgi_id, mouse_symbol, marker_name,
#'                  phenotype_count, phenotypes (with zygosity), mgi_url}
#'   \item{Not found}{found = FALSE, source = "mgi"}
#'   \item{Error}{error = TRUE, source = "mgi", message = <details>}
#' }
#'
#' @details
#' Uses MouseMine InterMine API which provides reliable JSON responses:
#' 1. HGene_MPhenotype template: Maps human gene to mouse ortholog phenotypes
#' 2. _Genotype_Phenotype template: Gets zygosity data for the mouse symbol
#'
#' Uses memoised caching with 14-day TTL (cache_stable) since phenotype
#' annotations change moderately.
#'
#' @examples
#' \dontrun{
#'   result <- fetch_mgi_phenotypes("SCN1A")
#'   if (!isTRUE(result$found == FALSE) && !isTRUE(result$error)) {
#'     print(result$phenotype_count)
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

      # Step 1: Query MouseMine HGene_MPhenotype template
      # This maps human gene symbol to mouse ortholog phenotypes
      phenotype_url <- paste0(MOUSEMINE_BASE_URL, "/template/results")

      phenotype_response <- httr2::request(phenotype_url) |>
        httr2::req_url_query(
          name = "HGene_MPhenotype",
          constraint1 = "Gene",
          op1 = "LOOKUP",
          value1 = gene_symbol,
          extra1 = "H. sapiens",
          format = "json",
          size = "10000"
        ) |>
        httr2::req_retry(
          max_tries = 3,
          backoff = ~ 2
        ) |>
        httr2::req_throttle(
          rate = EXTERNAL_API_THROTTLE$mgi$capacity / EXTERNAL_API_THROTTLE$mgi$fill_time_s,
          realm = "mousemine"
        ) |>
        httr2::req_timeout(30) |>
        httr2::req_perform()

      phenotype_data <- httr2::resp_body_json(phenotype_response)

      # Check if we got results
      results <- phenotype_data$results
      if (is.null(results) || length(results) == 0) {
        return(list(found = FALSE, source = "mgi"))
      }

      # Extract unique mouse symbol and MGI ID from first result
      # MouseMine HGene_MPhenotype response structure (R 1-indexed):
      # [1]: Human gene ID, [2]: Human symbol, [3]: Human organism
      # [4]: MGI ID, [5]: Mouse symbol, [6]: Mouse organism
      # [7]: MP ID (phenotype), [8]: Phenotype term
      first_result <- results[[1]]
      mgi_id <- first_result[[4]]
      mouse_symbol <- first_result[[5]]

      # Collect unique phenotypes from all results
      phenotype_map <- list()
      for (row in results) {
        mp_id <- row[[7]]  # MP ID (phenotype identifier)
        term <- row[[8]]   # Phenotype term name
        if (!is.null(mp_id) && !is.null(term)) {
          phenotype_map[[mp_id]] <- list(
            phenotype_id = mp_id,
            term = term,
            zygosity = NA_character_
          )
        }
      }

      # Step 2: Query for zygosity data using _Genotype_Phenotype template
      if (!is.null(mouse_symbol) && nchar(mouse_symbol) > 0) {
        zygosity_response <- tryCatch(
          {
            httr2::request(phenotype_url) |>
              httr2::req_url_query(
                name = "_Genotype_Phenotype",
                constraint1 = "OntologyAnnotation.subject.symbol",
                op1 = "CONTAINS",
                value1 = mouse_symbol,
                format = "json",
                size = "10000"
              ) |>
              httr2::req_retry(max_tries = 2, backoff = ~ 2) |>
              httr2::req_throttle(
                rate = EXTERNAL_API_THROTTLE$mgi$capacity / EXTERNAL_API_THROTTLE$mgi$fill_time_s,
                realm = "mousemine"
              ) |>
              httr2::req_timeout(30) |>
              httr2::req_perform() |>
              httr2::resp_body_json()
          },
          error = function(e) NULL
        )

        # Parse zygosity data if available
        if (!is.null(zygosity_response) && !is.null(zygosity_response$results)) {
          for (row in zygosity_response$results) {
            # _Genotype_Phenotype structure varies; extract zygosity info
            # Typically includes genotype zygosity state
            mp_id <- NULL
            zygosity <- NULL

            # Try to find MP ID and zygosity in row
            for (i in seq_along(row)) {
              val <- row[[i]]
              if (is.character(val)) {
                if (grepl("^MP:", val)) {
                  mp_id <- val
                } else if (val %in% c("homozygous", "heterozygous", "conditional",
                                       "hm", "ht", "cn")) {
                  zygosity <- switch(
                    val,
                    "hm" = "homozygous",
                    "ht" = "heterozygous",
                    "cn" = "conditional",
                    val
                  )
                }
              }
            }

            # Update phenotype with zygosity if found
            if (!is.null(mp_id) && !is.null(zygosity) &&
                !is.null(phenotype_map[[mp_id]])) {
              phenotype_map[[mp_id]]$zygosity <- zygosity
            }
          }
        }
      }

      # Convert phenotype map to list
      phenotypes <- unname(phenotype_map)
      phenotype_count <- length(phenotypes)

      # Build MGI marker URL (use MGI ID if available, otherwise search URL)
      mgi_url <- if (!is.null(mgi_id) && grepl("^MGI:", mgi_id)) {
        paste0("https://www.informatics.jax.org/marker/", mgi_id)
      } else {
        paste0("https://www.informatics.jax.org/searchtool/Search.do?query=",
               utils::URLencode(gene_symbol))
      }

      # Return structured response
      return(list(
        source = "mgi",
        gene_symbol = gene_symbol,
        mgi_id = mgi_id,
        mouse_symbol = mouse_symbol %||% gene_symbol,
        marker_name = NULL,  # Not provided by this template
        phenotype_count = phenotype_count,
        phenotypes = phenotypes,
        mgi_url = mgi_url
      ))
    },
    error = function(e) {
      # Check for specific HTTP errors
      msg <- conditionMessage(e)
      if (grepl("404|Not Found", msg, ignore.case = TRUE)) {
        return(list(found = FALSE, source = "mgi"))
      }
      return(list(
        error = TRUE,
        source = "mgi",
        message = paste("MouseMine query failed:", msg)
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
