# functions/external-proxy-functions.R
#### This file holds shared infrastructure for external API proxy layer

require(httr2)   # Load httr2 for modern HTTP client functionality
require(cachem)  # Load cachem for disk-based caching

#### Per-source cache backends with different TTLs

# Static cache for rarely-changing data (constraint scores, AlphaFold URLs)
# 30 days TTL, 200 MB max size
cache_static_dir <- "/app/cache/external/static"
dir.create(cache_static_dir, recursive = TRUE, showWarnings = FALSE)
cache_static <- cache_disk(
  dir = cache_static_dir,
  max_age = 30 * 24 * 3600,  # 30 days in seconds
  max_size = 200 * 1024^2    # 200 MB
)

# Stable cache for moderately-changing data (protein domains, gene structure, phenotypes)
# 14 days TTL, 200 MB max size
cache_stable_dir <- "/app/cache/external/stable"
dir.create(cache_stable_dir, recursive = TRUE, showWarnings = FALSE)
cache_stable <- cache_disk(
  dir = cache_stable_dir,
  max_age = 14 * 24 * 3600,  # 14 days in seconds
  max_size = 200 * 1024^2    # 200 MB
)

# Dynamic cache for frequently-changing data (ClinVar variants)
# 7 days TTL, 200 MB max size
cache_dynamic_dir <- "/app/cache/external/dynamic"
dir.create(cache_dynamic_dir, recursive = TRUE, showWarnings = FALSE)
cache_dynamic <- cache_disk(
  dir = cache_dynamic_dir,
  max_age = 7 * 24 * 3600,   # 7 days in seconds
  max_size = 200 * 1024^2    # 200 MB
)


#### Rate limit configuration for all external APIs

#' External API rate limit configuration
#'
#' @description
#' Named list containing rate limit configurations for all 6 external APIs.
#' Each entry specifies capacity (max requests) and fill_time_s (time window).
#' Conservative limits applied where official documentation is unavailable.
#'
#' @format List with named entries for each API:
#' \describe{
#'   \item{gnomad}{10 requests per 60 seconds (conservative, undocumented)}
#'   \item{ensembl}{900 requests per 60 seconds (15 req/sec documented)}
#'   \item{uniprot}{100 requests per 1 second (conservative estimate)}
#'   \item{alphafold}{20 requests per 60 seconds (conservative, undocumented)}
#'   \item{mgi}{30 requests per 60 seconds (conservative, undocumented)}
#'   \item{rgd}{30 requests per 60 seconds (conservative, undocumented)}
#' }
#'
#' @export
EXTERNAL_API_THROTTLE <- list(
  gnomad = list(capacity = 10, fill_time_s = 60),    # 10 req/min (conservative)
  ensembl = list(capacity = 900, fill_time_s = 60),  # 15 req/sec (documented)
  uniprot = list(capacity = 100, fill_time_s = 1),   # 100 req/sec (conservative)
  alphafold = list(capacity = 20, fill_time_s = 60), # 20 req/min (conservative)
  mgi = list(capacity = 30, fill_time_s = 60),       # 30 req/min (conservative)
  rgd = list(capacity = 30, fill_time_s = 60)        # 30 req/min (conservative)
)


#' Make an external API request with retry and rate limiting
#'
#' @description
#' Shared request helper that applies httr2 retry logic with exponential backoff,
#' rate limiting (token bucket), and timeout protection. Handles transient errors
#' (429, 503, 504) automatically and provides structured error responses.
#'
#' @param url Character string, the API endpoint URL to request
#' @param api_name Character string, name of the API (for error reporting)
#' @param throttle_config List with `capacity` and `fill_time_s` fields for rate limiting
#' @param method Character string, HTTP method (default: "GET")
#' @param body Optional list or JSON for POST requests (default: NULL)
#'
#' @return List with response data or error information:
#' \describe{
#'   \item{Success (200)}{Parsed JSON response body}
#'   \item{Not found (404)}{list(found = FALSE, source = api_name)}
#'   \item{Error (non-200)}{list(error = TRUE, status = <code>, source = api_name, message = <details>)}
#'   \item{Exception}{list(error = TRUE, source = api_name, message = <exception>)}
#' }
#'
#' @details
#' Retry policy: max 5 attempts over 120 seconds, exponential backoff (2^attempt).
#' Transient errors (429 rate limit, 503 service unavailable, 504 gateway timeout)
#' automatically trigger retry.
#'
#' Timeout: 30 seconds per request attempt.
#'
#' @examples
#' \dontrun{
#'   result <- make_external_request(
#'     url = "https://rest.ensembl.org/lookup/symbol/homo_sapiens/BRCA1",
#'     api_name = "ensembl",
#'     throttle_config = EXTERNAL_API_THROTTLE$ensembl
#'   )
#' }
#'
#' @export
make_external_request <- function(url, api_name, throttle_config, method = "GET", body = NULL) {
  tryCatch(
    {
      # Build httr2 request with retry, throttle, and timeout
      req <- request(url) %>%
        req_throttle(
          rate = throttle_config$capacity / throttle_config$fill_time_s
        ) %>%
        req_retry(
          max_tries = 5,
          max_seconds = 120,
          backoff = ~ 2^.x,
          is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
        ) %>%
        req_timeout(30) %>%
        req_error(is_error = ~FALSE)  # Disable automatic error throwing

      # Add method and body if POST request
      if (method == "POST") {
        req <- req %>%
          req_method("POST") %>%
          req_body_json(body)
      }

      # Perform the request
      response <- req_perform(req)

      # Handle 404 - not found (expected for some queries)
      if (resp_status(response) == 404) {
        return(list(found = FALSE, source = api_name))
      }

      # Handle other non-200 responses
      if (resp_status(response) != 200) {
        return(list(
          error = TRUE,
          status = resp_status(response),
          source = api_name,
          message = paste(api_name, "returned HTTP", resp_status(response))
        ))
      }

      # Success - return parsed JSON
      return(resp_body_json(response))
    },
    error = function(e) {
      # Catch network errors, timeouts, JSON parsing failures
      return(list(
        error = TRUE,
        source = api_name,
        message = conditionMessage(e)
      ))
    }
  )
}


#' Create RFC 9457 formatted error for external API failures
#'
#' @description
#' Returns a standardized error response following RFC 9457 (Problem Details for HTTP APIs)
#' with source identification field. Used by proxy endpoints to report failures to clients.
#'
#' @param api_name Character string, name of the external API that failed
#' @param detail Character string, human-readable error description
#' @param status Integer, HTTP status code (default: 503 Service Unavailable)
#' @param instance Character string, optional URI reference identifying the specific occurrence
#'
#' @return List conforming to RFC 9457 structure with:
#' \describe{
#'   \item{type}{URI identifying the problem type}
#'   \item{title}{Short human-readable summary}
#'   \item{status}{HTTP status code}
#'   \item{detail}{Human-readable explanation}
#'   \item{source}{Name of the external API (custom extension)}
#'   \item{instance}{Optional URI reference (if provided)}
#' }
#'
#' @examples
#' \dontrun{
#'   error <- create_external_error(
#'     api_name = "gnomad",
#'     detail = "GraphQL query timeout after 30 seconds",
#'     status = 503L
#'   )
#' }
#'
#' @export
create_external_error <- function(api_name, detail, status = 503L, instance = NULL) {
  error_response <- list(
    type = "https://sysndd.org/problems/external-api-failure",
    title = paste("Failed to fetch", api_name, "data"),
    status = status,
    detail = detail,
    source = api_name
  )

  # Add instance if provided
  if (!is.null(instance)) {
    error_response$instance <- instance
  }

  return(error_response)
}


#' Validate HGNC gene symbol format
#'
#' @description
#' Validates that a gene symbol matches HGNC conventions: uppercase letters, numbers,
#' and hyphens. Prevents GraphQL/SQL injection and validates input before external API calls.
#'
#' @param symbol Character string, gene symbol to validate
#'
#' @return Logical: TRUE if valid HGNC symbol, FALSE otherwise
#'
#' @details
#' HGNC gene symbols follow pattern: start with uppercase letter or digit,
#' followed by letters (upper or lower), digits, or hyphens.
#' Examples: BRCA1, TP53, PTEN, IL-6, C9orf72, MIR21.
#'
#' Returns FALSE for NULL, NA, empty string, or non-matching patterns.
#'
#' @examples
#' validate_gene_symbol("BRCA1")    # TRUE
#' validate_gene_symbol("TP53")     # TRUE
#' validate_gene_symbol("IL-6")     # TRUE
#' validate_gene_symbol("C9orf72")  # TRUE (contains lowercase orf)
#' validate_gene_symbol("brca1")    # FALSE (starts with lowercase)
#' validate_gene_symbol("1INVALID") # FALSE (starts with number)
#' validate_gene_symbol(NULL)       # FALSE
#' validate_gene_symbol(NA)         # FALSE
#'
#' @export
validate_gene_symbol <- function(symbol) {
  # Check for NULL, NA, or empty
  # Note: is.na() must be checked before nchar() as nchar(NA) returns NA
  if (is.null(symbol) || length(symbol) == 0 || is.na(symbol) || nchar(symbol) == 0) {
    return(FALSE)
  }

  # Check pattern: starts with uppercase letter, followed by alphanumeric or hyphen

  # HGNC symbols can contain lowercase letters (e.g., C9orf72, miR genes)
  return(grepl("^[A-Z][A-Za-z0-9-]+$", symbol))
}
