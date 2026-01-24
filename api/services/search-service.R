# Search Service Layer for SysNDD API
# Provides business logic for search functionality
#
# Functions accept pool as parameter (dependency injection)
# Handles entity, gene, and phenotype search operations

#' Search entities by gene symbol or disease name
#'
#' Performs fuzzy search across entity view matching gene symbols and disease names.
#' Returns up to 100 results ordered by relevance.
#'
#' @param query Character search query string
#' @param pool Database connection pool
#' @return Tibble of matching entities
#'
#' @details
#' - Minimum query length: 2 characters
#' - Uses LIKE pattern matching with wildcards
#' - Searches both symbol and disease_ontology_name columns
#' - Results limited to 100 records
#'
#' @examples
#' \dontrun{
#' results <- search_entities("BRCA", pool)
#' results <- search_entities("autism", pool)
#' }
#'
#' @export
search_entities <- function(query, pool) {
  # Validate query length
  if (missing(query) || is.null(query) || nchar(trimws(query)) < 2) {
    stop("Search query must be at least 2 characters")
  }

  # Build search pattern
  search_pattern <- paste0("%", query, "%")

  # Execute search
  pool %>%
    tbl("ndd_entity_view") %>%
    filter(
      symbol %like% !!search_pattern |
      disease_ontology_name %like% !!search_pattern
    ) %>%
    select(entity_id, hgnc_id, symbol, disease_ontology_id_version,
           disease_ontology_name) %>%
    head(100) %>%
    collect()
}


#' Search genes by HGNC ID or symbol
#'
#' Performs fuzzy search across gene list (non-alt loci).
#' Returns up to 100 results ordered by relevance.
#'
#' @param query Character search query string
#' @param pool Database connection pool
#' @return Tibble of matching genes
#'
#' @details
#' - Minimum query length: 2 characters
#' - Uses LIKE pattern matching with wildcards
#' - Searches HGNC ID and gene symbol
#' - Results limited to 100 records
#'
#' @examples
#' \dontrun{
#' results <- search_genes("BRCA", pool)
#' results <- search_genes("HGNC:1100", pool)
#' }
#'
#' @export
search_genes <- function(query, pool) {
  # Validate query length
  if (missing(query) || is.null(query) || nchar(trimws(query)) < 2) {
    stop("Search query must be at least 2 characters")
  }

  # Build search pattern
  search_pattern <- paste0("%", query, "%")

  # Execute search
  pool %>%
    tbl("search_non_alt_loci_view") %>%
    filter(result %like% !!search_pattern) %>%
    select(hgnc_id, symbol, name, search) %>%
    head(100) %>%
    collect()
}


#' Search disease ontology terms by ID or name
#'
#' Performs fuzzy search across disease ontology set.
#' Returns up to 100 results ordered by relevance.
#'
#' @param query Character search query string
#' @param pool Database connection pool
#' @return Tibble of matching disease ontology terms
#'
#' @details
#' - Minimum query length: 2 characters
#' - Uses LIKE pattern matching with wildcards
#' - Searches disease ontology ID and name
#' - Results limited to 100 records
#'
#' @examples
#' \dontrun{
#' results <- search_phenotypes("MONDO:0005148", pool)
#' results <- search_phenotypes("diabetes", pool)
#' }
#'
#' @export
search_phenotypes <- function(query, pool) {
  # Validate query length
  if (missing(query) || is.null(query) || nchar(trimws(query)) < 2) {
    stop("Search query must be at least 2 characters")
  }

  # Build search pattern
  search_pattern <- paste0("%", query, "%")

  # Execute search
  pool %>%
    tbl("search_disease_ontology_set") %>%
    filter(result %like% !!search_pattern) %>%
    select(disease_ontology_id_version, disease_ontology_id,
           disease_ontology_name, result, search) %>%
    head(100) %>%
    collect()
}


#' Search mode of inheritance terms
#'
#' Performs fuzzy search across mode of inheritance list.
#' Returns up to 100 results ordered by relevance.
#'
#' @param query Character search query string
#' @param pool Database connection pool
#' @return Tibble of matching mode of inheritance terms
#'
#' @details
#' - Minimum query length: 2 characters
#' - Uses LIKE pattern matching with wildcards
#' - Searches HPO mode of inheritance terms
#' - Results limited to 100 records
#'
#' @examples
#' \dontrun{
#' results <- search_inheritance("autosomal", pool)
#' results <- search_inheritance("recessive", pool)
#' }
#'
#' @export
search_inheritance <- function(query, pool) {
  # Validate query length
  if (missing(query) || is.null(query) || nchar(trimws(query)) < 2) {
    stop("Search query must be at least 2 characters")
  }

  # Build search pattern
  search_pattern <- paste0("%", query, "%")

  # Execute search
  pool %>%
    tbl("search_mode_of_inheritance_list_view") %>%
    filter(result %like% !!search_pattern) %>%
    select(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name,
           result, search, sort) %>%
    head(100) %>%
    collect()
}
