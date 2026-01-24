# functions/ols-functions.R
# EBI Ontology Lookup Service (OLS4) API integration
#
# Provides functions to query MONDO ontology for:
# - OMIM to MONDO mappings
# - Deprecated OMIM replacement suggestions
# - Term details and cross-references
#
# API Documentation: https://www.ebi.ac.uk/ols4/api
# Rate limits: Be respectful, add delays between batch requests

require(httr2)
require(purrr)
require(stringr)
require(logger)

# =============================================================================
# Constants
# =============================================================================

OLS4_BASE_URL <- "https://www.ebi.ac.uk/ols4/api"
OLS4_TIMEOUT_SECONDS <- 30
OLS4_MAX_RETRIES <- 3
OLS4_BATCH_DELAY_MS <- 200 # Delay between batch requests to be API-friendly


# =============================================================================
# Core API Functions (DRY - single request logic)
# =============================================================================

#' Make a request to the OLS4 API
#'
#' Generic function for OLS4 API requests with retry logic and error handling.
#' All other OLS functions use this as the base request mechanism.
#'
#' @param endpoint Character. API endpoint path (appended to base URL)
#' @param query_params List. Query parameters for the request
#' @return Parsed JSON response or NULL on error
#' @keywords internal
ols_request <- function(endpoint, query_params = list()) {
  url <- paste0(OLS4_BASE_URL, endpoint)


  tryCatch(
    {
      response <- request(url) %>%
        req_url_query(!!!query_params) %>%
        req_retry(
          max_tries = OLS4_MAX_RETRIES,
          backoff = ~ 2^.x
        ) %>%
        req_timeout(OLS4_TIMEOUT_SECONDS) %>%
        req_error(is_error = ~FALSE) %>%
        req_perform()

      status <- resp_status(response)

      if (status == 200) {
        return(resp_body_json(response))
      } else if (status == 404) {
        # Not found is expected for some queries
        return(NULL)
      } else {
        log_warn("OLS4 API returned status {status} for {endpoint}")
        return(NULL)
      }
    },
    error = function(e) {
      log_warn("OLS4 API request failed: {e$message}")
      return(NULL)
    }
  )
}


#' URL-encode an IRI for OLS4 API
#'
#' OLS4 requires double URL-encoding for term IRIs in path segments.
#'
#' @param iri Character. The IRI to encode (e.g., "http://purl.obolibrary.org/obo/MONDO_0033482")
#' @return Double URL-encoded string
#' @keywords internal
ols_encode_iri <- function(iri) {
  if (is.null(iri) || nchar(iri) == 0) {
    return("")
  }
  # Double encode for OLS4 API path segments
  # Step 1: First URL encode
  first_encode <- URLencode(iri, reserved = TRUE)
  # Step 2: Replace % with %25 to achieve true double-encoding
  # (R's URLencode doesn't re-encode % in %XX sequences)
  gsub("%", "%25", first_encode)
}


# =============================================================================
# MONDO Search Functions
# =============================================================================

#' Search MONDO ontology for a term
#'
#' Searches the MONDO ontology using the OLS4 search endpoint.
#' Can search by OMIM ID, disease name, or other identifiers.
#'
#' @param query Character. Search query (e.g., "617931" or "spinocerebellar ataxia")
#' @param exact Logical. If TRUE, search for exact matches only (default: FALSE)
#' @param rows Integer. Maximum number of results to return (default: 10)
#' @return List of search results or empty list if none found
#'
#' @examples
#' \dontrun{
#'   results <- ols_search_mondo("617931")
#'   results <- ols_search_mondo("spinocerebellar ataxia", rows = 5)
#' }
#'
#' @export
ols_search_mondo <- function(query, exact = FALSE, rows = 10) {
  if (is.null(query) || is.na(query) || nchar(trimws(query)) == 0) {
    return(list())
  }

  params <- list(
    q = query,
    ontology = "mondo",
    rows = rows
  )

  if (exact) {
    params$exact <- "true"
  }

  result <- ols_request("/search", params)

  if (is.null(result) || is.null(result$response)) {
    return(list())
  }

  return(result$response$docs %||% list())
}


#' Get MONDO term details by IRI
#'
#' Retrieves full term details including cross-references, annotations,
#' and deprecation information.
#'
#' @param iri Character. Full IRI of the MONDO term
#' @return List with term details or NULL if not found
#'
#' @examples
#' \dontrun{
#'   term <- ols_get_mondo_term("http://purl.obolibrary.org/obo/MONDO_0033482")
#' }
#'
#' @export
ols_get_mondo_term <- function(iri) {
  if (is.null(iri) || is.na(iri) || nchar(trimws(iri)) == 0) {
    return(NULL)
  }

  encoded_iri <- ols_encode_iri(iri)
  endpoint <- paste0("/ontologies/mondo/terms/", encoded_iri)

  ols_request(endpoint)
}


# =============================================================================
# OMIM Mapping Functions
# =============================================================================

#' Get MONDO equivalent for an OMIM ID
#'
#' Searches MONDO for a term that has an exact match cross-reference
#' to the given OMIM ID.
#'
#' @param omim_id Character. OMIM ID with or without prefix (e.g., "OMIM:617931" or "617931")
#' @return List with mondo_id, mondo_label, and mapping_type, or NULL if not found
#'
#' @examples
#' \dontrun{
#'   mapping <- ols_get_mondo_for_omim("OMIM:617931")
#'   mapping <- ols_get_mondo_for_omim("620719")
#' }
#'
#' @export
ols_get_mondo_for_omim <- function(omim_id) {
  if (is.null(omim_id) || is.na(omim_id) || nchar(trimws(omim_id)) == 0) {
    return(NULL)
  }

  # Normalize: extract just the number
  omim_number <- str_replace(omim_id, "^OMIM:", "")

  # Search for this OMIM ID in MONDO
  results <- ols_search_mondo(omim_number, rows = 20)

  if (length(results) == 0) {
    return(NULL)
  }

  # Look for a term with matching OMIM xref
  omim_pattern <- paste0("OMIM:", omim_number)

  for (doc in results) {
    # Search results don't include xrefs, need to fetch full term details
    term <- ols_get_mondo_term(doc$iri)
    if (is.null(term)) {
      next
    }

    # Check annotation.database_cross_reference for OMIM cross-references
    xrefs <- term$annotation$database_cross_reference %||% list()

    for (xref in xrefs) {
      if (is.character(xref) && xref == omim_pattern) {
        # Found a match - check if term is obsolete
        mapping_type <- if (isTRUE(term$is_obsolete)) {
          "equivalentObsolete"
        } else {
          "exactMatch"
        }

        return(list(
          mondo_id = term$obo_id %||% term$short_form,
          mondo_iri = term$iri,
          mondo_label = term$label,
          mapping_type = mapping_type,
          is_obsolete = term$is_obsolete %||% FALSE
        ))
      }
    }
  }

  return(NULL)
}


#' Get replacement suggestion for a deprecated OMIM ID
#'
#' Searches MONDO for information about a deprecated OMIM ID including:
#' - The MONDO term that references it (with equivalentObsolete)
#' - Deprecation reason from term annotations
#' - Suggested replacement term (from consider or replaced_by)
#'
#' @param omim_id Character. Deprecated OMIM ID
#' @return List with deprecation info and replacement suggestion, or NULL
#'
#' @examples
#' \dontrun{
#'   info <- ols_get_deprecated_omim_info("OMIM:617931")
#' }
#'
#' @export
ols_get_deprecated_omim_info <- function(omim_id) {
  # First, find the MONDO term for this OMIM
  mapping <- ols_get_mondo_for_omim(omim_id)

  if (is.null(mapping)) {
    return(NULL)
  }

  # Get full term details
  term <- ols_get_mondo_term(mapping$mondo_iri)

  if (is.null(term)) {
    return(list(
      mondo_id = mapping$mondo_id,
      mondo_label = mapping$mondo_label,
      mapping_type = mapping$mapping_type,
      deprecation_reason = NULL,
      replacement_mondo_id = NULL,
      replacement_mondo_label = NULL,
      replacement_omim_id = NULL
    ))
  }

  # Extract deprecation information
  result <- list(
    mondo_id = mapping$mondo_id,
    mondo_iri = mapping$mondo_iri,
    mondo_label = mapping$mondo_label,
    mapping_type = mapping$mapping_type,
    is_obsolete = term$is_obsolete %||% FALSE,
    deprecation_reason = NULL,
    replacement_mondo_id = NULL,
    replacement_mondo_label = NULL,
    replacement_omim_id = NULL
  )

  # Look for deprecation reason in description/annotation
  descriptions <- term$description %||% term$annotation$definition %||% list()
  for (desc in descriptions) {
    if (is.character(desc) && (grepl("deprecated", desc, ignore.case = TRUE) ||
      grepl("reclassified", desc, ignore.case = TRUE) ||
      grepl("obsolete", desc, ignore.case = TRUE))) {
      result$deprecation_reason <- desc

      # Try to extract replacement MONDO ID from the text
      mondo_match <- str_extract(desc, "MONDO:\\d+")
      if (!is.na(mondo_match)) {
        result$replacement_mondo_id <- mondo_match
      }
      break
    }
  }

  # Check term_replaced_by annotation
  replaced_by <- term$term_replaced_by %||% term$annotation$`term replaced by`
  if (!is.null(replaced_by) && length(replaced_by) > 0) {
    replacement_iri <- replaced_by[[1]]
    if (is.character(replacement_iri)) {
      # Extract MONDO ID from IRI
      mondo_match <- str_extract(replacement_iri, "MONDO_\\d+")
      if (!is.na(mondo_match)) {
        result$replacement_mondo_id <- str_replace(mondo_match, "_", ":")
      }
    }
  }

  # If we found a replacement MONDO ID, get its details and OMIM mapping
  if (!is.null(result$replacement_mondo_id)) {
    replacement_iri <- paste0(
      "http://purl.obolibrary.org/obo/",
      str_replace(result$replacement_mondo_id, ":", "_")
    )
    replacement_term <- ols_get_mondo_term(replacement_iri)

    if (!is.null(replacement_term)) {
      result$replacement_mondo_label <- replacement_term$label

      # Find OMIM xref in replacement term
      # xrefs are in annotation$database_cross_reference as strings
      xrefs <- replacement_term$annotation$database_cross_reference %||% list()
      for (xref in xrefs) {
        if (is.character(xref) && grepl("^OMIM:", xref)) {
          result$replacement_omim_id <- xref
          break
        }
      }
    }
  }

  return(result)
}


#' Get deprecation info for multiple OMIM IDs (batch)
#'
#' Efficiently queries OLS4 for multiple OMIM IDs with rate limiting.
#' Use this for batch processing to avoid hammering the API.
#'
#' @param omim_ids Character vector. List of OMIM IDs to look up
#' @param delay_ms Integer. Delay between requests in milliseconds (default: 200)
#' @return Named list with deprecation info for each OMIM ID
#'
#' @examples
#' \dontrun{
#'   infos <- ols_get_deprecated_omim_info_batch(c("OMIM:617931", "OMIM:123456"))
#' }
#'
#' @export
ols_get_deprecated_omim_info_batch <- function(omim_ids, delay_ms = OLS4_BATCH_DELAY_MS) {
  if (length(omim_ids) == 0) {
    return(list())
  }

  results <- list()

  for (i in seq_along(omim_ids)) {
    omim_id <- omim_ids[i]

    # Add delay between requests (except first)
    if (i > 1 && delay_ms > 0) {
      Sys.sleep(delay_ms / 1000)
    }

    info <- ols_get_deprecated_omim_info(omim_id)
    results[[omim_id]] <- info
  }

  return(results)
}


# =============================================================================
# Helper Functions
# =============================================================================

#' Check if an OMIM ID has a valid MONDO equivalent
#'
#' Quick check to see if an OMIM ID maps to a non-obsolete MONDO term.
#'
#' @param omim_id Character. OMIM ID to check
#' @return Logical. TRUE if a valid MONDO equivalent exists
#'
#' @export
ols_has_mondo_equivalent <- function(omim_id) {
  mapping <- ols_get_mondo_for_omim(omim_id)

  if (is.null(mapping)) {
    return(FALSE)
  }

  # Check if it's a current (not obsolete) mapping
  return(mapping$mapping_type == "exactMatch" && !isTRUE(mapping$is_obsolete))
}


#' Format deprecation info for display
#'
#' Creates a human-readable summary of deprecation information.
#'
#' @param info List. Result from ols_get_deprecated_omim_info()
#' @return Character string with formatted summary
#'
#' @export
ols_format_deprecation_summary <- function(info) {
  if (is.null(info)) {
    return("No MONDO mapping found")
  }

  parts <- c()

  # MONDO term info
  if (!is.null(info$mondo_id)) {
    parts <- c(parts, paste0("MONDO: ", info$mondo_id, " (", info$mondo_label, ")"))
  }

  # Mapping type
  if (!is.null(info$mapping_type)) {
    parts <- c(parts, paste0("Mapping: ", info$mapping_type))
  }

  # Replacement suggestion
  if (!is.null(info$replacement_omim_id)) {
    parts <- c(parts, paste0("Suggested replacement: ", info$replacement_omim_id))
  } else if (!is.null(info$replacement_mondo_id)) {
    parts <- c(parts, paste0("Suggested MONDO: ", info$replacement_mondo_id))
  }

  paste(parts, collapse = " | ")
}
