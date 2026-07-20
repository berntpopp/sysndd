# functions/external-proxy-functions.R
#### This file holds shared infrastructure for external API proxy layer

require(httr2) # Load httr2 for modern HTTP client functionality
require(cachem) # Load cachem for disk-based caching

# #344: per-request external-time accounting + API lane identity live in a
# sibling module (keeps this file under the 600-line ceiling). load_modules.R /
# setup_workers.R source it first in production (so this guard is a no-op there);
# guard-source it here so direct-source unit tests get these helpers. Resolve the
# sibling CWD-robustly: `get_api_dir()` exists only under testthat (whose CWD is
# tests/testthat, not the api dir); production falls back to the relative path
# (CWD is /app).
if (!exists("external_proxy_request_reset", mode = "function")) {
  .eprs_path <- if (exists("get_api_dir", mode = "function")) {
    file.path(get_api_dir(), "functions", "external-proxy-request-state.R")
  } else {
    "functions/external-proxy-request-state.R"
  }
  if (file.exists(.eprs_path)) {
    source(.eprs_path, local = TRUE)
  }
  rm(.eprs_path)
}

#### Per-source cache backends with different TTLs

#' Resolve a writable external proxy cache directory
#'
#' @param name Cache bucket name.
#' @return Writable directory path.
#' @noRd
external_proxy_cache_dir <- function(name) {
  root <- Sys.getenv("EXTERNAL_PROXY_CACHE_DIR", "/app/cache/external")
  path <- file.path(root, name)
  if (dir.exists(path) || dir.create(path, recursive = TRUE, showWarnings = FALSE)) {
    return(path)
  }

  fallback <- file.path(tempdir(), "sysndd-external-cache", name)
  dir.create(fallback, recursive = TRUE, showWarnings = FALSE)
  fallback
}

# Static cache for rarely-changing data (constraint scores, AlphaFold URLs)
# 30 days TTL, 200 MB max size
cache_static_dir <- external_proxy_cache_dir("static")
cache_static <- cache_disk(
  dir = cache_static_dir,
  max_age = 30 * 24 * 3600, # 30 days in seconds
  max_size = 200 * 1024^2 # 200 MB
)

# Stable cache for moderately-changing data (protein domains, gene structure, phenotypes)
# 14 days TTL, 200 MB max size
cache_stable_dir <- external_proxy_cache_dir("stable")
cache_stable <- cache_disk(
  dir = cache_stable_dir,
  max_age = 14 * 24 * 3600, # 14 days in seconds
  max_size = 200 * 1024^2 # 200 MB
)

# Dynamic cache for frequently-changing data (ClinVar variants)
# 7 days TTL, 200 MB max size
cache_dynamic_dir <- external_proxy_cache_dir("dynamic")
cache_dynamic <- cache_disk(
  dir = cache_dynamic_dir,
  max_age = 7 * 24 * 3600, # 7 days in seconds
  max_size = 200 * 1024^2 # 200 MB
)

#### External proxy cache policy helpers

#' Check whether an external proxy result represents an upstream error
#'
#' @param result External proxy result list.
#' @return TRUE when the result is an error payload that must not be cached.
#' @noRd
external_proxy_is_error <- function(result) {
  is.list(result) && isTRUE(result$error)
}

#' Log an external proxy event in a compact structured format
#'
#' @param source External source name.
#' @param event Event name.
#' @param status Optional upstream or mapped status.
#' @param detail Optional detail string.
#' @noRd
external_proxy_log_event <- function(source,
                                     event,
                                     status = NULL,
                                     detail = NULL,
                                     elapsed_ms = NULL,
                                     cache = NULL) {
  parts <- c(
    source = source %||% "unknown",
    event = event %||% "unknown"
  )
  if (!is.null(status)) {
    parts <- c(parts, status = as.character(status))
  }
  if (!is.null(elapsed_ms)) {
    parts <- c(parts, elapsed_ms = as.character(as.integer(round(elapsed_ms))))
  }
  if (!is.null(cache)) {
    parts <- c(parts, cache = as.character(cache))
  }
  if (!is.null(detail) && nzchar(detail)) {
    parts <- c(parts, detail = detail)
  }
  message(paste0("[external-proxy] ", paste(names(parts), parts, sep = "=", collapse = " ")))
}

#' Memoise an external fetcher while refusing to retain error payloads
#'
#' @description
#' `memoise::memoise()` caches every returned value, including
#' `list(error = TRUE, ...)`. For external enrichment endpoints, that poisons
#' the disk cache for the full source TTL after one transient upstream timeout.
#' This wrapper keeps normal successful/not-found caching, but immediately
#' clears the memoised cache after an error result so a later request can retry.
#'
#' When a `source` label is supplied the wrapper also emits one structured
#' timing log per call (`event=complete`) covering cache hit/miss, the wall
#' time spent serving the request (upstream duration on a miss, cache lookup on
#' a hit), and the mapped response status. This gives every external provider
#' the same observability without each fetcher having to wrap itself, and keeps
#' the hot path cheap: the cache-hit probe is a single key lookup and the timing
#' is two `proc.time()` reads.
#'
#' @param f Function to memoise.
#' @param cache cachem backend.
#' @param source Optional source label used for structured timing logs. When
#'   `NULL` (default) no per-call timing log is emitted (legacy behaviour).
#' @return Function with the same call shape as `f`.
#' @export
memoise_external_success_only <- function(f, cache, source = NULL) {
  memoised <- memoise::memoise(f, cache = cache)

  function(...) {
    # Short-circuit before a cache probe / upstream call once this request has
    # already spent its external-time budget (#344). Covers every provider whose
    # public entry is a `*_mem` wrapper (gnomad/uniprot/ensembl/alphafold/mgi/
    # rgd/genereviews).
    if (external_proxy_request_ceiling_exceeded()) {
      return(external_proxy_request_budget_error(source))
    }

    cache_status <- NULL
    if (!is.null(source)) {
      cache_status <- tryCatch(
        if (isTRUE(memoise::has_cache(memoised)(...))) "hit" else "miss",
        error = function(e) NULL
      )
    }

    start <- proc.time()[["elapsed"]]
    result <- memoised(...)
    elapsed_ms <- as.numeric((proc.time()[["elapsed"]] - start) * 1000)
    external_proxy_request_add(elapsed_ms)

    if (external_proxy_is_error(result)) {
      tryCatch(
        memoise::forget(memoised),
        error = function(e) FALSE
      )
      external_proxy_log_event(
        source = result$source %||% source %||% "unknown",
        event = "error_not_cached",
        status = result$status %||% 503L,
        detail = result$message %||% NULL
      )
    }

    if (!is.null(source)) {
      external_proxy_log_event(
        source = result$source %||% source,
        event = "complete",
        status = external_proxy_result_status(result),
        elapsed_ms = elapsed_ms,
        cache = cache_status
      )
    }

    result
  }
}


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
  gnomad = list(capacity = 10, fill_time_s = 60), # 10 req/min (conservative)
  ensembl = list(capacity = 900, fill_time_s = 60), # 15 req/sec (documented)
  uniprot = list(capacity = 100, fill_time_s = 1), # 100 req/sec (conservative)
  alphafold = list(capacity = 20, fill_time_s = 60), # 20 req/min (conservative)
  mgi = list(capacity = 30, fill_time_s = 60), # 30 req/min (conservative)
  rgd = list(capacity = 30, fill_time_s = 60) # 30 req/min (conservative)
)

external_proxy_budget <- function(api_name,
                                  default_timeout = 6,
                                  default_max = 10,
                                  default_tries = 2L) {
  api_name <- toupper(as.character(api_name %||% "default")[[1]])
  timeout <- as.numeric(Sys.getenv(
    paste0("EXTERNAL_PROXY_", api_name, "_TIMEOUT_SECONDS"),
    Sys.getenv("EXTERNAL_PROXY_TIMEOUT_SECONDS", as.character(default_timeout))
  ))
  max_seconds <- as.numeric(Sys.getenv(
    paste0("EXTERNAL_PROXY_", api_name, "_MAX_SECONDS"),
    Sys.getenv("EXTERNAL_PROXY_MAX_SECONDS", as.character(default_max))
  ))
  max_tries <- as.integer(Sys.getenv(
    paste0("EXTERNAL_PROXY_", api_name, "_MAX_TRIES"),
    Sys.getenv("EXTERNAL_PROXY_MAX_TRIES", as.character(default_tries))
  ))
  list(
    timeout_seconds = if (is.na(timeout) || timeout <= 0) default_timeout else timeout,
    max_seconds = if (is.na(max_seconds) || max_seconds <= 0) default_max else max_seconds,
    max_tries = if (is.na(max_tries) || max_tries < 1L) max(1L, as.integer(default_tries)) else max_tries
  )
}

external_proxy_with_timing <- function(source, expr_fn) {
  # Short-circuit before doing any upstream work once this request has already
  # spent its external-time budget (#344).
  if (external_proxy_request_ceiling_exceeded()) {
    return(external_proxy_request_budget_error(source))
  }
  start <- proc.time()[["elapsed"]]
  result <- tryCatch(
    expr_fn(),
    error = function(e) {
      list(
        error = TRUE,
        status = 503L,
        source = source,
        message = conditionMessage(e)
      )
    }
  )
  elapsed_ms <- as.numeric((proc.time()[["elapsed"]] - start) * 1000)
  external_proxy_request_add(elapsed_ms)

  if (!is.list(result)) {
    result <- list(value = result)
  }
  result$elapsed_ms <- elapsed_ms
  if (is.null(result$source)) {
    result$source <- source
  }

  status <- external_proxy_result_status(result)
  external_proxy_log_event(
    source = source,
    event = "complete",
    status = status,
    elapsed_ms = elapsed_ms,
    cache = result$cache_status %||% NULL
  )
  result
}

external_proxy_result_status <- function(result) {
  if (!is.null(result$status)) {
    return(result$status)
  }
  if (isTRUE(result$error)) {
    return(503L)
  }
  if (isTRUE(result$found == FALSE)) {
    return(404L)
  }
  200L
}

external_proxy_aggregate_budget <- function() {
  max_seconds <- as.numeric(Sys.getenv("EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS", "12"))
  if (is.na(max_seconds) || max_seconds <= 0) {
    12
  } else {
    max_seconds
  }
}

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
      budget <- external_proxy_budget(api_name)
      # Build httr2 request with retry, throttle, and timeout
      req <- request(url) %>%
        req_throttle(
          rate = throttle_config$capacity / throttle_config$fill_time_s
        ) %>%
        req_retry(
          max_tries = budget$max_tries,
          max_seconds = budget$max_seconds,
          backoff = ~ 2^.x,
          is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
        ) %>%
        req_timeout(budget$timeout_seconds) %>%
        req_error(is_error = ~FALSE) # Disable automatic error throwing

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
        status = 503L,
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

external_proxy_aggregate_sources <- function(symbol, sources, instance = NULL) {
  results <- list(
    gene_symbol = symbol,
    sources = list(),
    errors = list(),
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  )
  aggregate_started <- proc.time()[["elapsed"]]
  aggregate_max_seconds <- external_proxy_aggregate_budget()
  skipped_sources <- character()

  source_names <- names(sources)
  for (i in seq_along(source_names)) {
    source_name <- source_names[[i]]
    elapsed_seconds <- proc.time()[["elapsed"]] - aggregate_started
    if (elapsed_seconds > aggregate_max_seconds) {
      skipped_sources <- source_names[i:length(source_names)]
      break
    }

    result <- tryCatch(
      sources[[source_name]](),
      error = function(e) {
        list(error = TRUE, source = source_name, message = conditionMessage(e))
      }
    )

    if (is.list(result) && isTRUE(result$error)) {
      results$errors[[source_name]] <- create_external_error(
        source_name,
        result$message %||% paste(source_name, "unavailable"),
        503L,
        instance
      )
    } else if (is.list(result) && isTRUE(result$found == FALSE)) {
      results$sources[[source_name]] <- list(found = FALSE)
    } else {
      results$sources[[source_name]] <- result
    }
  }

  if (length(skipped_sources) > 0L) {
    results$partial <- TRUE
    results$skipped_sources <- as.list(skipped_sources)
  }
  results
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
