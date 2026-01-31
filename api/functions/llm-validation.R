# functions/llm-validation.R
#
# Entity validation pipeline for LLM-generated cluster summaries.
# Ensures all gene symbols exist in database and pathways match enrichment input.
#
# Key features:
# - Strict gene symbol validation against non_alt_loci_set
# - Pathway validation against provided enrichment terms
# - Complete error reporting for validation failures

require(tidyverse)
require(stringr)
require(logger)

log_threshold(INFO)

# Load database helper functions for repository layer access (if not already loaded)
if (!exists("db_execute_query", mode = "function")) {
  if (file.exists("functions/db-helpers.R")) {
    source("functions/db-helpers.R", local = TRUE)
  }
}

#------------------------------------------------------------------------------
# Common words to exclude from gene symbol extraction
# These are frequently matched but are not gene symbols
#------------------------------------------------------------------------------
COMMON_WORDS <- c(
  # Common abbreviations
  "THE", "AND", "FOR", "WITH", "ARE", "NOT", "HAS", "HAD", "WAS", "WERE",
  # Molecular biology terms
  "DNA", "RNA", "ATP", "GTP", "ADP", "GDP", "NAD", "FAD", "AMP", "GMP",
  # Database/ontology abbreviations
  "NDD", "HPO", "OMIM", "KEGG", "ORPHA", "MONDO", "DOID", "EFO",
  # Gene ontology terms
  "GO", "BP", "MF", "CC",
  # Common technical terms
  "PCR", "SNP", "CNV", "VUS", "LOF", "GOF",
  # Units and numbers-like
  "KDA", "MHZ", "KB", "MB", "GB",
  # Clinical terms often in caps
  "ID", "ASD", "ADHD", "OCD", "MRI", "EEG", "CT", "PET",
  # Other common caps words
  "USA", "UK", "EU", "WHO", "NIH", "CDC"
)


#' Extract potential gene symbols from text
#'
#' Uses regex to find HGNC-style gene symbols in free text.
#' Filters out common abbreviations that match the pattern.
#'
#' @param text Character string containing potential gene symbols
#'
#' @return Character vector of unique potential gene symbols
#'
#' @details
#' Gene symbol pattern: `\\b[A-Z][A-Z0-9-]{1,15}\\b`
#' - Starts with uppercase letter
#' - Contains only uppercase letters, digits, hyphens
#' - Length 2-16 characters
#' - Filters out COMMON_WORDS list
#'
#' @examples
#' \dontrun{
#' symbols <- extract_gene_symbols("The BRCA1 and TP53 genes regulate DNA repair")
#' # Returns: c("BRCA1", "TP53")  # DNA is filtered as common word
#' }
#'
#' @export
extract_gene_symbols <- function(text) {
  if (is.null(text) || length(text) == 0 || !is.character(text)) {
    return(character(0))
  }

  # Collapse if multiple strings
  text <- paste(text, collapse = " ")

  # Find all potential gene symbols using HGNC pattern
  # Pattern: starts with letter, contains letters/digits/hyphens, 2-16 chars total
  matches <- stringr::str_extract_all(text, "\\b[A-Z][A-Z0-9-]{1,15}\\b")[[1]]

  if (length(matches) == 0) {
    return(character(0))
  }

 # Filter out common words
  filtered <- matches[!matches %in% COMMON_WORDS]

  # Return unique values
  unique(filtered)
}


#' Validate gene symbols against database
#'
#' Checks if gene symbols exist in the non_alt_loci_set table.
#' This is the authoritative source for valid HGNC gene symbols.
#'
#' @param symbols Character vector of gene symbols to validate
#'
#' @return List with:
#'   - is_valid: Logical, TRUE if all symbols are valid
#'   - valid: Character vector of valid symbols found in database
#'   - invalid: Character vector of symbols not found in database
#'
#' @details
#' CRITICAL: Validation is STRICT. Any invalid gene symbol causes is_valid = FALSE.
#' This prevents hallucinated gene names from being stored in the database.
#'
#' @examples
#' \dontrun{
#' result <- validate_gene_symbols(c("BRCA1", "TP53", "FAKEGENE123"))
#' # result$is_valid = FALSE (FAKEGENE123 is invalid)
#' # result$valid = c("BRCA1", "TP53")
#' # result$invalid = c("FAKEGENE123")
#' }
#'
#' @export
validate_gene_symbols <- function(symbols) {
  # Handle empty input
  if (is.null(symbols) || length(symbols) == 0) {
    return(list(
      is_valid = TRUE,
      valid = character(0),
      invalid = character(0)
    ))
  }

  # Ensure symbols is character vector
  symbols <- as.character(symbols)
  symbols <- unique(symbols)

  # Build parameterized query for database lookup
  # Use parameterized query to prevent SQL injection
  placeholders <- paste(rep("?", length(symbols)), collapse = ", ")
  query <- sprintf(
    "SELECT symbol FROM non_alt_loci_set WHERE symbol IN (%s)",
    placeholders
  )

  # Execute query with symbols as parameters
  result <- tryCatch({
    db_execute_query(query, as.list(symbols))
  }, error = function(e) {
    log_error("Database error during gene symbol validation: {e$message}")
    # On database error, return empty result (treat all as invalid for safety)
    tibble::tibble(symbol = character(0))
  })

  # Extract valid symbols from result
  valid_symbols <- if (nrow(result) > 0) result$symbol else character(0)

  # Determine invalid symbols
  invalid_symbols <- setdiff(symbols, valid_symbols)

  # Log validation result
  if (length(invalid_symbols) > 0) {
    log_warn("Gene validation failed: {length(invalid_symbols)} invalid symbols: {paste(invalid_symbols, collapse = ', ')}")
  } else {
    log_debug("Gene validation passed: {length(valid_symbols)} valid symbols")
  }

  list(
    is_valid = length(invalid_symbols) == 0,
    valid = valid_symbols,
    invalid = invalid_symbols
  )
}


#' Validate pathways against enrichment terms
#'
#' Checks if pathways mentioned in LLM output exist in the input enrichment data.
#' Pathways should only reference terms that were provided to the LLM.
#'
#' @param pathways Character vector of pathway names from LLM output
#' @param enrichment_terms Character vector of valid pathway/term names from enrichment input
#'
#' @return List with:
#'   - is_valid: Logical, TRUE if all pathways are in enrichment_terms
#'   - valid: Character vector of valid pathways
#'   - invalid: Character vector of pathways not in enrichment_terms
#'
#' @details
#' Uses case-insensitive matching to handle variations in capitalization.
#'
#' @examples
#' \dontrun{
#' enrichment <- c("Oxidative phosphorylation", "DNA repair", "Cell cycle")
#' result <- validate_pathways(c("Oxidative phosphorylation", "Made up pathway"), enrichment)
#' # result$is_valid = FALSE
#' # result$invalid = c("Made up pathway")
#' }
#'
#' @export
validate_pathways <- function(pathways, enrichment_terms) {
  # Handle NULL or empty pathways
  if (is.null(pathways) || length(pathways) == 0) {
    return(list(
      is_valid = TRUE,
      valid = character(0),
      invalid = character(0)
    ))
  }

  # Handle NULL or empty enrichment_terms
  if (is.null(enrichment_terms) || length(enrichment_terms) == 0) {
    # If no enrichment terms provided, all pathways are invalid
    return(list(
      is_valid = FALSE,
      valid = character(0),
      invalid = pathways
    ))
  }

  # Ensure character vectors
  pathways <- as.character(pathways)
  enrichment_terms <- as.character(enrichment_terms)

  # Normalize for case-insensitive comparison
  pathways_lower <- tolower(pathways)
  enrichment_lower <- tolower(enrichment_terms)

  # Find valid and invalid pathways
  valid_mask <- pathways_lower %in% enrichment_lower
  valid_pathways <- pathways[valid_mask]
  invalid_pathways <- pathways[!valid_mask]

  # Log validation result
  if (length(invalid_pathways) > 0) {
    log_warn("Pathway validation failed: {length(invalid_pathways)} invalid: {paste(invalid_pathways, collapse = ', ')}")
  } else {
    log_debug("Pathway validation passed: {length(valid_pathways)} valid pathways")
  }

  list(
    is_valid = length(invalid_pathways) == 0,
    valid = valid_pathways,
    invalid = invalid_pathways
  )
}


#' Validate all entities in LLM summary
#'
#' Comprehensive validation of gene symbols and pathways in an LLM-generated summary.
#' This is the main entry point for entity validation.
#'
#' @param summary_result List containing LLM output with:
#'   - summary: Character string prose summary
#'   - pathways: Character vector of pathway names (optional)
#' @param cluster_data List containing cluster input data with:
#'   - term_enrichment: Tibble with 'term' column for pathway validation
#'
#' @return List with:
#'   - is_valid: Logical, TRUE if all validations pass
#'   - mentioned_genes: Character vector of valid gene symbols found
#'   - invalid_genes: Character vector of invalid gene symbols found
#'   - mentioned_pathways: Character vector of valid pathways
#'   - invalid_pathways: Character vector of invalid pathways
#'   - errors: Character vector of human-readable error messages
#'
#' @details
#' CRITICAL: Validation is STRICT. Any invalid gene symbol OR invalid pathway
#' causes is_valid = FALSE, rejecting the entire summary.
#'
#' This matches CONTEXT.md decision: "Strict - reject entire summary if any
#' invalid gene symbols detected"
#'
#' @examples
#' \dontrun{
#' summary_result <- list(
#'   summary = "BRCA1 and TP53 are involved in DNA repair.",
#'   pathways = c("Oxidative phosphorylation")
#' )
#' cluster_data <- list(
#'   term_enrichment = tibble(term = c("Oxidative phosphorylation", "DNA repair"))
#' )
#' result <- validate_summary_entities(summary_result, cluster_data)
#' }
#'
#' @export
validate_summary_entities <- function(summary_result, cluster_data) {
  errors <- character(0)

  # Extract gene symbols from summary text
  summary_text <- summary_result$summary %||% ""
  extracted_symbols <- extract_gene_symbols(summary_text)

  log_debug("Extracted {length(extracted_symbols)} potential gene symbols from summary")

  # Validate gene symbols against database
  gene_result <- validate_gene_symbols(extracted_symbols)

  if (!gene_result$is_valid) {
    errors <- c(
      errors,
      sprintf(
        "Invalid gene symbols detected: %s. These genes do not exist in the HGNC database.",
        paste(gene_result$invalid, collapse = ", ")
      )
    )
  }

  # Extract enrichment terms for pathway validation
  enrichment_terms <- if (!is.null(cluster_data$term_enrichment) &&
                           "term" %in% names(cluster_data$term_enrichment)) {
    cluster_data$term_enrichment$term
  } else {
    character(0)
  }

  # Validate pathways
  pathways <- summary_result$pathways %||% character(0)
  pathway_result <- validate_pathways(pathways, enrichment_terms)

  if (!pathway_result$is_valid && length(pathways) > 0) {
    errors <- c(
      errors,
      sprintf(
        "Invalid pathways detected: %s. These pathways were not in the enrichment input.",
        paste(pathway_result$invalid, collapse = ", ")
      )
    )
  }

  # Determine overall validity
  is_valid <- gene_result$is_valid && pathway_result$is_valid

  if (is_valid) {
    log_info("Entity validation passed: {length(gene_result$valid)} genes, {length(pathway_result$valid)} pathways")
  } else {
    log_warn("Entity validation FAILED: {length(errors)} error(s)")
  }

  list(
    is_valid = is_valid,
    mentioned_genes = gene_result$valid,
    invalid_genes = gene_result$invalid,
    mentioned_pathways = pathway_result$valid,
    invalid_pathways = pathway_result$invalid,
    errors = errors
  )
}
