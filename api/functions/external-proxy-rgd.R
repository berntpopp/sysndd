# functions/external-proxy-rgd.R
#### RGD (Rat Genome Database) phenotype proxy functions

#' Fetch RGD rat phenotype data by RGD ID
#'
#' @description
#' Retrieves rat phenotype data from Rat Genome Database (RGD) using
#' the rat gene RGD ID directly. This is the preferred method since
#' RGD gene lookup APIs are unreliable.
#'
#' @param rgd_id Character string, RGD ID (e.g., "RGD:69364" or "69364")
#' @param gene_symbol Character string, HGNC gene symbol for response context
#'
#' @return List containing:
#' \describe{
#'   \item{Success}{source, gene_symbol, rgd_id, rat_symbol, phenotype_count,
#'                  phenotypes, rgd_url}
#'   \item{Not found}{found = FALSE, source = "rgd"}
#'   \item{Error}{error = TRUE, source = "rgd", message = <details>}
#' }
#'
#' @details
#' Uses the RGD annotations endpoint which is reliable, unlike the gene
#' lookup endpoints which have server bugs. Fetches mammalian phenotype (MP)
#' ontology annotations for the given RGD ID.
#'
#' @examples
#' \dontrun{
#'   result <- fetch_rgd_phenotypes_by_id("69364", "SCN1A")
#'   if (!isTRUE(result$found == FALSE) && !isTRUE(result$error)) {
#'     print(result$phenotype_count)
#'   }
#' }
#'
#' @export
fetch_rgd_phenotypes_by_id <- function(rgd_id, gene_symbol = NULL) {
  tryCatch(
    {
      # Normalize RGD ID (remove "RGD:" prefix if present)
      clean_rgd_id <- gsub("^RGD:", "", rgd_id)

      # Validate RGD ID is numeric
      if (!grepl("^[0-9]+$", clean_rgd_id)) {
        return(list(
          error = TRUE,
          source = "rgd",
          message = paste("Invalid RGD ID format:", rgd_id)
        ))
      }

      # Fetch mammalian phenotype (MP) annotations for the RGD ID
      phenotype_url <- paste0(
        "https://rest.rgd.mcw.edu/rgdws/annotations/rgdId/",
        clean_rgd_id,
        "/MP"
      )

      phenotype_response <- httr2::request(phenotype_url) |>
        httr2::req_retry(
          max_tries = 3,
          backoff = ~ 2
        ) |>
        httr2::req_throttle(
          rate = EXTERNAL_API_THROTTLE$rgd$capacity / EXTERNAL_API_THROTTLE$rgd$fill_time_s,
          realm = "rgd"
        ) |>
        httr2::req_timeout(30) |>
        httr2::req_perform()

      phenotype_data <- httr2::resp_body_json(phenotype_response)

      # Extract phenotypes
      phenotype_count <- 0
      phenotypes <- list()
      rat_symbol <- NULL

      if (!is.null(phenotype_data) && length(phenotype_data) > 0) {
        # Extract unique phenotypes
        phenotype_map <- list()
        for (annotation in phenotype_data) {
          term_acc <- annotation$termAcc
          if (!is.null(term_acc) && !is.null(annotation$term)) {
            phenotype_map[[term_acc]] <- list(
              term = annotation$term,
              annotation_type = "MP"
            )
          }
          # Extract rat symbol from first annotation
          if (is.null(rat_symbol) && !is.null(annotation$objectSymbol)) {
            rat_symbol <- annotation$objectSymbol
          }
        }
        phenotypes <- unname(phenotype_map)
        phenotype_count <- length(phenotypes)
      }

      # Return structured response
      return(list(
        source = "rgd",
        gene_symbol = gene_symbol %||% rat_symbol %||% clean_rgd_id,
        rgd_id = paste0("RGD:", clean_rgd_id),
        rat_symbol = rat_symbol,
        rat_name = NULL,  # Not available from annotations endpoint
        phenotype_count = phenotype_count,
        phenotypes = phenotypes,
        rgd_url = paste0("https://rgd.mcw.edu/rgdweb/report/gene/main.html?id=", clean_rgd_id)
      ))
    },
    error = function(e) {
      msg <- conditionMessage(e)
      # Check for 404/empty response (no phenotype annotations)
      if (grepl("404|Not Found|empty", msg, ignore.case = TRUE)) {
        return(list(
          source = "rgd",
          gene_symbol = gene_symbol,
          rgd_id = paste0("RGD:", gsub("^RGD:", "", rgd_id)),
          rat_symbol = NULL,
          rat_name = NULL,
          phenotype_count = 0,
          phenotypes = list(),
          rgd_url = paste0("https://rgd.mcw.edu/rgdweb/report/gene/main.html?id=",
                           gsub("^RGD:", "", rgd_id))
        ))
      }
      return(list(
        error = TRUE,
        source = "rgd",
        message = paste("RGD query failed:", msg)
      ))
    }
  )
}

#' Fetch RGD rat phenotype data for a gene symbol
#'
#' @description
#' Retrieves rat phenotype data from Rat Genome Database (RGD) for a given
#' gene symbol. First tries to use the internal gene database to find the
#' RGD ID, then falls back to RGD API gene lookup.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "SCN1A")
#' @param rgd_id Optional RGD ID if already known (e.g., "RGD:69364")
#'
#' @return List containing:
#' \describe{
#'   \item{Success}{source, gene_symbol, rgd_id, rat_symbol, rat_name,
#'                  phenotype_count, phenotypes, rgd_url}
#'   \item{Not found}{found = FALSE, source = "rgd"}
#'   \item{Error}{error = TRUE, source = "rgd", message = <details>}
#' }
#'
#' @details
#' If rgd_id parameter is provided, uses it directly to fetch phenotypes.
#' Otherwise, attempts to find RGD ID via RGD gene lookup APIs (unreliable).
#'
#' Uses memoised caching with 14-day TTL (cache_stable) since phenotype
#' annotations change moderately.
#'
#' @examples
#' \dontrun{
#'   # Preferred: with RGD ID
#'   result <- fetch_rgd_phenotypes("SCN1A", rgd_id = "RGD:69364")
#'
#'   # Fallback: symbol only (may fail due to RGD API issues)
#'   result <- fetch_rgd_phenotypes("SCN1A")
#' }
#'
#' @export
fetch_rgd_phenotypes <- function(gene_symbol, rgd_id = NULL) {
  tryCatch(
    {
      # If RGD ID is provided, use it directly
      if (!is.null(rgd_id) && nchar(rgd_id) > 0) {
        return(fetch_rgd_phenotypes_by_id(rgd_id, gene_symbol))
      }

      # Validate gene symbol format
      if (!validate_gene_symbol(gene_symbol)) {
        return(list(
          error = TRUE,
          source = "rgd",
          message = paste("Invalid gene symbol format:", gene_symbol)
        ))
      }

      # Note: RGD gene lookup APIs are unreliable and often return 500 errors.
      # The preferred approach is to provide the rgd_id parameter directly.

      # Try RGD annotations endpoint with various ID formats
      # Unfortunately, RGD doesn't have a reliable gene symbol search API

      # Return not found (recommend using rgd_id parameter)
      return(list(
        found = FALSE,
        source = "rgd",
        message = paste(
          "RGD gene lookup APIs are unreliable.",
          "Please ensure rgd_id is provided from the internal gene database."
        )
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


#' Memoised version of fetch_rgd_phenotypes_by_id with 14-day cache
#'
#' @description
#' Cached wrapper around fetch_rgd_phenotypes_by_id using cache_stable
#' (14-day TTL). RGD phenotype data changes moderately as new annotations
#' are added.
#'
#' @param rgd_id RGD ID (e.g., "RGD:69364" or "69364")
#' @param gene_symbol Optional gene symbol for response context
#'
#' @return Same as fetch_rgd_phenotypes_by_id
#'
#' @seealso fetch_rgd_phenotypes_by_id
#'
#' @export
fetch_rgd_phenotypes_by_id_mem <- memoise::memoise(
  fetch_rgd_phenotypes_by_id,
  cache = cache_stable
)


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
