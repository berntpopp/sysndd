# functions/ensembl-functions.R
# Ensembl/biomaRt functions with robust error handling
#
# Features:
# - Mirror failover (useast, uswest, asia, main)
# - Exponential backoff retry logic
# - Graceful degradation (returns NA on failure instead of crashing)
# - Configurable timeouts
# - Comprehensive logging

library(biomaRt)
library(dplyr)
library(tibble)
library(logger)

# =============================================================================
# Configuration
# =============================================================================

# Ensembl mirrors in order of preference
# hg38 mirrors (current genome)
ENSEMBL_HG38_MIRRORS <- c(
  "https://useast.ensembl.org",
  "https://uswest.ensembl.org",
  "https://asia.ensembl.org",
  "https://www.ensembl.org"
)

# hg19/GRCh37 mirrors (legacy genome)
ENSEMBL_HG19_MIRRORS <- c(
  "https://grch37.ensembl.org"
  # GRCh37 only has one server
)

# Retry configuration
ENSEMBL_MAX_RETRIES <- 3
ENSEMBL_BASE_DELAY_SECONDS <- 2
ENSEMBL_MAX_DELAY_SECONDS <- 30
ENSEMBL_TIMEOUT_SECONDS <- 120

# =============================================================================
# Helper Functions
# =============================================================================
#' Sleep with exponential backoff and jitter
#'
#' @param attempt Current attempt number (1-based)
#' @param base_delay Base delay in seconds
#' @param max_delay Maximum delay in seconds
#'
#' @return NULL (side effect: sleeps)
#' @keywords internal
sleep_with_backoff <- function(attempt, base_delay = ENSEMBL_BASE_DELAY_SECONDS,
                               max_delay = ENSEMBL_MAX_DELAY_SECONDS) {

  # Exponential backoff: base_delay * 2^(attempt-1)
  delay <- min(base_delay * (2^(attempt - 1)), max_delay)
  # Add jitter (random factor between 0.5 and 1.5)
  jitter <- runif(1, 0.5, 1.5)
  actual_delay <- delay * jitter

  log_debug("Sleeping {round(actual_delay, 1)}s before retry (attempt {attempt})")
  Sys.sleep(actual_delay)
}


#' Create Ensembl mart connection with mirror failover
#'
#' Attempts to connect to Ensembl using multiple mirrors with retry logic.
#'
#' @param reference Reference genome ("hg19" or "hg38")
#' @param max_retries Maximum retry attempts per mirror
#'
#' @return A biomaRt mart object, or NULL if all attempts fail
#' @export
create_ensembl_mart <- function(reference = "hg38", max_retries = ENSEMBL_MAX_RETRIES) {
  # Set timeout for curl operations
  old_timeout <- getOption("timeout")
  options(timeout = ENSEMBL_TIMEOUT_SECONDS)
  on.exit(options(timeout = old_timeout), add = TRUE)

  # Select mirrors based on reference
  if (reference == "hg19") {
    mirrors <- ENSEMBL_HG19_MIRRORS
  } else {
    mirrors <- ENSEMBL_HG38_MIRRORS
  }

  log_info("Creating Ensembl mart for {reference} (trying {length(mirrors)} mirrors)")

  for (mirror in mirrors) {
    log_debug("Trying mirror: {mirror}")

    for (attempt in seq_len(max_retries)) {
      mart <- tryCatch(
        {
          log_debug("Attempt {attempt}/{max_retries} for {mirror}")

          # biomaRt accepts full URL with https:// prefix
          m <- biomaRt::useMart(
            biomart = "ensembl",
            dataset = "hsapiens_gene_ensembl",
            host = mirror
          )

          log_info("Successfully connected to Ensembl at {mirror}")
          return(m)
        },
        error = function(e) {
          log_warn(
            "Ensembl connection failed (mirror={mirror}, attempt={attempt}): {conditionMessage(e)}"
          )
          NULL
        }
      )

      if (!is.null(mart)) {
        return(mart)
      }

      # Sleep before retry (but not after last attempt)
      if (attempt < max_retries) {
        sleep_with_backoff(attempt)
      }
    }

    log_warn("All retries exhausted for mirror {mirror}, trying next mirror")
  }

  log_error("Failed to connect to any Ensembl mirror for {reference}")
  return(NULL)
}


#' Execute getBM with retry logic
#'
#' Wrapper around biomaRt::getBM with exponential backoff retry.
#'
#' @param attributes Vector of attributes to retrieve
#' @param filters Vector of filters to apply
#' @param values List of filter values
#' @param mart biomaRt mart object
#' @param max_retries Maximum retry attempts
#'
#' @return Data frame from getBM, or NULL on failure
#' @keywords internal
safe_getBM <- function(attributes, filters, values, mart,
                       max_retries = ENSEMBL_MAX_RETRIES) {
  if (is.null(mart)) {
    log_warn("Cannot execute getBM: mart is NULL")
    return(NULL)
  }

  # Set timeout
  old_timeout <- getOption("timeout")
  options(timeout = ENSEMBL_TIMEOUT_SECONDS)
  on.exit(options(timeout = old_timeout), add = TRUE)

  for (attempt in seq_len(max_retries)) {
    result <- tryCatch(
      {
        log_debug("getBM attempt {attempt}/{max_retries}")

        data <- biomaRt::getBM(
          attributes = attributes,
          filters = filters,
          values = values,
          mart = mart
        )

        log_debug("getBM returned {nrow(data)} rows")
        return(data)
      },
      error = function(e) {
        log_warn("getBM failed (attempt {attempt}): {conditionMessage(e)}")
        NULL
      }
    )

    if (!is.null(result)) {
      return(result)
    }

    # Sleep before retry (but not after last attempt)
    if (attempt < max_retries) {
      sleep_with_backoff(attempt)
    }
  }

  log_error("getBM failed after {max_retries} attempts")
  return(NULL)
}


# =============================================================================
# Main Functions (with graceful degradation)
# =============================================================================

#' Retrieve gene coordinates in BED format from gene symbols
#'
#' This function retrieves the gene coordinates in BED format for the given gene
#' symbols. The coordinates are obtained from the specified reference genome.
#' If Ensembl is unavailable, returns NA for coordinates instead of failing.
#'
#' @param gene_symbols A vector or tibble containing the gene symbols.
#' @param reference The reference genome to use (default: "hg19").
#'
#' @return A tibble with the gene symbols and their corresponding coordinates
#'         in BED format. Returns NA for bed_format if Ensembl unavailable.
#'
#' @examples
#' gene_symbols <- c("ARID1B", "GRIN2B", "NAA10")
#' gene_coordinates_from_symbol(gene_symbols, reference = "hg19")
#'
#' @export
gene_coordinates_from_symbol <- function(gene_symbols, reference = "hg19") {
  # Prepare input
  gene_symbol_list <- as_tibble(gene_symbols) %>%
    dplyr::select(hgnc_symbol = value)

  # Early return if empty input
  if (nrow(gene_symbol_list) == 0) {
    return(gene_symbol_list %>% mutate(bed_format = character(0)))
  }

  # Create mart with failover
  mart <- create_ensembl_mart(reference = reference)

  if (is.null(mart)) {
    log_warn("Ensembl unavailable - returning NA for gene coordinates (symbol)")
    return(gene_symbol_list %>% mutate(bed_format = NA_character_))
  }

  # Query with retry
  attributes <- c("hgnc_symbol", "chromosome_name", "start_position", "end_position")
  filters <- "hgnc_symbol"
  values <- list(hgnc_symbol = gene_symbol_list$hgnc_symbol)

  result <- safe_getBM(
    attributes = attributes,
    filters = filters,
    values = values,
    mart = mart
  )

  if (is.null(result) || nrow(result) == 0) {
    log_warn("No coordinates returned from Ensembl (symbol) - returning NA")
    return(gene_symbol_list %>% mutate(bed_format = NA_character_))
  }

  # Process results
  gene_coordinates <- result %>%
    group_by(hgnc_symbol) %>%
    summarise(
      chromosome_name = first(chromosome_name),
      start_position = min(start_position),
      end_position = max(end_position),
      .groups = "drop"
    ) %>%
    mutate(bed_format = paste0("chr", chromosome_name, ":", start_position, "-", end_position)) %>%
    dplyr::select(hgnc_symbol, bed_format)

  # Join back to ensure all input symbols are in output
  gene_symbol_list %>%
    left_join(gene_coordinates, by = "hgnc_symbol")
}


#' Retrieve gene coordinates in BED format from Ensembl IDs
#'
#' This function retrieves the gene coordinates in BED format for the given Ensembl
#' gene IDs. The coordinates are obtained from the specified reference genome.
#' If Ensembl is unavailable, returns NA for coordinates instead of failing.
#'
#' @param ensembl_id A vector or tibble containing the Ensembl gene IDs.
#' @param reference The reference genome to use (default: "hg19").
#'
#' @return A tibble with the Ensembl gene IDs and their corresponding coordinates
#'         in BED format. Returns NA for bed_format if Ensembl unavailable.
#'
#' @examples
#' ensembl_id <- c("ENSG00000123456", "ENSG00000123457", "ENSG00000123458")
#' gene_coordinates_from_ensembl(ensembl_id, reference = "hg19")
#'
#' @export
gene_coordinates_from_ensembl <- function(ensembl_id, reference = "hg19") {
  # Prepare input
  ensembl_id_list <- as_tibble(ensembl_id) %>%
    dplyr::select(ensembl_gene_id = value)

  # Early return if empty input
  if (nrow(ensembl_id_list) == 0) {
    return(ensembl_id_list %>% mutate(bed_format = character(0)))
  }

  # Create mart with failover
  mart <- create_ensembl_mart(reference = reference)

  if (is.null(mart)) {
    log_warn("Ensembl unavailable - returning NA for gene coordinates (ensembl_id)")
    return(ensembl_id_list %>% mutate(bed_format = NA_character_))
  }

  # Query with retry
  attributes <- c("ensembl_gene_id", "chromosome_name", "start_position", "end_position")
  filters <- "ensembl_gene_id"
  values <- list(ensembl_gene_id = ensembl_id_list$ensembl_gene_id)

  result <- safe_getBM(
    attributes = attributes,
    filters = filters,
    values = values,
    mart = mart
  )

  if (is.null(result) || nrow(result) == 0) {
    log_warn("No coordinates returned from Ensembl (ensembl_id) - returning NA")
    return(ensembl_id_list %>% mutate(bed_format = NA_character_))
  }

  # Process results
  gene_coordinates <- result %>%
    group_by(ensembl_gene_id) %>%
    summarise(
      chromosome_name = first(chromosome_name),
      start_position = min(start_position),
      end_position = max(end_position),
      .groups = "drop"
    ) %>%
    mutate(bed_format = paste0("chr", chromosome_name, ":", start_position, "-", end_position)) %>%
    dplyr::select(ensembl_gene_id, bed_format)

  # Join back to ensure all input IDs are in output
  ensembl_id_list %>%
    left_join(gene_coordinates, by = "ensembl_gene_id")
}


#' Retrieve Ensembl gene ID versions from Ensembl gene IDs
#'
#' This function retrieves the Ensembl gene ID versions for the given Ensembl
#' gene IDs. The ID versions are obtained from the specified reference genome.
#' If Ensembl is unavailable, returns NA for versions instead of failing.
#'
#' @param ensembl_id A vector or tibble containing the Ensembl gene IDs.
#' @param reference The reference genome to use (default: "hg19").
#'
#' @return A tibble with the Ensembl gene IDs and their corresponding Ensembl
#'         gene ID versions. Returns NA for version if Ensembl unavailable.
#'
#' @examples
#' ensembl_id <- c("ENSG00000203782", "ENSG00000008710")
#' gene_id_version_from_ensembl(ensembl_id, reference = "hg19")
#'
#' @export
gene_id_version_from_ensembl <- function(ensembl_id, reference = "hg19") {
  # Prepare input
  ensembl_id_list <- enframe(ensembl_id, name = NULL, value = "ensembl_gene_id")

  # Early return if empty input
  if (nrow(ensembl_id_list) == 0) {
    return(ensembl_id_list %>% mutate(ensembl_gene_id_version = character(0)))
  }

  # Create mart with failover
  mart <- create_ensembl_mart(reference = reference)

  if (is.null(mart)) {
    log_warn("Ensembl unavailable - returning NA for gene ID versions")
    return(ensembl_id_list %>% mutate(ensembl_gene_id_version = NA_character_))
  }

  # Query with retry
  attributes <- c("ensembl_gene_id", "ensembl_gene_id_version")
  filters <- "ensembl_gene_id"

  result <- safe_getBM(
    attributes = attributes,
    filters = filters,
    values = ensembl_id_list$ensembl_gene_id,
    mart = mart
  )

  if (is.null(result) || nrow(result) == 0) {
    log_warn("No gene ID versions returned from Ensembl - returning NA")
    return(ensembl_id_list %>% mutate(ensembl_gene_id_version = NA_character_))
  }

  # Join back to ensure all input IDs are in output
  ensembl_id_list %>%
    left_join(result, by = "ensembl_gene_id")
}


#' Check Ensembl connectivity
#'
#' Tests whether Ensembl is reachable. Useful for pre-flight checks.
#'
#' @param reference Reference genome to test ("hg19" or "hg38")
#'
#' @return List with status (TRUE/FALSE), mirror used, and error message if any
#' @export
check_ensembl_connectivity <- function(reference = "hg38") {
  log_info("Checking Ensembl connectivity for {reference}")

  mart <- create_ensembl_mart(reference = reference, max_retries = 1)

  if (is.null(mart)) {
    return(list(
      connected = FALSE,
      mirror = NA_character_,
      error = "Failed to connect to any Ensembl mirror"
    ))
  }

  # Try a minimal query to verify connection works
  test_result <- tryCatch(
    {
      biomaRt::listAttributes(mart)[1:5, ]
      TRUE
    },
    error = function(e) {
      FALSE
    }
  )

  if (test_result) {
    list(
      connected = TRUE,
      mirror = mart@host,
      error = NA_character_
    )
  } else {
    list(
      connected = FALSE,
      mirror = mart@host,
      error = "Connected but query failed"
    )
  }
}
